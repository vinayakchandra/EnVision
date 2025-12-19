import UIKit

//extension UIColor {
//    convenience init(hex: String) {
//        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
//            .replacingOccurrences(of: "#", with: "")
//
//        if cleaned.count == 6 {
//            cleaned.append("FF") // add alpha
//        }
//
//        var value: UInt64 = 0
//        Scanner(string: cleaned).scanHexInt64(&value)
//
//        let r = CGFloat((value >> 24) & 0xFF) / 255
//        let g = CGFloat((value >> 16) & 0xFF) / 255
//        let b = CGFloat((value >> 8) & 0xFF) / 255
//        let a = CGFloat(value & 0xFF) / 255
//
//        self.init(red: r, green: g, blue: b, alpha: a)
//    }
//}

extension UIView {
    func applyGradientBackground(colors: [UIColor]) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = bounds
        gradientLayer.opacity = 0.25
        layer.insertSublayer(gradientLayer, at: 0)
    }
}
//
//class CustomTextField: UITextField {
//
//    init(placeholder: String) {
//        super.init(frame: .zero)
//        self.placeholder = placeholder
//        self.layer.cornerRadius = 12
//        self.backgroundColor = .white
//        self.layer.borderWidth = 1
//        self.layer.borderColor = UIColor.systemGray4.cgColor
//        self.font = UIFont.systemFont(ofSize: 16)
//        self.autocapitalizationType = .none
//        self.translatesAutoresizingMaskIntoConstraints = false
//        self.setLeftPadding(14)
//        self.heightAnchor.constraint(equalToConstant: 50).isActive = true
//    }
//
//    required init?(coder: NSCoder) { fatalError() }
//}

extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: self.frame.height))
        leftView = paddingView
        leftViewMode = .always
    }
}
extension String {
    var isValidEmail: Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }

    var isStrongPassword: Bool {
        let regex = "^(?=.*[A-Z])(?=.*[0-9]).{8,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
}
