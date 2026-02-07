import Foundation

// MARK: - Agent Prompt Templates

enum AgentPrompts {
    /// Base system identity prompt for LOKI.
    static let identity = """
    You are LOKI — Locally Operated Kinetic Intelligence.
    You are a personal AI assistant that runs entirely on this iPhone.
    All processing happens on-device. No data leaves this device.
    """

    /// Prompt suffix for tool-calling mode.
    static func toolCallingInstructions(toolNames: [String]) -> String {
        """
        When you need to perform an action, use the available tools.
        Available tools: \(toolNames.joined(separator: ", "))

        To call a tool, output:
        <tool_call>
        {"name": "tool_name", "arguments": "{\\"key\\": \\"value\\"}"}
        </tool_call>

        Rules:
        1. Only call tools that are listed above.
        2. Provide valid JSON in the arguments field.
        3. Wait for tool results before making conclusions about the action.
        4. You can chain multiple tool calls if needed.
        5. If a tool fails, explain the error and suggest alternatives.
        """
    }

    /// Persona variations for different interaction styles.
    enum Persona: String, CaseIterable, Sendable {
        case standard = "Standard"
        case concise = "Concise"
        case detailed = "Detailed"
        case friendly = "Friendly"

        var systemSuffix: String {
            switch self {
            case .standard:
                return "Be helpful and balanced in your responses."
            case .concise:
                return "Be extremely concise. Use bullet points. No filler words."
            case .detailed:
                return "Provide thorough, detailed explanations with examples when helpful."
            case .friendly:
                return "Be warm and conversational. Use a friendly, approachable tone."
            }
        }
    }

    /// Construct the full system prompt.
    static func buildSystemPrompt(
        persona: Persona = .standard,
        toolNames: [String] = [],
        additionalContext: String? = nil
    ) -> String {
        var parts = [identity, persona.systemSuffix]

        if !toolNames.isEmpty {
            parts.append(toolCallingInstructions(toolNames: toolNames))
        }

        if let context = additionalContext {
            parts.append("Additional context: \(context)")
        }

        return parts.joined(separator: "\n\n")
    }
}
