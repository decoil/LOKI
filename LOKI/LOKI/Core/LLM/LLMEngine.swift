import Foundation

// MARK: - LLM Engine Protocol

/// Protocol defining the contract for any LLM inference backend.
/// Designed for actor-isolated implementations to ensure thread safety.
protocol LLMEngine: Sendable {
    /// Load the model into memory and prepare for inference.
    func load() async throws

    /// Unload the model and free resources.
    func unload() async

    /// Whether the model is currently loaded and ready.
    var isLoaded: Bool { get async }

    /// Generate a streaming response for the given messages.
    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<TokenEvent, Error>

    /// Cancel any in-progress generation.
    func cancelGeneration() async
}

// MARK: - Chat Message

struct ChatMessage: Sendable, Codable, Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var toolCalls: [ToolCall]?
    var toolResult: ToolResult?

    enum Role: String, Sendable, Codable {
        case system
        case user
        case assistant
        case tool
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        toolCalls: [ToolCall]? = nil,
        toolResult: ToolResult? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.toolResult = toolResult
    }
}

// MARK: - Tool Call / Result

struct ToolCall: Sendable, Codable, Identifiable {
    let id: String
    let name: String
    let arguments: String
}

struct ToolResult: Sendable, Codable {
    let toolCallID: String
    let content: String
    let isError: Bool
}

// MARK: - Token Event

enum TokenEvent: Sendable {
    case token(String)
    case toolCall(ToolCall)
    case done(FinishReason)
}

enum FinishReason: Sendable {
    case stop
    case length
    case toolUse
    case cancelled
}

// MARK: - Generation Parameters

struct GenerationParameters: Sendable {
    var temperature: Float
    var topP: Float
    var topK: Int32
    var maxTokens: Int32
    var repeatPenalty: Float
    var stopSequences: [String]

    static let `default` = GenerationParameters(
        temperature: 0.7,
        topP: 0.9,
        topK: 40,
        maxTokens: 2048,
        repeatPenalty: 1.1,
        stopSequences: []
    )

    static let precise = GenerationParameters(
        temperature: 0.2,
        topP: 0.8,
        topK: 20,
        maxTokens: 2048,
        repeatPenalty: 1.1,
        stopSequences: []
    )

    static let creative = GenerationParameters(
        temperature: 0.9,
        topP: 0.95,
        topK: 60,
        maxTokens: 4096,
        repeatPenalty: 1.05,
        stopSequences: []
    )
}

// MARK: - LLM Configuration

struct LLMConfiguration: Sendable {
    let modelPath: String
    let contextSize: Int32
    let gpuLayers: Int32
    let temperature: Float
    let topP: Float
    let seed: UInt32

    static let `default` = LLMConfiguration(
        modelPath: "",
        contextSize: 4096,
        gpuLayers: 99,
        temperature: 0.7,
        topP: 0.9,
        seed: 0
    )
}

// MARK: - LLM Errors

enum LLMError: LocalizedError {
    case modelNotFound(String)
    case failedToLoad(String)
    case contextCreationFailed
    case generationFailed(String)
    case modelNotLoaded
    case cancelled
    case outOfMemory

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model file not found: \(path)"
        case .failedToLoad(let reason):
            return "Failed to load model: \(reason)"
        case .contextCreationFailed:
            return "Failed to create inference context"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        case .modelNotLoaded:
            return "Model is not loaded"
        case .cancelled:
            return "Generation was cancelled"
        case .outOfMemory:
            return "Not enough memory to run this model"
        }
    }
}
