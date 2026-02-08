import Foundation
import SwiftData

// MARK: - Conversation Store

/// Manages conversation CRUD operations backed by SwiftData.
@MainActor
final class ConversationStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetchAll() throws -> [ConversationEntity] {
        let descriptor = FetchDescriptor<ConversationEntity>(
            sortBy: [
                SortDescriptor(\.isPinned, order: .reverse),
                SortDescriptor(\.updatedAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetch(id: UUID) throws -> ConversationEntity? {
        let descriptor = FetchDescriptor<ConversationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Create

    @discardableResult
    func createConversation(title: String = "New Chat") throws -> ConversationEntity {
        let conversation = ConversationEntity(title: title)
        modelContext.insert(conversation)
        try modelContext.save()
        return conversation
    }

    // MARK: - Messages

    func addMessage(
        to conversation: ConversationEntity,
        role: ChatMessage.Role,
        content: String,
        toolCalls: [ToolCall]? = nil,
        toolResult: ToolResult? = nil
    ) throws -> MessageEntity {
        let message = MessageEntity(
            role: role.rawValue,
            content: content
        )
        message.toolCalls = toolCalls
        message.toolResult = toolResult
        // Setting the inverse relationship is sufficient — SwiftData manages both sides.
        // Do NOT also append to conversation.messages (causes duplicate insertion).
        message.conversation = conversation
        conversation.updatedAt = Date()

        // Auto-generate title from first user message
        if conversation.title == "New Chat",
           role == .user,
           conversation.messages.count <= 2 {
            conversation.title = generateTitle(from: content)
        }

        try modelContext.save()
        return message
    }

    func updateMessageContent(_ message: MessageEntity, content: String) throws {
        message.content = content
        try modelContext.save()
    }

    func markStreamingComplete(_ message: MessageEntity) throws {
        message.isStreaming = false
        try modelContext.save()
    }

    // MARK: - Update

    func renameConversation(_ conversation: ConversationEntity, title: String) throws {
        conversation.title = title
        try modelContext.save()
    }

    func togglePin(_ conversation: ConversationEntity) throws {
        conversation.isPinned.toggle()
        try modelContext.save()
    }

    // MARK: - Delete

    func deleteConversation(_ conversation: ConversationEntity) throws {
        modelContext.delete(conversation)
        try modelContext.save()
    }

    func deleteAllConversations() throws {
        let conversations = try fetchAll()
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        try modelContext.save()
    }

    // MARK: - Helpers

    private func generateTitle(from content: String) -> String {
        let words = content.split(separator: " ").prefix(6)
        let title = words.joined(separator: " ")
        return title.count > 40 ? String(title.prefix(40)) + "..." : title
    }
}
