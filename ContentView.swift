//
//  ContentView.swift
//  RagChatApp
//
//  Created by Soumik Bhattacharyya on 24/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var uploadViewModel = UploadViewModel()

    @AppStorage("forceDarkMode") private var forceDarkMode = false
    @State private var isUploadSheetPresented = false
    @State private var isSettingsSheetPresented = false

    var body: some View {
        ChatView(
            viewModel: chatViewModel,
            uploadStatus: uploadViewModel.status,
            showUpload: {
                uploadViewModel.reset()
                isUploadSheetPresented = true
            },
            showSettings: {
                isSettingsSheetPresented = true
            }
        )
        .preferredColorScheme(forceDarkMode ? .dark : nil)
        .sheet(isPresented: $isUploadSheetPresented) {
            UploadModalView(viewModel: uploadViewModel) { filename in
                chatViewModel.documentDidUpload(filename: filename)
            }
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsView(chatViewModel: chatViewModel, forceDarkMode: $forceDarkMode)
        }
    }
}

#Preview {
    ContentView()
}
