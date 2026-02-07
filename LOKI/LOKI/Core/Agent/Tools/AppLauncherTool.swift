import Foundation
import UIKit

// MARK: - App Launcher Tool

struct AppLauncherTool: AgentTool {
    let name = "open_app"
    let description = "Open system apps or URLs on the device."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "target": .init(
                type: "string",
                description: "App or URL to open",
                enumValues: [
                    "settings", "mail", "messages", "phone", "safari",
                    "maps", "camera", "photos", "music", "notes",
                    "weather", "clock", "calculator", "health", "wallet",
                    "url",
                ]
            ),
            "url": .init(
                type: "string",
                description: "URL to open (when target is 'url' or 'safari')"
            ),
            "search_query": .init(
                type: "string",
                description: "Search query (for maps)"
            ),
        ],
        required: ["target"]
    )

    private static let urlSchemes: [String: String] = [
        "settings": UIApplication.openSettingsURLString,
        "mail": "mailto:",
        "messages": "sms:",
        "phone": "tel:",
        "safari": "https://",
        "maps": "maps://",
        "camera": "camera://",
        "photos": "photos-redirect://",
        "music": "music://",
        "notes": "mobilenotes://",
        "weather": "weather://",
        "clock": "clock-alarm://",
        "calculator": "calc://",
        "health": "x-apple-health://",
        "wallet": "shoebox://",
    ]

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let target = arguments["target"] as? String else {
            throw ToolError.invalidArguments("'target' is required")
        }

        let urlString: String
        if target == "url" {
            guard let url = arguments["url"] as? String, !url.isEmpty else {
                return .error("'url' parameter is required when target is 'url'")
            }
            urlString = url
        } else if target == "maps", let query = arguments["search_query"] as? String {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            urlString = "maps://?q=\(encoded)"
        } else if target == "safari", let url = arguments["url"] as? String {
            urlString = url.hasPrefix("http") ? url : "https://\(url)"
        } else {
            guard let scheme = Self.urlSchemes[target] else {
                return .error("Unknown app target: \(target)")
            }
            urlString = scheme
        }

        guard let url = URL(string: urlString) else {
            return .error("Invalid URL: \(urlString)")
        }

        let opened = await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }

        if opened {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return .success("Opened: \(target)")
        } else {
            return .error("Cannot open \(target). The app may not be installed.")
        }
    }
}
