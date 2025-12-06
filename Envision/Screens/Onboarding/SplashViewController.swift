//
//  SplashViewController.swift
//  Envisionf2
//
//  Created by user@78 on 13/11/25.
//

import Foundation
import UIKit

class SplashViewController: UIViewController {

    // MARK: - UI Components

    private let iconView: UIImageView = {
        let img = UIImageView(image: UIImage(named: "envision"))
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        return img
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "EnVision"
        lbl.font = UIFont.boldSystemFont(ofSize: 32)
        lbl.textAlignment = .center
//        lbl.textColor = .system
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let subLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "See it in your space, before you buy it."
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.textAlignment = .center
        lbl.textColor = .darkGray
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
//        view.backgroundColor = UIColor(hex: "#F2F2F7")
        view.backgroundColor = .systemBackground
        setupUI()
        // navigateToOnboarding()  // removed to avoid double navigation
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateLogo()
    }


    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(subLabel)

        NSLayoutConstraint.activate([

            // Icon
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 210),
            iconView.widthAnchor.constraint(equalToConstant: 150),
            iconView.heightAnchor.constraint(equalToConstant: 150),

            // Title
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Subtitle
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    private func goNext() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let nextVC = OnboardingController()
            nextVC.modalPresentationStyle = .fullScreen
            nextVC.modalTransitionStyle = .crossDissolve   // ← Apple-style fade
            self.present(nextVC, animated: true)
        }
    }

    private func animateLogo() {

        // Start state
        iconView.alpha = 0
        iconView.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        UIView.animate(withDuration: 1.2,         // slower, elegant
                       delay: 0.1,
                       usingSpringWithDamping: 0.88,   // soft, minimal bounce
                       initialSpringVelocity: 0.4,
                       options: [.curveEaseInOut]) {

            self.iconView.alpha = 1

            // Slight smooth scale up
            self.iconView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)

        } completion: { _ in
            // Gentle settle to perfect 1.0 scale
            UIView.animate(withDuration: 0.35,
                           delay: 0,
                           options: [.curveEaseInOut]) {
                self.iconView.transform = .identity
            } completion: { _ in
                self.goNext()
            }
        }
    }


    // MARK: - Navigation

    private func navigateToOnboarding() {
        // handled by goNext() after animation
    }
}
