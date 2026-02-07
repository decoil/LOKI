import Foundation
import SwiftData

// MARK: - Conversation Entity

@Model
final class ConversationEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.conversation)
    var messages: [MessageEntity]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isPinned: Bool = false,
        messages: [MessageEntity] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.messages = messages
    }

    var sortedMessages: [MessageEntity] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }

    var lastMessage: MessageEntity? {
        sortedMessages.last
    }

    var preview: String {
        lastMessage?.content.prefix(100).description ?? "Empty conversation"
    }

    func toChatMessages() -> [ChatMessage] {
        sortedMessages.map { msg in
            ChatMessage(
                id: msg.id,
                role: ChatMessage.Role(rawValue: msg.role) ?? .user,
                content: msg.content,
                timestamp: msg.timestamp
            )
        }
    }
}
