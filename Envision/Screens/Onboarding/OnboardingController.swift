//
//  OnboardingController.swift
//  Envision
//

import UIKit

final class OnboardingController: UIViewController {
    private let hasSeenOnboardingKey = "hasSeenAppOnboarding"

    // MARK: - Pages

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Scan Your Room",
            subtitle: "Turn any space into a 3D model using your iPhone's LiDAR sensor.",
            assetImage: "roomScan",
            fallbackSystemImage: "cube.transparent.fill"
        ),
        OnboardingPage(
            title: "Capture Furniture",
            subtitle: "Walk around any object and let Object Capture build a 3D model.",
            assetImage: "furnitureScan",
            fallbackSystemImage: "camera.viewfinder"
        ),
        OnboardingPage(
            title: "Visualize with AR",
            subtitle: "Place furniture in your room and see exactly how it fits — before you buy.",
            assetImage: "visualizeRoom",
            fallbackSystemImage: "arkit"
        ),
    ]

    private var currentIndex = 0
    private var pageVC: UIPageViewController!

    // MARK: - UI

    private let indicatorStack: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    private var dots: [UIView] = []
    private var dotWidths: [NSLayoutConstraint] = []

    private let continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Continue", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = AppColors.accent
        btn.layer.cornerRadius = 14
        btn.layer.cornerCurve = .continuous
        return btn
    }()

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Skip", for: .normal)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupPageVC()
        setupIndicator()
        setupButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pages[0].playEntranceAnimation()
    }

    // MARK: - Page View Controller

    private func setupPageVC() {
        pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([pages[0]], direction: .forward, animated: false)

        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.didMove(toParent: self)

        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        pageVC.view.backgroundColor = .clear

        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Indicator Dots

    private func setupIndicator() {
        for i in 0..<pages.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = i == 0 ? AppColors.accent : .systemGray4
            dot.layer.cornerRadius = 3.5
            indicatorStack.addArrangedSubview(dot)

            let h = dot.heightAnchor.constraint(equalToConstant: 7)
            let w = dot.widthAnchor.constraint(equalToConstant: i == 0 ? 20 : 7)
            NSLayoutConstraint.activate([h, w])

            dots.append(dot)
            dotWidths.append(w)
        }

        view.addSubview(indicatorStack)
        NSLayoutConstraint.activate([
            indicatorStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -104),
            indicatorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func updateIndicator(to index: Int) {
        for (i, (dot, width)) in zip(dots, dotWidths).enumerated() {
            let active = i == index
            width.constant = active ? 20 : 7
            UIView.animate(withDuration: 0.25) {
                dot.backgroundColor = active ? AppColors.accent : .systemGray4
                self.indicatorStack.layoutIfNeeded()
            }
        }
    }

    // MARK: - Buttons

    private func setupButtons() {
        view.addSubview(continueButton)
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 52),

            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
    }

    private func updateContinueTitle() {
        let title = currentIndex == pages.count - 1 ? "Get Started" : "Continue"
        continueButton.setTitle(title, for: .normal)
    }

    // MARK: - Actions

    @objc private func continueTapped() {
        HapticsManager.shared.impactLight()
        if currentIndex == pages.count - 1 {
            HapticsManager.shared.success()
            goToLogin()
            return
        }
        let next = currentIndex + 1
        pageVC.setViewControllers([pages[next]], direction: .forward, animated: true) { [weak self] done in
            guard done, let self else { return }
            HapticsManager.shared.selection()
            self.currentIndex = next
            self.updateIndicator(to: next)
            self.updateContinueTitle()
            self.pages[next].playEntranceAnimation()
        }
    }

    @objc private func skipTapped() {
        HapticsManager.shared.selection()
        goToLogin()
    }

    private func goToLogin() {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        let nav = UINavigationController(rootViewController: LoginViewController())
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .crossDissolve
        present(nav, animated: true)
    }
}

// MARK: - UIPageViewControllerDataSource

extension OnboardingController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? OnboardingPage,
              let index = pages.firstIndex(of: page), index > 0 else { return nil }
        return pages[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? OnboardingPage,
              let index = pages.firstIndex(of: page), index < pages.count - 1 else { return nil }
        return pages[index + 1]
    }
}

// MARK: - UIPageViewControllerDelegate

extension OnboardingController: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed,
              let page = pageViewController.viewControllers?.first as? OnboardingPage,
              let index = pages.firstIndex(of: page) else { return }

        HapticsManager.shared.selection()
        currentIndex = index
        updateIndicator(to: index)
        updateContinueTitle()
        page.playEntranceAnimation()
    }
}
