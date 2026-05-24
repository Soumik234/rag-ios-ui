import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    let uploadStatus: UploadStatus
    let showUpload: () -> Void
    let showSettings: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isInputFocused: Bool
    @State private var showEmptyPromptWarning = false
    @State private var didAppear = false

    var body: some View {
        ZStack {
            AnimatedAuroraBackground()

            VStack(spacing: 12) {
                header
                messageList
                inputBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 14)

            if showEmptyPromptWarning {
                Text("Enter a question first")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassCard(cornerRadius: 12, material: .regular)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 72)
            }
        }
        .alert("Chat Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.45)) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RAG Chat")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)
                Text("Document-grounded answers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            UploadStatusChip(status: uploadStatus)

            Spacer()

            Button(action: showUpload) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color.ragSecondary, Color.ragPrimary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: Color.ragSecondary.opacity(0.35), radius: 14, x: 0, y: 8)
            .accessibilityLabel("Add documents")

            Button(action: showSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassCard(cornerRadius: 22, material: .regular, tint: Color.ragPrimary.opacity(0.4))
            .accessibilityLabel("Open settings")
        }
        .padding(16)
        .glassCard(cornerRadius: 22, material: .regular, tint: Color.ragPrimary)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                    }

                    if viewModel.isSending {
                        TypingIndicator()
                            .id("typing-indicator")
                    }
                }
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToLatest(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToLatest(proxy: proxy)
            }
            .onChange(of: viewModel.isSending) {
                scrollToLatest(proxy: proxy)
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Ask about your documents", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...4)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: 12, material: .ultraThin, tint: isInputFocused ? Color.ragPrimary : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isInputFocused ? Color.ragPrimary.opacity(0.55) : .clear, lineWidth: 1.2)
                }
                .onSubmit {
                    sendTapped()
                }
                .accessibilityLabel("Question input")

            Button(action: sendTapped) {
                if viewModel.isSending {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                viewModel.isSending
                    ? Color.secondary
                    : Color.ragSecondary,
                in: Circle()
            )
            .shadow(color: Color.ragSecondary.opacity(viewModel.isSending ? 0 : 0.35), radius: 12, x: 0, y: 8)
            .disabled(viewModel.isSending)
            .scaleEffect(viewModel.isSending ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: viewModel.isSending)
            .accessibilityLabel("Send question")
        }
        .padding(12)
        .glassCard(cornerRadius: 22, material: .regular, tint: Color.ragSecondary)
    }

    private func sendTapped() {
        let trimmedDraft = viewModel.draft.trimmedForSubmission
        guard !trimmedDraft.isEmpty else {
            withAnimation {
                showEmptyPromptWarning = true
            }

            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation {
                        showEmptyPromptWarning = false
                    }
                }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await viewModel.sendMessage()
        }
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        guard let lastMessage = viewModel.messages.last else {
            return
        }

        withAnimation(.smooth(duration: 0.25)) {
            if viewModel.isSending {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

private struct AnimatedAuroraBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let firstOffset = CGFloat(sin(time * 0.18)) * 90
            let secondOffset = CGFloat(cos(time * 0.14)) * 110

            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [
                        Color.ragPrimary.opacity(0.22),
                        Color(.systemBackground).opacity(0.3),
                        Color.ragSecondary.opacity(0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.ragPrimary.opacity(0.24))
                    .frame(width: 280, height: 280)
                    .blur(radius: 44)
                    .offset(x: -120 + firstOffset, y: -260)

                Circle()
                    .fill(Color.ragSecondary.opacity(0.2))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: 160, y: 220 + secondOffset)
            }
            .ignoresSafeArea()
        }
    }
}

private struct TypingIndicator: View {
    @State private var pulse = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.ragPrimary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1 : 0.55)
                        .opacity(pulse ? 1 : 0.45)
                        .animation(
                            .easeInOut(duration: 0.55)
                                .repeatForever()
                                .delay(Double(index) * 0.12),
                            value: pulse
                        )
                }
            }
            Text("Generating answer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .glassCard(cornerRadius: 16, material: .ultraThin, tint: Color.ragPrimary)
        .onAppear {
            pulse = true
        }
    }
}

private struct UploadStatusChip: View {
    let status: UploadStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .foregroundStyle(foregroundStyle)
        .glassCard(cornerRadius: 14, material: .ultraThin, tint: tint)
        .contentTransition(.symbolEffect(.replace))
        .animation(.smooth(duration: 0.25), value: title)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch status {
        case .idle:
            "No PDF"
        case .ready:
            "Ready"
        case .uploading(let progress):
            "\(Int(progress * 100))%"
        case .success:
            "Indexed"
        case .error:
            "Issue"
        }
    }

    private var iconName: String {
        switch status {
        case .idle:
            "doc"
        case .ready:
            "doc.badge.plus"
        case .uploading:
            "arrow.triangle.2.circlepath"
        case .success:
            "checkmark.seal.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .success:
            .green
        case .error:
            .red
        case .uploading:
            .ragSecondary
        default:
            .ragPrimary
        }
    }

    private var foregroundStyle: Color {
        switch status {
        case .success:
            .green
        case .error:
            .red
        default:
            .primary
        }
    }
}
