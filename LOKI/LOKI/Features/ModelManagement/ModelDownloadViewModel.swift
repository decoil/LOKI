import Foundation
import SwiftUI

// MARK: - Model Download View Model

@MainActor
@Observable
final class ModelDownloadViewModel {
    private let modelManager: ModelManager
    var selectedModel: ModelDescriptor?
    var showConfirmation = false
    var errorMessage: String?

    init(modelManager: ModelManager) {
        self.modelManager = modelManager
    }

    var isDownloading: Bool {
        guard let id = selectedModel?.id else { return false }
        if let progress = modelManager.downloadProgress[id],
           case .downloading = progress.status {
            return true
        }
        return false
    }

    var downloadFraction: Double {
        guard let id = selectedModel?.id else { return 0 }
        return modelManager.downloadProgress[id]?.fraction ?? 0
    }

    func startDownload(_ model: ModelDescriptor) async {
        selectedModel = model
        errorMessage = nil
        do {
            try await modelManager.downloadModel(model)
            modelManager.setActiveModel(model)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelDownload() {
        guard let id = selectedModel?.id else { return }
        modelManager.cancelDownload(id)
        selectedModel = nil
    }
}
