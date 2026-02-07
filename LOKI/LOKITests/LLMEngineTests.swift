import XCTest
@testable import LOKI

final class LLMEngineTests: XCTestCase {

    // MARK: - ChatMessage Tests

    func testChatMessageCreation() {
        let msg = ChatMessage(role: .user, content: "Hello LOKI")
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.content, "Hello LOKI")
        XCTAssertNil(msg.toolCalls)
        XCTAssertNil(msg.toolResult)
    }

    func testChatMessageCodable() throws {
        let original = ChatMessage(
            role: .assistant,
            content: "Hi there!",
            toolCalls: [ToolCall(id: "1", name: "calculator", arguments: "{\"expression\": \"2+2\"}")]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded.role, original.role)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.toolCalls?.count, 1)
        XCTAssertEqual(decoded.toolCalls?.first?.name, "calculator")
    }

    func testChatMessageRoles() {
        XCTAssertEqual(ChatMessage.Role(rawValue: "system"), .system)
        XCTAssertEqual(ChatMessage.Role(rawValue: "user"), .user)
        XCTAssertEqual(ChatMessage.Role(rawValue: "assistant"), .assistant)
        XCTAssertEqual(ChatMessage.Role(rawValue: "tool"), .tool)
        XCTAssertNil(ChatMessage.Role(rawValue: "invalid"))
    }

    // MARK: - GenerationParameters Tests

    func testDefaultParameters() {
        let params = GenerationParameters.default
        XCTAssertEqual(params.temperature, 0.7)
        XCTAssertEqual(params.topP, 0.9)
        XCTAssertEqual(params.topK, 40)
        XCTAssertEqual(params.maxTokens, 2048)
    }

    func testPreciseParameters() {
        let params = GenerationParameters.precise
        XCTAssertEqual(params.temperature, 0.2)
        XCTAssertTrue(params.temperature < GenerationParameters.default.temperature)
    }

    func testCreativeParameters() {
        let params = GenerationParameters.creative
        XCTAssertEqual(params.temperature, 0.9)
        XCTAssertTrue(params.temperature > GenerationParameters.default.temperature)
    }

    // MARK: - LLMConfiguration Tests

    func testDefaultConfiguration() {
        let config = LLMConfiguration.default
        XCTAssertEqual(config.contextSize, 4096)
        XCTAssertEqual(config.gpuLayers, 99)
        XCTAssertEqual(config.temperature, 0.7)
    }

    // MARK: - LLMError Tests

    func testErrorDescriptions() {
        XCTAssertNotNil(LLMError.modelNotFound("/path").errorDescription)
        XCTAssertNotNil(LLMError.failedToLoad("reason").errorDescription)
        XCTAssertNotNil(LLMError.contextCreationFailed.errorDescription)
        XCTAssertNotNil(LLMError.generationFailed("reason").errorDescription)
        XCTAssertNotNil(LLMError.modelNotLoaded.errorDescription)
        XCTAssertNotNil(LLMError.cancelled.errorDescription)
        XCTAssertNotNil(LLMError.outOfMemory.errorDescription)
    }

    // MARK: - ModelDescriptor Tests

    func testModelDescriptorLocalPath() {
        let model = ModelCatalog.qwen3_4B
        XCTAssertTrue(model.localPath.contains("models"))
        XCTAssertTrue(model.localPath.hasSuffix(".gguf"))
    }

    func testModelCatalogRecommended() {
        XCTAssertEqual(ModelCatalog.recommended.id, ModelCatalog.qwen3_4B.id)
    }

    func testModelCatalogHasMultipleModels() {
        XCTAssertGreaterThanOrEqual(ModelCatalog.all.count, 4)
    }

    func testModelSizeFormatted() {
        let model = ModelCatalog.qwen3_4B
        XCTAssertFalse(model.sizeFormatted.isEmpty)
    }
}
