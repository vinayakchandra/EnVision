import UIKit

final class SocialButton: UIButton {

    private let iconView = UIImageView()

    init(title: String, image: UIImage?, iconTintColor: UIColor? = nil) {
        super.init(frame: .zero)

        // Icon setup
        iconView.image = image
        iconView.tintColor = iconTintColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        // Label setup
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center

        // Horizontal stack (centers icon + text perfectly)
        let hStack = UIStackView(arrangedSubviews: [iconView, label])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.isUserInteractionEnabled = false
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            hStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Button styling
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 25
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 1)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 60).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = UIColor.separator.cgColor
        }
    }
}
