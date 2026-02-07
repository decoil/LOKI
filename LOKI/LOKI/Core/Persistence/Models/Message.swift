import Foundation
import SwiftData

// MARK: - Message Entity

@Model
final class MessageEntity {
    @Attribute(.unique) var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var toolCallsJSON: Data?
    var toolResultJSON: Data?
    var isStreaming: Bool

    var conversation: ConversationEntity?

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        toolCallsJSON: Data? = nil,
        toolResultJSON: Data? = nil,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCallsJSON = toolCallsJSON
        self.toolResultJSON = toolResultJSON
        self.isStreaming = isStreaming
    }

    // MARK: - Tool Call Accessors

    var toolCalls: [ToolCall]? {
        get {
            guard let data = toolCallsJSON else { return nil }
            return try? JSONDecoder().decode([ToolCall].self, from: data)
        }
        set {
            toolCallsJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var toolResult: ToolResult? {
        get {
            guard let data = toolResultJSON else { return nil }
            return try? JSONDecoder().decode(ToolResult.self, from: data)
        }
        set {
            toolResultJSON = try? JSONEncoder().encode(newValue)
        }
    }

    var chatRole: ChatMessage.Role {
        ChatMessage.Role(rawValue: role) ?? .user
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            role: chatRole,
            content: content,
            timestamp: timestamp,
            toolCalls: toolCalls,
            toolResult: toolResult
        )
    }
}
