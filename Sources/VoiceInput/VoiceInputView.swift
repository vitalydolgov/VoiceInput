import SwiftUI

/// Voice input view with real-time waveform visualization.
///
/// Supports both on-device and cloud-based LLM transcription with automatic state and error handling.
///
/// ## Example
/// ```swift
/// VoiceInputView(
///     onConfirm: { text in print(text) },
///     onCancel: { },
///     llmTranscriber: MistralTranscriber(apiKey: "your-api-key")
/// )
/// ```
public struct VoiceInputView: View {
    @State private var viewModel: VoiceInputViewModel
    @AppStorage("useLLMTranscription") private var useLLMTranscription: Bool = false
    @FocusState private var isTextEditorFocused: Bool

    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    /// - Parameters:
    ///   - onConfirm: Called when user confirms the transcribed text.
    ///   - onCancel: Called when user cancels.
    ///   - llmTranscriber: Optional custom transcriber. When provided, toggle switches between on-device and LLM transcription.
    public init(
        onConfirm: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        llmTranscriber: Transcriber? = nil
    ) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _viewModel = State(initialValue: VoiceInputViewModel(llmTranscriber: llmTranscriber))
    }

    public var body: some View {
        VStack {
            VStack(spacing: 20) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(viewModel.recordingState == .recording ? .red : .gray)
                    .font(.title)

                if viewModel.recordingState == .recording {
                    WaveformView(levels: viewModel.audioLevels)
                        .padding(.horizontal)
                } else if viewModel.recordingState == .processing {
                    Text("Processing...")
                        .foregroundStyle(.secondary)
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                } else {
                    Text(viewModel.currentTranscribedText)
                }
            }
            .transition(.opacity)

            Spacer()

            VStack(spacing: 8) {
                if viewModel.hasLLMTranscriber {
                    Toggle(isOn: $useLLMTranscription) {
                        EmptyView()
                    }
                    .toggleStyle(.switch)
                    .disabled(viewModel.recordingState == .recording ||
                              viewModel.recordingState == .loading ||
                              viewModel.recordingState == .processing)
                    .labelsHidden()
                    .onChange(of: useLLMTranscription) { _, newValue in
                        viewModel.updateTranscriber(useLLM: newValue)
                    }

                    Label("Enhanced", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label("On-device transcription", systemImage: "cpu")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 36)

            ZStack {
                Button {
                    if viewModel.recordingState == .stopped {
                        viewModel.startRecording()
                    } else if viewModel.recordingState == .recording {
                        Task {
                            await viewModel.stopRecording()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .scaleEffect(viewModel.recordingState == .recording ? 1.3 : 1.0)
                            .opacity(viewModel.recordingState == .recording ? 0.5 : 0)
                            .animation(
                                viewModel.recordingState == .recording
                                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                    : .default,
                                value: viewModel.recordingState == .recording
                            )

                        Circle()
                            .fill(viewModel.recordingState == .recording ? .red : .gray.opacity(0.5))
                            .frame(width: 60, height: 60)

                        switch viewModel.recordingState {
                        case .loading:
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .symbolEffect(.pulse)
                        case .recording:
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        case .processing:
                            Image(systemName: "ellipsis")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .symbolEffect(.pulse)
                        case .stopped:
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.recordingState == .loading ||
                          viewModel.recordingState == .processing)

                HStack {
                    Button {
                        Task {
                            if viewModel.recordingState == .recording {
                                await viewModel.cancelRecording()
                            }
                            onCancel()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                            .font(.title)
                    }

                    Spacer()

                    Button {
                        onConfirm(viewModel.currentTranscribedText)
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.title)
                    }
                    .disabled(viewModel.recordingState != .stopped ||
                              viewModel.currentTranscribedText.isEmpty)
                    .opacity(viewModel.recordingState != .stopped ||
                             viewModel.currentTranscribedText.isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.recordingState)
        .padding()
        .onAppear {
            viewModel.updateTranscriber(useLLM: useLLMTranscription)
        }
    }
}

#Preview {
    VoiceInputView(
        onConfirm: { text in
            print("Confirmed: \(text)")
        },
        onCancel: {
            print("Cancelled")
        },
        llmTranscriber: nil
    )
}
