import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupLiquidGlassEffect()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showWelcomeTipIfNeeded()
    }

    private func setupTabs() {
//        let home = UINavigationController(rootViewController: RoomsViewController())
        let home = UINavigationController(rootViewController: MyRoomsViewController())
        home.tabBarItem = UITabBarItem(title: "My Rooms", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))

        let scan = UINavigationController(rootViewController: ScanFurnitureViewController())
        scan.tabBarItem = UITabBarItem(title: "My Furniture", image: UIImage(named: "sofa.viewfinder"), selectedImage: UIImage(named: "custom.sofafill.viewfinder"))

//        let shop = UINavigationController(rootViewController: ShopViewController())
//        shop.tabBarItem = UITabBarItem(title: "Shop", image: UIImage(systemName: "bag"), selectedImage: UIImage(systemName: "bag.fill"))

        let profile = UINavigationController(rootViewController: ProfileViewController())
        profile.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), selectedImage: UIImage(systemName: "person.fill"))

        viewControllers = [home, scan, profile]
        tabBar.tintColor = AppColors.accent
    }

    private func setupLiquidGlassEffect() {
        applyTabBarAppearance()
    }

    private func applyTabBarAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = isDark
            ? UIColor.black.withAlphaComponent(0.6)
            : UIColor.white.withAlphaComponent(0.8)

        tabBar.layer.cornerRadius = 30
        tabBar.layer.masksToBounds = true
        tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = isDark ? 0.3 : 0.1
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        tabBar.layer.shadowRadius = 10

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            applyTabBarAppearance()
        }
    }

    private func showWelcomeTipIfNeeded() {
        guard !TourManager.shared.hasSeen(tipID: AppTips.welcome.id) else { return }
        guard !TourManager.shared.tourSkipped, !TourManager.shared.hasCompletedTour else { return }
        guard presentedViewController == nil else { return }

        let alert = UIAlertController(
            title: AppTips.welcome.title,
            message: AppTips.welcome.message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: AppTips.welcome.primaryActionTitle, style: .default) { _ in
            TourManager.shared.startTour()
            TourManager.shared.markTipAsSeen(AppTips.welcome.id)
        })

        alert.addAction(UIAlertAction(title: AppTips.welcome.dismissActionTitle, style: .cancel) { _ in
            TourManager.shared.markTipAsSeen(AppTips.welcome.id)
            TourManager.shared.skipTour()
        })

        present(alert, animated: true)
    }
}
