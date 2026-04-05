import UIKit

final class PrimaryButton1: UIButton {
    init(title: String) {
        super.init(frame: .zero)

        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(red: 0.28, green: 0.56, blue: 0.51, alpha: 1)
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)

        self.configuration = config
        translatesAutoresizingMaskIntoConstraints = false
        addTarget(self, action: #selector(handleTapHaptic), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTapHaptic() {
        HapticsManager.shared.impactLight()
    }
}
