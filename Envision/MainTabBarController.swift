import UIKit
import TipKit
import SwiftUI

final class MainTabBarController: UITabBarController {
    
    private var tipHostingController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupLiquidGlassEffect()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 17.0, *) {
            showWelcomeTip()
        }
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
    
    @available(iOS 17.0, *)
    private func showWelcomeTip() {
        guard TourManager.shared.shouldShowTour() else { return }
        
        if let existing = tipHostingController {
            existing.willMove(toParent: nil)
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            tipHostingController = nil
        }
        
        let tip = WelcomeTip()
        
        let actionHandler: (Tip.Action) -> Void = { [weak self] action in
            guard let self = self else { return }
            switch action.id {
            case "start-tour":
                TourManager.shared.startTour()
                self.selectedIndex = 0
                self.dismissTip()
            case "skip":
                TourManager.shared.completeTour()
                self.dismissTip()
            default: break
            }
        }
        
        let tipView = TipView(tip, arrowEdge: .bottom) { action in
            actionHandler(action)
        }
        
        let hostingController = UIHostingController(rootView: tipView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = UIColor.clear
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: tabBar.topAnchor, constant: -20),
            hostingController.view.widthAnchor.constraint(lessThanOrEqualToConstant: 350)
        ])
        
        self.tipHostingController = hostingController
    }
    
    private func dismissTip() {
        if let existing = tipHostingController {
            existing.willMove(toParent: nil)
            existing.view.removeFromSuperview()
            existing.removeFromParent()
            tipHostingController = nil
        }
    }
}
