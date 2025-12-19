import UIKit

enum AppColors {
//    static let accent = UIColor(hex: "#4A90E2") // Blue accent
    static let accent = UIColor(hex: "#478F82") // green accent
    static let secondary = UIColor(hex: "#8B6F47") // Brown
//    static let background = UIColor(hex: "#FFFFFF")  // Pure white
    static let background: UIColor = .systemBackground
    static let backgroundSecondary = UIColor(hex: "#F8F9FA") // Off-white
    static let textPrimary = UIColor(hex: "#2C3E50") // Dark blue-gray
    static let textSecondary = UIColor(hex: "#7F8C8D") // Gray
    static let brown = UIColor(hex: "#8B6F47") // Brown
    static let lightBlue = UIColor(hex: "#E3F2FD") // Light blue background
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
