//
//  OnboardingController.swift
//  Envisionf2
//
//  Created by Abishai on 15/11/25.
//

import UIKit

class OnboardingController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    private var pageVC: UIPageViewController!
    private var pages: [OnboardingPage] = []
    private var currentIndex = 0   // Track current page

    // MARK: UI Elements
    private let pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.numberOfPages = 3
        pc.currentPage = 0
        pc.currentPageIndicatorTintColor = UIColor(hex: "#4A9085")
        pc.pageIndicatorTintColor = .lightGray
        pc.translatesAutoresizingMaskIntoConstraints = false
        return pc
    }()

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Skip", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        btn.setTitleColor(.systemBlue, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Continue", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(hex: "#4A9085")
        btn.layer.cornerRadius = 22
        btn.alpha = 1       // ALWAYS visible
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemPink

        setupPages()
        setupPageVC()
        setupUI()
    }

    // MARK: Create Pages
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

    // MARK: Setup PageViewController
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

        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: Setup UI
    private func setupUI() {

        view.addSubview(pageControl)
        view.addSubview(skipButton)
        view.addSubview(continueButton)

        // Bring UI above PageVC
        view.bringSubviewToFront(skipButton)
        view.bringSubviewToFront(pageControl)
        view.bringSubviewToFront(continueButton)

        // Skip button
        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            skipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        // Page control
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        // Continue button
        NSLayoutConstraint.activate([
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            continueButton.heightAnchor.constraint(equalToConstant: 52)
        ])
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }

    // MARK: PageViewController Data Source
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

    // MARK: Page Changed
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {

        guard completed,
              let currentVC = pageViewController.viewControllers?.first,
              let index = pages.firstIndex(of: currentVC as! OnboardingPage)
        else { return }

        currentIndex = index
        pageControl.currentPage = index
    }

    // MARK: Actions
    @objc private func skipTapped() {
        goToLogin()
    }

    @objc private func continueTapped() {
        
        // If last page → go to login
        if currentIndex == pages.count - 1 {
            goToLogin()
            return
        }

        // Next index
        let nextIndex = currentIndex + 1
        let nextVC = pages[nextIndex]

        // Animate to next page
        pageVC.setViewControllers([nextVC], direction: .forward, animated: true) { completed in
            if completed {
                self.currentIndex = nextIndex
                self.pageControl.currentPage = nextIndex
            }
        }
    }

    private func goToLogin() {
        let login = LoginViewController()
        let nav = UINavigationController(rootViewController: login)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .crossDissolve
        present(nav, animated: true)
    }

}
