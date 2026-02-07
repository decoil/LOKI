import XCTest
@testable import LOKI

final class AgentCoordinatorTests: XCTestCase {

    // MARK: - Tool Tests

    func testToolOutputSuccess() {
        let output = ToolOutput.success("result")
        XCTAssertEqual(output.content, "result")
        XCTAssertFalse(output.isError)
        XCTAssertTrue(output.artifacts.isEmpty)
    }

    func testToolOutputError() {
        let output = ToolOutput.error("failed")
        XCTAssertEqual(output.content, "failed")
        XCTAssertTrue(output.isError)
    }

    func testToolErrorDescriptions() {
        XCTAssertNotNil(ToolError.invalidArguments("msg").errorDescription)
        XCTAssertNotNil(ToolError.permissionDenied("msg").errorDescription)
        XCTAssertNotNil(ToolError.executionFailed("msg").errorDescription)
        XCTAssertNotNil(ToolError.toolNotFound("name").errorDescription)
    }

    // MARK: - Tool Schema Tests

    func testToolParametersSchemaJSON() {
        let schema = ToolParametersSchema(
            type: "object",
            properties: [
                "query": .init(type: "string", description: "Search query"),
            ],
            required: ["query"]
        )

        let json = schema.jsonRepresentation
        XCTAssertTrue(json.contains("query"))
        XCTAssertTrue(json.contains("string"))
    }

    // MARK: - Calculator Tool Tests

    func testCalculatorBasicArithmetic() async throws {
        let tool = CalculatorTool()
        let result = try await tool.execute(arguments: ["expression": "2 + 2"])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("4"))
    }

    func testCalculatorPercentage() async throws {
        let tool = CalculatorTool()
        let result = try await tool.execute(arguments: ["expression": "15% of 200"])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("30"))
    }

    func testCalculatorSqrt() async throws {
        let tool = CalculatorTool()
        let result = try await tool.execute(arguments: ["expression": "sqrt(144)"])
        XCTAssertFalse(result.isError)
        XCTAssertTrue(result.content.contains("12"))
    }

    func testCalculatorMissingExpression() async {
        let tool = CalculatorTool()
        do {
            _ = try await tool.execute(arguments: [:])
            XCTFail("Should throw")
        } catch {
            XCTAssertTrue(error is ToolError)
        }
    }

    // MARK: - Agent Prompts Tests

    func testSystemPromptContainsIdentity() {
        let prompt = AgentPrompts.buildSystemPrompt()
        XCTAssertTrue(prompt.contains("LOKI"))
        XCTAssertTrue(prompt.contains("Locally Operated Kinetic Intelligence"))
    }

    func testSystemPromptWithTools() {
        let prompt = AgentPrompts.buildSystemPrompt(toolNames: ["calculator", "web_search"])
        XCTAssertTrue(prompt.contains("calculator"))
        XCTAssertTrue(prompt.contains("web_search"))
        XCTAssertTrue(prompt.contains("tool_call"))
    }

    func testPersonaSuffixes() {
        for persona in AgentPrompts.Persona.allCases {
            XCTAssertFalse(persona.systemSuffix.isEmpty)
        }
    }

    // MARK: - String Extension Tests

    func testEstimatedTokenCount() {
        let text = "Hello world"
        XCTAssertGreaterThan(text.estimatedTokenCount, 0)
    }

    func testTruncatedToTokens() {
        let longText = String(repeating: "word ", count: 1000)
        let truncated = longText.truncatedToTokens(10)
        XCTAssertLessThan(truncated.count, longText.count)
    }

    func testStrippingTags() {
        let html = "<b>Hello</b> <i>World</i>"
        XCTAssertEqual(html.strippingTags, "Hello World")
    }

    func testExtractBetween() {
        let text = "<tool_call>{\"name\": \"test\"}</tool_call>"
        let extracted = text.extractBetween(open: "<tool_call>", close: "</tool_call>")
        XCTAssertEqual(extracted, "{\"name\": \"test\"}")
    }

    // MARK: - Display Message Tests

    func testDisplayMessageInit() {
        let msg = DisplayMessage(role: .user, content: "Test")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Test")
        XCTAssertFalse(msg.isStreaming)
    }
}
