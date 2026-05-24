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

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                MessageContentText(content: message.content, isUser: isUser)

                if !message.sources.isEmpty {
                    SourcesSummary(sources: message.sources, isUser: isUser)
                }

                Text(Self.timestampFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .frame(maxWidth: isUser ? 315 : .infinity, alignment: isUser ? .trailing : .leading)
            .background(bubbleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .glassCard(cornerRadius: 18, material: isUser ? .ultraThin : .regular, tint: isUser ? Color.ragPrimary : .clear)
            .shadow(color: isUser ? Color.ragPrimary.opacity(0.16) : .black.opacity(0.1), radius: 14, x: 0, y: 8)
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

    private var bubbleFill: some ShapeStyle {
        if isUser {
            LinearGradient(
                colors: [Color.ragPrimary.opacity(0.9), Color.ragPrimary.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct MessageContentText: View {
    let content: String
    let isUser: Bool

    private var blocks: [MessageTextBlock] {
        MessageTextBlock.blocks(from: content)
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            ForEach(blocks) { block in
                switch block {
                case .paragraph(let text):
                    formattedText(text)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.semibold))
                        formattedText(text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
        .foregroundStyle(isUser ? .white : .primary)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private func formattedText(_ text: String) -> Text {
        let attributed = (try? AttributedString(markdown: text)) ?? AttributedString(text)
        return Text(attributed)
            .font(.body)
    }
}

private enum MessageTextBlock: Identifiable {
    case paragraph(String)
    case bullet(String)

    var id: String {
        switch self {
        case .paragraph(let text): "paragraph-\(text)"
        case .bullet(let text): "bullet-\(text)"
        }
    }

    static func blocks(from content: String) -> [MessageTextBlock] {
        content
            .components(separatedBy: .newlines)
            .reduce(into: [MessageTextBlock]()) { blocks, rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !line.isEmpty else {
                    return
                }

                if let bullet = bulletText(from: line) {
                    blocks.append(.bullet(bullet))
                } else {
                    blocks.append(.paragraph(line))
                }
            }
    }

    private static func bulletText(from line: String) -> String? {
        let bulletPrefixes = ["*   ", "* ", "-   ", "- "]

        for prefix in bulletPrefixes where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }

        return nil
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
