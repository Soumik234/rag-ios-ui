import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case serverMessage(String)
    case decodingFailed(String?)
    case emptyData

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
        }
    }
}

final class NetworkService: @unchecked Sendable {
    static let shared = NetworkService()

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = APIConstants.baseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConstants.timeout
        configuration.timeoutIntervalForResource = APIConstants.timeout
        session = URLSession(configuration: configuration)
    }

    func sendChat(question: String) async throws -> ChatResponse {
        let url = baseURL.appendingPathComponent(APIConstants.chatPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatRequest(question: question))

        let (data, response) = try await session.data(for: request)
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

    func uploadDocument(fileURL: URL, progress: @MainActor @escaping (Double) -> Void) async throws -> UploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let filename = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(fileData: fileData, filename: filename, boundary: boundary)

        let url = baseURL.appendingPathComponent(APIConstants.ingestPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
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

        let (data, response) = try await session.upload(for: request, from: body)
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
