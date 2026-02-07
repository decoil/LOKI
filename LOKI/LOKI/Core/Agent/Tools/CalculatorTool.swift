import Foundation

// MARK: - Calculator Tool

struct CalculatorTool: AgentTool {
    let name = "calculator"
    let description = "Perform mathematical calculations. Supports basic arithmetic, percentages, and unit conversions."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "expression": .init(
                type: "string",
                description: "Mathematical expression to evaluate (e.g., '15% of 200', 'sqrt(144)', '5 * 12 + 3')"
            ),
        ],
        required: ["expression"]
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let expression = arguments["expression"] as? String, !expression.isEmpty else {
            throw ToolError.invalidArguments("'expression' is required")
        }

        // Handle percentage expressions
        if let percentResult = evaluatePercentage(expression) {
            return .success("\(expression) = \(formatNumber(percentResult))")
        }

        // Handle special functions
        if let funcResult = evaluateFunction(expression) {
            return .success("\(expression) = \(formatNumber(funcResult))")
        }

        // Use NSExpression for standard math
        let sanitized = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "^", with: "**")

        do {
            let expr = NSExpression(format: sanitized)
            if let result = expr.expressionValue(with: nil, context: nil) as? NSNumber {
                return .success("\(expression) = \(formatNumber(result.doubleValue))")
            }
            return .error("Could not evaluate expression: \(expression)")
        } catch {
            return .error("Invalid expression: \(expression). Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Percentage

    private func evaluatePercentage(_ expr: String) -> Double? {
        // Pattern: "X% of Y"
        let pattern = #"(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: expr, range: NSRange(expr.startIndex..., in: expr)),
              match.numberOfRanges == 3,
              let r1 = Range(match.range(at: 1), in: expr),
              let r2 = Range(match.range(at: 2), in: expr),
              let percent = Double(expr[r1]),
              let value = Double(expr[r2]) else {
            return nil
        }
        return (percent / 100.0) * value
    }

    // MARK: - Functions

    private func evaluateFunction(_ expr: String) -> Double? {
        let trimmed = expr.trimmingCharacters(in: .whitespaces).lowercased()

        let patterns: [(String, (Double) -> Double)] = [
            ("sqrt", { Foundation.sqrt($0) }),
            ("cbrt", { Foundation.cbrt($0) }),
            ("abs", { Foundation.fabs($0) }),
            ("sin", { Foundation.sin($0) }),
            ("cos", { Foundation.cos($0) }),
            ("tan", { Foundation.tan($0) }),
            ("log", { Foundation.log10($0) }),
            ("ln", { Foundation.log($0) }),
            ("ceil", { Foundation.ceil($0) }),
            ("floor", { Foundation.floor($0) }),
            ("round", { Foundation.round($0) }),
        ]

        for (name, fn) in patterns {
            let fnPattern = "\(name)\\(([^)]+)\\)"
            if let regex = try? NSRegularExpression(pattern: fnPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed),
               let value = Double(trimmed[range]) {
                return fn(value)
            }
        }

        return nil
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.6g", value)
    }
}
