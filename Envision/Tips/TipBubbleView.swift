import UIKit

final class TipBubbleView: UIView {

    enum ArrowEdge { case top, bottom, left, right }

    struct Configuration {
        let title: String
        let message: String
        let primaryActionTitle: String
        let dismissActionTitle: String
        let progressText: String?
        let arrowEdge: ArrowEdge
        let arrowOffset: CGFloat
    }

    var onPrimaryAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Private views

    private let blurView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 18
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    // Tint overlay so the card reads dark regardless of light/dark mode (matches dock / tab bar)
    private let tintOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        return v
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 15, weight: .semibold)
        lbl.textColor = .white
        lbl.numberOfLines = 1
        return lbl
    }()

    private let progressLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.78)
        lbl.textAlignment = .right
        lbl.numberOfLines = 1
        return lbl
    }()

    private let messageLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 13, weight: .regular)
        lbl.textColor = UIColor.white.withAlphaComponent(0.72)
        lbl.numberOfLines = 0
        return lbl
    }()

    private let primaryButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = AppColors.accent
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.layer.cornerRadius = 10
        btn.layer.cornerCurve = .continuous
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return btn
    }()

    private let dismissButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        return btn
    }()

    private let arrowLayer = CAShapeLayer()
    private let config: Configuration
    private let arrowSize: CGFloat = 10

    // MARK: - Init

    init(configuration: Configuration) {
        self.config = configuration
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        titleLabel.text  = config.title
        messageLabel.text = config.message
        primaryButton.setTitle(config.primaryActionTitle, for: .normal)
        dismissButton.setTitle(config.dismissActionTitle, for: .normal)
        progressLabel.text = config.progressText
        progressLabel.isHidden = (config.progressText?.isEmpty ?? true)

        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        // Arrow sits on the outer view, below Auto Layout
        arrowLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        layer.insertSublayer(arrowLayer, at: 0)

        // Build view hierarchy inside blur
        addSubview(blurView)
        blurView.contentView.addSubview(tintOverlay)
        blurView.contentView.addSubview(titleLabel)
        blurView.contentView.addSubview(progressLabel)
        blurView.contentView.addSubview(messageLabel)
        blurView.contentView.addSubview(primaryButton)
        blurView.contentView.addSubview(dismissButton)

        let top: CGFloat = config.arrowEdge == .top    ? arrowSize : 0
        let bot: CGFloat = config.arrowEdge == .bottom ? arrowSize : 0

        NSLayoutConstraint.activate([
            // Blur fills the view, offset for arrow space
            blurView.topAnchor.constraint(equalTo: topAnchor, constant: top),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bot),

            // Tint fills blur
            tintOverlay.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: progressLabel.leadingAnchor, constant: -8),

            progressLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            progressLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.leadingAnchor, constant: 16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            primaryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            primaryButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            primaryButton.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -14),

            dismissButton.leadingAnchor.constraint(equalTo: primaryButton.trailingAnchor, constant: 12),
            dismissButton.centerYAnchor.constraint(equalTo: primaryButton.centerYAnchor),
            dismissButton.trailingAnchor.constraint(lessThanOrEqualTo: blurView.contentView.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Arrow

    override func layoutSubviews() {
        super.layoutSubviews()
        drawArrow()
    }

    private func drawArrow() {
        let path = UIBezierPath()
        switch config.arrowEdge {
        case .top:
            let cx = (bounds.midX + config.arrowOffset)
                .clamped(to: (arrowSize + 8)...(bounds.width - arrowSize - 8))
            path.move(to: CGPoint(x: cx, y: 0))
            path.addLine(to: CGPoint(x: cx - arrowSize, y: arrowSize))
            path.addLine(to: CGPoint(x: cx + arrowSize, y: arrowSize))
            path.close()
        case .bottom:
            let cx = (bounds.midX + config.arrowOffset)
                .clamped(to: (arrowSize + 8)...(bounds.width - arrowSize - 8))
            let y = bounds.height
            path.move(to: CGPoint(x: cx, y: y))
            path.addLine(to: CGPoint(x: cx - arrowSize, y: y - arrowSize))
            path.addLine(to: CGPoint(x: cx + arrowSize, y: y - arrowSize))
            path.close()
        case .left, .right:
            arrowLayer.path = nil
            return
        }
        arrowLayer.path = path.cgPath
    }

    // MARK: - Actions

    @objc private func primaryTapped() { onPrimaryAction?() }
    @objc private func dismissTapped()  { onDismiss?() }
}

// MARK: - Comparable clamped helper

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
