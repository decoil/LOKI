import SwiftUI

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: DisplayMessage
    @State private var showTimestamp = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 48) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .onTapGesture { showTimestamp.toggle() }

                if showTimestamp {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if message.role != .user { Spacer(minLength: 48) }
        }
        .animation(.easeInOut(duration: 0.2), value: showTimestamp)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        case .tool:
            toolBubble
        case .system:
            EmptyView()
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.accent, in: BubbleShape(isUser: true))
            .textSelection(.enabled)
    }

    // MARK: - Assistant Bubble

    private var assistantBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            lokiAvatar

            VStack(alignment: .leading, spacing: 4) {
                Text(attributedContent)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .textSelection(.enabled)

                if message.isStreaming {
                    PulsingDotView()
                        .frame(height: 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.Colors.surface, in: BubbleShape(isUser: false))
        }
    }

    // MARK: - Tool Result Bubble

    private var toolBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.caption)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 20)

            Text(message.content)
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.Colors.surfaceElevated.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Avatar

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

    // MARK: - Attributed Content

    private var attributedContent: AttributedString {
        // Simple markdown-like formatting for **bold** and `code`
        var result = AttributedString(message.content)

        // Bold
        while let boldStart = result.range(of: "**"),
              let boldEnd = result[boldStart.upperBound...].range(of: "**") {
            let boldRange = boldStart.lowerBound..<boldEnd.upperBound
            let textRange = boldStart.upperBound..<boldEnd.lowerBound
            var boldText = AttributedString(result[textRange])
            boldText.font = .body.bold()
            result.replaceSubrange(boldRange, with: boldText)
        }

        // Inline code
        while let codeStart = result.range(of: "`"),
              let codeEnd = result[codeStart.upperBound...].range(of: "`") {
            let codeRange = codeStart.lowerBound..<codeEnd.upperBound
            let textRange = codeStart.upperBound..<codeEnd.lowerBound
            var codeText = AttributedString(result[textRange])
            codeText.font = .system(.body, design: .monospaced)
            codeText.backgroundColor = Theme.Colors.surface
            result.replaceSubrange(codeRange, with: codeText)
        }

        return result
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 4

        var path = Path()

        if isUser {
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: radius,
                    bottomLeading: radius,
                    bottomTrailing: tailRadius,
                    topTrailing: radius
                )
            )
        } else {
            path.addRoundedRect(
                in: rect,
                cornerRadii: RectangleCornerRadii(
                    topLeading: radius,
                    bottomLeading: tailRadius,
                    bottomTrailing: radius,
                    topTrailing: radius
                )
            )
        }

        return path
    }
}
