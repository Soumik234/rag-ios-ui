import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case serverMessage(String)
    case decodingFailed(String?)
    case emptyData
    case timedOut

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case .serverError(let statusCode):
            statusCode >= 500
                ? "The server is temporarily unavailable. Please try again later."
                : "The request failed with status code \(statusCode)."
        case .serverMessage(let message):
            message
        case .decodingFailed(let responseText):
            if let responseText, !responseText.isEmpty {
                "The server response could not be read: \(responseText)"
            } else {
                "The server response could not be read."
            }
        case .emptyData:
            "No response data was received."
        case .timedOut:
            "The upload timed out before the backend finished processing. Try again after the server wakes up, or use a smaller PDF."
        }
    }
}

enum ChatStreamEvent: Equatable {
    case token(String)
    case sources([String])
    case done
}

final class NetworkService: @unchecked Sendable {
    static let shared = NetworkService()

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIConstants.baseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConstants.requestTimeout
        configuration.timeoutIntervalForResource = APIConstants.uploadTimeout
        session = URLSession(configuration: configuration)
    }

    func sendChat(question: String) async throws -> ChatResponse {
        let url = baseURL.appendingPathComponent(APIConstants.chatPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConstants.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(question: question))

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.mapNetworkError(error)
        }

        try validate(response: response, data: data)

        guard !data.isEmpty else {
            throw NetworkError.emptyData
        }

        do {
            return try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(Self.responseText(from: data))
        }
    }

    func streamChat(question: String) throws -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let url = baseURL.appendingPathComponent(APIConstants.chatStreamPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConstants.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(ChatRequest(question: question))

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response: response)

                    for try await line in bytes.lines {
                        guard let event = Self.parseStreamLine(line) else {
                            continue
                        }

                        continuation.yield(event)

                        if event == .done {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: Self.mapNetworkError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func uploadDocument(fileURL: URL, progress: @MainActor @escaping (Double) -> Void) async throws -> UploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let filename = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(fileData: fileData, filename: filename, boundary: boundary)

        let url = baseURL.appendingPathComponent(APIConstants.ingestPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConstants.uploadTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")

        progress(0.1)
        let progressTask = Task { @MainActor in
            var currentProgress = 0.1
            while !Task.isCancelled && currentProgress < 0.9 {
                try? await Task.sleep(for: .milliseconds(180))
                currentProgress += 0.08
                progress(min(currentProgress, 0.9))
            }
        }

        defer {
            progressTask.cancel()
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch {
            throw Self.mapNetworkError(error)
        }

        try validate(response: response, data: data)
        progress(1)

        guard !data.isEmpty else {
            throw NetworkError.emptyData
        }

        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(Self.responseText(from: data))
        }
    }

    private func validate(response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            if let data, let message = Self.serverErrorMessage(from: data) {
                throw NetworkError.serverMessage(message)
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
    }

    private static func serverErrorMessage(from data: Data) -> String? {
        if
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"] as? String
        {
            return detail
        }

        return responseText(from: data)
    }

    private static func responseText(from data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    private static func mapNetworkError(_ error: Error) -> Error {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return NetworkError.timedOut
        }

        return error
    }

    private static func parseStreamLine(_ line: String) -> ChatStreamEvent? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return nil
        }

        let payload: String
        if trimmedLine.hasPrefix("data:") {
            payload = String(trimmedLine.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmedLine.hasPrefix("event:") || trimmedLine.hasPrefix("id:") || trimmedLine.hasPrefix("retry:") {
            return nil
        } else {
            payload = trimmedLine
        }

        guard !payload.isEmpty else {
            return nil
        }

        if payload == "[DONE]" || payload.lowercased() == "done" {
            return .done
        }

        guard let data = payload.data(using: .utf8) else {
            return .token(payload)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .token(payload)
        }

        if let sources = parseSources(from: object["sources"]) {
            return .sources(sources)
        }

        if let token = parseToken(from: object), !token.isEmpty {
            return .token(token)
        }

        if let isDone = object["done"] as? Bool, isDone {
            return .done
        }

        return nil
    }

    private static func parseToken(from object: [String: Any]) -> String? {
        for key in ["token", "content", "delta", "text", "answer", "response", "message"] {
            if let value = object[key] as? String {
                return value
            }
        }

        if
            let choices = object["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let delta = firstChoice["delta"] as? [String: Any],
            let content = delta["content"] as? String
        {
            return content
        }

        return nil
    }

    private static func parseSources(from value: Any?) -> [String]? {
        if let sources = value as? [String] {
            return sources
        }

        guard let sourceObjects = value as? [[String: Any]] else {
            return nil
        }

        return sourceObjects.map { object in
            let rawSource = object["source"] as? String
            let filename = rawSource?.split(separator: "/").last.map(String.init) ?? "Source"
            let pageLabel = object["page_label"] as? String
            let page = object["page"] as? Int
            let totalPages = object["total_pages"] as? Int

            var details = [filename]

            if let pageLabel {
                details.append("page \(pageLabel)")
            } else if let page {
                details.append("page \(page + 1)")
            }

            if let totalPages {
                details.append("\(totalPages) total")
            }

            return details.joined(separator: " · ")
        }
    }

    private func makeMultipartBody(fileData: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: application/pdf\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
