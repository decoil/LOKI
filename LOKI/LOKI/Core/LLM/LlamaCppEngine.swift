import Foundation
import llama
import os.lock

// MARK: - llama.cpp Backend Lifecycle (process-global, thread-safe)

private let backendLock = OSAllocatedUnfairLock()
private var backendRefCount = 0

private func retainBackend() {
    backendLock.withLock {
        if backendRefCount == 0 {
            llama_backend_init()
        }
        backendRefCount += 1
    }
}

private func releaseBackend() {
    backendLock.withLock {
        backendRefCount -= 1
        if backendRefCount == 0 {
            llama_backend_free()
        }
    }
}

// MARK: - Cancellation Flag (shared across isolation domains)

final class AtomicFlag: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    var value: Bool {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

// MARK: - llama.cpp Inference Engine

actor LlamaCppEngine: LLMEngine {
    private let configuration: LLMConfiguration
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private let cancelFlag = AtomicFlag()
    private var isGenerating = false

    var isLoaded: Bool { model != nil && context != nil }

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Lifecycle

    func load() async throws {
        guard FileManager.default.fileExists(atPath: configuration.modelPath) else {
            throw LLMError.modelNotFound(configuration.modelPath)
        }

        retainBackend()

        let (loadedModel, ctx) = try await Task.detached { [configuration] in
            var modelParams = llama_model_default_params()
            modelParams.n_gpu_layers = configuration.gpuLayers

            guard let loadedModel = llama_model_load_from_file(
                configuration.modelPath,
                modelParams
            ) else {
                releaseBackend()
                throw LLMError.failedToLoad("llama_model_load_from_file returned nil")
            }

            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = UInt32(max(512, configuration.contextSize))
            ctxParams.n_batch = 512
            ctxParams.n_threads = UInt32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))
            ctxParams.flash_attn = true

            guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
                llama_model_free(loadedModel)
                releaseBackend()
                throw LLMError.contextCreationFailed
            }

            return (loadedModel, ctx)
        }.value

        self.model = loadedModel
        self.context = ctx
    }

    func unload() {
        if let context {
            llama_free(context)
            self.context = nil
        }
        if let model {
            llama_model_free(model)
            self.model = nil
            releaseBackend()
        }
    }

    func cancelGeneration() {
        cancelFlag.value = true
    }

    // MARK: - Generation

    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<TokenEvent, Error> {
        let capturedModel = model
        let capturedContext = context
        let capturedConfig = configuration
        let flag = cancelFlag

        return AsyncThrowingStream { continuation in
            let task = Task.detached { [flag] in
                do {
                    try Self.runGeneration(
                        model: capturedModel,
                        context: capturedContext,
                        configuration: capturedConfig,
                        messages: messages,
                        parameters: parameters,
                        cancelFlag: flag,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                flag.value = true
                task.cancel()
            }

            flag.value = false
        }
    }

    // MARK: - Generation (static, detached from actor)

    private static func runGeneration(
        model: OpaquePointer?,
        context: OpaquePointer?,
        configuration: LLMConfiguration,
        messages: [ChatMessage],
        parameters: GenerationParameters,
        cancelFlag: AtomicFlag,
        continuation: AsyncThrowingStream<TokenEvent, Error>.Continuation
    ) throws {
        guard let model, let context else {
            throw LLMError.modelNotLoaded
        }

        let params = parameters.clamped()
        llama_kv_cache_clear(context)

        let prompt = formatChatPrompt(messages: messages)
        let tokens = tokenize(text: prompt, model: model)

        guard !tokens.isEmpty else {
            throw LLMError.generationFailed("Tokenization produced empty result")
        }

        let ctxSize = Int(llama_n_ctx(context))
        guard tokens.count < ctxSize else {
            throw LLMError.generationFailed(
                "Prompt (\(tokens.count) tokens) exceeds context (\(ctxSize))"
            )
        }

        // Evaluate prompt in batches
        let batchSize = 512
        for i in stride(from: 0, to: tokens.count, by: batchSize) {
            if cancelFlag.value { return yieldCancelled(continuation) }

            let end = min(i + batchSize, tokens.count)
            let slice = Array(tokens[i..<end])
            var batch = llama_batch_init(Int32(slice.count), 0, 1)
            defer { llama_batch_free(batch) }

            for (j, token) in slice.enumerated() {
                llama_batch_add(&batch, token, Int32(i + j), [0], (i + j == tokens.count - 1))
            }

            let rc = llama_decode(context, batch)
            if rc != 0 { throw LLMError.generationFailed("llama_decode failed: \(rc)") }
        }

        // Autoregressive generation
        let vocab = llama_model_get_vocab(model)
        let sampler = createSampler(vocab: vocab, parameters: params)
        defer { llama_sampler_free(sampler) }

        var generated: Int32 = 0
        var pos = Int32(tokens.count)
        var tokenBuffer = [CChar](repeating: 0, count: 512)
        var pendingToolCall = ""
        var inToolCall = false

        var nextBatch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(nextBatch) }

        while generated < params.maxTokens {
            if cancelFlag.value || Task.isCancelled { return yieldCancelled(continuation) }

            let newToken = llama_sampler_sample(sampler, context, -1)

            if llama_vocab_is_eog(vocab, newToken) {
                if inToolCall, let call = parseToolCall(pendingToolCall) {
                    continuation.yield(.toolCall(call))
                }
                continuation.yield(.done(inToolCall ? .toolUse : .stop))
                continuation.finish()
                return
            }

            let count = llama_token_to_piece(
                vocab, newToken, &tokenBuffer, Int32(tokenBuffer.count), 0, false
            )

            if count > 0 {
                let data = Data(bytes: tokenBuffer, count: Int(count))
                let piece = String(data: data, encoding: .utf8)
                    ?? String(repeating: "\u{FFFD}", count: Int(count))

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
            } else if count < 0 {
                let needed = Int(-count) + 1
                var big = [CChar](repeating: 0, count: needed)
                let rc = llama_token_to_piece(vocab, newToken, &big, Int32(needed), 0, false)
                if rc > 0 {
                    let data = Data(bytes: big, count: Int(rc))
                    let piece = String(data: data, encoding: .utf8) ?? ""
                    if inToolCall { pendingToolCall += piece }
                    else { continuation.yield(.token(piece)) }
                }
            }

            nextBatch.n_tokens = 0
            llama_batch_add(&nextBatch, newToken, pos, [0], true)
            let rc = llama_decode(context, nextBatch)
            if rc != 0 { throw LLMError.generationFailed("Decode failed at \(pos)") }

            pos += 1
            generated += 1
        }

        continuation.yield(.done(.length))
        continuation.finish()
    }

    private static func yieldCancelled(
        _ continuation: AsyncThrowingStream<TokenEvent, Error>.Continuation
    ) {
        continuation.yield(.done(.cancelled))
        continuation.finish()
    }

    // MARK: - Prompt Formatting

    private static func formatChatPrompt(messages: [ChatMessage]) -> String {
        // ChatML format — compatible with Qwen3, Gemma, and most instruction models
        var prompt = ""
        for message in messages {
            prompt += "<|im_start|>\(message.role.rawValue)\n\(message.content)<|im_end|>\n"
        }
        prompt += "<|im_start|>assistant\n"
        return prompt
    }

    // MARK: - Tokenization

    private static func tokenize(text: String, model: OpaquePointer) -> [llama_token] {
        let utf8 = Array(text.utf8)
        let maxTokens = utf8.count + 16
        var tokens = [llama_token](repeating: 0, count: maxTokens)
        let vocab = llama_model_get_vocab(model)

        let count = llama_tokenize(
            vocab, text, Int32(utf8.count), &tokens, Int32(maxTokens), true, true
        )
        guard count >= 0 else { return [] }
        return Array(tokens.prefix(Int(count)))
    }

    // MARK: - Sampler

    private static func createSampler(
        vocab: OpaquePointer?,
        parameters: GenerationParameters
    ) -> OpaquePointer {
        let sparams = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(sparams) else {
            fatalError("Failed to create sampler chain — out of memory")
        }

        llama_sampler_chain_add(chain, llama_sampler_init_penalties(
            Int32(0), parameters.repeatPenalty, 0.0, 0.0
        ))
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(parameters.topK))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(parameters.topP, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(max(0.01, parameters.temperature)))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        return chain
    }

    // MARK: - Tool Call Parsing

    private static func parseToolCall(_ raw: String) -> ToolCall? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return nil
        }

        let arguments: String
        if let argsDict = json["arguments"] as? [String: Any],
           let argsData = try? JSONSerialization.data(withJSONObject: argsDict),
           let argsStr = String(data: argsData, encoding: .utf8) {
            arguments = argsStr
        } else if let argsStr = json["arguments"] as? String {
            arguments = argsStr
        } else {
            arguments = "{}"
        }

        return ToolCall(id: UUID().uuidString, name: name, arguments: arguments)
    }
}

// MARK: - GenerationParameters Validation

extension GenerationParameters {
    func clamped() -> GenerationParameters {
        GenerationParameters(
            temperature: max(0.01, min(temperature, 2.0)),
            topP: max(0.0, min(topP, 1.0)),
            topK: max(1, topK),
            maxTokens: max(1, maxTokens),
            repeatPenalty: max(1.0, min(repeatPenalty, 2.0)),
            stopSequences: stopSequences
        )
    }
}
