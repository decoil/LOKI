import XCTest
@testable import LOKI

final class ToolRegistryTests: XCTestCase {

    func testRegistryHasDefaultTools() async {
        let registry = ToolRegistry()
        let names = await registry.registeredToolNames
        XCTAssertTrue(names.contains("calculator"))
        XCTAssertTrue(names.contains("device_info"))
        XCTAssertTrue(names.contains("clipboard"))
        XCTAssertTrue(names.contains("web_search"))
        XCTAssertTrue(names.contains("calendar"))
        XCTAssertTrue(names.contains("reminders"))
        XCTAssertTrue(names.contains("open_app"))
        XCTAssertTrue(names.contains("timer"))
    }

    func testRegistryToolLookup() async {
        let registry = ToolRegistry()
        let calc = await registry.tool(named: "calculator")
        XCTAssertNotNil(calc)
        XCTAssertEqual(calc?.name, "calculator")
    }

    func testRegistryToolNotFound() async {
        let registry = ToolRegistry()
        let nonexistent = await registry.tool(named: "nonexistent_tool")
        XCTAssertNil(nonexistent)
    }

    func testRegistryExecuteNonexistent() async {
        let registry = ToolRegistry()
        do {
            _ = try await registry.execute(toolName: "nonexistent", arguments: [:])
            XCTFail("Should throw ToolError.toolNotFound")
        } catch let error as ToolError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRegistryToolDescriptions() async {
        let registry = ToolRegistry()
        let desc = await registry.toolDescriptions()
        XCTAssertTrue(desc.contains("Available tools"))
        XCTAssertTrue(desc.contains("tool_call"))
    }

    func testRegisterCustomTool() async {
        let registry = ToolRegistry()
        let custom = MockTool()
        await registry.register(custom)

        let found = await registry.tool(named: "mock_tool")
        XCTAssertNotNil(found)
    }

    func testUnregisterTool() async {
        let registry = ToolRegistry()
        await registry.unregister("calculator")
        let calc = await registry.tool(named: "calculator")
        XCTAssertNil(calc)
    }
}

// MARK: - Mock Tool

private struct MockTool: AgentTool {
    let name = "mock_tool"
    let description = "A mock tool for testing"
    let parametersSchema = ToolParametersSchema(
        type: "object",
        properties: [:],
        required: []
    )

    func execute(arguments: [String: Any]) async throws -> ToolOutput {
        .success("mock result")
    }
}
