import UIKit

final class CustomTextField: UITextField {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        layer.cornerRadius = 10
        layer.borderWidth = 1.0
        layer.borderColor = AppColors.accent.withAlphaComponent(0.3).cgColor
        backgroundColor = .white
        font = AppFonts.regular(15)
        textColor = AppColors.textPrimary
        setLeftPaddingPoints(12)
        heightAnchor.constraint(equalToConstant: 45).isActive = true
        
        // Add subtle shadow
        layer.shadowColor = AppColors.accent.withAlphaComponent(0.1).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 1
    }
}

extension UITextField {
    func setLeftPaddingPoints(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: frame.height))
        leftView = paddingView
        leftViewMode = .always
    }
}
