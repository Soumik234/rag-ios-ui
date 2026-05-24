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
            VStack(spacing: 20) {
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
                    Button("Close") { dismiss() }
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
                    .fill(Color.ragPrimary.opacity(0.14))
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 32, weight: .medium))
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
                .font(.title3.weight(.bold))

            Text("The document becomes available to the chat after ingestion finishes.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var uploadArea: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.ragPrimary.opacity(0.1))
                        .frame(width: 52, height: 52)

                    Image(systemName: uploadAreaIconName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(uploadAreaIconColor)
                        .contentTransition(.symbolEffect(.replace))
                }

                switch viewModel.status {
                case .ready(let filename, let fileSize):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filename)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        Text(fileSize)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                default:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Select a PDF")
                            .font(.subheadline.weight(.semibold))
                        Text("PDF, up to 50 MB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .padding(14)
            .glassCard(cornerRadius: 20, material: .regular, tint: Color.ragPrimary.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        Color.ragPrimary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.2, dash: viewModel.selectedFileURL == nil ? [6, 5] : [])
                    )
            }
            .scaleEffect(isUploadAreaHighlighted ? 0.98 : 1)
            .animation(.snappy(duration: 0.25), value: isUploadAreaHighlighted)
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
            HStack(spacing: 12) {
                UploadProgressRing(progress: progress)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Uploading and indexing")
                        .font(.subheadline.weight(.semibold))
                    Text("\(Int(progress * 100))% complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .glassCard(cornerRadius: 16, material: .ultraThin, tint: Color.ragSecondary.opacity(0.05))
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 16, material: .ultraThin, tint: .green.opacity(0.15))
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 16, material: .ultraThin, tint: .red.opacity(0.15))
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
            HStack(spacing: 8) {
                if viewModel.status.isUploading {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.status.isUploading ? "Uploading" : "Upload")
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            canUpload
                ? LinearGradient(colors: [Color.ragSecondary, Color.ragPrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color.secondary.opacity(0.4), Color.secondary.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: canUpload ? Color.ragSecondary.opacity(0.25) : .clear, radius: 10, x: 0, y: 6)
        .disabled(!canUpload)
        .accessibilityLabel("Upload selected document")
    }

    private var canUpload: Bool {
        viewModel.selectedFileURL != nil && !viewModel.status.isUploading
    }

    private var uploadAreaIconName: String {
        switch viewModel.status {
        case .ready, .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .uploading: "arrow.triangle.2.circlepath"
        case .idle: "doc.badge.plus"
        }
    }

    private var uploadAreaIconColor: Color {
        switch viewModel.status {
        case .ready, .success: .green
        case .error: .red
        case .uploading: .ragSecondary
        case .idle: .ragPrimary
        }
    }
}

// MARK: - Upload Progress Ring
private struct UploadProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [Color.ragSecondary, Color.ragPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.2), value: progress)

            Text("\(Int(progress * 100))")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: 40, height: 40)
    }
}

private struct UploadSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.ragPrimary.opacity(0.1),
                Color.clear,
                Color.ragSecondary.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
