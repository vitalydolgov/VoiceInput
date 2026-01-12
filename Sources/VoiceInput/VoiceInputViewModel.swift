import Combine
import Speech

enum RecordingState: Equatable {
    case loading
    case recording
    case processing
    case stopped
}

@MainActor
@Observable
class VoiceInputViewModel {
    var currentTranscribedText: String = ""
    var audioLevels: [Float] = []
    var errorMessage: String?

    private let llmTranscriber: Transcriber?
    private var speechRecognizer: SpeechRecognizer?
    private var cancellables = Set<AnyCancellable>()

    var hasLLMTranscriber: Bool {
        llmTranscriber != nil
    }

    init(llmTranscriber: Transcriber?) {
        self.llmTranscriber = llmTranscriber
    }

    var recordingState: RecordingState = .loading {
        didSet {
            playSound(for: recordingState)
        }
    }

    private func playSound(for state: RecordingState) {
        switch state {
        case .recording:
            AudioServicesPlaySystemSound(1113)
        case .stopped:
            AudioServicesPlaySystemSound(1114)
        default:
            break
        }
    }

    func startRecording() {
        Task {
            do {
                errorMessage = nil
                try await speechRecognizer?.startRecording()
                recordingState = .recording
            } catch {
                print(error)
                recordingState = .stopped
            }
        }
    }

    func stopRecording() async {
        recordingState = .processing
        audioLevels = []

        await speechRecognizer?.stopRecording()
    }

    func cancelRecording() async {
        recordingState = .stopped
        audioLevels = []

        await speechRecognizer?.cancelRecording()
    }

    func updateTranscriber(useLLM: Bool) {
        guard recordingState != .recording else { return }

        speechRecognizer = makeSpeechRecognizer(useLLM: useLLM)
        startRecording()
    }

    private func makeSpeechRecognizer(useLLM: Bool) -> SpeechRecognizer {
        let locale = Locale(identifier: Locale.preferredLanguages[0])
        let transcriber: any Transcriber

        if useLLM, let llmTranscriber {
            transcriber = llmTranscriber
        } else {
            transcriber = LocalTranscriber(speechRecognizer: SFSpeechRecognizer(locale: locale)!)
        }

        let speechRecognizer = SpeechRecognizer(
            locale: locale,
            transcriber: transcriber
        )!

        cancellables.removeAll()

        speechRecognizer.transcriptionResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let result = result else { return }

                switch result {
                case .success(let text):
                    self?.currentTranscribedText = text
                    self?.errorMessage = nil
                    if self?.recordingState == .processing {
                        self?.recordingState = .stopped
                    }
                case .failure(let error):
                    self?.currentTranscribedText = ""
                    self?.recordingState = .stopped
                }
            }
            .store(in: &cancellables)

        speechRecognizer.audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevels.append(level)
                if (self?.audioLevels.count ?? 0) > 40 {
                    self?.audioLevels.removeFirst()
                }
            }
            .store(in: &cancellables)

        return speechRecognizer
    }
}
