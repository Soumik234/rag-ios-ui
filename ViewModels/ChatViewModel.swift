import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = [
        Message(
            content: "Upload a PDF and ask anything about it. I can summarize sections, find key details, compare ideas, or answer specific questions from the document.",
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
            try await streamMessage(question: question)
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

    private func streamMessage(question: String) async throws {
        let assistantMessage = Message(content: "", sender: .assistant)
        messages.append(assistantMessage)

        var streamedContent = ""
        var streamedSources: [String] = []
        var didReceiveStreamContent = false

        do {
            let stream = try networkService.streamChat(question: question)

            for try await event in stream {
                switch event {
                case .token(let token):
                    didReceiveStreamContent = true
                    streamedContent += token
                    updateMessage(
                        id: assistantMessage.id,
                        content: streamedContent,
                        sources: streamedSources
                    )
                case .sources(let sources):
                    streamedSources = sources
                    updateMessage(
                        id: assistantMessage.id,
                        content: streamedContent,
                        sources: streamedSources
                    )
                case .done:
                    logResponse(
                        question: question,
                        answer: streamedContent,
                        sources: streamedSources,
                        transport: "stream"
                    )
                    return
                }
            }

            if !streamedContent.isEmpty || !streamedSources.isEmpty {
                logResponse(
                    question: question,
                    answer: streamedContent,
                    sources: streamedSources,
                    transport: "stream"
                )
                return
            }
        } catch {
            if didReceiveStreamContent {
                throw error
            }
        }

        messages.removeAll { $0.id == assistantMessage.id }
        let response = try await networkService.sendChat(question: question)
        logResponse(
            question: question,
            answer: response.answer,
            sources: response.sources ?? [],
            transport: "fallback"
        )
        messages.append(
            Message(
                content: response.answer,
                sender: .assistant,
                sources: response.sources ?? []
            )
        )
    }

    private func updateMessage(id: UUID, content: String, sources: [String]) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            return
        }

        let existingMessage = messages[index]
        messages[index] = Message(
            id: existingMessage.id,
            content: content,
            sender: existingMessage.sender,
            timestamp: existingMessage.timestamp,
            sources: sources
        )
    }

    private func logResponse(question: String, answer: String, sources: [String], transport: String) {
        print("""
        [ChatResponse][\(transport)]
        Question: \(question)
        Answer:
        \(answer)
        Sources: \(sources)
        """)
    }
}
