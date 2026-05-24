import Foundation
import Combine

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var status: UploadStatus = .idle
    @Published var errorMessage: String?

    private let networkService: NetworkService
    private let maxFileSize = 50 * 1024 * 1024

    init(networkService: NetworkService? = nil) {
        self.networkService = networkService ?? .shared
    }

    func selectFile(_ url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize ?? 0

            guard fileSize <= maxFileSize else {
                selectedFileURL = nil
                status = .error("PDF files must be smaller than 50 MB.")
                return
            }

            selectedFileURL = url
            status = .ready(filename: url.lastPathComponent, fileSize: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
        } catch {
            selectedFileURL = nil
            status = .error("The selected file could not be read.")
        }
    }

    @discardableResult
    func uploadDocument() async -> String? {
        guard let selectedFileURL else {
            status = .error("Choose a PDF before uploading.")
            return nil
        }

        let didStartAccessing = selectedFileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                selectedFileURL.stopAccessingSecurityScopedResource()
            }
        }

        status = .uploading(progress: 0)

        do {
            let response = try await networkService.uploadDocument(fileURL: selectedFileURL) { [weak self] progress in
                self?.status = .uploading(progress: progress)
            }
            status = .success("Uploaded \(response.filename)")
            return response.filename
        } catch {
            let message = error.localizedDescription
            status = .error(message)
            errorMessage = message
            return nil
        }
    }

    func reset() {
        selectedFileURL = nil
        status = .idle
        errorMessage = nil
    }
}
