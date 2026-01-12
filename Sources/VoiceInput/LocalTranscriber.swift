import Speech

struct LocalTranscriber: Transcriber {
    let speechRecognizer: SFSpeechRecognizer

    init(speechRecognizer: SFSpeechRecognizer) {
        self.speechRecognizer = speechRecognizer
    }

    func transcribe(file: URL, language _: String?) async throws -> String {
        let request = SFSpeechURLRecognitionRequest(url: file)

        return try await withCheckedThrowingContinuation { continuation in
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else { return }

                if result.isFinal {
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: text)
                }
            }
        }
    }
}
