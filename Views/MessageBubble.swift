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
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                avatar
            }

            if isUser {
                Spacer(minLength: 44)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.body)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(isUser ? .white : .primary)

                if !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(message.sources, id: \.self) { source in
                            Label(source, systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                                .lineLimit(2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                }

                Text(Self.timestampFormatter.string(from: message.timestamp))
                    .font(.caption2)
                    .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)
            .background(bubbleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .glassCard(cornerRadius: 18, material: isUser ? .ultraThin : .regular, tint: isUser ? Color.ragPrimary : .clear)
            .shadow(color: isUser ? Color.ragPrimary.opacity(0.16) : .black.opacity(0.1), radius: 14, x: 0, y: 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isUser ? "You said \(message.content)" : "Assistant said \(message.content)")

            if !isUser {
                Spacer(minLength: 44)
            }
        }
        .padding(.horizontal, 2)
    }

    private var avatar: some View {
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
