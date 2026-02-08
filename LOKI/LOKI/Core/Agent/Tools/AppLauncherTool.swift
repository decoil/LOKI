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

    /// Allowlisted URL schemes for system apps.
    /// Evaluated lazily to avoid static-property MainActor violations.
    private static let urlSchemes: [String: String] = [
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

    /// Allowed schemes for user-provided URLs (target == "url" or "safari").
    private static let allowedUserSchemes: Set<String> = ["http", "https", "mailto", "tel", "sms", "maps"]

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let target = arguments["target"] as? String else {
            throw ToolError.invalidArguments("'target' is required")
        }

        let urlString: String
        if target == "url" {
            guard let url = arguments["url"] as? String, !url.isEmpty else {
                return .error("'url' parameter is required when target is 'url'")
            }
            // Validate scheme to prevent arbitrary URL scheme opening via prompt injection
            guard let parsed = URL(string: url),
                  let scheme = parsed.scheme?.lowercased(),
                  Self.allowedUserSchemes.contains(scheme) else {
                return .error("Only http, https, mailto, tel, sms, and maps URLs are allowed.")
            }
            urlString = url
        } else if target == "maps", let query = arguments["search_query"] as? String {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            urlString = "maps://?q=\(encoded)"
        } else if target == "safari", let url = arguments["url"] as? String {
            let sanitized = url.hasPrefix("http") ? url : "https://\(url)"
            // Validate it's actually http/https
            guard let parsed = URL(string: sanitized),
                  let scheme = parsed.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return .error("Invalid URL for Safari.")
            }
            urlString = sanitized
        } else if target == "settings" {
            // UIApplication.openSettingsURLString must be read on MainActor
            urlString = await MainActor.run { UIApplication.openSettingsURLString }
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
