import UIKit

final class LoginViewController: UIViewController {
    
    private let logoImageView = UIImageView(image: UIImage(named: "sofaLogo"))
    private let titleLabel = UILabel()
    private let appleButton = UIButton(type: .system)
    private let googleButton = UIButton(type: .system)
    private let forgotPasswordButton = UIButton(type: .system)
    private let createAccountButton = UIButton(type: .system)
    private let continueButton = PrimaryButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.background
        
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.text = "EnVision"
        titleLabel.font = AppFonts.bold(22)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        
        configureOAuthButton(appleButton, title: "Sign in with Apple", icon: "applelogo")
        configureOAuthButton(googleButton, title: "Sign in with Google", icon: "globe")
        
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.tintColor = AppColors.textSecondary
        forgotPasswordButton.titleLabel?.font = AppFonts.regular(14)
        forgotPasswordButton.addTarget(self, action: #selector(forgotTapped), for: .touchUpInside)
        
        createAccountButton.setTitle("Create Account", for: .normal)
        createAccountButton.tintColor = AppColors.accent
        createAccountButton.titleLabel?.font = AppFonts.semibold(15)
        createAccountButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        
        continueButton.setTitle("Continue", for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [appleButton, googleButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 15
        
        let linkStack = UIStackView(arrangedSubviews: [forgotPasswordButton, createAccountButton])
        linkStack.axis = .horizontal
        linkStack.spacing = 10
        linkStack.alignment = .center
        
        let stack = UIStackView(arrangedSubviews: [logoImageView, titleLabel, buttonStack, linkStack])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stack)
        view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 90),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -25),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -35)
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
    
    @objc private func forgotTapped() {
        presentSlideUp(ForgotPasswordViewController())
    }
    
    @objc private func createTapped() {
        presentSlideUp(SignupViewController())
    }
    
    @objc private func continueTapped() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        setAsRoot(MainTabBarController())
    }

}
