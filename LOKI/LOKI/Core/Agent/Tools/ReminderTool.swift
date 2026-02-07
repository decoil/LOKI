import EventKit
import Foundation

// MARK: - Reminder Tool

struct ReminderTool: AgentTool {
    let name = "reminders"
    let description = "Create, list, or complete reminders."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "action": .init(
                type: "string",
                description: "Action to perform",
                enumValues: ["list", "create", "complete"]
            ),
            "title": .init(
                type: "string",
                description: "Reminder title (for create action)"
            ),
            "due_date": .init(
                type: "string",
                description: "Due date in ISO 8601 format (optional for create)"
            ),
            "priority": .init(
                type: "integer",
                description: "Priority 0-9 where 0 is none, 1 is high, 5 is medium, 9 is low"
            ),
            "reminder_index": .init(
                type: "integer",
                description: "Index of reminder to complete (for complete action)"
            ),
        ],
        required: ["action"]
    )

    private let store = EKEventStore()

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let action = arguments["action"] as? String else {
            throw ToolError.invalidArguments("'action' is required")
        }

        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await store.requestFullAccessToReminders()
        } else {
            granted = try await store.requestAccess(to: .reminder)
        }

        guard granted else {
            return .error("Reminders access denied. Please enable in Settings > Privacy > Reminders.")
        }

        switch action {
        case "list":
            return try await listReminders()
        case "create":
            return try createReminder(arguments: arguments)
        case "complete":
            return try await completeReminder(arguments: arguments)
        default:
            return .error("Unknown action: \(action)")
        }
    }

    private func listReminders() async throws -> ToolOutput {
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        let reminders = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                cont.resume(returning: result ?? [])
            }
        }

        if reminders.isEmpty {
            return .success("No incomplete reminders.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        let list = reminders.enumerated().map { index, reminder in
            var line = "\(index + 1). \(reminder.title ?? "Untitled")"
            if let dueDate = reminder.dueDateComponents,
               let date = Calendar.current.date(from: dueDate) {
                line += " (due: \(formatter.string(from: date)))"
            }
            if reminder.priority > 0 {
                let priority = switch reminder.priority {
                case 1...4: "High"
                case 5: "Medium"
                default: "Low"
                }
                line += " [\(priority)]"
            }
            return line
        }.joined(separator: "\n")

        return .success("Incomplete reminders:\n\(list)")
    }

    private func createReminder(arguments: [String: Any]) throws -> ToolOutput {
        guard let title = arguments["title"] as? String else {
            return .error("'title' is required to create a reminder")
        }

        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDateStr = arguments["due_date"] as? String {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dueDateStr) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                reminder.addAlarm(EKAlarm(absoluteDate: date))
            }
        }

        if let priority = arguments["priority"] as? Int {
            reminder.priority = min(max(priority, 0), 9)
        }

        try store.save(reminder, commit: true)
        return .success("Created reminder: \"\(title)\"")
    }

    private func completeReminder(arguments: [String: Any]) async throws -> ToolOutput {
        guard let index = arguments["reminder_index"] as? Int else {
            return .error("'reminder_index' is required to complete a reminder")
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )

        let reminders = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[EKReminder], Error>) in
            store.fetchReminders(matching: predicate) { result in
                cont.resume(returning: result ?? [])
            }
        }

        let adjustedIndex = index - 1
        guard adjustedIndex >= 0, adjustedIndex < reminders.count else {
            return .error("Invalid reminder index: \(index)")
        }

        let reminder = reminders[adjustedIndex]
        reminder.isCompleted = true
        try store.save(reminder, commit: true)

        return .success("Completed: \"\(reminder.title ?? "Untitled")\"")
    }
}
