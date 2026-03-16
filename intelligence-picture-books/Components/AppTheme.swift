import SwiftUI

enum AppTheme {
    static let primary = Color(hex: 0x7B8CFF)
    static let secondary = Color(hex: 0xA8B4FF)
    static let accent = Color(hex: 0xFFD76B)
    static let background = Color(hex: 0xF8F9FF)

    static let skyTop = Color(hex: 0xC5CCFF)
    static let skyMiddle = Color(hex: 0xD8DCFF)
    static let skyBottom = Color(hex: 0xEDE8FF)
    static let cloudWhite = Color.white.opacity(0.7)

    static let heroGradient = LinearGradient(
        colors: [skyTop, skyMiddle, skyBottom],
        startPoint: .top, endPoint: .bottom
    )

    static let buttonGradient = LinearGradient(
        colors: [Color(hex: 0x8B8FFF), Color(hex: 0x9B7EFF), Color(hex: 0xA88BFF)],
        startPoint: .leading, endPoint: .trailing
    )
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
