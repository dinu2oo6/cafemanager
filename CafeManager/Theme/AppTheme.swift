import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let primary = Color(red: 107/255, green: 68/255, blue: 35/255)       // #6B4423
    static let secondary = Color(red: 139/255, green: 90/255, blue: 43/255)     // #8B5A2B
    static let accent = Color(red: 245/255, green: 240/255, blue: 232/255)      // #F5F0E8
    static let success = Color(red: 40/255, green: 167/255, blue: 69/255)       // #28A745
    static let warning = Color(red: 255/255, green: 193/255, blue: 7/255)       // #FFC107
    static let error = Color(red: 220/255, green: 53/255, blue: 69/255)         // #DC3545
    static let textPrimary = Color(red: 44/255, green: 24/255, blue: 16/255)    // #2C1810

    // MARK: - Backgrounds
    static let cardBackground = Color.white
    static let background = accent

    // MARK: - Layout
    static let cornerRadius: CGFloat = 8
    static let padding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12

    // MARK: - Gradients
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [primary.opacity(0.1), accent],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
