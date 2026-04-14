//
//  OnboardingPage.swift
//  Envision
//

import UIKit
import Lottie

final class OnboardingPage: UIViewController {

    enum Visual {
        case systemImage(String)
        case assetImage(String)
        case lottie(String)
    }

    // MARK: - Data

    private let visual: Visual
    private let fallbackSystemImage: String
    private let titleText: String
    private let subtitleText: String
    private var activeAnimationView: LottieAnimationView?
    private var iconWrapperSizeConstraint: NSLayoutConstraint?

    init(title: String, subtitle: String, systemImage: String) {
        self.titleText = title
        self.subtitleText = subtitle
        self.visual = .systemImage(systemImage)
        self.fallbackSystemImage = systemImage
        super.init(nibName: nil, bundle: nil)
    }

    init(title: String, subtitle: String, assetImage: String, fallbackSystemImage: String) {
        self.titleText = title
        self.subtitleText = subtitle
        self.visual = .assetImage(assetImage)
        self.fallbackSystemImage = fallbackSystemImage
        super.init(nibName: nil, bundle: nil)
    }

    init(title: String, subtitle: String, lottieName: String, fallbackSystemImage: String) {
        self.titleText = title
        self.subtitleText = subtitle
        self.visual = .lottie(lottieName)
        self.fallbackSystemImage = fallbackSystemImage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Views

    private let iconWrapper: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 36
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activeAnimationView?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        activeAnimationView?.stop()
    }

    // MARK: - Layout

    private func setupViews() {
        iconWrapper.backgroundColor = AppColors.accent.withAlphaComponent(0.1)
        configureVisual()

        titleLabel.text = titleText
        subtitleLabel.text = subtitleText

        view.addSubview(iconWrapper)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)

        let iconSize: CGFloat = {
            switch visual {
            case .lottie:
                return 240
            case .assetImage:
                return 300
            case .systemImage:
                return 100
            }
        }()

        iconWrapperSizeConstraint = iconWrapper.widthAnchor.constraint(equalToConstant: iconSize)

        NSLayoutConstraint.activate([
            iconWrapper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconWrapper.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),
            iconWrapperSizeConstraint!,
            iconWrapper.heightAnchor.constraint(equalTo: iconWrapper.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconWrapper.bottomAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func configureVisual() {
        switch visual {
        case let .systemImage(iconName):
            applySystemImage(iconName)
        case let .assetImage(assetName):
            applyAssetImage(assetName)
        case let .lottie(lottieName):
            applyLottie(lottieName)
        }
    }

    private func applySystemImage(_ iconName: String) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = AppColors.accent

        iconWrapper.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconWrapper.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWrapper.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func applyLottie(_ lottieName: String) {
        guard LottieAnimation.named(lottieName) != nil else {
            applySystemImage(fallbackSystemImage)
            return
        }

        iconWrapper.backgroundColor = .clear

        let animationView = LottieAnimationView(name: lottieName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundBehavior = .pauseAndRestore
        activeAnimationView = animationView

        iconWrapper.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: iconWrapper.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: iconWrapper.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
        ])
    }

    private func applyAssetImage(_ assetName: String) {
        guard let image = UIImage(named: assetName) else {
            applySystemImage(fallbackSystemImage)
            return
        }

        iconWrapper.backgroundColor = .secondarySystemBackground
        iconWrapper.layer.cornerRadius = 28
        iconWrapper.layer.cornerCurve = .continuous
        iconWrapper.layer.borderWidth = 1
        iconWrapper.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        iconView.image = image
        iconView.tintColor = nil
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 28
        iconView.layer.cornerCurve = .continuous

        iconWrapper.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: iconWrapper.topAnchor),
            iconView.leadingAnchor.constraint(equalTo: iconWrapper.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: iconWrapper.trailingAnchor),
            iconView.bottomAnchor.constraint(equalTo: iconWrapper.bottomAnchor),
        ])
    }

    // MARK: - Entrance (called by OnboardingController)

    func playEntranceAnimation() {
        let views: [UIView] = [iconWrapper, titleLabel, subtitleLabel]
        views.forEach {
            $0.alpha = 0
            $0.transform = .identity
        }

        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            views.forEach {
                $0.alpha = 1
                $0.transform = .identity
            }
        }
    }
}
