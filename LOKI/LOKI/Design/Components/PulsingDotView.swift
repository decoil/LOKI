import SwiftUI

// MARK: - Pulsing Dot View

/// Animated cursor/caret for streaming text responses.
struct PulsingDotView: View {
    @State private var isVisible = true

    var body: some View {
        Circle()
            .fill(Theme.Colors.accent)
            .frame(width: 8, height: 8)
            .opacity(isVisible ? 1 : 0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isVisible
            )
            .onAppear { isVisible = false }
    }
}
