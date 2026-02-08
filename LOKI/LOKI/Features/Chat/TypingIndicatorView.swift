import SwiftUI

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            lokiAvatar

            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Theme.Colors.secondaryText)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotScale(for: index))
                        .opacity(dotOpacity(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Theme.Colors.surface, in: BubbleShape(isUser: false))

            Spacer()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }

    private var lokiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("L")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 26, height: 26)
    }

    private func dotScale(for index: Int) -> CGFloat {
        let offset = Double(index) / 3.0
        let adjustedPhase = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.5 + 0.5 * sin(adjustedPhase * .pi * 2)
    }

    private func dotOpacity(for index: Int) -> CGFloat {
        let offset = Double(index) / 3.0
        let adjustedPhase = (phase + offset).truncatingRemainder(dividingBy: 1.0)
        return 0.4 + 0.6 * sin(adjustedPhase * .pi * 2)
    }
}
