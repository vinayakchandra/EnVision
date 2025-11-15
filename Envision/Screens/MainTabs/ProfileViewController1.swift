import UIKit

final class ProfileViewController1: UIViewController {

    private let avatarView = UIImageView(image: UIImage(systemName: "person.crop.circle"))
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let logoutButton = PrimaryButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Profile"
        view.backgroundColor = AppColors.background
        
        avatarView.tintColor = AppColors.accent
        avatarView.contentMode = .scaleAspectFit
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        
        nameLabel.text = "John Doe"
        nameLabel.font = AppFonts.bold(20)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.textAlignment = .center
        
        emailLabel.text = "john@example.com"
        emailLabel.font = AppFonts.regular(16)
        emailLabel.textColor = AppColors.textSecondary
        emailLabel.textAlignment = .center
        
        logoutButton.setTitle("Log Out", for: .normal)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        
        [avatarView, nameLabel, emailLabel, logoutButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            avatarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarView.heightAnchor.constraint(equalToConstant: 100),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            
            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 20),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            emailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logoutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            logoutButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            logoutButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            logoutButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func logoutTapped() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        setAsRoot(LoginViewController())
    }

}
