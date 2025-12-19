//
//  ArrowGuideView.swift
//  Envision
//
//  Created by user@78 on 22/11/25.
//


import UIKit

final class ArrowGuideView: UIImageView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        image = UIImage(systemName: "arrow.triangle.2.circlepath.camera")?
            .withRenderingMode(.alwaysTemplate)
        tintColor = .white
        alpha = 0
    }

    func show() {
        UIView.animate(withDuration: 0.25) { self.alpha = 1 }
    }

    func hide() {
        UIView.animate(withDuration: 0.25) { self.alpha = 0 }
    }
}
