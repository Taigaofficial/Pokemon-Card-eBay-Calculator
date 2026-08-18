import Foundation

/// Structured result the LLM extracts from a raw transcription.
struct ExtractedThought: Codable {
    let title: String
    let summary: String
    let category: String
    let actionItems: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case category
        case actionItems = "action_items"
    }
}

/// Async pipeline: audio file → Whisper transcription → LLM extraction.
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let transcriptionURL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private let chatURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum APIError: LocalizedError {
        case missingAPIKey
        case requestFailed(status: Int, body: String)
        case emptyResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "No OpenAI API key set. Add one in Settings."
            case .requestFailed(let status, let body):
                "API request failed (\(status)): \(body)"
            case .emptyResponse:
                "The API returned an empty response."
            case .decodingFailed:
                "Could not decode the API response."
            }
        }
    }

    private var apiKey: String {
        get throws {
            let key = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
            guard !key.isEmpty else { throw APIError.missingAPIKey }
            return key
        }
    }

    /// Full pipeline used after a capture finishes.
    func process(audioFileURL: URL) async throws -> (transcript: String, extracted: ExtractedThought) {
        let transcript = try await transcribe(audioFileURL: audioFileURL)
        let extracted = try await extract(from: transcript)
        return (transcript, extracted)
    }

    // MARK: - Whisper speech-to-text

    func transcribe(audioFileURL: URL) async throws -> String {
        let key = try apiKey
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: transcriptionURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        let audioData = try Data(contentsOf: audioFileURL)
        var body = Data()

        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        appendField(name: "model", value: "whisper-1")
        appendField(name: "response_format", value: "json")

        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFileURL.lastPathComponent)\"\r\n".utf8
        ))
        body.append(Data("Content-Type: audio/m4a\r\n\r\n".utf8))
        body.append(audioData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw APIError.decodingFailed
        }
        return decoded.text
    }

    // MARK: - LLM extraction

    private static let extractionPrompt = """
    You are a note-taking assistant. The user dictated a raw, stream-of-consciousness \
    voice memo. From the transcription, extract:
    - "title": a concise title (max 8 words)
    - "summary": the thought rewritten as clean, well-structured prose, keeping all \
    substantive content but removing filler words and repetition
    - "category": exactly one of "Idea", "Task", "Journal", "Work", "Personal", "Other"
    - "action_items": an array of concrete follow-up actions mentioned or implied \
    (empty array if none)

    Respond with only a JSON object containing those four keys.
    """

    func extract(from transcript: String) async throws -> ExtractedThought {
        let key = try apiKey

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": Self.extractionPrompt],
                ["role": "user", "content": transcript],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        guard
            let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
            let content = decoded.choices.first?.message.content,
            let contentData = content.data(using: .utf8)
        else {
            throw APIError.emptyResponse
        }

        guard let extracted = try? JSONDecoder().decode(ExtractedThought.self, from: contentData) else {
            throw APIError.decodingFailed
        }
        return extracted
    }

    // MARK: - Helpers

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.requestFailed(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
    }
}
