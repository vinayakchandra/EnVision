import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupLiquidGlassEffect()
    }

    private func setupTabs() {
        let home = UINavigationController(rootViewController: RoomsViewController())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))

        let scan = UINavigationController(rootViewController: ScanFurnitureViewController())
        scan.tabBarItem = UITabBarItem(title: "Scan", image: UIImage(systemName: "camera.viewfinder"), selectedImage: UIImage(systemName: "camera.viewfinder"))

        let shop = UINavigationController(rootViewController: ShopViewController())
        shop.tabBarItem = UITabBarItem(title: "Shop", image: UIImage(systemName: "bag"), selectedImage: UIImage(systemName: "bag.fill"))

        let profile = UINavigationController(rootViewController: ProfileViewController())
        profile.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), selectedImage: UIImage(systemName: "person.fill"))

        viewControllers = [home, scan, shop, profile]
        tabBar.tintColor = AppColors.accent
    }

    private func setupLiquidGlassEffect() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.8)

        tabBar.layer.cornerRadius = 30
        tabBar.layer.masksToBounds = true
        tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        // Add subtle shadow
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.1
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        tabBar.layer.shadowRadius = 10
        
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }
}
