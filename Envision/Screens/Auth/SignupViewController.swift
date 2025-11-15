import UIKit

final class SignupViewController: UIViewController {

    private let logoImageView = UIImageView(image: UIImage(named: "sofaLogo"))
    private let titleLabel = UILabel()
    private let nameField = CustomTextField()
    private let emailField = CustomTextField()
    private let passwordField = CustomTextField()
    private let createAccountButton = PrimaryButton()
    private let orLabel = UILabel()
    private let dividerLeft = UIView()
    private let dividerRight = UIView()
    private let appleButton = UIButton(type: .system)
    private let googleButton = UIButton(type: .system)
    private let backToLoginButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = AppColors.background

        // Logo
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = "EnVision"
        titleLabel.font = AppFonts.bold(22)
        titleLabel.textAlignment = .center
        titleLabel.textColor = AppColors.textPrimary

        // Text Fields
        nameField.placeholder = "Enter your name"
        emailField.placeholder = "Enter your email"
        passwordField.placeholder = "Enter your password"

        // Primary Button
        createAccountButton.setTitle("Create Account", for: .normal)
        createAccountButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)

        // Divider “or”
        dividerLeft.backgroundColor = .systemGray4
        dividerRight.backgroundColor = .systemGray4
        orLabel.text = "or"
        orLabel.font = AppFonts.regular(15)
        orLabel.textColor = AppColors.textSecondary
        orLabel.textAlignment = .center

        let dividerStack = UIStackView(arrangedSubviews: [dividerLeft, orLabel, dividerRight])
        dividerStack.axis = .horizontal
        dividerStack.spacing = 8
        dividerStack.distribution = .fillEqually

        // OAuth Buttons
        configureOAuthButton(appleButton, title: "Sign up with Apple", icon: "applelogo")
        configureOAuthButton(googleButton, title: "Sign up with Google", icon: "globe")

        // Back to Login
        backToLoginButton.setTitle("← Back to Login", for: .normal)
        backToLoginButton.tintColor = AppColors.accent
        backToLoginButton.titleLabel?.font = AppFonts.regular(15)
        backToLoginButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // Stack Setup
        let stack = UIStackView(arrangedSubviews: [
            logoImageView,
            titleLabel,
            nameField,
            emailField,
            passwordField,
            createAccountButton,
            dividerStack,
            appleButton,
            googleButton,
            backToLoginButton
        ])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 100),
            dividerLeft.heightAnchor.constraint(equalToConstant: 1),
            dividerRight.heightAnchor.constraint(equalToConstant: 1),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func configureOAuthButton(_ button: UIButton, title: String, icon: String) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColors.backgroundSecondary
        config.baseForegroundColor = AppColors.textPrimary
        config.cornerStyle = .capsule
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.imagePlacement = .leading
        button.configuration = config
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.layer.borderWidth = 1
        button.layer.borderColor = AppColors.accent.withAlphaComponent(0.2).cgColor
        button.layer.cornerRadius = 22
    }

    @objc private func createTapped() {
        print("Account created successfully")
    }
    
    @objc private func backTapped() {
        dismiss(animated: true)
    }
    @objc private func createAccountTapped() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        setAsRoot(MainTabBarController())
    }

}
