import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                modelSection
                personalitySection
                memorySection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Model Section

    private var modelSection: some View {
        Section {
            NavigationLink {
                ModelListView()
            } label: {
                HStack {
                    Label("Model", systemImage: "brain")
                    Spacer()
                    if let model = appState.modelManager.activeModel {
                        Text(model.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Text("None")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }

            HStack {
                Label("Context Size", systemImage: "text.alignleft")
                Spacer()
                Text("\(viewModel.contextSize)")
                    .foregroundStyle(Theme.Colors.secondaryText)
                Stepper("", value: $viewModel.contextSize, in: 512...4096, step: 512)
                    .labelsHidden()
                    .frame(width: 100)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Temperature", systemImage: "thermometer.medium")
                    Spacer()
                    Text(String(format: "%.1f", viewModel.temperature))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.temperature, in: 0...2, step: 0.1)
                    .tint(Theme.Colors.accent)
            }

            HStack {
                Label("GPU Layers", systemImage: "cpu")
                Spacer()
                Text("\(viewModel.gpuLayers)")
                    .foregroundStyle(Theme.Colors.secondaryText)
                Stepper("", value: $viewModel.gpuLayers, in: 0...99)
                    .labelsHidden()
                    .frame(width: 100)
            }
        } header: {
            Text("Inference")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    // MARK: - Personality Section

    private var personalitySection: some View {
        Section {
            Picker("Persona", selection: $viewModel.selectedPersona) {
                ForEach(AgentPrompts.Persona.allCases, id: \.self) { persona in
                    Text(persona.rawValue).tag(persona)
                }
            }

            Toggle("Enable Tool Calling", isOn: $viewModel.toolCallingEnabled)
                .tint(Theme.Colors.accent)
        } header: {
            Text("Personality")
        }
        .listRowBackground(Theme.Colors.surface)
    }

    // MARK: - Memory Section

    private var memorySection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showDeleteAllAlert = true
            } label: {
                Label("Delete All Conversations", systemImage: "trash")
                    .foregroundStyle(.red)
            }

            HStack {
                Label("Disk Usage", systemImage: "internaldrive")
                Spacer()
                Text(viewModel.diskUsageFormatted)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        } header: {
            Text("Data")
        }
        .listRowBackground(Theme.Colors.surface)
        .alert("Delete All Conversations?", isPresented: $viewModel.showDeleteAllAlert) {
            Button("Delete All", role: .destructive) {
                let store = ConversationStore(modelContext: modelContext)
                try? store.deleteAllConversations()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            HStack {
                Label("Engine", systemImage: "gearshape.2")
                Spacer()
                Text("llama.cpp")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            HStack {
                Label("Privacy", systemImage: "lock.shield")
                Spacer()
                Text("100% On-Device")
                    .foregroundStyle(Theme.Colors.accent)
            }
        } header: {
            Text("About LOKI")
        } footer: {
            Text("Locally Operated Kinetic Intelligence\nAll processing happens on your device. Your data never leaves your iPhone.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .listRowBackground(Theme.Colors.surface)
    }
}
