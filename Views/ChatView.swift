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

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .zIndex(1) // Keeps header cleanly layered over scrolling content

                messageList
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 12)

            if showEmptyPromptWarning {
                Text("Enter a question first")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 14, material: .regular)
                    .transition(.move(edge: .top)
                    .combined(with: .opacity))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 90)
                    .zIndex(2)
            }
        }
        // Attaching the input bar as a safe area inset provides perfect native keyboard adjustments
        .safeAreaInset(edge: .bottom) {
            inputBar
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [.clear, Color(.systemBackground).opacity(0.15), Color(.systemBackground).opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                didAppear = true
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.ragPrimary, Color.ragSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: "text.bubble.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("RAG Chat")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Button(action: showUpload) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 38, height: 38)
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
            .shadow(color: Color.ragSecondary.opacity(0.3), radius: 10, x: 0, y: 6)
            .accessibilityLabel("Add documents")

            Button(action: showSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .glassCard(cornerRadius: 19, material: .regular, tint: Color.ragPrimary.opacity(0.3))
            .accessibilityLabel("Open settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 24, material: .regular, tint: Color.ragPrimary.opacity(0.1))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages.filter { !$0.content.trimmedForSubmission.isEmpty }) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }

                    if viewModel.isSending {
                        TypingIndicator()
                            .id("typing-indicator")
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 104)
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
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about your documents", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassCard(cornerRadius: 18, material: .ultraThin, tint: isInputFocused ? Color.ragPrimary.opacity(0.1) : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(isInputFocused ? Color.ragPrimary.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                }
                .onSubmit {
                    sendTapped()
                }
                .accessibilityLabel("Question input")

            Button(action: sendTapped) {
                ZStack {
                    if viewModel.isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                viewModel.isSending ? Color.secondary.opacity(0.6) : Color.ragSecondary,
                in: Circle()
            )
            .shadow(color: Color.ragSecondary.opacity(viewModel.isSending ? 0 : 0.25), radius: 8, x: 0, y: 5)
            .disabled(viewModel.isSending)
            .scaleEffect(viewModel.isSending ? 0.95 : 1)
            .animation(.snappy(duration: 0.2), value: viewModel.isSending)
            .accessibilityLabel("Send question")
        }
        .padding(10)
        .glassCard(cornerRadius: 24, material: .regular, tint: Color.ragSecondary.opacity(0.05))
    }

    private func sendTapped() {
        let trimmedDraft = viewModel.draft.trimmedForSubmission
        guard !trimmedDraft.isEmpty else {
            withAnimation(.smooth(duration: 0.25)) {
                showEmptyPromptWarning = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    withAnimation(.smooth(duration: 0.25)) {
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
        guard !viewModel.messages.isEmpty || viewModel.isSending else { return }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if viewModel.isSending {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else if let lastMessage = viewModel.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    private var statusSubtitle: String {
        switch uploadStatus {
        case .idle: "Upload a PDF to begin"
        case .ready: "PDF selected"
        case .uploading(let progress): "Indexing document \(Int(progress * 100))%"
        case .success: "Ready for questions"
        case .error: "Upload needs attention"
        }
    }
}

// MARK: - Animated Aurora Background
private struct AnimatedAuroraBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let firstOffset = CGFloat(sin(time * 0.15)) * 70
            let secondOffset = CGFloat(cos(time * 0.12)) * 80

            ZStack {
                Color(.systemBackground)
                
                LinearGradient(
                    colors: [
                        Color.ragPrimary.opacity(0.15),
                        Color(.systemBackground).opacity(0.4),
                        Color.ragSecondary.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.ragPrimary.opacity(0.2))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .offset(x: -100 + firstOffset, y: -220)

                Circle()
                    .fill(Color.ragSecondary.opacity(0.16))
                    .frame(width: 280, height: 280)
                    .blur(radius: 64)
                    .offset(x: 120, y: 200 + secondOffset)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Typing Indicator
private struct TypingIndicator: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.ragPrimary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1 : 0.5)
                        .opacity(pulse ? 1 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: pulse
                        )
                }
            }
            Text("Generating answer...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 16, material: .ultraThin, tint: Color.ragPrimary.opacity(0.05))
        .padding(.trailing, 60) // Matches layout width rules of assistant bubbles
        .onAppear {
            pulse = true
        }
    }
}

// MARK: - Upload Status Chip
private struct UploadStatusChip: View {
    let status: UploadStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foregroundStyle)
        .glassCard(cornerRadius: 12, material: .ultraThin, tint: tint.opacity(0.15))
        .contentTransition(.symbolEffect(.replace))
        .animation(.smooth(duration: 0.2), value: title)
        .accessibilityLabel(title)
    }

    private var title: String {
        switch status {
        case .idle: "No PDF"
        case .ready: "Ready"
        case .uploading(let progress): "\(Int(progress * 100))%"
        case .success: "Indexed"
        case .error: "Issue"
        }
    }

    private var iconName: String {
        switch status {
        case .idle: "doc"
        case .ready: "doc.badge.plus"
        case .uploading: "arrow.triangle.2.circlepath"
        case .success: "checkmark.seal.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch status {
        case .success: .green
        case .error: .red
        case .uploading: .ragSecondary
        default: .ragPrimary
        }
    }

    private var foregroundStyle: Color {
        switch status {
        case .success: .green
        case .error: .red
        default: .primary
        }
    }
}
