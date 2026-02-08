import Foundation

// MARK: - Tool Registry

/// Central registry for all available agent tools.
/// Provides tool lookup, schema generation, and execution dispatch.
actor ToolRegistry {
    private var tools: [String: any AgentTool] = [:]

    init() {
        registerDefaults()
    }

    // MARK: - Registration

    func register(_ tool: any AgentTool) {
        tools[tool.name] = tool
    }

    func unregister(_ name: String) {
        tools.removeValue(forKey: name)
    }

    // MARK: - Lookup & Execution

    func tool(named name: String) -> (any AgentTool)? {
        tools[name]
    }

    func execute(toolName: String, arguments: [String: Any]) async throws -> ToolOutput {
        guard let tool = tools[toolName] else {
            throw ToolError.toolNotFound(toolName)
        }
        return try await tool.execute(arguments: arguments)
    }

    // MARK: - Schema Generation

    /// Generate tool descriptions for the LLM system prompt.
    func toolDescriptions() -> String {
        let toolList = tools.values.map { tool in
            """
            - **\(tool.name)**: \(tool.description)
              Parameters: \(tool.parametersSchema.jsonRepresentation)
            """
        }.sorted().joined(separator: "\n")

        return """
        Available tools:
        \(toolList)

        To use a tool, respond with:
        <tool_call>
        {"name": "tool_name", "arguments": "{\\\"param\\\": \\\"value\\\"}"}
        </tool_call>
        """
    }

    var registeredToolNames: [String] {
        Array(tools.keys).sorted()
    }

    // MARK: - Default Tools

    private func registerDefaults() {
        let defaults: [any AgentTool] = [
            DeviceInfoTool(),
            ClipboardTool(),
            WebSearchTool(),
            CalendarTool(),
            ReminderTool(),
            AppLauncherTool(),
            TimerTool(),
            CalculatorTool(),
        ]
        for tool in defaults {
            tools[tool.name] = tool
        }
    }
}
