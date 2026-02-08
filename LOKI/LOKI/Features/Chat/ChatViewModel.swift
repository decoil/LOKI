import Foundation
import SwiftData
import SwiftUI

// MARK: - Chat View Model

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [DisplayMessage] = []
    @Published var inputText = ""
    @Published var isGenerating = false
    @Published var streamingText = ""
    @Published var activeToolName: String?
    @Published var error: String?

    let conversationID: UUID
    private var store: ConversationStore?
    private var agent: AgentCoordinator?
    private var conversation: ConversationEntity?
    private var generationTask: Task<Void, Never>?
    private var isConfigured = false

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    init(conversationID: UUID) {
        self.conversationID = conversationID
    }

    /// Configure once — guards against repeated `.onAppear` calls.
    func configure(modelContext: ModelContext, agent: AgentCoordinator?) {
        guard !isConfigured else { return }
        isConfigured = true
        self.store = ConversationStore(modelContext: modelContext)
        self.agent = agent
        loadConversation()
    }

    // MARK: - Load

    private func loadConversation() {
        guard let store else { return }
        do {
            if let existing = try store.fetch(id: conversationID) {
                conversation = existing
                messages = existing.sortedMessages.map { DisplayMessage(from: $0) }
            } else {
                conversation = try store.createConversation()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Send

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let conversation, let store, let agent else { return }

        inputText = ""

        let userMessage = DisplayMessage(role: .user, content: text)
        messages.append(userMessage)

        do {
            _ = try store.addMessage(to: conversation, role: .user, content: text)
        } catch {
            self.error = error.localizedDescription
        }

        isGenerating = true
        streamingText = ""

        // Use a stable ID to find the assistant message by identity, not index
        let assistantID = UUID()
        messages.append(DisplayMessage(id: assistantID, role: .assistant, content: "", isStreaming: true))

        let chatMessages = conversation.toChatMessages()

        generationTask = Task { [weak self] in
            guard let self else { return }

            do {
                let stream = agent.process(messages: chatMessages)

                for try await event in stream {
                    switch event {
                    case .text(let token):
                        self.streamingText += token
                        self.updateMessage(id: assistantID, content: self.streamingText)

                    case .toolCallStarted(let name):
                        self.activeToolName = name

                    case .toolExecuting(let name):
                        self.activeToolName = name

                    case .toolResult(let name, let result):
                        self.activeToolName = nil
                        let toolMsg = DisplayMessage(role: .tool, content: "[\(name)] \(result)")
                        // Insert BEFORE assistant message — find by stable ID
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantID }) {
                            self.messages.insert(toolMsg, at: idx)
                        }

                    case .completed:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    let fallback = self.streamingText.isEmpty
                        ? "Sorry, I encountered an error. Please try again."
                        : self.streamingText
                    self.updateMessage(id: assistantID, content: fallback)
                }
            }

            // Finalize
            self.finalizeMessage(id: assistantID)
            self.isGenerating = false
            self.activeToolName = nil
            self.generationTask = nil

            let content = self.messages.first(where: { $0.id == assistantID })?.content ?? ""
            if !content.isEmpty {
                try? store.addMessage(to: conversation, role: .assistant, content: content)
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil

        Task { await agent?.cancel() }

        isGenerating = false
        activeToolName = nil

        if let idx = messages.lastIndex(where: { $0.isStreaming }) {
            messages[idx].isStreaming = false
            if messages[idx].content.isEmpty {
                messages[idx].content = "*Generation stopped.*"
            }
        }
    }

    // MARK: - Safe ID-based message mutation

    private func updateMessage(id: UUID, content: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].content = content
    }

    private func finalizeMessage(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].isStreaming = false
    }
}

// MARK: - Display Message

struct DisplayMessage: Identifiable {
    let id: UUID
    let role: ChatMessage.Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var toolCalls: [ToolCall]?

    init(
        id: UUID = UUID(),
        role: ChatMessage.Role,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        toolCalls: [ToolCall]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.toolCalls = toolCalls
    }

    init(from entity: MessageEntity) {
        self.id = entity.id
        self.role = entity.chatRole
        self.content = entity.content
        self.timestamp = entity.timestamp
        self.isStreaming = entity.isStreaming
        self.toolCalls = entity.toolCalls
    }
}
