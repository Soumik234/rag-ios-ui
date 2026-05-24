import Foundation

enum UploadStatus: Equatable {
    case idle
    case ready(filename: String, fileSize: String)
    case uploading(progress: Double)
    case success(String)
    case error(String)

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }
}
