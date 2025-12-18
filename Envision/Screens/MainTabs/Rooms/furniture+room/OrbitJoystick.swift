import UIKit

final class OrbitJoystick: UIView {

    // MARK: - Output
    /// Normalized values (-1...1)
    var onMove: ((Float, Float) -> Void)?

    // MARK: - UI
    private let knob = UIView()

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
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        clipsToBounds = true

        knob.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        addSubview(knob)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
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
