//
//  LiDAROnboardingView.swift
//  Envision
//
//  First-time guidance overlay for room scanning via LiDAR / RoomPlan.
//  Shown once per install, then never again.
//

import UIKit

// MARK: - Step Model

private struct OnboardingStep {
    let icon: String      // SF Symbol name
    let title: String
    let detail: String
}

// MARK: - LiDAROnboardingView

final class LiDAROnboardingView: UIView {

    // Call this to check whether the overlay should be shown at all.
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: "hasSeenLiDAROnboarding")
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenLiDAROnboarding")
    }

    // Called when the user dismisses the overlay.
    var onDismiss: (() -> Void)?

    // MARK: - Data

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "iphone.and.arrow.forward",
            title: "Hold upright & move slowly",
            detail: "Keep your iPhone vertical. Pan steadily — LiDAR needs time to build each surface."
        ),
        OnboardingStep(
            icon: "lightbulb.max",
            title: "Good lighting helps",
            detail: "Bright, even light produces cleaner scans. Avoid harsh direct sunlight or very dark corners."
        ),
        OnboardingStep(
            icon: "house.and.flag",
            title: "Cover walls, floor & ceiling",
            detail: "Walk around the entire perimeter. RoomPlan auto-detects doors, windows and openings."
        ),
        OnboardingStep(
            icon: "checkmark.seal",
            title: "Wait for the mesh to settle",
            detail: "Yellow surfaces are still being refined. Keep scanning until they turn white, then tap Save."
        ),
    ]

    private var currentStep = 0

    // MARK: - UI

    private let blurView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let card: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 24
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.18
        v.layer.shadowRadius = 20
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = AppColors.accent
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 20, weight: .bold)
        lbl.textColor = .label
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        return lbl
    }()

    private let detailLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 15, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        return lbl
    }()

    private let stepDots: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        return sv
    }()

    private let nextButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Next", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = AppColors.accent
        btn.layer.cornerRadius = 14
        return btn
    }()

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Skip", for: .normal)
        btn.setTitleColor(.secondaryLabel, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        return btn
    }()

    private var dotViews: [UIView] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        updateContent(animated: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        addSubview(blurView)
        blurView.contentView.addSubview(card)

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(detailLabel)
        card.addSubview(stepDots)
        card.addSubview(nextButton)
        card.addSubview(skipButton)

        // Build dots
        for i in 0..<steps.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 4
            dot.backgroundColor = i == 0 ? AppColors.accent : .systemGray4
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            stepDots.addArrangedSubview(dot)
            dotViews.append(dot)
        }

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            card.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            card.widthAnchor.constraint(equalTo: blurView.contentView.widthAnchor, multiplier: 0.88),

            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            detailLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            detailLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),

            stepDots.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 24),
            stepDots.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            nextButton.topAnchor.constraint(equalTo: stepDots.bottomAnchor, constant: 20),
            nextButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            nextButton.heightAnchor.constraint(equalToConstant: 50),

            skipButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 10),
            skipButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
    }

    // MARK: - Content

    private func updateContent(animated: Bool) {
        let step = steps[currentStep]
        let isLast = currentStep == steps.count - 1

        let updateBlock = {
            self.iconView.image = UIImage(systemName: step.icon,
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium))
            self.titleLabel.text = step.title
            self.detailLabel.text = step.detail
            self.nextButton.setTitle(isLast ? "Start Scanning" : "Next", for: .normal)

            for (i, dot) in self.dotViews.enumerated() {
                UIView.animate(withDuration: animated ? 0.25 : 0) {
                    dot.backgroundColor = i == self.currentStep ? AppColors.accent : .systemGray4
                    dot.transform = i == self.currentStep
                        ? CGAffineTransform(scaleX: 1.4, y: 1.4)
                        : .identity
                }
            }
        }

        if animated {
            UIView.transition(with: card, duration: 0.3,
                              options: [.transitionCrossDissolve], animations: updateBlock)
        } else {
            updateBlock()
        }
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if currentStep < steps.count - 1 {
            currentStep += 1
            updateContent(animated: true)
        } else {
            dismiss()
        }
    }

    @objc private func skipTapped() {
        dismiss()
    }

    private func dismiss() {
        LiDAROnboardingView.markSeen()
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        })
    }

    // MARK: - Present

    /// Adds the overlay to `parent` and animates it in.
    func present(in parent: UIView) {
        frame = parent.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        parent.addSubview(self)
        UIView.animate(withDuration: 0.35) { self.alpha = 1 }
    }
}
