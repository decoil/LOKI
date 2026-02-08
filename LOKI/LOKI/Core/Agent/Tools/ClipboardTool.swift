import Foundation
import UIKit

// MARK: - Clipboard Tool

struct ClipboardTool: AgentTool {
    let name = "clipboard"
    let description = "Read from or write to the device clipboard/pasteboard."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "action": .init(
                type: "string",
                description: "Action to perform",
                enumValues: ["read", "write"]
            ),
            "text": .init(
                type: "string",
                description: "Text to write to clipboard (required for write action)"
            ),
        ],
        required: ["action"]
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("'action' is required")
        }

        return await MainActor.run {
            switch action {
            case "read":
                if let text = UIPasteboard.general.string, !text.isEmpty {
                    return .success("Clipboard contents:\n\(text)")
                } else {
                    return .success("Clipboard is empty or contains non-text content.")
                }

            case "write":
                guard let text = arguments["text"] as? String else {
                    return .error("'text' parameter is required for write action")
                }
                UIPasteboard.general.string = text
                return .success("Copied to clipboard: \"\(text.prefix(100))\"")

            default:
                return .error("Unknown action: \(action). Use 'read' or 'write'.")
            }
        }
    }
}
