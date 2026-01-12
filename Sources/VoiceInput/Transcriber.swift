import Foundation

/// A protocol for implementing audio transcription services.
///
/// ## Example
/// ```swift
/// struct MyTranscriber: Transcriber {
///     func transcribe(file: URL, language: String?) async throws -> String {
///         // Your transcription implementation
///         return "transcribed text"
///     }
/// }
/// ```
public protocol Transcriber {
    /// Transcribes the audio file at the specified URL.
    ///
    /// - Parameters:
    ///   - file: URL of the audio file to transcribe.
    ///   - language: Optional language code (e.g., "en", "es").
    /// - Returns: The transcribed text.
    func transcribe(file: URL, language: String?) async throws -> String
}

/// Mistral AI transcriber using the Voxtral model.
///
/// - Important: Get your API key at https://console.mistral.ai
public struct MistralTranscriber: Transcriber {
    public let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func transcribe(file: URL, language: String?) async throws -> String {
        let url = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: file)
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("voxtral-mini-latest\r\n".data(using: .utf8)!)

        if let language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return response.text
    }
}

private struct TranscriptionResponse: Codable {
    let text: String
}
