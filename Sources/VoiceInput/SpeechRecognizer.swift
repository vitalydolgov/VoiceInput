import Combine
import Speech
import AVFoundation

enum RecordingError: Error {
    case notAuthorized, recordingFailed
}

enum TranscriptionError: Error {
    case noSpeechDetected
    case emptyTranscription
    case apiError(String)
}

class SpeechRecognizer {
    let transcriber: Transcriber

    let transcriptionResult = CurrentValueSubject<Result<String, TranscriptionError>?, Never>(nil)
    let audioLevel = CurrentValueSubject<Float, Never>(0.0)
    var isPaused = true

    private let audioEngine = AVAudioEngine()
    private var audioBuffers: [AVAudioPCMBuffer] = []
    private let audioEncoder = AudioEncoder()

    init?(locale _: Locale, transcriber: Transcriber) {
        self.transcriber = transcriber
    }

    func startRecording() async throws {
        guard case .authorized = await requestAuthorizationRecognizer() else {
            throw RecordingError.notAuthorized
        }

        audioBuffers = []
        transcriptionResult.send(nil)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.duckOthers, .defaultToSpeaker]
        )

        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(recordingFormat.sampleRate * 0.1),
            format: recordingFormat
        ) { [weak self] buffer, _ in
            guard let self = self else { return }

            if let bufferCopy = buffer.copy() as? AVAudioPCMBuffer {
                self.audioBuffers.append(bufferCopy)
            }

            let level = self.calculateAudioLevel(from: buffer)
            self.audioLevel.send(level)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isPaused = false
    }

    private func requestAuthorizationRecognizer() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func stopRecording() async {
        guard !isPaused else { return }

        isPaused = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioLevel.send(0.0)

        await transcribeRecording()
    }

    func cancelRecording() async {
        guard !isPaused else { return }

        isPaused = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioLevel.send(0.0)
        audioBuffers = []
    }

    private func transcribeRecording() async {
        guard !audioBuffers.isEmpty else {
            transcriptionResult.send(.failure(.noSpeechDetected))
            return
        }

        do {
            let audioData = audioEncoder.encodeToWAV(buffers: audioBuffers)

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            try audioData.write(to: tempURL)

            let transcription = try await transcriber.transcribe(file: tempURL, language: nil)

            try? FileManager.default.removeItem(at: tempURL)

            let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTranscription.isEmpty {
                transcriptionResult.send(.failure(.emptyTranscription))
            } else {
                transcriptionResult.send(.success(transcription))
            }
        } catch {
            print("ERROR: \(error.localizedDescription)")

            let errorMessage = error.localizedDescription
            if errorMessage.lowercased().contains("no speech") {
                transcriptionResult.send(.failure(.noSpeechDetected))
            } else {
                transcriptionResult.send(.failure(.apiError(errorMessage)))
            }
        }
    }

    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0.0 }
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0.0
        for i in 0 ..< frameLength {
            let sample = channelDataValue[i]
            sum += abs(sample)
        }

        return sum / Float(frameLength)
    }
}
