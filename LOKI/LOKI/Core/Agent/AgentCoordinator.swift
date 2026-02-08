import Foundation

// MARK: - Agent Coordinator

/// Orchestrates the agentic loop: prompt -> LLM -> tool calls -> results -> LLM.
/// Implements ReAct-style reasoning with a configurable max iteration depth.
@MainActor
final class AgentCoordinator: ObservableObject {
    private let engine: LlamaCppEngine
    private let toolRegistry = ToolRegistry()
    private let maxIterations = 5
    private var currentTask: Task<Void, Never>?

    @Published private(set) var isProcessing = false
    @Published private(set) var currentToolExecution: String?

    init(engine: LlamaCppEngine) {
        self.engine = engine
    }

    // MARK: - Public API

    /// Process a user message through the full agentic pipeline.
    /// Returns an AsyncStream of response fragments (text + tool results).
    func process(
        messages: [ChatMessage],
        parameters: GenerationParameters = .default
    ) -> AsyncThrowingStream<AgentEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                self.isProcessing = true
                defer {
                    self.isProcessing = false
                    self.currentToolExecution = nil
                    self.currentTask = nil
                }

                do {
                    try await self.runAgentLoop(
                        messages: messages,
                        parameters: parameters,
                        continuation: continuation
                    )
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }

            self.currentTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func cancel() async {
        currentTask?.cancel()
        currentTask = nil
        await engine.cancelGeneration()
        isProcessing = false
        currentToolExecution = nil
    }

    // MARK: - Agent Loop

    private func runAgentLoop(
        messages: [ChatMessage],
        parameters: GenerationParameters,
        continuation: AsyncThrowingStream<AgentEvent, Error>.Continuation
    ) async throws {
        var conversationMessages = messages
        let systemPrompt = await buildSystemPrompt()

        // Prepend system prompt if not already present
        if conversationMessages.first?.role != .system {
            conversationMessages.insert(
                ChatMessage(role: .system, content: systemPrompt),
                at: 0
            )
        }

        for iteration in 0..<maxIterations {
            try Task.checkCancellation()

            var accumulatedText = ""
            var pendingToolCalls: [ToolCall] = []
            var finishReason: FinishReason = .stop

            // Stream from LLM
            let stream = await engine.generate(
                messages: conversationMessages,
                parameters: parameters
            )

            for try await event in stream {
                switch event {
                case .token(let text):
                    accumulatedText += text
                    continuation.yield(.text(text))

                case .toolCall(let call):
                    pendingToolCalls.append(call)
                    continuation.yield(.toolCallStarted(call.name))

                case .done(let reason):
                    finishReason = reason
                }
            }

            // Execute tool calls if any were emitted, regardless of finishReason.
            // Small models may not always set finishReason to .toolUse even when
            // they emit valid tool calls via <tool_call> tags.
            guard !pendingToolCalls.isEmpty else {
                continuation.yield(.completed)
                continuation.finish()
                return
            }

            // Add assistant message with tool calls
            conversationMessages.append(ChatMessage(
                role: .assistant,
                content: accumulatedText,
                toolCalls: pendingToolCalls
            ))

            // Execute tools
            for call in pendingToolCalls {
                try Task.checkCancellation()

                currentToolExecution = call.name
                continuation.yield(.toolExecuting(call.name))

                let result = await executeToolSafely(call)
                continuation.yield(.toolResult(call.name, result.content))

                conversationMessages.append(ChatMessage(
                    role: .tool,
                    content: result.content,
                    toolResult: ToolResult(
                        toolCallID: call.id,
                        content: result.content,
                        isError: result.isError
                    )
                ))
            }

            currentToolExecution = nil

            // Safety check: last iteration without resolution
            if iteration == maxIterations - 1 {
                continuation.yield(.text("\n\n*Reached maximum tool call depth.*"))
                continuation.yield(.completed)
                continuation.finish()
                return
            }
        }

        continuation.yield(.completed)
        continuation.finish()
    }

    // MARK: - System Prompt

    private func buildSystemPrompt() async -> String {
        let toolDescriptions = await toolRegistry.toolDescriptions()
        return """
        You are LOKI (Locally Operated Kinetic Intelligence), a personal AI assistant \
        running entirely on-device. You are helpful, concise, and action-oriented.

        Core principles:
        - Be direct and efficient. No unnecessary preamble.
        - When the user asks you to DO something, use the appropriate tool.
        - Think step-by-step for complex requests, but keep responses focused.
        - If a tool call fails, explain what happened and suggest alternatives.
        - You run locally—reassure users their data stays on-device.

        \(toolDescriptions)

        Respond naturally in conversation. Use tools when action is needed.
        """
    }

    // MARK: - Tool Execution

    private func executeToolSafely(_ call: ToolCall) async -> ToolOutput {
        do {
            let args = parseArguments(call.arguments)
            return try await toolRegistry.execute(toolName: call.name, arguments: args)
        } catch {
            return .error("Tool '\(call.name)' failed: \(error.localizedDescription)")
        }
    }

    private func parseArguments(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
}

// MARK: - Agent Events

enum AgentEvent: Sendable {
    case text(String)
    case toolCallStarted(String)
    case toolExecuting(String)
    case toolResult(String, String)
    case completed
}
