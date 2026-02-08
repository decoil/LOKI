import Foundation

// MARK: - Agent Tool Protocol

/// Protocol for agentic tools that LOKI can invoke to perform actions.
protocol AgentTool: Sendable {
    /// Unique identifier for this tool.
    var name: String { get }

    /// Human-readable description for the LLM to understand when to use this tool.
    var description: String { get }

    /// JSON Schema describing the tool's parameters.
    var parametersSchema: ToolParametersSchema { get }

    /// Execute the tool with the given arguments.
    func execute(arguments: [String: Any]) async throws -> ToolOutput
}

// MARK: - Tool Parameters Schema

struct ToolParametersSchema: Sendable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]

    struct PropertySchema: Sendable {
        let type: String
        let description: String
        let enumValues: [String]?

        init(type: String, description: String, enumValues: [String]? = nil) {
            self.type = type
            self.description = description
            self.enumValues = enumValues
        }
    }

    /// Render as JSON string for inclusion in system prompt.
    var jsonRepresentation: String {
        var props: [String: Any] = [:]
        for (key, schema) in properties {
            var prop: [String: Any] = [
                "type": schema.type,
                "description": schema.description,
            ]
            if let enums = schema.enumValues {
                prop["enum"] = enums
            }
            props[key] = prop
        }
        let schema: [String: Any] = [
            "type": type,
            "properties": props,
            "required": required,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: schema, options: .sortedKeys),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - Tool Output

struct ToolOutput: Sendable {
    let content: String
    let isError: Bool
    let artifacts: [Artifact]

    struct Artifact: Sendable {
        let type: ArtifactType
        let data: Data

        enum ArtifactType: Sendable {
            case text
            case json
            case url
        }
    }

    static func success(_ content: String) -> ToolOutput {
        ToolOutput(content: content, isError: false, artifacts: [])
    }

    static func error(_ message: String) -> ToolOutput {
        ToolOutput(content: message, isError: true, artifacts: [])
    }
}

// MARK: - Tool Errors

enum ToolError: LocalizedError {
    case invalidArguments(String)
    case permissionDenied(String)
    case executionFailed(String)
    case toolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        case .executionFailed(let msg): return "Execution failed: \(msg)"
        case .toolNotFound(let name): return "Tool not found: \(name)"
        }
    }
}
