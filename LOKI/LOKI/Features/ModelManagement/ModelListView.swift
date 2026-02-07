import SwiftUI

// MARK: - Model List View

struct ModelListView: View {
    @EnvironmentObject private var appState: AppState

    private var modelManager: ModelManager { appState.modelManager }

    var body: some View {
        List {
            recommendedSection
            allModelsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background)
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        Section {
            ModelRow(
                model: ModelCatalog.recommended,
                isActive: modelManager.activeModel?.id == ModelCatalog.recommended.id,
                progress: modelManager.downloadProgress[ModelCatalog.recommended.id],
                onSelect: { selectModel(ModelCatalog.recommended) },
                onDownload: { downloadModel(ModelCatalog.recommended) },
                onDelete: { deleteModel(ModelCatalog.recommended) }
            )
        } header: {
            Text("Recommended")
        } footer: {
            Text("Qwen3 1.7B has the best tool-calling and reasoning for an agentic AI on iPhone 12+. Only ~1.2GB.")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    // MARK: - All Models

    private var allModelsSection: some View {
        Section {
            ForEach(modelManager.availableModels.filter { $0.id != ModelCatalog.recommended.id }) { model in
                ModelRow(
                    model: model,
                    isActive: modelManager.activeModel?.id == model.id,
                    progress: modelManager.downloadProgress[model.id],
                    onSelect: { selectModel(model) },
                    onDownload: { downloadModel(model) },
                    onDelete: { deleteModel(model) }
                )
            }
        } header: {
            Text("All Models")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    // MARK: - Actions

    private func selectModel(_ model: ModelDescriptor) {
        guard model.isDownloaded else { return }
        modelManager.setActiveModel(model)
        Task { await appState.bootEngine() }
    }

    private func downloadModel(_ model: ModelDescriptor) {
        Task {
            try? await modelManager.downloadModel(model)
        }
    }

    private func deleteModel(_ model: ModelDescriptor) {
        try? modelManager.deleteModel(model)
    }
}

// MARK: - Model Row

struct ModelRow: View {
    let model: ModelDescriptor
    let isActive: Bool
    let progress: ModelManager.DownloadProgress?
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: model.family.icon)
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.name)
                            .font(.headline)
                        if isActive {
                            Text("Active")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text("\(model.parameterCount) params  \(model.quantization)  \(model.sizeFormatted)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Spacer()

                actionButton
            }

            // Capabilities
            HStack(spacing: 4) {
                ForEach(Array(model.capabilities).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { cap in
                    Text(cap.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.surfaceElevated, in: Capsule())
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }

            // Download progress
            if let progress, case .downloading = progress.status {
                ProgressView(value: progress.fraction)
                    .tint(Theme.Colors.accent)
                    .animation(.linear, value: progress.fraction)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var actionButton: some View {
        if model.isDownloaded {
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.accent)
            } else {
                Menu {
                    Button("Set as Active", action: onSelect)
                    Button("Delete Model", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        } else if let progress, case .downloading = progress.status {
            ProgressView()
                .scaleEffect(0.8)
        } else {
            Button(action: onDownload) {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
    }
}
