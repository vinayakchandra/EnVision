//
//  ModernTextField.swift
//  Envision
//
//  iOS 26 styled text field with floating labels
//

import UIKit

final class ModernTextField: UIView {

    let textField = UITextField()
    private let floatingLabel = UILabel()
    private let eyeButton = UIButton(type: .system)
    private let placeholderText: String
    
    private var floatingLabelTopConstraint: NSLayoutConstraint!
    private var floatingLabelCenterConstraint: NSLayoutConstraint!

    var isSecureEntry = false {
        didSet { textField.isSecureTextEntry = isSecureEntry }
    }

    init(placeholder: String, secure: Bool = false) {
        self.placeholderText = placeholder
        super.init(frame: .zero)
        
        setupView()
        setupTextField(secure: secure)
        setupFloatingLabel()
        setupEyeButton(secure: secure)
        setupConstraints(secure: secure)
        
        // Add observers for text field events
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.addTarget(self, action: #selector(textFieldDidBeginEditing), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(textFieldDidEndEditing), for: .editingDidEnd)
    }
    
    private func setupView() {
        // Adaptive background - looks good in both light and dark mode
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        
        // Premium shadow for depth
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.masksToBounds = false
        
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupTextField(secure: Bool) {
        textField.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textField.textColor = .label
        textField.tintColor = AppColors.accent
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        isSecureEntry = secure
        textField.isSecureTextEntry = secure
        
        // Remove default placeholder (we use floating label)
        textField.attributedPlaceholder = nil
        
        addSubview(textField)
    }
    
    private func setupFloatingLabel() {
        floatingLabel.text = placeholderText
        floatingLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        floatingLabel.textColor = .secondaryLabel
        floatingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(floatingLabel)
    }
    
    private func setupEyeButton(secure: Bool) {
        guard secure else { return }
        
        eyeButton.setImage(UIImage(systemName: "eye.slash.fill"), for: .normal)
        eyeButton.tintColor = .tertiaryLabel
        eyeButton.addTarget(self, action: #selector(toggleSecure), for: .touchUpInside)
        eyeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Modern button configuration
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        eyeButton.configuration = config
        
        addSubview(eyeButton)
    }
    
    private func setupConstraints(secure: Bool) {
        // Floating label constraints
        floatingLabelCenterConstraint = floatingLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        floatingLabelTopConstraint = floatingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8)
        floatingLabelCenterConstraint.isActive = true
        
        NSLayoutConstraint.activate([
            floatingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
        ])
        
        // Eye button constraints
        if secure {
            NSLayoutConstraint.activate([
                eyeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                eyeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
                eyeButton.widthAnchor.constraint(equalToConstant: 44),
                eyeButton.heightAnchor.constraint(equalToConstant: 44),
            ])
        }
        
        // Text field constraints
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            textField.trailingAnchor.constraint(equalTo: secure ? eyeButton.leadingAnchor : trailingAnchor, constant: -18),
            textField.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(equalToConstant: 58)
        ])
    }
    
    // MARK: - Floating Label Animation
    
    @objc private func textFieldDidChange() {
        animateFloatingLabel(shouldFloat: !textField.text.isNilOrEmpty)
    }
    
    @objc private func textFieldDidBeginEditing() {
        animateBorderColor(focused: true)
        animateFloatingLabel(shouldFloat: true)
    }
    
    @objc private func textFieldDidEndEditing() {
        animateBorderColor(focused: false)
        animateFloatingLabel(shouldFloat: !textField.text.isNilOrEmpty)
    }
    
    private func animateFloatingLabel(shouldFloat: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            if shouldFloat {
                // Float up
                self.floatingLabelCenterConstraint.isActive = false
                self.floatingLabelTopConstraint.isActive = true
                self.floatingLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                self.floatingLabel.textColor = AppColors.accent
            } else {
                // Center (placeholder position)
                self.floatingLabelTopConstraint.isActive = false
                self.floatingLabelCenterConstraint.isActive = true
                self.floatingLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
                self.floatingLabel.textColor = .secondaryLabel
            }
            self.layoutIfNeeded()
        }
    }
    
    private func animateBorderColor(focused: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            if focused {
                // Focused: Teal border with stronger shadow
                self.layer.borderColor = AppColors.accent.cgColor
                self.layer.borderWidth = 2.0
                self.layer.shadowOpacity = 0.18
                self.layer.shadowRadius = 20
                self.layer.shadowOffset = CGSize(width: 0, height: 6)
            } else {
                // Unfocused: Adaptive separator color with subtle shadow
                self.layer.borderColor = UIColor.separator.cgColor
                self.layer.borderWidth = 1.0
                self.layer.shadowOpacity = 0.12
                self.layer.shadowRadius = 16
                self.layer.shadowOffset = CGSize(width: 0, height: 4)
            }
        }
    }

    @objc private func toggleSecure() {
        textField.isSecureTextEntry.toggle()

        let icon = textField.isSecureTextEntry ? "eye.slash.fill" : "eye.fill"
        eyeButton.setImage(UIImage(systemName: icon), for: .normal)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Helper Extension
private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
