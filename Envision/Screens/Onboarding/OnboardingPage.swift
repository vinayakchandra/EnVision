//
//  OnboardingPage.swift
//  Envisionf2
//

import UIKit

class OnboardingPage: UIViewController {

    // MARK: - Views

    private let cardContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 28
        v.layer.cornerCurve = .continuous
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius = 24
        v.layer.shadowOffset = CGSize(width: 0, height: 8)
        return v
    }()

    private let blurCard: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 28
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let borderOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.layer.cornerRadius = 28
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        v.isUserInteractionEnabled = false
        return v
    }()

    private let iconContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        // Matches app accent #478F82 at low opacity
        v.backgroundColor = UIColor(red: 0.278, green: 0.561, blue: 0.510, alpha: 0.18)
        v.layer.cornerRadius = 52
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(red: 0.278, green: 0.561, blue: 0.510, alpha: 0.3).cgColor
        // Soft accent glow
        v.layer.shadowColor = UIColor(hex: "#478F82").cgColor
        v.layer.shadowOpacity = 0.4
        v.layer.shadowRadius = 20
        v.layer.shadowOffset = .zero
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        lbl.textColor = UIColor.white.withAlphaComponent(0.62)
        lbl.textAlignment = .center
        lbl.numberOfLines = 3
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - Data

    private var iconName: String = ""
    private var titleText: String = ""
    private var subtitleText: String = ""

    convenience init(title: String, subtitle: String, systemImage: String) {
        self.init()
        self.titleText = title
        self.subtitleText = subtitle
        self.iconName = systemImage
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        iconView.image = UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 44, weight: .medium))
        // Lighter tint of the app accent so it's visible on dark bg
        iconView.tintColor = UIColor(hex: "#7BBFB5")

        titleLabel.text = titleText
        subtitleLabel.text = subtitleText

        view.addSubview(cardContainer)
        cardContainer.addSubview(blurCard)
        blurCard.contentView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconView)
        blurCard.contentView.addSubview(titleLabel)
        blurCard.contentView.addSubview(subtitleLabel)
        view.addSubview(borderOverlay)

        NSLayoutConstraint.activate([
            cardContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cardContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -48),
            cardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            blurCard.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            blurCard.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            blurCard.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            blurCard.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            borderOverlay.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            borderOverlay.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            borderOverlay.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            borderOverlay.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            iconContainerView.topAnchor.constraint(equalTo: blurCard.contentView.topAnchor, constant: 32),
            iconContainerView.centerXAnchor.constraint(equalTo: blurCard.contentView.centerXAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 104),
            iconContainerView.heightAnchor.constraint(equalToConstant: 104),

            iconView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.topAnchor.constraint(equalTo: iconContainerView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: blurCard.contentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: blurCard.contentView.trailingAnchor, constant: -28),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: blurCard.contentView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: blurCard.contentView.trailingAnchor, constant: -28),
            subtitleLabel.bottomAnchor.constraint(equalTo: blurCard.contentView.bottomAnchor, constant: -32)
        ])
    }

    // MARK: - Animations

    func playEntranceAnimation() {
        stopFloatAnimation()

        cardContainer.alpha = 0
        cardContainer.transform = CGAffineTransform(translationX: 0, y: 28)
        borderOverlay.alpha = 0
        iconContainerView.alpha = 0
        iconContainerView.transform = CGAffineTransform(scaleX: 0.80, y: 0.80)
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 10)
        subtitleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 10)

        UIView.animate(
            withDuration: 0.55,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.3,
            options: [.curveEaseOut]
        ) {
            self.cardContainer.alpha = 1
            self.borderOverlay.alpha = 1
            self.cardContainer.transform = .identity
        }

        UIView.animate(
            withDuration: 0.48,
            delay: 0.1,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.4,
            options: []
        ) {
            self.iconContainerView.transform = .identity
            self.iconContainerView.alpha = 1
        } completion: { _ in
            self.startFloatAnimation()
        }

        UIView.animate(withDuration: 0.38, delay: 0.20, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }

        UIView.animate(withDuration: 0.38, delay: 0.28, options: [.curveEaseOut]) {
            self.subtitleLabel.alpha = 1
            self.subtitleLabel.transform = .identity
        }
    }

    private func startFloatAnimation() {
        UIView.animate(
            withDuration: 2.8,
            delay: 0,
            options: [.autoreverse, .repeat, .curveEaseInOut, .allowUserInteraction]
        ) {
            self.iconContainerView.transform = CGAffineTransform(translationX: 0, y: -7)
        }
    }

    private func stopFloatAnimation() {
        iconContainerView.layer.removeAllAnimations()
        iconContainerView.transform = .identity
    }
}
