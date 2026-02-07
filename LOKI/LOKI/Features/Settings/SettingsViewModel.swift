import Foundation
import SwiftUI

// MARK: - Settings View Model

@MainActor
final class SettingsViewModel: ObservableObject {
    @AppStorage("contextSize") var contextSize = 4096
    @AppStorage("temperature") var temperature = 0.7
    @AppStorage("gpuLayers") var gpuLayers = 99
    @AppStorage("selectedPersona") var selectedPersona: AgentPrompts.Persona = .standard
    @AppStorage("toolCallingEnabled") var toolCallingEnabled = true

    @Published var showDeleteAllAlert = false
    @Published var diskUsageFormatted = "Calculating..."

    init() {
        calculateDiskUsage()
    }

    func deleteAllConversations() {
        // Handled via the ConversationStore in the calling view
    }

    func calculateDiskUsage() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("models")

        var totalSize: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: modelsDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let url as URL in enumerator {
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(attrs?.fileSize ?? 0)
            }
        }

        diskUsageFormatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - AppStorage Conformance for Persona

extension AgentPrompts.Persona: RawRepresentable {
    // Already RawRepresentable via String
}
