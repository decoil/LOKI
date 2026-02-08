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
        // Only boot from idle or error — skip if already loading or ready
        switch engineStatus {
        case .loading, .ready: return
        case .idle, .error: break
        }
        engineStatus = .loading

        do {
            guard let activeModel = modelManager.activeModel else {
                engineStatus = .error("No model selected")
                return
            }

            // Read user-configured settings, falling back to model defaults
            let contextSize = Int32(UserDefaults.standard.object(forKey: "contextSize") as? Int
                ?? Int(activeModel.contextSize))
            let gpuLayers = Int32(UserDefaults.standard.object(forKey: "gpuLayers") as? Int
                ?? Int(activeModel.recommendedGPULayers))
            let temperature = Float(UserDefaults.standard.object(forKey: "temperature") as? Double ?? 0.7)

            let config = LLMConfiguration(
                modelPath: activeModel.localPath,
                contextSize: contextSize,
                gpuLayers: gpuLayers,
                temperature: temperature,
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
