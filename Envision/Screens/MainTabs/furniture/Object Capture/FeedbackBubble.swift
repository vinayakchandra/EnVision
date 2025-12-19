//
//  FeedbackBubble.swift
//  Envision
//

import UIKit

final class FeedbackBubble: UIView {

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        layer.cornerRadius = 14

        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        alpha = 0
    }

    func show(text: String) {
        label.text = text

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(hide), with: nil, afterDelay: 1.8)
    }

    @objc func hide() {
        UIView.animate(withDuration: 0.25) {
            self.alpha = 0
        }
    }
}
