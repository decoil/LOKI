import SwiftUI
import SwiftData

// MARK: - Conversation List View

struct ConversationListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var conversations: [ConversationEntity] = []
    @State private var selectedConversation: ConversationEntity?
    @State private var showSettings = false
    @State private var showDeleteAlert = false
    @State private var conversationToDelete: ConversationEntity?

    private var store: ConversationStore {
        ConversationStore(modelContext: modelContext)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("LOKI")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Delete Conversation?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let conv = conversationToDelete {
                        deleteConversation(conv)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatView(conversationID: conversation.id)
            }
            .onAppear { refreshConversations() }
            .task { await appState.bootEngine() }
        }
        .tint(Theme.Colors.accent)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.accent.opacity(0.3), Theme.Colors.accentSecondary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Text("L")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.accent)
            }

            Text("Welcome to LOKI")
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.primaryText)

            Text("Your on-device AI assistant.\nFully private. Always available.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            statusBadge

            Button(action: createNewConversation) {
                Label("Start a conversation", systemImage: "plus.message.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.engineStatus != .ready)
        }
        .padding()
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.Colors.surface, in: Capsule())
    }

    private var statusColor: Color {
        switch appState.engineStatus {
        case .ready: return .green
        case .loading: return .yellow
        case .idle: return .gray
        case .error: return .red
        }
    }

    private var statusLabel: String {
        switch appState.engineStatus {
        case .ready: return "Model loaded"
        case .loading: return "Loading model..."
        case .idle: return "No model loaded"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        List {
            ForEach(conversations) { conversation in
                Button {
                    selectedConversation = conversation
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .listRowBackground(Theme.Colors.surface)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        conversationToDelete = conversation
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        togglePin(conversation)
                    } label: {
                        Label(
                            conversation.isPinned ? "Unpin" : "Pin",
                            systemImage: conversation.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button(action: createNewConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(appState.engineStatus != .ready)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    // MARK: - Actions

    private func createNewConversation() {
        do {
            let conv = try store.createConversation()
            refreshConversations()
            selectedConversation = conv
        } catch {
            // Handle error
        }
    }

    private func deleteConversation(_ conversation: ConversationEntity) {
        try? store.deleteConversation(conversation)
        refreshConversations()
    }

    private func togglePin(_ conversation: ConversationEntity) {
        try? store.togglePin(conversation)
        refreshConversations()
    }

    private func refreshConversations() {
        conversations = (try? store.fetchAll()) ?? []
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationEntity

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .lineLimit(1)
                }

                Text(conversation.preview)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Text(conversation.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(.vertical, 4)
    }
}
