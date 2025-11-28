////
////  ModernTextField.swift
////  Envisionf2
////
////  Created by user@78 on 15/11/25.
////
//
//
//import UIKit
//
//final class ModernTextField1: UIView {
//
//    let textField = UITextField()
//    private let eyeButton = UIButton(type: .system)
//
//    var isSecureEntry = false {
//        didSet { textField.isSecureTextEntry = isSecureEntry }
//    }
//
//    init(placeholder: String, secure: Bool = false) {
//        super.init(frame: .zero)
//
//        layer.cornerRadius = 12
////        backgroundColor = .white
//        backgroundColor = .secondarySystemBackground
//        layer.shadowColor = UIColor.black.cgColor
//        layer.shadowOpacity = 0.04
//        layer.shadowRadius = 8
//        layer.shadowOffset = CGSize(width: 0, height: 2)
//
//        textField.placeholder = placeholder
//        textField.autocapitalizationType = .none
//        textField.autocorrectionType = .no
//        textField.font = UIFont.systemFont(ofSize: 16)
//        textField.translatesAutoresizingMaskIntoConstraints = false
//
//        isSecureEntry = secure
//        textField.isSecureTextEntry = secure
//
//        addSubview(textField)
//
//        // Eye Icon
//        if secure {
//            eyeButton.setImage(UIImage(systemName: "eye.slash"), for: .normal)
//            eyeButton.tintColor = .gray
//            eyeButton.addTarget(self, action: #selector(toggleSecure), for: .touchUpInside)
//            eyeButton.translatesAutoresizingMaskIntoConstraints = false
//            addSubview(eyeButton)
//
//            NSLayoutConstraint.activate([
//                eyeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
//                eyeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
//                eyeButton.widthAnchor.constraint(equalToConstant: 30),
//                eyeButton.heightAnchor.constraint(equalToConstant: 24),
//            ])
//        }
//
//        NSLayoutConstraint.activate([
//            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
//            textField.trailingAnchor.constraint(equalTo: secure ? eyeButton.leadingAnchor : trailingAnchor, constant: -12),
//            textField.topAnchor.constraint(equalTo: topAnchor, constant: 14),
//            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
//            heightAnchor.constraint(equalToConstant: 52)
//        ])
//
//        translatesAutoresizingMaskIntoConstraints = false
//    }
//
//    @objc private func toggleSecure() {
//        textField.isSecureTextEntry.toggle()
//
//        let icon = textField.isSecureTextEntry ? "eye.slash" : "eye"
//        eyeButton.setImage(UIImage(systemName: icon), for: .normal)
//    }
//
//    required init?(coder: NSCoder) { fatalError() }
//}
