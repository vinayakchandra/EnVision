import UIKit

final class SplashViewController: UIViewController {

    private let logoImageView = UIImageView(image: UIImage(named: "sofaLogo"))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.background
        setupLogo()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.navigateNext()
        }
    }

    private func setupLogo() {
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            logoImageView.widthAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func navigateNext() {
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")

        if !hasOnboarded {
            self.setAsRoot(OnboardingViewController())
        } else if !isLoggedIn {
            self.setAsRoot(LoginViewController())
        } else {
            self.setAsRoot(MainTabBarController())
        }
    }
}
