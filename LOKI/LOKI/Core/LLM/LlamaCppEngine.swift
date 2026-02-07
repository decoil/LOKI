import Foundation
import llama

// MARK: - llama.cpp Inference Engine

/// Actor-isolated LLM engine backed by llama.cpp with Metal acceleration.
/// Provides thread-safe, streaming token generation for on-device inference.
actor LlamaCppEngine: LLMEngine {
    private let configuration: LLMConfiguration
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var isCancelled = false
    private var isGenerating = false

    var isLoaded: Bool { model != nil && context != nil }

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    deinit {
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }

    // MARK: - Lifecycle

    func load() throws {
        guard FileManager.default.fileExists(atPath: configuration.modelPath) else {
            throw LLMError.modelNotFound(configuration.modelPath)
        }

        llama_backend_init()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = configuration.gpuLayers

        guard let loadedModel = llama_model_load_from_file(
            configuration.modelPath,
            modelParams
        ) else {
            throw LLMError.failedToLoad("llama_model_load_from_file returned nil")
        }
        model = loadedModel

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(configuration.contextSize)
        ctxParams.n_batch = 512
        ctxParams.n_threads = UInt32(ProcessInfo.processInfo.activeProcessorCount)
        ctxParams.flash_attn = true

        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            model = nil
            throw LLMError.contextCreationFailed
        }
        context = ctx
    }

    func unload() {
        if let context {
            llama_free(context)
            self.context = nil
        }
        if let model {
            llama_model_free(model)
            self.model = nil
        }
        llama_backend_free()
    }

    func cancelGeneration() {
        isCancelled = true
    }

    // MARK: - Generation

    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<TokenEvent, Error> {
        AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish(throwing: LLMError.modelNotLoaded)
                    return
                }
                do {
                    try await self.runGeneration(
                        messages: messages,
                        parameters: parameters,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func runGeneration(
        messages: [ChatMessage],
        parameters: GenerationParameters,
        continuation: AsyncThrowingStream<TokenEvent, Error>.Continuation
    ) throws {
        guard let model, let context else {
            throw LLMError.modelNotLoaded
        }
        guard !isGenerating else {
            throw LLMError.generationFailed("Generation already in progress")
        }

        isGenerating = true
        isCancelled = false
        defer { isGenerating = false }

        llama_kv_cache_clear(context)

        let prompt = formatChatPrompt(messages: messages, model: model)
        let tokens = tokenize(text: prompt, model: model)

        guard !tokens.isEmpty else {
            throw LLMError.generationFailed("Tokenization produced empty result")
        }

        // Evaluate prompt tokens in batches
        let batchSize = 512
        for i in stride(from: 0, to: tokens.count, by: batchSize) {
            if isCancelled {
                continuation.yield(.done(.cancelled))
                continuation.finish()
                return
            }

            let end = min(i + batchSize, tokens.count)
            let batchTokens = Array(tokens[i..<end])
            var batch = llama_batch_init(Int32(batchTokens.count), 0, 1)
            defer { llama_batch_free(batch) }

            for (j, token) in batchTokens.enumerated() {
                let pos = Int32(i + j)
                let isLast = (i + j == tokens.count - 1)
                llama_batch_add(&batch, token, pos, [0], isLast)
            }

            let result = llama_decode(context, batch)
            if result != 0 {
                throw LLMError.generationFailed("llama_decode failed with code \(result)")
            }
        }

        // Autoregressive generation
        let vocab = llama_model_get_vocab(model)
        var sampler = createSampler(vocab: vocab, parameters: parameters)
        defer { llama_sampler_free(sampler) }

        var generatedCount: Int32 = 0
        var currentPos = Int32(tokens.count)
        var tokenBuffer = [CChar](repeating: 0, count: 256)
        var pendingToolCall = ""
        var inToolCall = false

        while generatedCount < parameters.maxTokens {
            if isCancelled {
                continuation.yield(.done(.cancelled))
                continuation.finish()
                return
            }

            let newToken = llama_sampler_sample(sampler, context, -1)

            if llama_vocab_is_eog(vocab, newToken) {
                let reason: FinishReason = inToolCall ? .toolUse : .stop
                if inToolCall, let call = parseToolCall(pendingToolCall) {
                    continuation.yield(.toolCall(call))
                }
                continuation.yield(.done(reason))
                continuation.finish()
                return
            }

            let count = llama_token_to_piece(vocab, newToken, &tokenBuffer, Int32(tokenBuffer.count), 0, false)
            if count > 0 {
                let piece = String(cString: tokenBuffer.prefix(Int(count)) + [0])

                // Detect tool call patterns
                if piece.contains("<tool_call>") {
                    inToolCall = true
                    pendingToolCall = ""
                } else if piece.contains("</tool_call>") {
                    inToolCall = false
                    if let call = parseToolCall(pendingToolCall) {
                        continuation.yield(.toolCall(call))
                    }
                    pendingToolCall = ""
                } else if inToolCall {
                    pendingToolCall += piece
                } else {
                    continuation.yield(.token(piece))
                }
            }

            // Prepare next batch
            var nextBatch = llama_batch_init(1, 0, 1)
            defer { llama_batch_free(nextBatch) }
            llama_batch_add(&nextBatch, newToken, currentPos, [0], true)

            let decodeResult = llama_decode(context, nextBatch)
            if decodeResult != 0 {
                throw LLMError.generationFailed("Decode failed at position \(currentPos)")
            }

            currentPos += 1
            generatedCount += 1
        }

        continuation.yield(.done(.length))
        continuation.finish()
    }

    // MARK: - Prompt Formatting

    private func formatChatPrompt(messages: [ChatMessage], model: OpaquePointer) -> String {
        // Use Qwen3/ChatML format:
        // <|im_start|>system\n{system}<|im_end|>
        // <|im_start|>user\n{user}<|im_end|>
        // <|im_start|>assistant\n
        var prompt = ""
        for message in messages {
            let role = message.role.rawValue
            prompt += "<|im_start|>\(role)\n\(message.content)<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }

    // MARK: - Tokenization

    private func tokenize(text: String, model: OpaquePointer) -> [llama_token] {
        let utf8 = Array(text.utf8)
        let maxTokens = utf8.count + 16
        var tokens = [llama_token](repeating: 0, count: maxTokens)
        let vocab = llama_model_get_vocab(model)

        let count = llama_tokenize(
            vocab,
            text,
            Int32(utf8.count),
            &tokens,
            Int32(maxTokens),
            true,
            true
        )

        guard count >= 0 else { return [] }
        return Array(tokens.prefix(Int(count)))
    }

    // MARK: - Sampler

    private func createSampler(
        vocab: OpaquePointer?,
        parameters: GenerationParameters
    ) -> OpaquePointer {
        let sparams = llama_sampler_chain_default_params()
        let chain = llama_sampler_chain_init(sparams)!

        llama_sampler_chain_add(chain, llama_sampler_init_top_k(parameters.topK))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(parameters.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(parameters.temperature))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(configuration.seed))

        return chain
    }

    // MARK: - Tool Call Parsing

    private func parseToolCall(_ raw: String) -> ToolCall? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }

        struct RawToolCall: Decodable {
            let name: String
            let arguments: String?
        }

        guard let parsed = try? JSONDecoder().decode(RawToolCall.self, from: data) else {
            return nil
        }

        return ToolCall(
            id: UUID().uuidString,
            name: parsed.name,
            arguments: parsed.arguments ?? "{}"
        )
    }
}
