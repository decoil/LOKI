import EventKit
import Foundation

// MARK: - Calendar Tool

struct CalendarTool: AgentTool {
    let name = "calendar"
    let description = "Create, read, or search calendar events. Can check upcoming events or add new ones."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "action": .init(
                type: "string",
                description: "Action to perform",
                enumValues: ["list_today", "list_upcoming", "create", "search"]
            ),
            "title": .init(
                type: "string",
                description: "Event title (for create action)"
            ),
            "date": .init(
                type: "string",
                description: "Event date in ISO 8601 format (for create action)"
            ),
            "duration_minutes": .init(
                type: "integer",
                description: "Event duration in minutes (for create, default 60)"
            ),
            "query": .init(
                type: "string",
                description: "Search query (for search action)"
            ),
        ],
        required: ["action"]
    )

    private let store = EKEventStore()

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("'action' is required")
        }

        // Request access
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }

        guard granted else {
            return .error("Calendar access denied. Please enable in Settings > Privacy > Calendars.")
        }

        switch action {
        case "list_today":
            return listEvents(from: Calendar.current.startOfDay(for: Date()),
                            to: Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400))

        case "list_upcoming":
            return listEvents(from: Date(),
                            to: Date().addingTimeInterval(7 * 86400))

        case "create":
            return try await createEvent(arguments: arguments)

        case "search":
            let query = arguments["query"] as? String ?? ""
            return searchEvents(query: query)

        default:
            return .error("Unknown action: \(action)")
        }
    }

    private func listEvents(from startDate: Date, to endDate: Date) -> ToolOutput {
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return .success("No events found in the specified time range.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let list = events.map { event in
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            let cal = event.calendar.title
            return "- \(event.title ?? "Untitled") | \(start) - \(end) [\(cal)]"
        }.joined(separator: "\n")

        return .success("Events:\n\(list)")
    }

    private func createEvent(arguments: [String: Any]) async throws -> ToolOutput {
        guard let title = arguments["title"] as? String else {
            return .error("'title' is required to create an event")
        }

        let dateString = arguments["date"] as? String
        let duration = arguments["duration_minutes"] as? Int ?? 60

        let startDate: Date
        if let dateString {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let parsed = formatter.date(from: dateString) else {
                return .error("Invalid date format. Use ISO 8601 (e.g., 2024-12-25T14:00:00Z)")
            }
            startDate = parsed
        } else {
            // Default to next hour
            let now = Date()
            let cal = Calendar.current
            var components = cal.dateComponents([.year, .month, .day, .hour], from: now)
            components.hour = (components.hour ?? 0) + 1
            components.minute = 0
            startDate = cal.date(from: components) ?? now.addingTimeInterval(3600)
        }

        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
        event.calendar = store.defaultCalendarForNewEvents

        try store.save(event, span: .thisEvent)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return .success("Created event: \"\(title)\" on \(formatter.string(from: startDate)) for \(duration) minutes.")
    }

    private func searchEvents(query: String) -> ToolOutput {
        let startDate = Date().addingTimeInterval(-30 * 86400)
        let endDate = Date().addingTimeInterval(90 * 86400)
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { ($0.title ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return .success("No events found matching \"\(query)\".")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        let list = events.prefix(10).map { event in
            "- \(event.title ?? "Untitled") | \(formatter.string(from: event.startDate))"
        }.joined(separator: "\n")

        return .success("Events matching \"\(query)\":\n\(list)")
    }
}
