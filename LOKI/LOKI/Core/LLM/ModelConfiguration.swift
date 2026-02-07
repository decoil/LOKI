import Foundation

// MARK: - Model Descriptor

struct ModelDescriptor: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let family: ModelFamily
    let parameterCount: String
    let quantization: String
    let sizeBytes: Int64
    let contextSize: Int32
    let downloadURL: URL
    let sha256: String?
    let recommendedGPULayers: Int32
    let capabilities: Set<ModelCapability>

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var localPath: String {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("models/\(id).gguf").path
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localPath)
    }
}

// MARK: - Model Family

enum ModelFamily: String, Codable, Sendable, CaseIterable {
    case qwen3 = "Qwen3"
    case gemma3 = "Gemma 3"
    case gemma2 = "Gemma 2"
    case smolLM = "SmolLM"

    var icon: String {
        switch self {
        case .qwen3: return "brain.head.profile"
        case .gemma3: return "diamond"
        case .gemma2: return "diamond.fill"
        case .smolLM: return "sparkle"
        }
    }
}

// MARK: - Model Capability

enum ModelCapability: String, Codable, Sendable {
    case chat
    case toolCalling
    case reasoning
    case coding
    case multilingual
    case vision
}

// MARK: - Built-in Model Catalog
//
// Targeting iPhone 12+ (A14 Bionic, 4GB RAM, ~2.5GB usable).
// Models are ordered by recommendation for this hardware tier.

enum ModelCatalog {
    static let all: [ModelDescriptor] = [
        qwen3_1_7B,
        gemma2_2B,
        gemma3_1B,
        smolLM3_3B,
        qwen3_0_6B,
    ]

    // MARK: - Recommended: Qwen3 1.7B
    // Best choice for agentic AI on iPhone 12+. Distilled from Qwen3-235B.
    // Strongest tool-calling and instruction-following at this size.
    // 1.2GB leaves ~1.3GB headroom for KV cache + app on 4GB devices.
    static let qwen3_1_7B = ModelDescriptor(
        id: "qwen3-1.7b-q4km",
        name: "Qwen3 1.7B",
        family: .qwen3,
        parameterCount: "1.7B",
        quantization: "Q4_K_M",
        sizeBytes: 1_200_000_000,
        contextSize: 2048,
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .toolCalling, .reasoning, .coding, .multilingual]
    )

    // MARK: - Gemma 2 2B
    // Google's 2B model. Slightly larger (~1.5GB) but strong general intelligence.
    // Comfortable fit on iPhone 12+, leaves ~1GB headroom.
    static let gemma2_2B = ModelDescriptor(
        id: "gemma-2-2b-it-q4km",
        name: "Gemma 2 2B",
        family: .gemma2,
        parameterCount: "2B",
        quantization: "Q4_K_M",
        sizeBytes: 1_500_000_000,
        contextSize: 2048,
        downloadURL: URL(string: "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .reasoning, .coding, .multilingual]
    )

    // MARK: - Gemma 3 1B
    // Google's lightweight 1B. Only ~700MB — fast and leaves tons of headroom.
    // Great for quick responses and older devices.
    static let gemma3_1B = ModelDescriptor(
        id: "gemma-3-1b-it-q4km",
        name: "Gemma 3 1B",
        family: .gemma3,
        parameterCount: "1B",
        quantization: "Q4_K_M",
        sizeBytes: 700_000_000,
        contextSize: 2048,
        downloadURL: URL(string: "https://huggingface.co/bartowski/google_gemma-3-1b-it-GGUF/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .reasoning, .coding, .multilingual]
    )

    // MARK: - SmolLM3 3B
    // Smartest option — outperforms Llama 3.2 3B. Tight fit on 4GB devices
    // (~1.9GB model + KV cache). Best for iPhone 13+ with more thermal headroom.
    static let smolLM3_3B = ModelDescriptor(
        id: "smollm3-3b-q4km",
        name: "SmolLM3 3B",
        family: .smolLM,
        parameterCount: "3B",
        quantization: "Q4_K_M",
        sizeBytes: 1_900_000_000,
        contextSize: 2048,
        downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM3-3B-GGUF/resolve/main/smollm3-3b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .reasoning, .coding]
    )

    // MARK: - Qwen3 0.6B
    // Ultra-lightweight fallback (~490MB). Fastest inference, least capable.
    // Good for testing or very constrained scenarios.
    static let qwen3_0_6B = ModelDescriptor(
        id: "qwen3-0.6b-q4km",
        name: "Qwen3 0.6B",
        family: .qwen3,
        parameterCount: "0.6B",
        quantization: "Q4_K_M",
        sizeBytes: 490_000_000,
        contextSize: 2048,
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/qwen3-0.6b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .multilingual]
    )

    static var recommended: ModelDescriptor { qwen3_1_7B }
}
