# LOKI - Locally Operated Kinetic Intelligence

An on-device AI assistant for iPhone that runs a local LLM with agentic capabilities. 100% private — no data ever leaves your device.

## Architecture

```
LOKI/
├── App/                    # App entry point, root state
├── Core/
│   ├── LLM/               # llama.cpp inference engine
│   ├── Agent/              # Agentic tool-calling system
│   │   └── Tools/          # Built-in tools (8 tools)
│   └── Persistence/        # SwiftData conversation storage
├── Features/
│   ├── Chat/               # Chat UI (messages, input, streaming)
│   ├── Settings/           # App configuration
│   ├── ModelManagement/    # Model download & selection
│   └── Onboarding/         # First-run experience
├── Design/                 # Theme, colors, reusable components
└── Extensions/             # Swift utilities
```

## Key Technologies

| Component | Technology |
|-----------|-----------|
| **LLM Runtime** | [llama.cpp](https://github.com/ggml-org/llama.cpp) via Swift Package |
| **Default Model** | Qwen3 1.7B (Q4_K_M GGUF, ~1.2GB) |
| **UI Framework** | SwiftUI + MVVM |
| **Persistence** | SwiftData |
| **Concurrency** | Swift Actors, async/await, AsyncThrowingStream |
| **Target** | iOS 17+, iPhone (arm64) |

## Recommended Model

**Qwen3 1.7B** (Q4_K_M quantization) is the default model, targeting iPhone 12+ (4GB RAM):
- Distilled from Qwen3-235B — strongest tool-calling at this size
- ~1.2GB leaves ~1.3GB headroom for KV cache and app on 4GB devices
- 119 language support, reasoning, and coding capability
- Apache 2.0 license (fully permissive)

Alternative models: Gemma 2 2B (1.5GB, smarter), Gemma 3 1B (700MB, lighter), SmolLM3 3B (1.9GB, smartest but tight fit), Qwen3 0.6B (490MB, fastest).

## Built-in Agent Tools

| Tool | Description |
|------|-------------|
| `calculator` | Math expressions, percentages, scientific functions |
| `calendar` | List, create, and search calendar events |
| `reminders` | Create, list, and complete reminders |
| `web_search` | Search the web via DuckDuckGo |
| `device_info` | Battery, storage, device model info |
| `clipboard` | Read/write system clipboard |
| `open_app` | Launch system apps and URLs |
| `timer` | Set countdown timers with notifications |

## Setup

### Prerequisites
- Xcode 16+
- iOS 17+ device (iPhone 12 or newer)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (optional, for project generation)

### Build

```bash
# Option A: Generate Xcode project with XcodeGen
brew install xcodegen
cd LOKI
xcodegen generate
open LOKI.xcodeproj

# Option B: Open Package.swift directly in Xcode
open Package.swift
```

### Run
1. Build and run on a physical device (simulator lacks Metal GPU)
2. On first launch, download Qwen3 1.7B from the model picker
3. Start chatting

## Design Decisions

- **Actor-isolated LLM engine**: Thread-safe inference with no data races
- **ReAct-style agent loop**: LLM reasons, calls tools, observes results, up to 5 iterations
- **Streaming via AsyncThrowingStream**: Token-by-token UI updates with backpressure
- **ChatML prompt format**: Compatible with Qwen3, Phi-4, and most instruction-tuned models
- **Protocol-oriented tools**: New tools implement `AgentTool` and register in `ToolRegistry`

## License

MIT
