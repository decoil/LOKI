import SwiftUI

// MARK: - Theme

enum Theme {
    // MARK: Colors
    enum Colors {
        static let accent = Color("AccentColor")
        static let accentSecondary = Color(red: 0.5, green: 0.4, blue: 1.0)

        // Backgrounds
        static let background = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
                : UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        })

        static let surface = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
                : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
        })

        static let surfaceElevated = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.16, blue: 0.2, alpha: 1)
                : UIColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1)
        })

        // Text
        static let primaryText = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)
                : UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1)
        })

        static let secondaryText = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.6, green: 0.6, blue: 0.67, alpha: 1)
                : UIColor(red: 0.4, green: 0.4, blue: 0.47, alpha: 1)
        })

        static let tertiaryText = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.4, green: 0.4, blue: 0.45, alpha: 1)
                : UIColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        })
    }

    // MARK: Layout
    enum Layout {
        static let cornerRadius: CGFloat = 12
        static let messagePadding: CGFloat = 16
        static let avatarSize: CGFloat = 32
        static let maxBubbleWidth: CGFloat = 280
    }

    // MARK: Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }
}
