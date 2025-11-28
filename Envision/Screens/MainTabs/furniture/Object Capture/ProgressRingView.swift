//
//  ProgressRingView.swift
//  Envision
//
//  Created by user@78 on 22/11/25.
//


import UIKit

final class ProgressRingView: UIView {

    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let countLabel = UILabel()

    var progress: CGFloat = 0 {
        didSet { updateProgress() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        let circlePath = UIBezierPath(
            ovalIn: CGRect(x: 0, y: 0, width: 60, height: 60)
        )

        backgroundLayer.path = circlePath.cgPath
        backgroundLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        backgroundLayer.lineWidth = 6
        backgroundLayer.fillColor = UIColor.clear.cgColor

        progressLayer.path = circlePath.cgPath
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.lineWidth = 6
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeEnd = 0

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(progressLayer)

        countLabel.textAlignment = .center
        countLabel.font = .boldSystemFont(ofSize: 17)
        countLabel.textColor = .white

        addSubview(countLabel)
        countLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            countLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func updateCount(_ value: Int) {
        countLabel.text = "\(value)"
    }

    private func updateProgress() {
        progressLayer.strokeEnd = progress
    }
}
