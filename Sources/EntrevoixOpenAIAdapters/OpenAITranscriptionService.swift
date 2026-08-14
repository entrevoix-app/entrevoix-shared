import Foundation
import EntrevoixCore

public protocol HTTPTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct EphemeralHTTPTransport: HTTPTransporting {
    private let session: URLSession

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        self.session = URLSession(configuration: configuration, delegate: RedirectRejectingDelegate(), delegateQueue: nil)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

private final class RedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public enum OpenAIAdapterError: Error, Equatable, Sendable {
    case invalidEndpoint
    case missingAPIKey
    case invalidHeader
    case fileTooLarge
    case invalidResponse
    case emptyResult
    case http(statusCode: Int, message: String?)
}

public struct OpenAITranscriptionService: SpeechTranscribing {
    private let transport: any HTTPTransporting
    private let makeBoundary: @Sendable () -> String

    public init(transport: any HTTPTransporting = EphemeralHTTPTransport(), makeBoundary: @escaping @Sendable () -> String = { "Boundary-\(UUID().uuidString)" }) {
        self.transport = transport
        self.makeBoundary = makeBoundary
    }

    public func transcribe(audio: AudioFile, configuration: APIProviderConfiguration, apiKey: String, prompt: String?, language: String?) async throws -> String {
        guard let endpoint = configuration.endpointURL else { throw OpenAIAdapterError.invalidEndpoint }
        let data = try Data(contentsOf: audio.url)
        guard data.count <= 25 * 1024 * 1024 else { throw OpenAIAdapterError.fileTooLarge }
        let boundary = makeBoundary()
        var body = Data()
        appendField("model", configuration.model, to: &body, boundary: boundary)
        if let prompt, !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { appendField("prompt", prompt, to: &body, boundary: boundary) }
        if let language, !language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { appendField("language", language, to: &body, boundary: boundary) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(audio.fileName)\"\r\nContent-Type: \(audio.mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        try setAuthentication(on: &request, configuration: configuration, apiKey: apiKey)
        let (responseData, response) = try await transport.data(for: request.withHTTPBody(body))
        guard let http = response as? HTTPURLResponse else { throw OpenAIAdapterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw OpenAIAdapterError.http(statusCode: http.statusCode, message: errorMessage(from: responseData)) }
        if let result = try? JSONDecoder().decode(TranscriptionResponse.self, from: responseData), !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let text = String(data: responseData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { throw OpenAIAdapterError.emptyResult }
        return text
    }

    private func appendField(_ name: String, _ value: String, to body: inout Data, boundary: String) {
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    private func setAuthentication(on request: inout URLRequest, configuration: APIProviderConfiguration, apiKey: String) throws {
        switch configuration.authentication {
        case .none: break
        case .bearer:
            guard !apiKey.isEmpty else { throw OpenAIAdapterError.missingAPIKey }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            guard !apiKey.isEmpty else { throw OpenAIAdapterError.missingAPIKey }
            let header = configuration.customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty else { throw OpenAIAdapterError.invalidHeader }
            request.setValue(apiKey, forHTTPHeaderField: header)
        }
    }

    private func errorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
    }
}

public struct OpenAITextCleanupService: TextCleaning {
    private let transport: any HTTPTransporting

    public init(transport: any HTTPTransporting = EphemeralHTTPTransport()) { self.transport = transport }

    public func clean(text: String, configuration: APIProviderConfiguration, apiKey: String, format: CleanupAPIFormat, prompt: String) async throws -> String {
        guard let endpoint = configuration.endpointURL else { throw OpenAIAdapterError.invalidEndpoint }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw OpenAIAdapterError.emptyResult }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try setAuthentication(on: &request, configuration: configuration, apiKey: apiKey)
        switch format {
        case .responses:
            request.httpBody = try JSONEncoder().encode(ResponsesRequest(model: configuration.model, instructions: prompt, input: text, store: false))
        case .chatCompletions:
            request.httpBody = try JSONEncoder().encode(ChatRequest(model: configuration.model, messages: [ChatMessage(role: "system", content: prompt), ChatMessage(role: "user", content: text)], store: false))
        }
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIAdapterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw OpenAIAdapterError.http(statusCode: http.statusCode, message: errorMessage(from: data)) }
        let output: String?
        switch format {
        case .responses: output = try? decodeResponses(from: data)
        case .chatCompletions: output = try? decodeChat(from: data)
        }
        guard let output, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw OpenAIAdapterError.emptyResult }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setAuthentication(on request: inout URLRequest, configuration: APIProviderConfiguration, apiKey: String) throws {
        switch configuration.authentication {
        case .none: break
        case .bearer:
            guard !apiKey.isEmpty else { throw OpenAIAdapterError.missingAPIKey }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        case .apiKey:
            guard !apiKey.isEmpty else { throw OpenAIAdapterError.missingAPIKey }
            let header = configuration.customHeaderName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !header.isEmpty else { throw OpenAIAdapterError.invalidHeader }
            request.setValue(apiKey, forHTTPHeaderField: header)
        }
    }

    private func decodeResponses(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        if let outputText = response.outputText, !outputText.isEmpty { return outputText }
        return response.output.flatMap { $0.content ?? [] }.compactMap(\.text).joined()
    }

    private func decodeChat(from data: Data) throws -> String {
        try JSONDecoder().decode(ChatResponse.self, from: data).choices.compactMap { $0.message.content }.joined()
    }

    private func errorMessage(from data: Data) -> String? { (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message }
}

private extension URLRequest {
    func withHTTPBody(_ body: Data) -> URLRequest { var copy = self; copy.httpBody = body; return copy }
}

private struct TranscriptionResponse: Decodable { let text: String }
private struct APIErrorEnvelope: Decodable { let error: APIError }
private struct APIError: Decodable { let message: String }
private struct ResponsesRequest: Encodable { let model: String; let instructions: String; let input: String; let store: Bool }
private struct ResponsesResponse: Decodable { let outputText: String?; let output: [ResponsesOutput]; enum CodingKeys: String, CodingKey { case outputText = "output_text"; case output } }
private struct ResponsesOutput: Decodable { let content: [ResponsesContent]? }
private struct ResponsesContent: Decodable { let text: String? }
private struct ChatRequest: Encodable { let model: String; let messages: [ChatMessage]; let store: Bool }
private struct ChatMessage: Codable { let role: String; let content: String }
private struct ChatResponse: Decodable { let choices: [ChatChoice] }
private struct ChatChoice: Decodable { let message: ChatMessage }
