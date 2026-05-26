import SwiftUI

struct MessageBubble: View {
    let message: Message

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private var isUser: Bool {
        message.sender == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if !isUser {
                assistantAvatar
            }

            if isUser {
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                MessageContentText(content: message.content, isUser: isUser)

                if !message.sources.isEmpty {
                    SourcesSummary(sources: message.sources, isUser: isUser)
                }

                Text(Self.timestampFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
                    .frame(maxWidth: contentMaxWidth, alignment: isUser ? .trailing : .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                isUser ? Color.ragPrimary.opacity(0.85) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .glassCard(cornerRadius: 18, material: .thin, tint: isUser ? Color.ragPrimary.opacity(0.2) : .clear)
            .shadow(color: isUser ? Color.ragPrimary.opacity(0.16) : .black.opacity(0.1), radius: 14, x: 0, y: 8)
            .frame(maxWidth: bubbleMaxWidth, alignment: isUser ? .trailing : .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isUser ? "You said \(message.content)" : "Assistant said \(message.content)")

            if isUser {
                userAvatar
            } else {
                Spacer(minLength: 44)
            }
        }
        .padding(.horizontal, 2)
    }

    private var bubbleMaxWidth: CGFloat {
        isUser ? 280 : 320
    }

    private var contentMaxWidth: CGFloat? {
        isUser ? nil : .infinity
    }

    private var assistantAvatar: some View {
        Image(systemName: "sparkles")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                LinearGradient(
                    colors: [Color.ragPrimary, Color.ragSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: Color.ragPrimary.opacity(0.25), radius: 8, x: 0, y: 5)
            .accessibilityHidden(true)
    }

    private var userAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                LinearGradient(
                    colors: [Color.ragSecondary, Color.ragPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: Color.ragSecondary.opacity(0.25), radius: 8, x: 0, y: 5)
            .accessibilityHidden(true)
    }

}

private struct MessageContentText: View {
    let content: String
    let isUser: Bool

    private var blocks: [MessageTextBlock] {
        MessageTextBlock.blocks(from: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let text):
                    formattedText(text)
                case .numbered(let number, let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(number).")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                        formattedText(text)
                    }
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.semibold))
                        formattedText(text)
                    }
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
        .foregroundStyle(isUser ? .white : .primary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: contentMaxWidth, alignment: .leading)
    }

    private var contentMaxWidth: CGFloat? {
        isUser ? nil : .infinity
    }

    private func formattedText(_ text: String) -> some View {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return Text(attributed)
            .font(.body)
            .lineSpacing(2)
    }
}

private enum MessageTextBlock: Identifiable {
    case paragraph(String)
    case numbered(String, String)
    case bullet(String)

    var id: String {
        switch self {
        case .paragraph(let text): "paragraph-\(text)"
        case .numbered(let number, let text): "numbered-\(number)-\(text)"
        case .bullet(let text): "bullet-\(text)"
        }
    }

    static func blocks(from content: String) -> [MessageTextBlock] {
        cleanedContent(from: content)
            .components(separatedBy: .newlines)
            .reduce(into: [MessageTextBlock]()) { blocks, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !line.isEmpty else {
                    return
                }

                if let numbered = numberedText(from: line) {
                    blocks.append(.numbered(numbered.number, numbered.text))
                } else if let bullet = bulletText(from: line) {
                    blocks.append(.bullet(bullet))
                } else {
                    blocks.append(.paragraph(line))
                }
            }
    }

    private static func numberedText(from line: String) -> (number: String, text: String)? {
        let pattern = #"^(\d+)\.\s+"#

        guard
            let range = line.range(of: pattern, options: .regularExpression),
            let numberRange = line.range(of: #"^\d+"#, options: .regularExpression)
        else {
            return nil
        }

        return (String(line[numberRange]), String(line[range.upperBound...]))
    }

    private static func bulletText(from line: String) -> String? {
        let pattern = #"^(\*|-)\s+"#

        if let range = line.range(of: pattern, options: .regularExpression) {
            return String(line[range.upperBound...])
        }

        return nil
    }

    private static func cleanedContent(from content: String) -> String {
        var cleanedContent = content
            .replacingOccurrences(of: #"^\s*Based on the provided context[:,]?\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"Sources:\s*\[\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        cleanedContent = cleanedContent
            .replacingOccurrences(of: #"([:;.!?])\s*(\d+\.)\s*"#, with: "$1\n$2 ", options: .regularExpression)
            .replacingOccurrences(of: #"([:;.!?])\s*\*\s+"#, with: "$1\n* ", options: .regularExpression)
            .replacingOccurrences(of: #"(?<!\*)\s+\*\s+(?!\*)"#, with: "\n* ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+-\s+"#, with: "\n- ", options: .regularExpression)

        return cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SourcesSummary: View {
    let sources: [String]
    let isUser: Bool

    private var uniqueSources: [String] {
        Array(NSOrderedSet(array: sources)).compactMap { $0 as? String }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "doc.text.magnifyingglass")
                .font(.caption)
                .foregroundStyle(isUser ? AnyShapeStyle(.white.opacity(0.85)) : AnyShapeStyle(.secondary))

            if let firstSource = uniqueSources.first {
                Text(firstSource)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isUser ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.tertiary))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var title: String {
        uniqueSources.count == 1 ? "1 source" : "\(uniqueSources.count) sources"
    }
}
#Preview("Message Formatting") {
    ScrollView {
        VStack(spacing: 16) {
            MessageBubble(
                message: Message(
                    content: "Okay",
                    sender: .user,
                    timestamp: .now
                )
            )

            MessageBubble(
                message: Message(
                    content: "When is insulin considered?",
                    sender: .user,
                    timestamp: .now
                )
            )

            MessageBubble(
                message: Message(
                    content: "What drugs are added for obese patients?",
                    sender: .user,
                    timestamp: .now
                )
            )

            MessageBubble(
                message: Message(
                    content: "What is the treatment for obese patients with type 2 diabetes after first-line medication does not work?",
                    sender: .user,
                    timestamp: .now
                )
            )

            MessageBubble(
                message: Message(
                    content: "Based on the provided context:For obese patients:*   If glycemic targets are not met after 3 months on metformin, **vildagliptin 50mg twice daily** after meals is added.*   If glycemic targets are still not met after 3 months on metformin + vildagliptin, then **Glimepride 1 mg once daily** before breakfast is added. The dose of Glimepride can be increased monthly by 1 mg increments until targets are met or a dose of 4 mg once daily is reached. Sources: []",
                    sender: .assistant,
                    timestamp: .now
                )
            )
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
