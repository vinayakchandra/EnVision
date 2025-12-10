import UIKit

final class LoginViewController: UIViewController {

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

    private let appleButton = SocialButton(title: "Sign in with Apple", image: UIImage(systemName: "apple.logo"))
    private let googleButton = SocialButton(title: "Sign in with Google", image: UIImage(named: "google_icon"))

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
         forgotPasswordButton, createAccountButton, appleButton, googleButton
        ].forEach { contentView.addSubview($0) }

        appleButton.tintColor = .black
        NSLayoutConstraint.activate([
                                        logoImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 40),
                                        logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                                        logoImageView.heightAnchor.constraint(equalToConstant: 110),

                                        titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 8),
                                        titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

                                        emailField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
                                        emailField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
                                        emailField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),

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

                                        forgotPasswordButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 18),
                                        forgotPasswordButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),

                                        createAccountButton.centerYAnchor.constraint(equalTo: forgotPasswordButton.centerYAnchor),
                                        createAccountButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),

                                        appleButton.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 28),
                                        appleButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
                                        appleButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
                                        appleButton.heightAnchor.constraint(equalToConstant: 50),

                                        googleButton.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 18),
                                        googleButton.leadingAnchor.constraint(equalTo: appleButton.leadingAnchor),
                                        googleButton.trailingAnchor.constraint(equalTo: appleButton.trailingAnchor),
                                        googleButton.heightAnchor.constraint(equalToConstant: 50),

                                        googleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
                                    ])
    }

    // MARK: - Actions
    private func setupActions() {
        continueButton.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        createAccountButton.addTarget(self, action: #selector(goToSignup), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(goToForgotPassword), for: .touchUpInside)
    }

    @objc private func handleLogin() {
        let email = emailField.textField.text ?? ""
        let password = passwordField.textField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else { showError("All fields are required.") ; return }
        guard email.isValidEmail else { showError("Invalid email format.") ; return }

        // Hide any previous error
        errorLabel.alpha = 0

        // Login using UserManager
        UserManager.shared.login(email: email, password: password) { [weak self] result in
            switch result {
            case .success(_):
                // Switch to main app (Tab Bar) post-login
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let sceneDelegate = scene.delegate as? SceneDelegate {
                    sceneDelegate.switchToMainApp()
                } else {
                    // Fallback: present tab bar modally
                    let tab = MainTabBarController()
                    tab.modalPresentationStyle = .fullScreen
                    self?.present(tab, animated: true)
                }
            case .failure(let error):
                self?.showError(error.localizedDescription)
            }
        }
    }

    @objc private func goToSignup() {
        navigationController?.pushViewController(SignupViewController(), animated: true)
    }

    @objc private func goToForgotPassword() {
        navigationController?.pushViewController(ForgotPasswordViewController(), animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }


    private func showError(_ message: String) {
        errorLabel.text = message
        UIView.animate(withDuration: 0.25) { self.errorLabel.alpha = 1 }
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

