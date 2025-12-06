import UIKit

final class SignupViewController: UIViewController {

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

    private let appleButton = SocialButton(
        title: "Sign up with Apple",
        image: UIImage(systemName: "apple.logo")
    )

    private let googleButton = SocialButton(
        title: "Sign in with Google",
        image: UIImage(named: "google_icon")
    )

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
            logoImageView.heightAnchor.constraint(equalToConstant: 110),

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

            googleButton.topAnchor.constraint(equalTo: appleButton.bottomAnchor, constant: 18),
            googleButton.leadingAnchor.constraint(equalTo: appleButton.leadingAnchor),
            googleButton.trailingAnchor.constraint(equalTo: appleButton.trailingAnchor),
            googleButton.heightAnchor.constraint(equalToConstant: 50),
            googleButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50)
        ])
    }

    // MARK: - Actions
    private func setupActions() {
        createButton.addTarget(self, action: #selector(handleSignup), for: .touchUpInside)
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

        // MARK: Navigate to next screen (REPLACE LATER)
        let homeVC = MainTabBarController()
        homeVC.modalPresentationStyle = .fullScreen
        present(homeVC, animated: true)
    }

    private func showError(_ msg: String) {
        errorLabel.text = msg
        UIView.animate(withDuration: 0.25) {
            self.errorLabel.alpha = 1
        }
    }
}
