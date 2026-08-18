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

/// Which model does the structured extraction step.
enum ExtractionProvider: String, CaseIterable, Identifiable {
    case gemini
    case claude

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .gemini: "Google Gemini"
        case .claude: "Claude"
        }
    }
}

/// Async pipeline: audio file → Gemini transcription → LLM extraction.
///
/// Gemini is multimodal and accepts the M4A audio directly, so no separate
/// speech-to-text service is needed. When Gemini is also the extraction
/// provider, transcription + extraction happen in a single call; when Claude
/// is selected, Gemini transcribes and Claude extracts the structured fields.
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let geminiModel = "gemini-2.5-flash"
    private let claudeModel = "claude-opus-5"
    private let claudeURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum APIError: LocalizedError {
        case missingGeminiKey
        case missingClaudeKey
        case audioTooLarge
        case requestFailed(status: Int, body: String)
        case emptyResponse
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .missingGeminiKey:
                "No Gemini API key set. Add one in Settings."
            case .missingClaudeKey:
                "No Claude API key set. Add one in Settings or switch extraction to Gemini."
            case .audioTooLarge:
                "This recording is too large to upload. Try a shorter capture."
            case .requestFailed(let status, let body):
                "API request failed (\(status)): \(body)"
            case .emptyResponse:
                "The API returned an empty response."
            case .decodingFailed:
                "Could not decode the API response."
            }
        }
    }

    // MARK: - Configuration

    private func storedKey(_ name: String) -> String? {
        let key = UserDefaults.standard.string(forKey: name) ?? ""
        return key.isEmpty ? nil : key
    }

    private var geminiKey: String {
        get throws {
            guard let key = storedKey("gemini_api_key") else { throw APIError.missingGeminiKey }
            return key
        }
    }

    private var claudeKey: String {
        get throws {
            guard let key = storedKey("anthropic_api_key") else { throw APIError.missingClaudeKey }
            return key
        }
    }

    private var extractionProvider: ExtractionProvider {
        ExtractionProvider(
            rawValue: UserDefaults.standard.string(forKey: "extraction_provider") ?? ""
        ) ?? .gemini
    }

    // MARK: - Prompts

    private static let structuredFields = """
    - "title": a concise title (max 8 words)
    - "summary": the thought rewritten as clean, well-structured prose, keeping all \
    substantive content but removing filler words and repetition
    - "category": exactly one of "Idea", "Task", "Journal", "Work", "Personal", "Other"
    - "action_items": an array of concrete follow-up actions mentioned or implied \
    (empty array if none)
    """

    // MARK: - Pipeline

    /// Full pipeline used after a capture finishes.
    func process(audioFileURL: URL) async throws -> (transcript: String, extracted: ExtractedThought) {
        switch extractionProvider {
        case .gemini:
            // One multimodal call: audio in, transcript + structured fields out.
            return try await geminiTranscribeAndExtract(audioFileURL: audioFileURL)
        case .claude:
            let transcript = try await geminiTranscribe(audioFileURL: audioFileURL)
            let extracted = try await claudeExtract(from: transcript)
            return (transcript, extracted)
        }
    }

    // MARK: - Gemini

    private func geminiRequest(body: [String: Any]) throws -> URLRequest {
        let key = try geminiKey
        let url = URL(string:
            "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent"
        )!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func audioPart(for audioFileURL: URL) throws -> [String: Any] {
        let audioData = try Data(contentsOf: audioFileURL)
        // Gemini's inline-data limit is 20MB per request; ~128kbps AAC keeps
        // even long memos well under it, but guard anyway.
        guard audioData.count < 19_000_000 else { throw APIError.audioTooLarge }
        return [
            "inline_data": [
                "mime_type": "audio/mp4",
                "data": audioData.base64EncodedString(),
            ]
        ]
    }

    private func geminiGenerate(parts: [[String: Any]]) async throws -> String {
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["responseMimeType": "application/json"],
        ]
        let request = try geminiRequest(body: body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }

        guard
            let decoded = try? JSONDecoder().decode(GeminiResponse.self, from: data),
            let text = decoded.candidates?.first?.content?.parts?
                .compactMap(\.text).joined(), !text.isEmpty
        else {
            throw APIError.emptyResponse
        }
        return text
    }

    /// Single call: transcribe the audio AND extract the structured fields.
    func geminiTranscribeAndExtract(
        audioFileURL: URL
    ) async throws -> (transcript: String, extracted: ExtractedThought) {
        let prompt = """
        The attached audio is a stream-of-consciousness voice memo. \
        Respond with only a JSON object containing:
        - "transcript": the full verbatim transcription of the audio
        \(Self.structuredFields)
        """
        let text = try await geminiGenerate(parts: [
            try audioPart(for: audioFileURL),
            ["text": prompt],
        ])

        struct FullResult: Codable {
            let transcript: String
            let title: String
            let summary: String
            let category: String
            let actionItems: [String]

            enum CodingKeys: String, CodingKey {
                case transcript, title, summary, category
                case actionItems = "action_items"
            }
        }
        guard let result = decodeJSON(FullResult.self, from: text) else {
            throw APIError.decodingFailed
        }
        return (
            result.transcript,
            ExtractedThought(
                title: result.title,
                summary: result.summary,
                category: result.category,
                actionItems: result.actionItems
            )
        )
    }

    /// Transcription only (used when Claude does the extraction).
    func geminiTranscribe(audioFileURL: URL) async throws -> String {
        let prompt = """
        Transcribe the attached voice memo verbatim. Respond with only a JSON \
        object of the form {"transcript": "..."}.
        """
        let text = try await geminiGenerate(parts: [
            try audioPart(for: audioFileURL),
            ["text": prompt],
        ])

        struct TranscriptResult: Codable { let transcript: String }
        guard let result = decodeJSON(TranscriptResult.self, from: text) else {
            throw APIError.decodingFailed
        }
        return result.transcript
    }

    // MARK: - Claude extraction

    func claudeExtract(from transcript: String) async throws -> ExtractedThought {
        let key = try claudeKey

        var request = URLRequest(url: claudeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let systemPrompt = """
        You are a note-taking assistant. The user dictated a stream-of-consciousness \
        voice memo; you receive its transcription. Respond with only a JSON object \
        (no markdown fences, no prose) containing:
        \(Self.structuredFields)
        """

        let payload: [String: Any] = [
            "model": claudeModel,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": transcript]
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        struct ClaudeResponse: Decodable {
            struct ContentBlock: Decodable {
                let type: String
                let text: String?
            }
            let content: [ContentBlock]
            let stop_reason: String?
        }

        guard
            let decoded = try? JSONDecoder().decode(ClaudeResponse.self, from: data),
            let text = decoded.content.first(where: { $0.type == "text" })?.text
        else {
            throw APIError.emptyResponse
        }

        guard let extracted = decodeJSON(ExtractedThought.self, from: text) else {
            throw APIError.decodingFailed
        }
        return extracted
    }

    // MARK: - Helpers

    /// Decodes model output as JSON, tolerating surrounding markdown fences.
    private func decodeJSON<T: Decodable>(_ type: T.Type, from text: String) -> T? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

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
