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
    case phi4 = "Phi-4"
    case gemma3 = "Gemma 3"
    case smolLM = "SmolLM"
    case llama = "Llama"

    var icon: String {
        switch self {
        case .qwen3: return "brain.head.profile"
        case .phi4: return "function"
        case .gemma3: return "diamond"
        case .smolLM: return "sparkle"
        case .llama: return "hare"
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

enum ModelCatalog {
    static let all: [ModelDescriptor] = [
        qwen3_4B,
        qwen3_1_7B,
        phi4Mini,
        smolLM3_3B,
        qwen3_0_6B,
    ]

    static let qwen3_4B = ModelDescriptor(
        id: "qwen3-4b-q4km",
        name: "Qwen3 4B",
        family: .qwen3,
        parameterCount: "4B",
        quantization: "Q4_K_M",
        sizeBytes: 2_680_000_000,
        contextSize: 4096,
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/qwen3-4b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .toolCalling, .reasoning, .coding, .multilingual]
    )

    static let qwen3_1_7B = ModelDescriptor(
        id: "qwen3-1.7b-q4km",
        name: "Qwen3 1.7B",
        family: .qwen3,
        parameterCount: "1.7B",
        quantization: "Q4_K_M",
        sizeBytes: 1_200_000_000,
        contextSize: 4096,
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .toolCalling, .reasoning, .multilingual]
    )

    static let phi4Mini = ModelDescriptor(
        id: "phi4-mini-q4km",
        name: "Phi-4 Mini",
        family: .phi4,
        parameterCount: "3.8B",
        quantization: "Q4_K_M",
        sizeBytes: 2_400_000_000,
        contextSize: 4096,
        downloadURL: URL(string: "https://huggingface.co/microsoft/Phi-4-mini-instruct-GGUF/resolve/main/phi-4-mini-instruct-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .reasoning, .coding]
    )

    static let smolLM3_3B = ModelDescriptor(
        id: "smollm3-3b-q4km",
        name: "SmolLM3 3B",
        family: .smolLM,
        parameterCount: "3B",
        quantization: "Q4_K_M",
        sizeBytes: 1_900_000_000,
        contextSize: 4096,
        downloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolLM3-3B-GGUF/resolve/main/smollm3-3b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .reasoning, .coding]
    )

    static let qwen3_0_6B = ModelDescriptor(
        id: "qwen3-0.6b-q4km",
        name: "Qwen3 0.6B",
        family: .qwen3,
        parameterCount: "0.6B",
        quantization: "Q4_K_M",
        sizeBytes: 490_000_000,
        contextSize: 4096,
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/main/qwen3-0.6b-q4_k_m.gguf")!,
        sha256: nil,
        recommendedGPULayers: 99,
        capabilities: [.chat, .multilingual]
    )

    static var recommended: ModelDescriptor { qwen3_4B }
}
