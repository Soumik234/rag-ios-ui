import Foundation

struct Message: Identifiable, Equatable {
    enum Sender: Equatable {
        case user
        case assistant
    }

    let id: UUID
    let content: String
    let sender: Sender
    let timestamp: Date
    let sources: [String]

    init(
        id: UUID = UUID(),
        content: String,
        sender: Sender,
        timestamp: Date = Date(),
        sources: [String] = []
    ) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
        self.sources = sources
    }
}
