import Foundation

enum APIConstants {
    static let baseURL = URL(string: "https://rag-backend-hmj8.onrender.com")!
    static let chatPath = "/chat/"
    static let chatStreamPath = "/chat/stream"
    static let ingestPath = "/ingest/"
    static let requestTimeout: TimeInterval = 60
    static let uploadTimeout: TimeInterval = 180
}
