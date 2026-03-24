//
//  OnboardingController.swift
//  Envisionf2
//

import UIKit

class OnboardingController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    // MARK: - Properties

    private var pageVC: UIPageViewController!
    private var pages: [OnboardingPage] = []
    private var currentIndex = 0
    private var orbsSetup = false

    private let backgroundGradientLayer = CAGradientLayer()

    // All gradients derived from the app's primary accent #478F82
    private let pageGradients: [[CGColor]] = [
        // Page 1 — deep teal-green
        [UIColor(hex: "#0B1A18").cgColor, UIColor(hex: "#1A3832").cgColor, UIColor(hex: "#274F47").cgColor],
        // Page 2 — shifted slightly cooler
        [UIColor(hex: "#0E1B20").cgColor, UIColor(hex: "#1A3040").cgColor, UIColor(hex: "#254A4A").cgColor],
        // Page 3 — back to warm teal
        [UIColor(hex: "#0C1C1A").cgColor, UIColor(hex: "#1C3A34").cgColor, UIColor(hex: "#2E5448").cgColor]
    ]

    // MARK: - Custom Pill Indicator

    private var indicatorDots: [UIView] = []
    private var indicatorWidthConstraints: [NSLayoutConstraint] = []

    private let indicatorStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 7
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - UI

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = "Skip"
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.75)
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        btn.configuration = config
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 14
        btn.layer.cornerCurve = .continuous
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Continue", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        // Uses the app's actual primary accent color
        btn.backgroundColor = UIColor(hex: "#478F82")
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.layer.cornerRadius = 22
        btn.layer.cornerCurve = .continuous
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.shadowColor = UIColor(hex: "#478F82").cgColor
        btn.layer.shadowOpacity = 0.45
        btn.layer.shadowRadius = 16
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupPages()
        setupPageVC()
        setupUI()
        updateCTA()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pages.first?.playEntranceAnimation()
        animateCTAEntrance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
        guard !orbsSetup, view.bounds.width > 0 else { return }
        orbsSetup = true
        setupAmbientOrbs()
    }

    // MARK: - Background

    private func setupBackground() {
        backgroundGradientLayer.colors = pageGradients[0]
        backgroundGradientLayer.locations = [0, 0.5, 1]
        backgroundGradientLayer.startPoint = CGPoint(x: 0.15, y: 0.0)
        backgroundGradientLayer.endPoint   = CGPoint(x: 0.85, y: 1.0)
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
    }

    // Subtle ambient blobs — same hue family as accent, very low opacity, slow drift
    private func setupAmbientOrbs() {
        let W = view.bounds.width
        let H = view.bounds.height

        let configs: [(x: CGFloat, y: CGFloat, size: CGFloat, alpha: CGFloat)] = [
            (W * 0.78, H * 0.14, 240, 0.14),
            (W * 0.10, H * 0.52, 280, 0.10),
            (W * 0.55, H * 0.82, 190, 0.10)
        ]
        let drifts: [(CGFloat, CGFloat)] = [(-14, -20), (18, 14), (-8, 22)]
        let durations: [Double] = [7.0, 8.5, 6.5]

        for (i, c) in configs.enumerated() {
            let orb = UIView()
            orb.frame = CGRect(
                x: c.x - c.size / 2,
                y: c.y - c.size / 2,
                width: c.size,
                height: c.size
            )
            // All orbs use the app's primary accent hue
            orb.backgroundColor = UIColor(hex: "#478F82").withAlphaComponent(c.alpha)
            orb.layer.cornerRadius = c.size / 2
            view.insertSubview(orb, at: 0)

            UIView.animate(
                withDuration: durations[i],
                delay: Double(i) * 0.9,
                options: [.autoreverse, .repeat, .curveEaseInOut, .allowUserInteraction]
            ) {
                orb.transform = CGAffineTransform(translationX: drifts[i].0, y: drifts[i].1)
            }
        }
    }

    // MARK: - Pages

    private func setupPages() {
        pages = [
            OnboardingPage(
                title: "Scan Your Room",
                subtitle: "Turn your space into a 3D model using AR.",
                systemImage: "cube.transparent.fill"
            ),
            OnboardingPage(
                title: "Capture Any Furniture",
                subtitle: "Transform real items into 3D models.",
                systemImage: "camera.viewfinder"
            ),
            OnboardingPage(
                title: "Visualize with Confidence",
                subtitle: "See how items fit before you buy.",
                systemImage: "arkit"
            )
        ]
    }

    private func setupPageVC() {
        pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([pages[0]], direction: .forward, animated: true)

        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)

        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        pageVC.view.backgroundColor = .clear

        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - UI Layout

    private func setupUI() {
        for i in 0..<3 {
            let dot = UIView()
            dot.backgroundColor = i == 0 ? .white : UIColor.white.withAlphaComponent(0.3)
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            indicatorStack.addArrangedSubview(dot)

            NSLayoutConstraint.activate([
                dot.heightAnchor.constraint(equalToConstant: 7)
            ])
            let widthC = dot.widthAnchor.constraint(equalToConstant: i == 0 ? 20 : 7)
            widthC.isActive = true

            indicatorDots.append(dot)
            indicatorWidthConstraints.append(widthC)
        }

        view.addSubview(skipButton)
        view.addSubview(indicatorStack)
        view.addSubview(continueButton)
        view.bringSubviewToFront(skipButton)
        view.bringSubviewToFront(indicatorStack)
        view.bringSubviewToFront(continueButton)

        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            indicatorStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -108),
            indicatorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            continueButton.heightAnchor.constraint(equalToConstant: 54)
        ])

        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    // MARK: - Indicator

    private func updateIndicator(to index: Int) {
        for (i, (dot, widthC)) in zip(indicatorDots, indicatorWidthConstraints).enumerated() {
            let isActive = i == index
            widthC.constant = isActive ? 20 : 7
            UIView.animate(
                withDuration: 0.28,
                delay: 0,
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.4,
                options: [.allowUserInteraction]
            ) {
                dot.backgroundColor = isActive ? .white : UIColor.white.withAlphaComponent(0.3)
                self.indicatorStack.layoutIfNeeded()
            }
        }
    }

    // MARK: - PageViewController DataSource

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController as! OnboardingPage) else { return nil }
        return index == 0 ? nil : pages[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController as! OnboardingPage) else { return nil }
        return index == pages.count - 1 ? nil : pages[index + 1]
    }

    // MARK: - PageViewController Delegate

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(of: currentVC as! OnboardingPage)
        else { return }

        currentIndex = index
        updateIndicator(to: index)
        updateCTA()
        animateBackground(for: index)
        pages[index].playEntranceAnimation()
    }

    // MARK: - Actions

    @objc private func skipTapped() {
        goToLogin()
    }

    @objc private func continueTapped() {
        if currentIndex == pages.count - 1 {
            goToLogin()
            return
        }
        let nextIndex = currentIndex + 1
        pageVC.setViewControllers([pages[nextIndex]], direction: .forward, animated: true) { completed in
            guard completed else { return }
            self.currentIndex = nextIndex
            self.updateIndicator(to: nextIndex)
            self.updateCTA()
            self.animateBackground(for: nextIndex)
            self.pages[nextIndex].playEntranceAnimation()
        }
    }

    private func goToLogin() {
        let login = LoginViewController()
        let nav = UINavigationController(rootViewController: login)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .crossDissolve
        present(nav, animated: true)
    }

    // MARK: - Helpers

    private func updateCTA() {
        let title = currentIndex == pages.count - 1 ? "Get Started" : "Continue"
        UIView.transition(with: continueButton, duration: 0.18, options: .transitionCrossDissolve) {
            self.continueButton.setTitle(title, for: .normal)
        }
    }

    private func animateBackground(for index: Int) {
        guard index < pageGradients.count else { return }
        let anim = CABasicAnimation(keyPath: "colors")
        anim.duration = 0.6
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fromValue = backgroundGradientLayer.colors
        anim.toValue = pageGradients[index]
        backgroundGradientLayer.add(anim, forKey: "gradientTransition")
        backgroundGradientLayer.colors = pageGradients[index]
    }

    private func animateCTAEntrance() {
        continueButton.alpha = 0
        continueButton.transform = CGAffineTransform(translationX: 0, y: 18)
        indicatorStack.alpha = 0
        skipButton.alpha = 0

        UIView.animate(
            withDuration: 0.48,
            delay: 0.16,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.3,
            options: []
        ) {
            self.continueButton.alpha = 1
            self.continueButton.transform = .identity
        }

        UIView.animate(withDuration: 0.35, delay: 0.10, options: [.curveEaseOut]) {
            self.indicatorStack.alpha = 1
            self.skipButton.alpha = 1
        }
    }
}
