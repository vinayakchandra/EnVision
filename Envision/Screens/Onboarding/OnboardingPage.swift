//
//  OnboardingPage.swift
//  Envision
//

import UIKit

final class OnboardingPage: UIViewController {

    // MARK: - Data

    private let iconName: String
    private let titleText: String
    private let subtitleText: String

    init(title: String, subtitle: String, systemImage: String) {
        self.titleText = title
        self.subtitleText = subtitle
        self.iconName = systemImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Views

    private let iconWrapper: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 36
        v.layer.cornerCurve = .continuous
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 28, weight: .bold)
        lbl.textColor = .label
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.adjustsFontForContentSizeCategory = true
        return lbl
    }()

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 17, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 3
        lbl.adjustsFontForContentSizeCategory = true
        return lbl
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupViews()
    }

    // MARK: - Layout

    private func setupViews() {
        iconWrapper.backgroundColor = AppColors.accent.withAlphaComponent(0.1)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = AppColors.accent

        titleLabel.text = titleText
        subtitleLabel.text = subtitleText

        iconWrapper.addSubview(iconView)
        view.addSubview(iconWrapper)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconWrapper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconWrapper.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            iconWrapper.widthAnchor.constraint(equalToConstant: 100),
            iconWrapper.heightAnchor.constraint(equalToConstant: 100),

            iconView.centerXAnchor.constraint(equalTo: iconWrapper.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWrapper.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: iconWrapper.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Entrance (called by OnboardingController)

    func playEntranceAnimation() {
        let views: [UIView] = [iconWrapper, titleLabel, subtitleLabel]
        views.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 16)
        }

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            views.forEach {
                $0.alpha = 1
                $0.transform = .identity
            }
        }
    }
}
