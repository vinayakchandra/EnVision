import UIKit

final class MainTabBarController: UITabBarController, UITabBarControllerDelegate {
    private var furnitureHandoffOverlay: TabTourOverlayView?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        setupTabs()
        setupLiquidGlassEffect()
        setupTraitChangeObservation()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRoomTourDidComplete),
            name: .roomTourDidComplete,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .roomTourDidComplete, object: nil)
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

        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search , tag: 3) 

        viewControllers = [home, scan, profile, search]
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

    private func setupTraitChangeObservation() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (tabBarController: Self, _) in
                tabBarController.applyTabBarAppearance()
            }
        }
    }

    func showWelcomeTipIfNeeded() {
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
            NotificationCenter.default.post(name: .tourDidStart, object: nil)
        })

        alert.addAction(UIAlertAction(title: AppTips.welcome.dismissActionTitle, style: .cancel) { _ in
            TourManager.shared.markTipAsSeen(AppTips.welcome.id)
            TourManager.shared.skipTour()
        })

        present(alert, animated: true)
    }

    @objc private func handleRoomTourDidComplete() {
        guard !TourManager.shared.tourSkipped, !TourManager.shared.hasCompletedTour else { return }
        guard furnitureHandoffOverlay == nil else { return }
        showFurnitureHandoffOverlay()
    }

    private func showFurnitureHandoffOverlay() {
        guard let targetFrame = frameForTabItem(at: 1) else { return }

        let overlay = TabTourOverlayView(
            highlightFrame: targetFrame,
            title: "Next: Furniture Tips",
            message: "You're done with Room tips. Continue to My Furniture for the next guided steps."
        )
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onContinue = { [weak self] in
            guard let self else { return }
            self.selectedIndex = 1
            self.dismissFurnitureHandoffOverlay()
            NotificationCenter.default.post(name: .furnitureTourShouldStart, object: nil)
        }
        overlay.onDismiss = { [weak self] in
            self?.dismissFurnitureHandoffOverlay()
        }

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        furnitureHandoffOverlay = overlay
    }

    private func dismissFurnitureHandoffOverlay() {
        furnitureHandoffOverlay?.removeFromSuperview()
        furnitureHandoffOverlay = nil
    }

    private func frameForTabItem(at index: Int) -> CGRect? {
        guard let items = tabBar.items, items.indices.contains(index) else { return nil }

        let tabButtons = tabBar.subviews
            .filter { NSStringFromClass(type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }

        if tabButtons.indices.contains(index) {
            return tabBar.convert(tabButtons[index].frame, to: view)
        }

        let width = tabBar.bounds.width / CGFloat(max(items.count, 1))
        let fallback = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: tabBar.bounds.height)
        return tabBar.convert(fallback, to: view)
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        HapticsManager.shared.selection()
    }
}

private final class TabTourOverlayView: UIView {
    var onContinue: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let highlightFrame: CGRect
    private let maskLayer = CAShapeLayer()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start Furniture Tips", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = AppColors.accent
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.layer.cornerRadius = 12
        return button
    }()

    private let laterButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Later", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        return button
    }()

    init(highlightFrame: CGRect, title: String, message: String) {
        self.highlightFrame = highlightFrame
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        titleLabel.text = title
        messageLabel.text = message
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateMaskPath()
    }

    private func setupUI() {
        let dimView = UIView()
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        addSubview(dimView)

        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        addSubview(card)

        card.contentView.addSubview(titleLabel)
        card.contentView.addSubview(messageLabel)
        card.contentView.addSubview(continueButton)
        card.contentView.addSubview(laterButton)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -100),

            titleLabel.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            continueButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            continueButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            continueButton.heightAnchor.constraint(equalToConstant: 44),

            laterButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 8),
            laterButton.centerXAnchor.constraint(equalTo: continueButton.centerXAnchor),
            laterButton.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -12),
        ])

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        laterButton.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)

        dimView.layer.mask = maskLayer
    }

    private func updateMaskPath() {
        let path = UIBezierPath(rect: bounds)
        let spotlightInset: CGFloat = -8
        let hole = UIBezierPath(roundedRect: highlightFrame.insetBy(dx: spotlightInset, dy: spotlightInset), cornerRadius: 16)
        path.append(hole)
        path.usesEvenOddFillRule = true
        maskLayer.frame = bounds
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
    }

    @objc private func continueTapped() {
        onContinue?()
    }

    @objc private func laterTapped() {
        onDismiss?()
    }
}
