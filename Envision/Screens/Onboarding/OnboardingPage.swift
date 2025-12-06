//
//  OnboardingPage.swift
//  Envisionf2
//
//  Created by user@78 on 15/11/25.
//


//
//  OnboardingPage.swift
//  Envisionf2
//

import UIKit

class OnboardingPage: UIViewController {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private var iconName: String = ""
    private var titleText: String = ""
    private var subtitleText: String = ""

    convenience init(title: String, subtitle: String, systemImage: String) {
        self.init()
        self.titleText = title
        self.subtitleText = subtitle
        self.iconName = systemImage
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        view.backgroundColor = UIColor(hex: "#F2F2F7")
        view.backgroundColor = .systemBackground

        setupUI()
    }

    private func setupUI() {

        // Icon
        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = UIColor(hex: "#4A9085")
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.text = titleText
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle
        subtitleLabel.text = subtitleText
        subtitleLabel.font = UIFont.systemFont(ofSize: 16)
        subtitleLabel.textColor = .darkGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(iconView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([

            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 160),
            iconView.widthAnchor.constraint(equalToConstant: 150),
            iconView.heightAnchor.constraint(equalToConstant: 150),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }
}
