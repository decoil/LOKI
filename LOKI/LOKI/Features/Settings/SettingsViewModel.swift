import Foundation
import SwiftUI

// MARK: - Settings View Model

/// @AppStorage in ObservableObject does NOT trigger objectWillChange, so we
/// use UserDefaults directly with @Published wrappers that persist on didSet.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var contextSize: Int {
        didSet { UserDefaults.standard.set(contextSize, forKey: "contextSize") }
    }
    @Published var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: "temperature") }
    }
    @Published var gpuLayers: Int {
        didSet { UserDefaults.standard.set(gpuLayers, forKey: "gpuLayers") }
    }
    @Published var selectedPersona: AgentPrompts.Persona {
        didSet { UserDefaults.standard.set(selectedPersona.rawValue, forKey: "selectedPersona") }
    }
    @Published var toolCallingEnabled: Bool {
        didSet { UserDefaults.standard.set(toolCallingEnabled, forKey: "toolCallingEnabled") }
    }

    @Published var showDeleteAllAlert = false
    @Published var diskUsageFormatted = "Calculating..."

    init() {
        let defaults = UserDefaults.standard
        self.contextSize = defaults.object(forKey: "contextSize") as? Int ?? 2048
        self.temperature = defaults.object(forKey: "temperature") as? Double ?? 0.7
        self.gpuLayers = defaults.object(forKey: "gpuLayers") as? Int ?? 99
        self.toolCallingEnabled = defaults.object(forKey: "toolCallingEnabled") as? Bool ?? true
        if let raw = defaults.string(forKey: "selectedPersona"),
           let persona = AgentPrompts.Persona(rawValue: raw) {
            self.selectedPersona = persona
        } else {
            self.selectedPersona = .standard
        }
        calculateDiskUsage()
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
