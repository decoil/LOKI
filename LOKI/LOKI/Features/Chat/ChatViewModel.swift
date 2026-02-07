import Foundation
import SwiftData
import SwiftUI
import Combine

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

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    init(conversationID: UUID) {
        self.conversationID = conversationID
    }

    func configure(modelContext: ModelContext, agent: AgentCoordinator?) {
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

        // Add user message
        let userMessage = DisplayMessage(role: .user, content: text)
        messages.append(userMessage)

        do {
            try store.addMessage(to: conversation, role: .user, content: text)
        } catch {
            self.error = error.localizedDescription
        }

        // Start generation
        isGenerating = true
        streamingText = ""

        let assistantMessage = DisplayMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        let chatMessages = conversation.toChatMessages()

        generationTask = Task {
            do {
                let stream = agent.process(messages: chatMessages)

                for try await event in stream {
                    switch event {
                    case .text(let token):
                        streamingText += token
                        messages[assistantIndex].content = streamingText

                    case .toolCallStarted(let name):
                        activeToolName = name

                    case .toolExecuting(let name):
                        activeToolName = name

                    case .toolResult(let name, let result):
                        activeToolName = nil
                        let toolMsg = DisplayMessage(
                            role: .tool,
                            content: "[\(name)] \(result)"
                        )
                        messages.insert(toolMsg, at: assistantIndex)

                    case .completed:
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                    messages[assistantIndex].content = streamingText.isEmpty
                        ? "Sorry, I encountered an error. Please try again."
                        : streamingText
                }
            }

            // Finalize
            messages[assistantIndex].isStreaming = false
            isGenerating = false
            activeToolName = nil

            let finalContent = messages[assistantIndex].content
            if !finalContent.isEmpty, let store, let conversation {
                try? store.addMessage(to: conversation, role: .assistant, content: finalContent)
            }
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        generationTask = nil

        Task {
            await agent?.cancel()
        }

        isGenerating = false
        activeToolName = nil

        if let lastIndex = messages.indices.last, messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
            if messages[lastIndex].content.isEmpty {
                messages[lastIndex].content = "*Generation stopped.*"
            }
        }
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
