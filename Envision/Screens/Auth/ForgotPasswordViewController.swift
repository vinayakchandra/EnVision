import UIKit

final class ForgotPasswordViewController: UIViewController {
    
    private let titleLabel = UILabel()
    private let emailField = CustomTextField()
    private let newPasswordField = CustomTextField()
    private let confirmPasswordField = CustomTextField()
    private let continueButton = PrimaryButton()
    private let backButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = AppColors.background
        
        titleLabel.text = "Reset Password"
        titleLabel.font = AppFonts.bold(22)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.textAlignment = .center
        
        emailField.placeholder = "Enter your email"
        newPasswordField.placeholder = "Enter new password"
        confirmPasswordField.placeholder = "Confirm password"
        
        continueButton.setTitle("Continue", for: .normal)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        
        backButton.setTitle("← Back to Login", for: .normal)
        backButton.tintColor = AppColors.accent
        backButton.titleLabel?.font = AppFonts.regular(15)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, emailField, newPasswordField, confirmPasswordField, continueButton, backButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func continueTapped() {
        print("Password reset successful")
    }
    
    @objc private func backTapped() {
        dismiss(animated: true)
    }
}
