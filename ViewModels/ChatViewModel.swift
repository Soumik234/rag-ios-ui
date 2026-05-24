import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = [
        Message(
            content: "Upload a PDF, then ask a question about its contents.",
            sender: .assistant
        )
    ]
    @Published var draft = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    private let networkService: NetworkService

    init(networkService: NetworkService? = nil) {
        self.networkService = networkService ?? .shared
    }

    func sendMessage() async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSending else {
            return
        }

        draft = ""
        isSending = true
        messages.append(Message(content: question, sender: .user))

        do {
            let response = try await networkService.sendChat(question: question)
            messages.append(
                Message(
                    content: response.answer,
                    sender: .assistant,
                    sources: response.sources ?? []
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    func clearHistory() {
        messages = [
            Message(
                content: "Conversation cleared. Ask another question when you are ready.",
                sender: .assistant
            )
        ]
    }

    func documentDidUpload(filename: String) {
        messages.append(
            Message(
                content: "\(filename) is ready. Ask a question about this document.",
                sender: .assistant
            )
        )
    }
}
