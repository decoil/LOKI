import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0
    @EnvironmentObject private var appState: AppState

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Meet LOKI",
            subtitle: "Locally Operated Kinetic Intelligence",
            description: "Your personal AI assistant that runs entirely on your iPhone. No cloud. No servers. Just you and LOKI."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Private by Design",
            subtitle: "Your data never leaves your device",
            description: "Every conversation, every request is processed on-device using a local language model. Zero data collection."
        ),
        OnboardingPage(
            icon: "bolt.fill",
            title: "Agentic AI",
            subtitle: "LOKI can act on your behalf",
            description: "Create reminders, search the web, manage calendar events, set timers, and more — all from a natural conversation."
        ),
        OnboardingPage(
            icon: "arrow.down.circle.fill",
            title: "Download a Model",
            subtitle: "Choose your intelligence",
            description: "Download a small but powerful language model to get started. Qwen3 4B is recommended for the best experience."
        ),
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                bottomSection
            }
        }
    }

    // MARK: - Page View

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.Colors.accent.opacity(0.2),
                                Theme.Colors.accentSecondary.opacity(0.2),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.title.bold())
                    .foregroundStyle(Theme.Colors.primaryText)

                Text(page.subtitle)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.accent)
            }

            Text(page.description)
                .font(.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Section

    private var bottomSection: some View {
        VStack(spacing: 20) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Theme.Colors.accent : Theme.Colors.surface)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Action button
            Button(action: advance) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            // Skip button
            if currentPage < pages.count - 1 {
                Button("Skip") {
                    withAnimation { currentPage = pages.count - 1 }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .padding(.bottom, 40)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            onComplete()
        }
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
}
