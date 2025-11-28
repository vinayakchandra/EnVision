import UIKit

final class SocialButton: UIButton {

    private let iconView = UIImageView()

    init(title: String, image: UIImage?) {
        super.init(frame: .zero)

        // Icon setup
        iconView.image = image
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        // Label setup
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = UIColor.black
        label.textAlignment = .center

        // Horizontal stack (centers icon + text perfectly)
        let hStack = UIStackView(arrangedSubviews: [iconView, label])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            hStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Button styling
        backgroundColor = .white
        layer.cornerRadius = 25
        layer.cornerCurve = .continuous

        layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 2)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 60).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
