import UIKit
import AuthenticationServices

final class SignupViewController: UIViewController {
    private func authDebug(_ message: String) {
        #if DEBUG
        print("[AuthDebug][SignupVC] \(message)")
        #endif
    }

    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "envision"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "EnVision"
        lbl.font = .systemFont(ofSize: 34, weight: .bold)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - TextFields
    private let nameField = ModernTextField(placeholder: "Enter your name")
    private let emailField = ModernTextField(placeholder: "Enter your email")
    private let passwordField = ModernTextField(placeholder: "Enter your password", secure: true)
    private let confirmField = ModernTextField(placeholder: "Confirm your password", secure: true)

    // MARK: Error Label
    private let errorLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .systemRed
        lbl.font = .systemFont(ofSize: 14)
        lbl.numberOfLines = 0
        lbl.alpha = 0
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: Buttons
    private let createButton = PrimaryButton1(title: "Create Account")

    private let orLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "or"
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let continueLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Continue with"
        lbl.font = .systemFont(ofSize: 15)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private lazy var appleButton: ASAuthorizationAppleIDButton = {
        let btn = ASAuthorizationAppleIDButton(type: .signUp, style: .black)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.cornerRadius = 25
        return btn
    }()

    private let googleButton = SocialButton(
        title: "Sign in with Google",
        image: UIImage(named: "google_icon")
    )
    private var currentAppleNonce: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        setupScrollView()
        setupUI()
        setupActions()
    }

    // MARK: - Scroll View
    private func setupScrollView() {
        scrollView.backgroundColor = .clear
        contentView.backgroundColor = .clear

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
                                        scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                                        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                                        contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                                        contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                                        contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                                        contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                                        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
                                    ])
    }

    // MARK: - UI Layout
    private func setupUI() {
        [
            logoImageView, titleLabel,
            nameField, emailField, passwordField, confirmField,
            errorLabel, createButton,
            orLabel, continueLabel,
            appleButton, googleButton
        ].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
                                        logoImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 40),
                                        logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                        logoImageView.heightAnchor.constraint(equalToConstant: 160),

                                        titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 10),
                                        titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        nameField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
                                        nameField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
                                        nameField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),

                                        emailField.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 14),
                                        emailField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        emailField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),

                                        passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 14),
                                        passwordField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        passwordField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),

                                        confirmField.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 14),
                                        confirmField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        confirmField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),

                                        errorLabel.topAnchor.constraint(equalTo: confirmField.bottomAnchor, constant: 4),
                                        errorLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                        errorLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.85),

                                        createButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
                                        createButton.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        createButton.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),
                                        createButton.heightAnchor.constraint(equalToConstant: 54),

                                        orLabel.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 22),
                                        orLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        continueLabel.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 4),
                                        continueLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        appleButton.topAnchor.constraint(equalTo: continueLabel.bottomAnchor, constant: 28),
                                        appleButton.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        appleButton.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),
                                        appleButton.heightAnchor.constraint(equalToConstant: 50),

                                        googleButton.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 14),
                                        googleButton.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
                                        googleButton.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),
                                        googleButton.heightAnchor.constraint(equalToConstant: 50),
                                        googleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
                                    ])
    }

    // MARK: - Actions
    private func setupActions() {
        createButton.addTarget(self, action: #selector(handleSignup), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(handleAppleSignIn), for: .touchUpInside)
        googleButton.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)
    }

    // MARK: - Signup Logic
    @objc private func handleSignup() {
        let name = nameField.textField.text ?? ""
        let email = emailField.textField.text ?? ""
        let password = passwordField.textField.text ?? ""
        let confirm = confirmField.textField.text ?? ""

        guard !name.isEmpty, !email.isEmpty, !password.isEmpty, !confirm.isEmpty else {
            return showError("All fields are required.")
        }
        guard email.isValidEmail else {
            return showError("Please enter a valid email address.")
        }
        guard password.isStrongPassword else {
            return showError("Password must be 8+ characters, 1 uppercase, 1 number.")
        }
        guard password == confirm else {
            return showError("Passwords do not match.")
        }

        errorLabel.alpha = 0

        AuthManager.shared.signUp(name: name, email: email, password: password) { [weak self] result in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    HapticsManager.shared.success()
                    self?.goToMainApp()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func handleGoogleSignIn() {
        authDebug("Google button tapped.")
        HapticsManager.shared.impactLight()
        errorLabel.alpha = 0
        googleButton.isEnabled = false

        AuthManager.shared.signInWithGoogle(presenting: self) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.authDebug("Google sign-in completed successfully.")
                    HapticsManager.shared.success()
                    self?.googleButton.isEnabled = true
                    self?.goToMainApp()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    self?.authDebug("Google sign-in failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                    self?.googleButton.isEnabled = true
                    self?.showError(error.localizedDescription)
                    self?.showGoogleSignInErrorAlert(error)
                }
            }
        }
    }

    @objc private func handleAppleSignIn() {
        authDebug("Apple button tapped.")
        HapticsManager.shared.impactLight()
        errorLabel.alpha = 0
        appleButton.isEnabled = false

        let nonce = AuthManager.shared.randomNonceString()
        currentAppleNonce = nonce
        authDebug("Generated Apple nonce.")

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthManager.shared.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        authDebug("Apple authorization request started.")
    }

    private func showError(_ msg: String) {
        HapticsManager.shared.error()
        errorLabel.text = msg
        UIView.animate(withDuration: 0.25) {
            self.errorLabel.alpha = 1
        }
    }

    private func goToMainApp() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.switchToMainApp()
        } else {
            let homeVC = MainTabBarController()
            homeVC.modalPresentationStyle = .fullScreen
            present(homeVC, animated: true)
        }
    }

    private func showGoogleSignInErrorAlert(_ error: Error) {
        let nsError = error as NSError
        let message = "\(error.localizedDescription)\n\nDomain: \(nsError.domain)\nCode: \(nsError.code)"

        let alert = UIAlertController(
            title: "Google Sign-In Failed",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension SignupViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { appleButton.isEnabled = true }
        authDebug("Apple authorization completed.")

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authDebug("Apple credential cast failed.")
            showError(AuthManagerError.appleCredentialMissing.localizedDescription)
            return
        }

        guard let nonce = currentAppleNonce else {
            authDebug("Missing stored nonce.")
            showError("Apple sign-in state is invalid. Try again.")
            return
        }

        guard let appleIDToken = appleIDCredential.identityToken else {
            authDebug("Missing Apple identity token.")
            showError(AuthManagerError.missingAppleIdentityToken.localizedDescription)
            return
        }

        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            authDebug("Apple identity token UTF-8 decode failed.")
            showError(AuthManagerError.invalidAppleIdentityToken.localizedDescription)
            return
        }

        AuthManager.shared.signInWithApple(
            idTokenString: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.authDebug("Apple sign-in completed successfully.")
                    HapticsManager.shared.success()
                    self?.goToMainApp()
                case .failure(let error):
                    let nsError = error as NSError
                    self?.authDebug("Apple sign-in failed. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleButton.isEnabled = true
        let nsError = error as NSError
        authDebug("Apple authorization failed before Firebase. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
        showError(error.localizedDescription)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
