import SwiftUI

struct SettingsView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var forceDarkMode: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    SettingsCard(title: "Conversation", systemImage: "text.bubble") {
                        Button(role: .destructive) {
                            chatViewModel.clearHistory()
                        } label: {
                            Label("Clear conversation history", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    SettingsCard(title: "Appearance", systemImage: "circle.lefthalf.filled") {
                        Toggle(isOn: $forceDarkMode) {
                            Text("Dark mode")
                        }
                    }

                    SettingsCard(title: "About", systemImage: "info.circle") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Version \(viewModel.appVersion)")
                                .font(.subheadline)
                            Button {
                                if let url = URL(string: "https://developer.apple.com/design/human-interface-guidelines/") {
                                    openURL(url)
                                }
                            } label: {
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppSettingsBackground())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16, material: .regular)
    }
}

private struct AppSettingsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.ragPrimary.opacity(0.12),
                Color(.systemBackground),
                Color.ragSecondary.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
