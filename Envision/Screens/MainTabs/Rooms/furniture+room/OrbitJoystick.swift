//
//  OrbitJoystick.swift
//  Envision
//
//  Created by Vinayak Suryavanshi on 18/12/25.
//


import UIKit

final class OrbitJoystick: UIView {

    // Output: normalized deltas (-1...1)
    var onMove: ((Float, Float) -> Void)?

    private let knob = UIView()
    private var knobRadius: CGFloat { bounds.width * 0.25 }
    private var maxDistance: CGFloat { bounds.width * 0.4 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true

        knob.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        knob.frame.size = CGSize(width: knobRadius * 2, height: knobRadius * 2)
        knob.layer.cornerRadius = knobRadius
        knob.center = centerPoint
        addSubview(knob)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }

    private var centerPoint: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let translation = g.translation(in: self)

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

        let nx = Float(dx / maxDistance)
        let ny = Float(dy / maxDistance)

        onMove?(nx, ny)

        if g.state == .ended || g.state == .cancelled {
            UIView.animate(withDuration: 0.15) {
                self.knob.center = self.centerPoint
            }
            onMove?(0, 0)
        }
    }
}
