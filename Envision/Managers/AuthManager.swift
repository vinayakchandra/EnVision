import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum AuthManagerError: LocalizedError {
    case missingGoogleClientID
    case missingGoogleIDToken
    case missingGoogleURLScheme
    case invalidGoogleURLScheme(expected: String)
    case invalidEmailOrPassword
    case emailUsesDifferentProvider
    case resetEmailNotFound
    case resetInvalidEmail

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
        case .resetEmailNotFound:
            return "No account found with this email."
        case .resetInvalidEmail:
            return "Enter a valid email address."
        }
    }
}

final class AuthManager {
    static let shared = AuthManager()

    private init() {}

    var isLoggedIn: Bool {
        Auth.auth().currentUser != nil
    }

    func signIn(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error {
                completion(.failure(self.mapEmailPasswordError(error)))
                return
            }

            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthManager", code: -1)))
                return
            }

            completion(.success(self.cacheLocalUser(from: user)))
        }
    }

    func signUp(name: String, email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthManager", code: -1)))
                return
            }

            let request = user.createProfileChangeRequest()
            request.displayName = name
            request.commitChanges { commitError in
                if let commitError {
                    completion(.failure(commitError))
                    return
                }
                completion(.success(self.cacheLocalUser(from: user, fallbackName: name)))
            }
        }
    }

    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error {
                completion(.failure(self.mapPasswordResetError(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController, completion: @escaping (Result<UserModel, Error>) -> Void) {
        if let configError = googleConfigValidationError() {
            completion(.failure(configError))
            return
        }

        guard let clientID = resolvedGoogleClientID() else {
            completion(.failure(AuthManagerError.missingGoogleClientID))
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                completion(.failure(AuthManagerError.missingGoogleIDToken))
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { authResult, authError in
                if let authError {
                    completion(.failure(authError))
                    return
                }

                guard let firebaseUser = authResult?.user else {
                    completion(.failure(NSError(domain: "AuthManager", code: -1)))
                    return
                }

                completion(.success(self.cacheLocalUser(from: firebaseUser)))
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
        UserManager.shared.logout()
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
}
