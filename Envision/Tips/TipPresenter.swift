import UIKit

/// Pure UIKit tip presenter (no SwiftUI/UIHostingController).
///
/// This renders a lightweight banner that matches iOS styling (blur + rounded corners),
/// supports multiple buttons, and never installs full-screen overlays.
///
/// Note: The app-wide tips/tour integration is temporarily disabled.
final class TipPresenter {

    // MARK: - Types

    struct Action {
        let id: String
        let title: String
    }

    // MARK: - Private

    private weak var owner: UIViewController?
    private weak var containerView: UIView?

    private var bannerView: TipBannerView?
    private var heightConstraint: NSLayoutConstraint?

    init(owner: UIViewController, containerView: UIView) {
        self.owner = owner
        self.containerView = containerView
    }

    func dismiss() {
        bannerView?.removeFromSuperview()
        bannerView = nil

        heightConstraint?.isActive = false
        heightConstraint = nil

        containerView?.isHidden = true
        owner?.view.setNeedsLayout()
    }

    /// Presents a UIKit banner representing the provided Tip.
    /// Note: We intentionally don't attempt to mirror TipKit's rule evaluation UI.
    /// The calling screen decides *which* tip to show; this class only renders it.
    @discardableResult
    func present(
        title: String,
        message: String?,
        systemImageName: String?,
        actions: [Action],
        onAction: @escaping (String) -> Void
    ) -> CGFloat {
        guard let owner, let containerView else { return 0 }

        dismiss()

        let banner = TipBannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.configure(
            title: title,
            message: message,
            systemImageName: systemImageName,
            actions: actions,
            onAction: onAction
        )

        containerView.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: containerView.topAnchor),
            banner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            banner.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        bannerView = banner
        containerView.isHidden = false

        owner.view.layoutIfNeeded()

        // Measure via Auto Layout and lock height to keep layout stable.
        let width = max(1, containerView.bounds.width)
        let measured = containerView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        heightConstraint?.isActive = false
        let hc = containerView.heightAnchor.constraint(equalToConstant: max(0, measured))
        hc.priority = .required
        hc.isActive = true
        heightConstraint = hc

        owner.view.layoutIfNeeded()
        return measured
    }
}

// MARK: - TipBannerView

private final class TipBannerView: UIView {

    private let backgroundView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.clipsToBounds = true
        v.layer.cornerRadius = 16
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 0
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        return l
    }()

    private let buttonStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.alignment = .fill
        s.distribution = .fillEqually
        s.spacing = 10
        return s
    }()

    private var actionHandler: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true

        addSubview(backgroundView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let content = backgroundView.contentView

        content.addSubview(iconView)
        content.addSubview(titleLabel)
        content.addSubview(messageLabel)
        content.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            iconView.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),

            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            buttonStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 12),
            buttonStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            buttonStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
        ])
    }

    func configure(
        title: String,
        message: String?,
        systemImageName: String?,
        actions: [TipPresenter.Action],
        onAction: @escaping (String) -> Void
    ) {
        self.actionHandler = onAction

        titleLabel.text = title
        messageLabel.text = message
        messageLabel.isHidden = (message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if let systemImageName {
            iconView.image = UIImage(systemName: systemImageName)
            iconView.isHidden = false
        } else {
            iconView.isHidden = true
        }

        // Rebuild buttons
        buttonStack.arrangedSubviews.forEach { v in
            buttonStack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        for action in actions {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false

            var config = UIButton.Configuration.filled()
            config.title = action.title
            config.baseBackgroundColor = .tertiarySystemFill
            config.baseForegroundColor = .label
            config.cornerStyle = .medium
            config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            b.configuration = config

            b.accessibilityIdentifier = action.id
            b.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            buttonStack.addArrangedSubview(b)
        }

        // If no actions, collapse the stack.
        buttonStack.isHidden = actions.isEmpty
    }

    @objc private func actionTapped(_ sender: UIButton) {
        guard let id = sender.accessibilityIdentifier else { return }
        actionHandler?(id)
    }
}
