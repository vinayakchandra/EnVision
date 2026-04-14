import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import CryptoKit

enum AuthManagerError: LocalizedError {
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingGoogleURLScheme
    case invalidGoogleURLScheme(expected: String)
    case invalidEmailOrPassword
    case emailUsesDifferentProvider
    case signupEmailAlreadyInUse
    case signupWeakPassword
    case signupInvalidEmail
    case resetEmailNotFound
    case resetInvalidEmail
    case missingAppleIdentityToken
    case invalidAppleIdentityToken
    case appleCredentialMissing
    case requiresRecentLogin

    var errorDescription: String? {
        switch self {
        case .missingGoogleClientID:
            return "Google Sign-In is not configured. Add CLIENT_ID to GoogleService-Info.plist."
        case .missingGoogleIDToken:
            return "Unable to get Google ID token."
        case .missingGoogleURLScheme:
            return "Google callback URL scheme is missing from Info.plist."
        case .invalidGoogleURLScheme(let expected):
            return "Google callback URL scheme mismatch. Expected: \(expected)"
        case .invalidEmailOrPassword:
            return "Invalid email or password."
        case .emailUsesDifferentProvider:
            return "This email is linked to a different sign-in method (likely Google). Use Google Sign-In or reset password."
        case .signupEmailAlreadyInUse:
            return "An account already exists with this email. Sign in instead or reset your password."
        case .signupWeakPassword:
            return "Password is too weak. Use at least 8 characters with uppercase letters and numbers."
        case .signupInvalidEmail:
            return "Please enter a valid email address."
        case .resetEmailNotFound:
            return "No account found with this email."
        case .resetInvalidEmail:
            return "Enter a valid email address."
        case .missingAppleIdentityToken:
            return "Unable to read Apple identity token."
        case .invalidAppleIdentityToken:
            return "Unable to decode Apple identity token."
        case .appleCredentialMissing:
            return "Unable to access your Apple sign-in credential."
        case .requiresRecentLogin:
            return "For security, please sign out and sign back in before deleting your account."
        }
    }
}

final class AuthManager {
    static let shared = AuthManager()
    private let hasSeenOnboardingKey = "hasSeenAppOnboarding"

    private init() {}

    private func authDebug(_ message: String) {
        #if DEBUG
        print("[AuthDebug] \(message)")
        #endif
    }

    var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }

    func signIn(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        authDebug("Email sign-in started for: \(email)")
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error {
                let nsError = error as NSError
                self.authDebug("Email sign-in failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                completion(.failure(self.mapEmailPasswordError(error)))
                return
            }

            guard let user = result?.user else {
                self.authDebug("Email sign-in failed: missing Firebase user in result.")
                completion(.failure(NSError(domain: "AuthManager", code: -1)))
                return
            }

            self.authDebug("Email sign-in success. uid=\(user.uid)")
            completion(.success(self.cacheLocalUser(from: user)))
        }
    }

    func signUp(name: String, email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        authDebug("Email sign-up started for: \(email)")
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error {
                let nsError = error as NSError
                self.authDebug("Email sign-up failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                completion(.failure(self.mapSignupError(error)))
                return
            }

            guard let user = result?.user else {
                self.authDebug("Email sign-up failed: missing Firebase user in result.")
                completion(.failure(NSError(domain: "AuthManager", code: -1)))
                return
            }

            let request = user.createProfileChangeRequest()
            request.displayName = name
            request.commitChanges { commitError in
                if let commitError {
                    let nsError = commitError as NSError
                    self.authDebug("Profile update after sign-up failed. domain=\(nsError.domain) code=\(nsError.code) message=\(commitError.localizedDescription)")
                    completion(.failure(commitError))
                    return
                }
                self.authDebug("Email sign-up success. uid=\(user.uid)")
                completion(.success(self.cacheLocalUser(from: user, fallbackName: name)))
            }
        }
    }

    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        authDebug("Password reset requested for: \(email)")
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error {
                let nsError = error as NSError
                self.authDebug("Password reset failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                completion(.failure(self.mapPasswordResetError(error)))
            } else {
                self.authDebug("Password reset email sent.")
                completion(.success(()))
            }
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController, completion: @escaping (Result<UserModel, Error>) -> Void) {
        authDebug("Google sign-in started.")
        if let configError = googleConfigValidationError() {
            authDebug("Google config validation failed: \(configError.localizedDescription)")
            completion(.failure(configError))
            return
        }

        guard let clientID = resolvedGoogleClientID() else {
            authDebug("Google sign-in failed: missing client ID.")
            completion(.failure(AuthManagerError.missingGoogleClientID))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error {
                let nsError = error as NSError
                self.authDebug("Google sign-in failed before Firebase. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.authDebug("Google sign-in failed: missing Google ID token.")
                completion(.failure(AuthManagerError.missingGoogleIDToken))
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { authResult, authError in
                if let authError {
                    let nsError = authError as NSError
                    self.authDebug("Google->Firebase sign-in failed. domain=\(nsError.domain) code=\(nsError.code) message=\(authError.localizedDescription)")
                    completion(.failure(authError))
                    return
                }

                guard let firebaseUser = authResult?.user else {
                    self.authDebug("Google->Firebase sign-in failed: missing Firebase user.")
                    completion(.failure(NSError(domain: "AuthManager", code: -1)))
                    return
                }

                self.authDebug("Google sign-in success. uid=\(firebaseUser.uid)")
                completion(.success(self.cacheLocalUser(from: firebaseUser)))
            }
        }
    }

    func signInWithApple(
        idTokenString: String,
        rawNonce: String,
        fullName: PersonNameComponents?,
        completion: @escaping (Result<UserModel, Error>) -> Void
    ) {
        authDebug("Apple->Firebase sign-in started. idTokenLength=\(idTokenString.count)")
        let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: rawNonce, fullName: fullName)

        Auth.auth().signIn(with: credential) { authResult, authError in
            if let authError {
                let nsError = authError as NSError
                self.authDebug("Apple->Firebase sign-in failed. domain=\(nsError.domain) code=\(nsError.code) message=\(authError.localizedDescription)")
                completion(.failure(authError))
                return
            }

            guard let firebaseUser = authResult?.user else {
                self.authDebug("Apple->Firebase sign-in failed: missing Firebase user.")
                completion(.failure(NSError(domain: "AuthManager", code: -1)))
                return
            }

            self.authDebug("Apple sign-in success. uid=\(firebaseUser.uid)")
            completion(.success(self.cacheLocalUser(from: firebaseUser)))
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        UserDefaults.standard.set(false, forKey: hasSeenOnboardingKey)
        UserManager.shared.logout()
    }

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user is signed in."])))
            return
        }

        authDebug("Delete account started. uid=\(user.uid)")

        user.delete { [self] error in
            if let error {
                let nsError = error as NSError
                self.authDebug("Delete account failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                if nsError.domain == AuthErrorDomain,
                   let code = AuthErrorCode(rawValue: nsError.code),
                   code == .requiresRecentLogin {
                    completion(.failure(AuthManagerError.requiresRecentLogin))
                } else {
                    completion(.failure(error))
                }
                return
            }

            self.authDebug("Account deleted successfully.")
            UserDefaults.standard.set(false, forKey: self.hasSeenOnboardingKey)
            UserManager.shared.logout()
            completion(.success(()))
        }
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private func cacheLocalUser(from firebaseUser: User, fallbackName: String? = nil) -> UserModel {
        let model = UserModel(
            id: firebaseUser.uid,
            name: firebaseUser.displayName
                ?? fallbackName
                ?? firebaseUser.email?.components(separatedBy: "@").first?.capitalized
                ?? "User",
            email: firebaseUser.email ?? ""
        )

        UserManager.shared.currentUser = model
        return model
    }

    private func resolvedGoogleClientID() -> String? {
        if let configured = FirebaseApp.app()?.options.clientID, !configured.isEmpty {
            return configured
        }

        if let infoClientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !infoClientID.isEmpty {
            return infoClientID
        }

        guard
            let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let clientID = dict["CLIENT_ID"] as? String,
            !clientID.isEmpty
        else {
            return nil
        }

        return clientID
    }

    private func googleConfigValidationError() -> AuthManagerError? {
        guard
            let googleInfoPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let googleInfo = NSDictionary(contentsOfFile: googleInfoPath),
            let reversedClientID = googleInfo["REVERSED_CLIENT_ID"] as? String,
            !reversedClientID.isEmpty
        else {
            return .missingGoogleClientID
        }

        guard
            let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        else {
            return .missingGoogleURLScheme
        }

        let allSchemes = urlTypes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }

        guard allSchemes.contains(reversedClientID) else {
            return .invalidGoogleURLScheme(expected: reversedClientID)
        }

        return nil
    }

    private func mapEmailPasswordError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .wrongPassword, .invalidEmail:
            return AuthManagerError.invalidEmailOrPassword
        case .invalidCredential, .userNotFound:
            return AuthManagerError.emailUsesDifferentProvider
        default:
            return error
        }
    }

    private func mapPasswordResetError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .invalidEmail:
            return AuthManagerError.resetInvalidEmail
        case .userNotFound:
            return AuthManagerError.resetEmailNotFound
        default:
            return error
        }
    }

    private func mapSignupError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }

        switch code {
        case .emailAlreadyInUse:
            return AuthManagerError.signupEmailAlreadyInUse
        case .weakPassword:
            return AuthManagerError.signupWeakPassword
        case .invalidEmail:
            return AuthManagerError.signupInvalidEmail
        case .credentialAlreadyInUse, .accountExistsWithDifferentCredential:
            return AuthManagerError.emailUsesDifferentProvider
        default:
            return error
        }
    }
}
