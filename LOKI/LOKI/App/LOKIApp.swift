import SwiftUI
import SwiftData

@main
struct LOKIApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(for: [
                    ConversationEntity.self,
                    MessageEntity.self,
                ])
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ConversationListView()
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var activeConversationID: UUID?
    @Published var engineStatus: EngineStatus = .idle

    let modelManager = ModelManager()
    private(set) var engine: LlamaCppEngine?
    private(set) var agent: AgentCoordinator?

    enum EngineStatus: Equatable {
        case idle
        case loading
        case ready
        case error(String)
    }

    func bootEngine() async {
        guard engineStatus != .loading else { return }
        engineStatus = .loading

        do {
            guard let activeModel = modelManager.activeModel else {
                engineStatus = .error("No model selected")
                return
            }

            let config = LLMConfiguration(
                modelPath: activeModel.localPath,
                contextSize: activeModel.contextSize,
                gpuLayers: activeModel.recommendedGPULayers,
                temperature: 0.7,
                topP: 0.9,
                seed: UInt32.random(in: 0...UInt32.max)
            )

            let newEngine = LlamaCppEngine(configuration: config)
            try await newEngine.load()
            engine = newEngine
            agent = AgentCoordinator(engine: newEngine)
            engineStatus = .ready
        } catch {
            engineStatus = .error(error.localizedDescription)
        }
    }

    func shutdownEngine() async {
        await engine?.unload()
        engine = nil
        agent = nil
        engineStatus = .idle
    }
}
