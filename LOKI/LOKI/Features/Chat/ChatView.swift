import SwiftUI
import SwiftData

// MARK: - Chat View

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var scrollAnchor

    let conversationID: UUID

    init(conversationID: UUID) {
        self.conversationID = conversationID
        _viewModel = StateObject(wrappedValue: ChatViewModel(conversationID: conversationID))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            toolExecutionBar
            inputBar
        }
        .background(Theme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            viewModel.configure(
                modelContext: modelContext,
                agent: appState.agent
            )
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isGenerating {
                        TypingIndicatorView()
                            .id("typing")
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.streamingText) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Tool Execution Bar

    @ViewBuilder
    private var toolExecutionBar: some View {
        if let toolName = viewModel.activeToolName {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Theme.Colors.accent)
                    .scaleEffect(0.8)
                Text("Running: \(toolName)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.Colors.surfaceElevated)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Message LOKI...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { sendMessage() }

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.Colors.background)
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Group {
                if viewModel.isGenerating {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                viewModel.canSend || viewModel.isGenerating
                    ? Theme.Colors.accent
                    : Theme.Colors.surface,
                in: Circle()
            )
        }
        .disabled(!viewModel.canSend && !viewModel.isGenerating)
        .animation(.easeInOut(duration: 0.15), value: viewModel.canSend)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text("LOKI")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    private var statusText: String {
        switch appState.engineStatus {
        case .idle: return "Offline"
        case .loading: return "Loading model..."
        case .ready: return "On-device"
        case .error: return "Error"
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        if viewModel.isGenerating {
            viewModel.stopGeneration()
        } else {
            viewModel.send()
            isInputFocused = true
        }
    }
}
