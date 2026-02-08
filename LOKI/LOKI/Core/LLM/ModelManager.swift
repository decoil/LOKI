import Foundation
import Observation

// MARK: - Model Manager

/// Manages model downloads, storage, and lifecycle.
@Observable
@MainActor
final class ModelManager {
    private(set) var availableModels: [ModelDescriptor] = ModelCatalog.all
    private(set) var downloadProgress: [String: DownloadProgress] = [:]
    private(set) var activeModel: ModelDescriptor?
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadSessions: [String: URLSession] = [:]
    private let fileManager = FileManager.default

    struct DownloadProgress: Sendable {
        let modelID: String
        var bytesWritten: Int64
        var totalBytes: Int64
        var fraction: Double { totalBytes > 0 ? Double(bytesWritten) / Double(totalBytes) : 0 }
        var status: Status

        enum Status: Sendable {
            case downloading
            case completed
            case failed(String)
            case cancelled
        }
    }

    init() {
        ensureModelDirectoryExists()
        loadActiveModel()
    }

    // MARK: - Public API

    func setActiveModel(_ model: ModelDescriptor) {
        activeModel = model
        UserDefaults.standard.set(model.id, forKey: "activeModelID")
    }

    func downloadModel(_ model: ModelDescriptor) async throws {
        guard downloadTasks[model.id] == nil else { return }

        downloadProgress[model.id] = DownloadProgress(
            modelID: model.id,
            bytesWritten: 0,
            totalBytes: model.sizeBytes,
            status: .downloading
        )

        let delegate = DownloadDelegate(modelID: model.id) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress[model.id] = progress
            }
        }

        let session = URLSession(
            configuration: .default,
            delegate: delegate,
            delegateQueue: nil
        )

        let task = session.downloadTask(with: model.downloadURL)
        downloadTasks[model.id] = task
        downloadSessions[model.id] = session

        // Set completion BEFORE resuming — eliminates race condition where
        // the delegate fires before the continuation body assigns the handler.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.completion = { [weak self] result in
                Task { @MainActor [weak self] in
                    self?.downloadTasks.removeValue(forKey: model.id)
                    // Invalidate session to prevent memory leak
                    self?.downloadSessions.removeValue(forKey: model.id)?.invalidateAndCancel()

                    switch result {
                    case .success(let tempURL):
                        do {
                            try self?.moveDownloadedModel(from: tempURL, to: model.localPath)
                            self?.downloadProgress[model.id]?.status = .completed
                            cont.resume()
                        } catch {
                            self?.downloadProgress[model.id]?.status = .failed(error.localizedDescription)
                            cont.resume(throwing: error)
                        }
                    case .failure(let error):
                        self?.downloadProgress[model.id]?.status = .failed(error.localizedDescription)
                        cont.resume(throwing: error)
                    }
                }
            }

            // Resume AFTER completion handler is set
            task.resume()
        }
    }

    func cancelDownload(_ modelID: String) {
        downloadTasks[modelID]?.cancel()
        downloadTasks.removeValue(forKey: modelID)
        downloadSessions.removeValue(forKey: modelID)?.invalidateAndCancel()
        downloadProgress[modelID]?.status = .cancelled
    }

    func deleteModel(_ model: ModelDescriptor) throws {
        if fileManager.fileExists(atPath: model.localPath) {
            try fileManager.removeItem(atPath: model.localPath)
        }
        if activeModel?.id == model.id {
            activeModel = nil
            UserDefaults.standard.removeObject(forKey: "activeModelID")
        }
    }

    func diskUsage() -> Int64 {
        availableModels
            .filter(\.isDownloaded)
            .reduce(0) { total, model in
                let attrs = try? fileManager.attributesOfItem(atPath: model.localPath)
                return total + (attrs?[.size] as? Int64 ?? 0)
            }
    }

    // MARK: - Private

    private func ensureModelDirectoryExists() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDir = docs.appendingPathComponent("models")
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try? fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
    }

    private func loadActiveModel() {
        guard let savedID = UserDefaults.standard.string(forKey: "activeModelID") else { return }
        activeModel = availableModels.first { $0.id == savedID && $0.isDownloaded }
    }

    private func moveDownloadedModel(from tempURL: URL, to path: String) throws {
        let destination = URL(fileURLWithPath: path)
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
        try fileManager.moveItem(at: tempURL, to: destination)
    }
}

// MARK: - Download Delegate

/// Thread-safe download delegate. The `completion` property is protected by a lock
/// since it is set from the MainActor continuation and read from the URLSession delegate queue.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    let modelID: String
    let progressHandler: @Sendable (ModelManager.DownloadProgress) -> Void

    private let _completion = OSAllocatedUnfairLock<((Result<URL, Error>) -> Void)?>(initialState: nil)

    var completion: ((Result<URL, Error>) -> Void)? {
        get { _completion.withLock { $0 } }
        set { _completion.withLock { $0 = newValue } }
    }

    init(
        modelID: String,
        progressHandler: @escaping @Sendable (ModelManager.DownloadProgress) -> Void
    ) {
        self.modelID = modelID
        self.progressHandler = progressHandler
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Copy to temp location since the file will be deleted after this method returns
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".gguf")
        do {
            try FileManager.default.copyItem(at: location, to: tempFile)
            completion?(.success(tempFile))
        } catch {
            completion?(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler(ModelManager.DownloadProgress(
            modelID: modelID,
            bytesWritten: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite,
            status: .downloading
        ))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            completion?(.failure(error))
        }
    }
}
