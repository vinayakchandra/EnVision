import UIKit
import AuthenticationServices

final class LoginViewController: UIViewController {
    private func authDebug(_ message: String) {
        #if DEBUG
        print("[AuthDebug][LoginVC] \(message)")
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

    private let emailField = ModernTextField(placeholder: "Enter your email")
    private let passwordField = ModernTextField(placeholder: "Enter your password", secure: true)

    private let errorLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .systemRed
        lbl.font = .systemFont(ofSize: 14)
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.alpha = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let continueButton = PrimaryButton1(title: "Continue")

    private let forgotPasswordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Forgot password?", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let createAccountButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Create Account", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let appleButtonContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let googleButton = SocialButton(title: "Sign in with Google", image: UIImage(named: "google_icon"))
    private var currentAppleNonce: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        emailField.textField.delegate = self
        passwordField.textField.delegate = self

        emailField.textField.returnKeyType = .next
        passwordField.textField.returnKeyType = .done


        setupScrollView()
        setupUI()
        setupActions()
        refreshAppleButtonStyle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    // MARK: - Layout
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.keyboardDismissMode = .onDrag

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

    private func setupUI() {
        [logoImageView, titleLabel, emailField, passwordField, errorLabel, continueButton,
         forgotPasswordButton, createAccountButton, appleButtonContainer, googleButton
        ].forEach { contentView.addSubview($0) }
        NSLayoutConstraint.activate([
                                        logoImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 40),
                                        logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                        logoImageView.heightAnchor.constraint(equalToConstant: 160),

                                        titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 8),
                                        titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        emailField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
                                        emailField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        passwordField.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 18),
                                        passwordField.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
                                        passwordField.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),

                                        errorLabel.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 4),
                                        errorLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                        errorLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.8),

                                        continueButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
                                        continueButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
                                        continueButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
                                        continueButton.heightAnchor.constraint(equalToConstant: 54),

                                        createAccountButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 18),
                                        createAccountButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),

                                        forgotPasswordButton.centerYAnchor.constraint(equalTo: createAccountButton.centerYAnchor),
                                        forgotPasswordButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),

                                        appleButtonContainer.topAnchor.constraint(equalTo: createAccountButton.bottomAnchor, constant: 28),
                                        appleButtonContainer.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
                                        appleButtonContainer.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
                                        appleButtonContainer.heightAnchor.constraint(equalToConstant: 50),

                                        googleButton.topAnchor.constraint(equalTo: appleButtonContainer.bottomAnchor, constant: 14),
                                        googleButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
                                        googleButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
                                        googleButton.heightAnchor.constraint(equalToConstant: 50),

                                        googleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
                                    ])

        let preferredWidth = emailField.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -60)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
        emailField.widthAnchor.constraint(lessThanOrEqualToConstant: 460).isActive = true
    }

    // MARK: - Actions
    private func setupActions() {
        continueButton.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        createAccountButton.addTarget(self, action: #selector(goToSignup), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(goToForgotPassword), for: .touchUpInside)
        googleButton.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)
    }

    @objc private func handleLogin() {
        let email = emailField.textField.text ?? ""
        let password = passwordField.textField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else { showError("All fields are required.") ; return }
        guard email.isValidEmail else { showError("Invalid email format.") ; return }

        // Hide any previous error
        errorLabel.alpha = 0

        AuthManager.shared.signIn(email: email, password: password) { [weak self] result in
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
        appleButtonContainer.isUserInteractionEnabled = false

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

    @objc private func goToSignup() {
        HapticsManager.shared.selection()
        navigationController?.pushViewController(SignupViewController(), animated: true)
    }

    @objc private func goToForgotPassword() {
        HapticsManager.shared.selection()
        navigationController?.pushViewController(ForgotPasswordViewController(), animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }


    private func refreshAppleButtonStyle() {
        appleButtonContainer.subviews.forEach { $0.removeFromSuperview() }
        let style: ASAuthorizationAppleIDButton.Style = traitCollection.userInterfaceStyle == .dark ? .white : .black
        let btn = ASAuthorizationAppleIDButton(type: .signIn, style: style)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.cornerRadius = 25
        btn.addTarget(self, action: #selector(handleAppleSignIn), for: .touchUpInside)
        appleButtonContainer.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: appleButtonContainer.topAnchor),
            btn.leadingAnchor.constraint(equalTo: appleButtonContainer.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: appleButtonContainer.trailingAnchor),
            btn.bottomAnchor.constraint(equalTo: appleButtonContainer.bottomAnchor),
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            refreshAppleButtonStyle()
        }
    }

    private func showError(_ message: String) {
        HapticsManager.shared.error()
        errorLabel.text = message
        UIView.animate(withDuration: 0.25) { self.errorLabel.alpha = 1 }
    }

    private func goToMainApp() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = scene.delegate as? SceneDelegate {
            sceneDelegate.switchToMainApp()
        } else {
            let tab = MainTabBarController()
            tab.modalPresentationStyle = .fullScreen
            present(tab, animated: true)
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

extension LoginViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { appleButtonContainer.isUserInteractionEnabled = true }
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
        appleButtonContainer.isUserInteractionEnabled = true
        let nsError = error as NSError
        authDebug("Apple authorization failed before Firebase. domain=\(nsError.domain) code=\(nsError.code) message=\(error.localizedDescription)")
        showError(error.localizedDescription)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}


extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField.textField {
            passwordField.textField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
