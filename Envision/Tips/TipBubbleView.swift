import UIKit

final class TipBubbleView: UIView {

    enum ArrowEdge {
        case top
        case bottom
        case left
        case right
    }

    struct Configuration {
        let title: String
        let message: String
        let primaryActionTitle: String
        let dismissActionTitle: String
        let arrowEdge: ArrowEdge
        let arrowOffset: CGFloat
    }

    var onPrimaryAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let arrowLayer = CAShapeLayer()

    private let config: Configuration
    private let arrowSize: CGFloat = 12

    init(configuration: Configuration) {
        self.config = configuration
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        accessibilityIdentifier = "TipBubbleView"
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
        backgroundColor = .clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.12
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12

        arrowLayer.fillColor = UIColor.secondarySystemBackground.cgColor
        layer.addSublayer(arrowLayer)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.text = config.title

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.text = config.message

        primaryButton.translatesAutoresizingMaskIntoConstraints = false
        var primaryConfig = UIButton.Configuration.filled()
        primaryConfig.title = config.primaryActionTitle
        primaryConfig.baseBackgroundColor = .systemBlue
        primaryConfig.baseForegroundColor = .white
        primaryConfig.cornerStyle = .medium
        primaryConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        primaryButton.configuration = primaryConfig
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.setTitle(config.dismissActionTitle, for: .normal)
        dismissButton.setTitleColor(.secondaryLabel, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .tertiaryLabel
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(primaryButton)
        containerView.addSubview(dismissButton)
        containerView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: topInsetForArrow()),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInsetForArrow()),

            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),

            primaryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 14),
            primaryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            primaryButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),

            dismissButton.leadingAnchor.constraint(equalTo: primaryButton.trailingAnchor, constant: 10),
            dismissButton.centerYAnchor.constraint(equalTo: primaryButton.centerYAnchor),
            dismissButton.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -14)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawArrow()
    }

    private func topInsetForArrow() -> CGFloat {
        config.arrowEdge == .top ? arrowSize : 0
    }

    private func bottomInsetForArrow() -> CGFloat {
        config.arrowEdge == .bottom ? arrowSize : 0
    }

    private func drawArrow() {
        let path = UIBezierPath()

        switch config.arrowEdge {
        case .top:
            let centerX = min(max(bounds.midX + config.arrowOffset, arrowSize + 8), bounds.width - arrowSize - 8)
            path.move(to: CGPoint(x: centerX, y: 0))
            path.addLine(to: CGPoint(x: centerX - arrowSize, y: arrowSize))
            path.addLine(to: CGPoint(x: centerX + arrowSize, y: arrowSize))
            path.close()
        case .bottom:
            let centerX = min(max(bounds.midX + config.arrowOffset, arrowSize + 8), bounds.width - arrowSize - 8)
            let y = bounds.height
            path.move(to: CGPoint(x: centerX, y: y))
            path.addLine(to: CGPoint(x: centerX - arrowSize, y: y - arrowSize))
            path.addLine(to: CGPoint(x: centerX + arrowSize, y: y - arrowSize))
            path.close()
        case .left, .right:
            arrowLayer.path = nil
            return
        }

        arrowLayer.path = path.cgPath
    }

    @objc private func primaryTapped() {
        onPrimaryAction?()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }
}
