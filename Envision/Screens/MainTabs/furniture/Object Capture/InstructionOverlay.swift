//
//  InstructionOverlay.swift
//  Envision
//

import UIKit

final class InstructionOverlay: UIView {

    var onContinue: (() -> Void)?

    private let bgView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialLight)
        return UIVisualEffectView(effect: blur)
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Before you start Scanning"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .black
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = """
Ensure good lighting
Clear the floor
Move phone slowly around the furniture
"""
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Continue", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor.systemBlue
        btn.layer.cornerRadius = 16
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        continueButton.addTarget(self, action: #selector(onContinueTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        layer.cornerRadius = 20
        clipsToBounds = true

        addSubview(bgView)
        bgView.frame = bounds
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, continueButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        addSubview(stack)

        stack.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85),

            continueButton.heightAnchor.constraint(equalToConstant: 36),
            continueButton.widthAnchor.constraint(equalToConstant: 110)
        ])
    }

    @objc private func onContinueTapped() {
        onContinue?()
    }
}
