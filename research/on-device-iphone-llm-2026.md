# On-Device iPhone LLM Research (February 2026)

## 1. Top Candidate Models (Under 4B Parameters)

### Tier 1: Best Overall for iPhone

| Model | Parameters | License | Key Strengths | RAM Footprint (Q4) |
|-------|-----------|---------|---------------|---------------------|
| **Qwen3-4B** | 4B (dense) | Apache 2.0 | Matches Qwen2.5-7B performance; strong reasoning, coding, multilingual (119 langs); distilled from Qwen3-235B frontier model | ~2.5GB |
| **Phi-4-mini-instruct** | 3.8B | MIT | Best-in-class math/coding reasoning at this size; ONNX Runtime optimized; 200K vocab for multilingual | ~2.3GB |
| **Gemma 3n E4B** | 5B raw / 4B active memory | Gemma license (permissive) | Per-Layer Embeddings (PLE) reduces memory to ~3GB; 1.5x faster than Gemma 3 4B; multimodal (text, image, audio, video); nested 2B submodel | ~3GB |
| **Phi-4-mini-flash-reasoning** | 3.8B | MIT | Hybrid architecture; 10x higher throughput and 2-3x lower latency vs Phi-4-mini; sub-250ms voice round-trips on mobile | ~2.3GB |

### Tier 2: Ultra-Lightweight (Broader Device Compatibility)

| Model | Parameters | License | Key Strengths | RAM Footprint (Q4) |
|-------|-----------|---------|---------------|---------------------|
| **Qwen3-1.7B** | 1.7B | Apache 2.0 | Outperforms Qwen2.5-3B; distilled from frontier models; excellent for chatbots and low-latency apps | ~1.2GB |
| **Gemma 3n E2B** | ~5B raw / 2B active | Gemma license | PLE tech = 2GB memory footprint; multimodal; MatFormer nested architecture | ~2GB |
| **SmolLM3-3B** | 3B | Apache 2.0 | Outperforms Llama-3.2-3B and Qwen2.5-3B; supports /think and /no_think modes; fully open | ~1.8GB |
| **Gemma 3 1B** | 1B | Gemma license | Only 529MB model file; runs on 4GB RAM devices; designed for mobile/web distribution | ~529MB |
| **Qwen3-0.6B** | 0.6B | Apache 2.0 | Ultra-lightweight for IoT and embedded; runs on even very weak devices | ~400MB |
| **SmolLM2-1.7B** | 1.7B | Apache 2.0 | Trained on 11T tokens; FineMath/Stack-Edu specialized data | ~1.1GB |

### Tier 3: MoE (High Quality, Higher Memory)

| Model | Params (Total/Active) | License | Notes |
|-------|----------------------|---------|-------|
| **Qwen3-30B-A3B** | 30B / 3.3B active | Apache 2.0 | Outperforms QwQ-32B; only 3B active per token BUT ~19GB Q4 = too large for iPhone |

### Special Mention: Apple's Own On-Device Model

| Model | Parameters | Access | Notes |
|-------|-----------|--------|-------|
| **Apple Foundation Model** | ~3B | iOS 26 Foundation Models framework | Free, zero-cost inference; tool calling, guided generation, streaming; works offline; no app size impact |

---

## 2. iOS Inference Frameworks

### Primary Frameworks

#### llama.cpp (Community Standard)
- **Format**: GGUF
- **Strengths**: Cross-platform; huge pre-quantized model ecosystem; Metal GPU acceleration on iOS; actively maintained (4,828+ commits, updated daily)
- **iOS Integration**: Via Swift packages (SpeziLLM, LocalLLMClient) or apps (Apollo AI, LLMFarm, Private LLM, Enclave AI)
- **Best for**: Running any open-source model in GGUF format
- **Swift Package**: `https://github.com/ggml-org/llama.cpp` (available on Swift Package Index)

#### MLX Swift (Apple's Open Source)
- **Format**: MLX (safetensors-based)
- **Strengths**: Optimized for Apple Silicon; NumPy-like API; M5 Neural Accelerator support (19-27% boost over M4); official Apple examples
- **iOS Integration**: `mlx-swift` SPM package (v0.10.0+); LLMEval reference app; mlx-swift-chat
- **Best for**: Maximum Apple Silicon performance; research/experimentation
- **Limitation**: Large models may crash on iPhone due to memory; try smaller/more quantized models
- **Swift Package**: `https://github.com/ml-explore/mlx-swift`

#### Core ML (Apple 1st-Party)
- **Format**: Core ML (.mlpackage / .mlmodel)
- **Strengths**: Neural Engine acceleration; Int4 quantization support; stateful KV cache; Xcode Instruments profiling
- **iOS Integration**: Native framework; coremltools for conversion
- **Best for**: Tightest hardware integration; Neural Engine utilization
- **Key detail**: A17 Pro / M4+ chips have increased int8-int8 Neural Engine throughput

#### Apple Foundation Models Framework (NEW - iOS 26)
- **Format**: Built into iOS (no model file needed)
- **Strengths**: Zero cost; zero app size impact; offline; tool calling; guided generation; streaming; @Generable macro for structured output
- **iOS Integration**: Native Swift API via `LanguageModelSession`
- **Best for**: Apps that need a capable 3B on-device model with zero distribution overhead
- **Requirement**: iOS 26 + Apple Intelligence enabled + Apple Intelligence-compatible device (A17 Pro+)

#### ExecuTorch (Meta/PyTorch)
- **Format**: ExecuTorch (.pte)
- **Strengths**: 50KB runtime footprint; 12+ hardware backends; used in production by Meta across Instagram/WhatsApp/Messenger
- **Best for**: Cross-platform mobile deployment from PyTorch ecosystem

#### Google MediaPipe LLM Inference API
- **Format**: TFLite
- **Strengths**: Easy integration; supports Gemma models natively
- **iOS Integration**: Via MediaPipe iOS SDK; Flutter support
- **Best for**: Running Gemma models on iOS

#### MLC (Machine Learning Compilation)
- **Format**: Compiled model + custom runtime
- **Strengths**: Compiles both model and runtime; runs in any C++ environment
- **Best for**: Maximum optimization through compilation

### iOS Apps for Testing/Running Models

| App | Engine | Key Feature |
|-----|--------|-------------|
| **Private LLM** | llama.cpp | 60+ models; complete privacy |
| **Enclave AI** | llama.cpp | Zero data tracking |
| **Apollo AI** | llama.cpp | Open-source; Metal acceleration |
| **LLMFarm** | llama.cpp/ggml | Open-source; multi-model testing |
| **Haplo AI** | llama.cpp | Simple UI; fully offline |

---

## 3. Recommended Models for Chatbot/Agentic Assistant

### Primary Recommendation: Qwen3-4B (GGUF Q4_K_M)

**Why:**
- Apache 2.0 license (fully permissive)
- Matches Qwen2.5-7B performance at half the parameters (thanks to distillation from 235B teacher)
- Strong instruction following, reasoning, coding, and multilingual support (119 languages)
- 32K native context window
- ~2.5GB in Q4_K_M quantization = fits comfortably on iPhone 15 Pro / 16 / 16 Pro (6-8GB RAM)
- Dual-mode thinking (fast responses by default, deep reasoning on demand)
- Excellent ecosystem support (GGUF available on HuggingFace, runs on llama.cpp, Ollama, etc.)

### For Tool/Function Calling Specifically:

1. **Phi-4-mini-flash-reasoning** (3.8B) - Purpose-built for edge; hybrid architecture delivers 10x throughput improvement; strong at structured reasoning
2. **Qwen3-4B** - Strong general tool-calling capability inherited from frontier model distillation
3. **Apple Foundation Model** (via Foundation Models framework on iOS 26) - Native tool calling API built in; @Generable macro for structured output; zero cost

### For Maximum Device Compatibility (older iPhones / less RAM):

1. **Qwen3-1.7B** (Q4_K_M, ~1.2GB) - Best performance-per-byte at this size
2. **Gemma 3n E2B** (~2GB active footprint) - Multimodal with efficient PLE architecture
3. **Gemma 3 1B** (~529MB) - Runs on nearly any modern iPhone

### For Agentic Workflows (tool calling + reasoning):

The recommended stack is:
1. **Primary model**: Qwen3-4B (general reasoning, planning, conversation)
2. **Lightweight router**: Qwen3-0.6B or Gemma 3 1B (fast classification, intent detection, routing)
3. **Framework**: llama.cpp via LocalLLMClient Swift package (supports both MLX and llama.cpp backends)

---

## 4. Model Format Considerations

### GGUF (Recommended Default for iOS)

- **What**: File format for quantized models, used by llama.cpp
- **Quantization levels for iPhone**:
  - **Q4_K_M**: Best balance of quality and size for iPhone (recommended)
  - **Q5_K_M**: Slightly better quality, ~25% larger
  - **Q8_0**: Near-original quality, 2x size of Q4
  - **Q2_K**: Smallest but noticeable quality degradation
- **Pros**: Massive ecosystem; cross-platform; CPU + Metal GPU hybrid; hardware-agnostic
- **Cons**: Doesn't use Neural Engine; not as tightly optimized for Apple hardware as Core ML

### Core ML (.mlpackage)

- **What**: Apple's native ML model format
- **Quantization**: Int4 via coremltools
- **Pros**: Neural Engine acceleration; tight OS integration; Xcode profiling tools
- **Cons**: Apple-only; conversion required from PyTorch/HuggingFace; smaller model ecosystem
- **Best for**: Production iOS apps targeting maximum performance on A17 Pro+ chips

### MLX (safetensors-based)

- **What**: Apple's open-source ML framework format
- **Quantization**: 4-bit, 8-bit via mlx-lm
- **Pros**: Optimized for Apple Silicon unified memory; M5 Neural Accelerator support
- **Cons**: Apple-only; iPhone support still maturing (better on Mac)
- **Best for**: Apple Silicon development workflow; research

### ExecuTorch (.pte)

- **What**: Meta's edge inference format
- **Pros**: 50KB runtime; 12+ backends; production-proven at Meta scale
- **Cons**: Smaller community model library; more complex toolchain

### Key Decision Matrix

| Scenario | Recommended Format |
|----------|-------------------|
| Broadest model selection | GGUF (llama.cpp) |
| Maximum iPhone performance | Core ML (Neural Engine) |
| Apple dev ecosystem | MLX Swift |
| Cross-platform mobile app | ExecuTorch |
| Zero distribution overhead | Apple Foundation Models (iOS 26) |
| Quick prototyping | GGUF (via Ollama/LLMFarm) |

---

## 5. Hardware Constraints by iPhone Generation

| iPhone | Chip | RAM | Max Practical Model Size (Q4) | Notes |
|--------|------|-----|-------------------------------|-------|
| iPhone 14 Pro | A16 | 6GB | ~3B params | ~2.5GB after OS overhead |
| iPhone 15 | A16 | 6GB | ~3B params | Same as 14 Pro |
| iPhone 15 Pro | A17 Pro | 8GB | ~4B params | Neural Engine improvements |
| iPhone 16 | A18 | 8GB | ~4B params | Good for Qwen3-4B / Phi-4-mini |
| iPhone 16 Pro | A18 Pro | 8GB | ~4B-7B params | Can stretch to 7B with aggressive quant |
| iPhone 17 Pro (expected) | A19 | 12GB? | ~7B-8B params | Significant headroom increase |

**Rule of thumb**: After OS overhead, expect ~3.5-4GB usable on 8GB devices, ~2-2.5GB on 6GB devices.

---

## 6. Performance Benchmarks (Approximate)

| Model | Format | Device | Tokens/sec | Notes |
|-------|--------|--------|------------|-------|
| Qwen3-4B Q4_K_M | GGUF | iPhone 16 Pro | ~15-25 t/s | Via llama.cpp + Metal |
| Phi-4-mini Q4 | GGUF | iPhone 16 Pro | ~15-25 t/s | Via llama.cpp + Metal |
| Gemma 3 1B | GGUF | iPhone 15 | ~30-40 t/s | Smaller model = faster |
| Qwen3-1.7B Q4 | GGUF | iPhone 15 | ~25-35 t/s | Good balance |
| SmolLM2-1.7B | GGUF | Pixel 6a (comparable) | ~13-18 t/s | INT8 via Cactus runtime |
| Apple Foundation Model | Native | A17 Pro+ | Apple-optimized | Framework handles optimization |

---

## 7. Summary Recommendation

**For a chatbot/agentic assistant on iPhone in 2026:**

1. **If targeting iOS 26+**: Use Apple's Foundation Models framework as the primary model (free, zero-overhead, native tool calling), with Qwen3-4B (GGUF) as a fallback for specialized tasks.

2. **If targeting iOS 17+**: Use **Qwen3-4B** in GGUF Q4_K_M format via llama.cpp (LocalLLMClient Swift package). This gives you the best reasoning and instruction-following at a size that fits comfortably on iPhone 15 Pro and newer.

3. **If broad device support is critical**: Use **Qwen3-1.7B** or **Gemma 3 1B** for maximum compatibility with older/lower-RAM iPhones.

4. **Framework choice**: Start with llama.cpp (GGUF) for broadest model compatibility. Consider Core ML conversion for production apps targeting specific models on A17 Pro+ hardware. Use Apple Foundation Models framework if you can target iOS 26.

5. **For tool calling**: Phi-4-mini-flash-reasoning or Qwen3-4B are the strongest small-model options. Apple's Foundation Models framework has native tool-calling support built in.
