import Foundation
import UserNotifications

// MARK: - Timer Tool

struct TimerTool: AgentTool {
    let name = "timer"
    let description = "Set a timer or alarm with a notification. Useful for cooking, reminders, etc."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "action": .init(
                type: "string",
                description: "Action to perform",
                enumValues: ["set", "cancel_all"]
            ),
            "seconds": .init(
                type: "integer",
                description: "Timer duration in seconds"
            ),
            "label": .init(
                type: "string",
                description: "Label for the timer notification"
            ),
        ],
        required: ["action"]
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("'action' is required")
        }

        let center = UNUserNotificationCenter.current()

        switch action {
        case "set":
            guard let seconds = arguments["seconds"] as? Int, seconds > 0 else {
                return .error("'seconds' must be a positive integer")
            }

            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            guard granted else {
                return .error("Notification permission denied. Enable in Settings.")
            }

            let label = arguments["label"] as? String ?? "LOKI Timer"

            let content = UNMutableNotificationContent()
            content.title = "LOKI Timer"
            content.body = label
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(seconds),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "loki-timer-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )

            try await center.add(request)

            let formatted = formatDuration(seconds)
            return .success("Timer set: \"\(label)\" in \(formatted)")

        case "cancel_all":
            center.removeAllPendingNotificationRequests()
            return .success("All pending timers cancelled.")

        default:
            return .error("Unknown action: \(action)")
        }
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        var parts: [String] = []
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        if seconds > 0 { parts.append("\(seconds)s") }
        return parts.joined(separator: " ")
    }
}
