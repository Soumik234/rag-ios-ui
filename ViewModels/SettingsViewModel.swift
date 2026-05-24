import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    let backendURL = APIConstants.baseURL.absoluteString
    let appVersion: String

    init(bundle: Bundle = .main) {
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, build) {
        case let (shortVersion?, build?):
            appVersion = "\(shortVersion) (\(build))"
        case let (shortVersion?, nil):
            appVersion = shortVersion
        case let (nil, build?):
            appVersion = build
        case (nil, nil):
            appVersion = "1.0"
        }
    }
}
