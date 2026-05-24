import Foundation

enum APIConstants {
    static let baseURL = URL(string: "https://rag-backend-hmj8.onrender.com")!
    static let chatPath = "/chat/"
    static let ingestPath = "/ingest/"
    static let timeout: TimeInterval = 30
}
