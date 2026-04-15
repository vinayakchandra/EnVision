import UIKit

final class OrbitJoystick: UIView {

    // MARK: - Output
    var onMove: ((Float, Float) -> Void)?

    // MARK: - UI
    private let knob = UIView()
    
    private var isDarkAppearance: Bool {
        traitCollection.userInterfaceStyle == .dark
    }

    // MARK: - Layout Constants
    private var knobRadius: CGFloat { bounds.width * 0.25 }
    private var maxDistance: CGFloat { bounds.width * 0.4 }

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setup() {
        clipsToBounds = true
        addSubview(knob)
        applyTheme()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard let previousTraitCollection else { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.width / 2

        knob.frame = CGRect(
            origin: .zero,
            size: CGSize(width: knobRadius * 2, height: knobRadius * 2)
        )
        knob.layer.cornerRadius = knobRadius
        knob.center = centerPoint
    }

    private func applyTheme() {
        backgroundColor = isDarkAppearance
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.black.withAlphaComponent(0.30)
        knob.backgroundColor = isDarkAppearance
            ? UIColor.white.withAlphaComponent(0.90)
            : UIColor.white.withAlphaComponent(0.90)
        layer.borderWidth = 1
        layer.borderColor = isDarkAppearance
            ? UIColor.white.withAlphaComponent(0.22).cgColor
            : UIColor.black.withAlphaComponent(0.15).cgColor
    }

    private var centerPoint: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Gesture
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)

        var dx = translation.x
        var dy = translation.y

        let distance = hypot(dx, dy)
        if distance > maxDistance {
            let scale = maxDistance / distance
            dx *= scale
            dy *= scale
        }

        knob.center = CGPoint(
            x: centerPoint.x + dx,
            y: centerPoint.y + dy
        )

        onMove?(Float(dx / maxDistance), Float(dy / maxDistance))

        if gesture.state == .ended || gesture.state == .cancelled {
            UIView.animate(withDuration: 0.15) {
                self.knob.center = self.centerPoint
            }
            onMove?(0, 0)
        }
    }
}
