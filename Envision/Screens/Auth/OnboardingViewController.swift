import UIKit

final class OnboardingViewController: UIViewController {
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "sofaLogo"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "What we do..."
        label.font = AppFonts.bold(22)
        label.textAlignment = .center
        label.textColor = AppColors.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let featureStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let continueButton: PrimaryButton = {
        let button = PrimaryButton()
        button.setTitle("Continue", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupUI()
    }
    
    private func setupUI() {
        view.addSubview(logoImageView)
        view.addSubview(titleLabel)
        view.addSubview(featureStack)
        view.addSubview(continueButton)
        
        // Add features
        addFeature(title: "Scan Your Room", desc: "Turn your space into 3D model with AR.")
        addFeature(title: "Capture Any Furniture", desc: "Turn real items from any store into 3D models.")
        addFeature(title: "Visualize with Confidence", desc: "Know it fits perfectly before you buy.")
        
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            featureStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            featureStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 35),
            featureStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -35),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 25),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -25)
        ])
    }
    
    private func addFeature(title: String, desc: String) {
        let iconView = UIImageView(image: UIImage(systemName: "checkmark.circle"))
        iconView.tintColor = AppColors.accent
        iconView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFonts.semibold(17)
        titleLabel.textColor = AppColors.textPrimary
        
        let descLabel = UILabel()
        descLabel.text = desc
        descLabel.font = AppFonts.regular(15)
        descLabel.textColor = AppColors.textSecondary
        descLabel.numberOfLines = 0
        
        let vStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        vStack.axis = .vertical
        vStack.spacing = 3
        
        let hStack = UIStackView(arrangedSubviews: [iconView, vStack])
        hStack.axis = .horizontal
        hStack.spacing = 12
        hStack.alignment = .top
        
        featureStack.addArrangedSubview(hStack)
    }
    
    @objc private func continueTapped() {
        let loginVC = LoginViewController()
        loginVC.modalPresentationStyle = .fullScreen
        loginVC.modalTransitionStyle = .coverVertical
        present(loginVC, animated: true)
    }
}
