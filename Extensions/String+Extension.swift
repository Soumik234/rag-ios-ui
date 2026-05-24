import Foundation

extension String {
    var trimmedForSubmission: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
