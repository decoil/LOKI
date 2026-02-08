import Foundation

// MARK: - Calculator Tool

/// Safe math evaluator using shunting-yard algorithm.
/// Does NOT use NSExpression (which allows ObjC runtime injection and crashes on invalid input).
struct CalculatorTool: AgentTool {
    let name = "calculator"
    let description = "Perform mathematical calculations. Supports arithmetic (+, -, *, /), percentages (15% of 200), and functions (sqrt, abs, sin, cos, tan, log, ln, ceil, floor, round, exp)."

    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [
            "expression": .init(
                type: "string",
                description: "Mathematical expression (e.g., '15% of 200', 'sqrt(144)', '5 * 12 + 3')"
            ),
        ],
        required: ["expression"]
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        guard let expression = arguments["expression"] as? String, !expression.isEmpty else {
            throw ToolError.invalidArguments("'expression' is required")
        }

        if let result = evaluatePercentage(expression) {
            return .success("\(expression) = \(fmt(result))")
        }

        if let result = evaluateFunction(expression) {
            return .success("\(expression) = \(fmt(result))")
        }

        do {
            let result = try evaluateArithmetic(expression)
            return .success("\(expression) = \(fmt(result))")
        } catch {
            return .error("Could not evaluate: \(expression). \(error.localizedDescription)")
        }
    }

    // MARK: - Percentage: "X% of Y"

    private func evaluatePercentage(_ expr: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: expr, range: NSRange(expr.startIndex..., in: expr)),
              match.numberOfRanges == 3,
              let r1 = Range(match.range(at: 1), in: expr),
              let r2 = Range(match.range(at: 2), in: expr),
              let pct = Double(expr[r1]),
              let val = Double(expr[r2]) else { return nil }
        return (pct / 100.0) * val
    }

    // MARK: - Functions: sqrt(X), sin(X), etc.

    private func evaluateFunction(_ expr: String) -> Double? {
        let t = expr.trimmingCharacters(in: .whitespaces).lowercased()
        let fns: [(String, (Double) -> Double)] = [
            ("sqrt", { Foundation.sqrt($0) }), ("cbrt", { Foundation.cbrt($0) }),
            ("abs", { Foundation.fabs($0) }), ("sin", { Foundation.sin($0) }),
            ("cos", { Foundation.cos($0) }), ("tan", { Foundation.tan($0) }),
            ("log", { Foundation.log10($0) }), ("ln", { Foundation.log($0) }),
            ("ceil", { Foundation.ceil($0) }), ("floor", { Foundation.floor($0) }),
            ("round", { Foundation.round($0) }), ("exp", { Foundation.exp($0) }),
        ]
        for (name, fn) in fns {
            let p = "\(name)\\(([^)]+)\\)"
            if let rx = try? NSRegularExpression(pattern: p),
               let m = rx.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let r = Range(m.range(at: 1), in: t),
               let v = Double(t[r].trimmingCharacters(in: .whitespaces)) {
                return fn(v)
            }
        }
        return nil
    }

    // MARK: - Safe Arithmetic (Shunting-Yard)

    private func evaluateArithmetic(_ expr: String) throws -> Double {
        let s = expr.replacingOccurrences(of: "×", with: "*")
                     .replacingOccurrences(of: "÷", with: "/")
        return try evalRPN(shuntingYard(tokenize(s)))
    }

    private enum Tok { case num(Double), op(Character), lp, rp }

    private func tokenize(_ s: String) throws -> [Tok] {
        var out: [Tok] = []
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c.isWhitespace { i = s.index(after: i); continue }
            if c.isNumber || c == "." {
                var n = String(c); var j = s.index(after: i)
                while j < s.endIndex, s[j].isNumber || s[j] == "." { n.append(s[j]); j = s.index(after: j) }
                guard let v = Double(n) else { throw CalcError.badNum(n) }
                out.append(.num(v)); i = j; continue
            }
            if "+-*/".contains(c) {
                if c == "-", out.isEmpty || { if case .op = out.last! { return true }; if case .lp = out.last! { return true }; return false }() {
                    var j = s.index(after: i)
                    while j < s.endIndex, s[j].isWhitespace { j = s.index(after: j) }
                    if j < s.endIndex, s[j].isNumber || s[j] == "." {
                        var n = "-"; while j < s.endIndex, s[j].isNumber || s[j] == "." { n.append(s[j]); j = s.index(after: j) }
                        guard let v = Double(n) else { throw CalcError.badNum(n) }
                        out.append(.num(v)); i = j; continue
                    }
                }
                out.append(.op(c)); i = s.index(after: i); continue
            }
            if c == "(" { out.append(.lp); i = s.index(after: i); continue }
            if c == ")" { out.append(.rp); i = s.index(after: i); continue }
            i = s.index(after: i)
        }
        return out
    }

    private func prec(_ o: Character) -> Int { "+-".contains(o) ? 1 : 2 }

    private func shuntingYard(_ tokens: [Tok]) throws -> [Tok] {
        var out: [Tok] = [], ops: [Tok] = []
        for t in tokens {
            switch t {
            case .num: out.append(t)
            case .op(let o):
                while case .op(let top) = ops.last, prec(top) >= prec(o) { out.append(ops.removeLast()) }
                ops.append(t)
            case .lp: ops.append(t)
            case .rp:
                while case .op = ops.last { out.append(ops.removeLast()) }
                guard case .lp = ops.last else { throw CalcError.parens }
                ops.removeLast()
            }
        }
        while let o = ops.popLast() {
            if case .lp = o { throw CalcError.parens }
            out.append(o)
        }
        return out
    }

    private func evalRPN(_ rpn: [Tok]) throws -> Double {
        var s: [Double] = []
        for t in rpn {
            switch t {
            case .num(let v): s.append(v)
            case .op(let o):
                guard s.count >= 2 else { throw CalcError.expr }
                let b = s.removeLast(), a = s.removeLast()
                switch o {
                case "+": s.append(a + b)
                case "-": s.append(a - b)
                case "*": s.append(a * b)
                case "/": guard b != 0 else { throw CalcError.divZero }; s.append(a / b)
                default: throw CalcError.expr
                }
            default: throw CalcError.expr
            }
        }
        guard s.count == 1 else { throw CalcError.expr }
        return s[0]
    }

    private func fmt(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(format: "%.0f", v) : String(format: "%.6g", v)
    }
}

private enum CalcError: LocalizedError {
    case badNum(String), expr, divZero, parens
    var errorDescription: String? {
        switch self {
        case .badNum(let s): return "Invalid number: \(s)"
        case .expr: return "Invalid expression"
        case .divZero: return "Division by zero"
        case .parens: return "Mismatched parentheses"
        }
    }
}
