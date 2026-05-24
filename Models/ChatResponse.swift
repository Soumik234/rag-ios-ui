import Foundation

struct ChatRequest: Encodable {
    let question: String
}

struct ChatResponse: Decodable {
    let answer: String
    let sources: [String]?

    enum CodingKeys: String, CodingKey {
        case answer
        case response
        case result
        case message
        case sources
    }

    init(answer: String, sources: [String]? = nil) {
        self.answer = answer
        self.sources = sources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answer = try container.decodeFirstString(for: [.answer, .response, .result, .message])
        sources = try container.decodeFlexibleSourcesIfPresent(forKey: .sources)
    }
}

struct UploadResponse: Decodable {
    let status: String
    let filename: String

    enum CodingKeys: String, CodingKey {
        case status
        case filename
        case fileName
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = (try? container.decode(String.self, forKey: .status)) ?? "success"
        filename = try container.decodeFirstString(for: [.filename, .fileName, .message])
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try? decode(String.self, forKey: key), !value.isEmpty {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected one of: \(keys.map(\.stringValue).joined(separator: ", "))"
            )
        )
    }

    func decodeFlexibleSourcesIfPresent(forKey key: Key) throws -> [String]? {
        guard contains(key) else {
            return nil
        }

        if let stringSources = try? decode([String].self, forKey: key) {
            return stringSources
        }

        if let objectSources = try? decode([SourceMetadata].self, forKey: key) {
            return objectSources.map(\.displayText)
        }

        return nil
    }
}

private struct SourceMetadata: Decodable {
    let source: String?
    let page: Int?
    let pageLabel: String?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case source
        case page
        case pageLabel = "page_label"
        case totalPages = "total_pages"
    }

    var displayText: String {
        let filename = source?
            .split(separator: "/")
            .last
            .map(String.init)
            ?? "Source"

        var details: [String] = [filename]

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
