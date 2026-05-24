import SwiftUI
import UniformTypeIdentifiers

struct UploadModalView: View {
    @ObservedObject var viewModel: UploadViewModel
    let onUploadComplete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isFileImporterPresented = false
    @State private var isUploadAreaHighlighted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                uploadHero
                uploadArea
                statusView
                uploadButton
                Spacer(minLength: 0)
            }
            .padding(24)
            .background(UploadSheetBackground())
            .navigationTitle("Add Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.selectFile(url)
                    }
                case .failure(let error):
                    viewModel.status = .error(error.localizedDescription)
                }
            }
            .alert("Upload Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "The document could not be uploaded.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    private var uploadHero: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.ragPrimary.opacity(0.18))
                    .frame(width: 84, height: 84)
                    .blur(radius: 10)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.ragPrimary, Color.ragSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating, value: viewModel.status.isUploading)
            }

            Text("Index a PDF")
                .font(.title2.weight(.bold))

            Text("The document becomes available to the chat after ingestion finishes.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var uploadArea: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.ragPrimary.opacity(0.12))
                        .frame(width: 58, height: 58)

                    Image(systemName: uploadAreaIconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(uploadAreaIconColor)
                        .contentTransition(.symbolEffect(.replace))
                }

                switch viewModel.status {
                case .ready(let filename, let fileSize):
                    VStack(alignment: .leading, spacing: 5) {
                        Text(filename)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                        Text(fileSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                default:
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Select a PDF")
                            .font(.body.weight(.semibold))
                        Text("PDF, up to 50 MB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(16)
            .glassCard(cornerRadius: 22, material: .regular, tint: Color.ragPrimary)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        Color.ragPrimary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: viewModel.selectedFileURL == nil ? [8, 6] : [])
                    )
            }
            .scaleEffect(isUploadAreaHighlighted ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isUploadAreaHighlighted)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.status.isUploading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isUploadAreaHighlighted = true }
                .onEnded { _ in isUploadAreaHighlighted = false }
        )
        .accessibilityLabel("Select PDF document")
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.status {
        case .idle, .ready:
            EmptyView()
        case .uploading(let progress):
            HStack(spacing: 14) {
                UploadProgressRing(progress: progress)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Uploading and indexing")
                        .font(.body.weight(.semibold))
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .glassCard(cornerRadius: 18, material: .ultraThin, tint: Color.ragSecondary)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 18, material: .ultraThin, tint: .green)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(.red)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 18, material: .ultraThin, tint: .red)
        }
    }

    private var uploadButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                if let filename = await viewModel.uploadDocument() {
                    onUploadComplete(filename)
                    dismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.status.isUploading {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.status.isUploading ? "Uploading" : "Upload")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            canUpload
                ? LinearGradient(colors: [Color.ragSecondary, Color.ragPrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color.secondary.opacity(0.5), Color.secondary.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: canUpload ? Color.ragSecondary.opacity(0.32) : .clear, radius: 14, x: 0, y: 8)
        .disabled(!canUpload)
        .accessibilityLabel("Upload selected document")
    }

    private var canUpload: Bool {
        viewModel.selectedFileURL != nil && !viewModel.status.isUploading
    }

    private var uploadAreaIconName: String {
        switch viewModel.status {
        case .ready, .success:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        case .uploading:
            "arrow.triangle.2.circlepath"
        case .idle:
            "doc.badge.plus"
        }
    }

    private var uploadAreaIconColor: Color {
        switch viewModel.status {
        case .ready, .success:
            .green
        case .error:
            .red
        case .uploading:
            .ragSecondary
        case .idle:
            .ragPrimary
        }
    }
}

private struct UploadProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.ragSecondary, Color.ragPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.25), value: progress)

            Text("\(Int(progress * 100))")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
        }
        .frame(width: 46, height: 46)
    }
}

private struct UploadSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.ragPrimary.opacity(0.12),
                Color.clear,
                Color.ragSecondary.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
