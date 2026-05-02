import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct AIAssistantView: View {
    @StateObject private var vm = AIAssistantViewModel()
    @EnvironmentObject var dataService: FirebaseDataService

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var selectedLibraryImage: UIImage?
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var showPhotoLibraryPicker = false
    @State private var showAttachMenu = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                Divider()
                inputBar
            }
        }
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .overlay(confirmationOverlay)
        .onChange(of: selectedPhoto) { item in
            Task {
                do {
                    guard let item else { return }
                    guard let data = try await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        vm.errorMessage = "Couldn't load selected photo. Try using Open Photo Library."
                        return
                    }
                    vm.sendImage(image, dataService: dataService)
                } catch {
                    vm.errorMessage = "Photo selection failed: \(error.localizedDescription)"
                }
            }
        }
        .onChange(of: capturedImage) { image in
            guard let image else { return }
            vm.sendImage(image, dataService: dataService)
        }
        .onChange(of: selectedLibraryImage) { image in
            guard let image else { return }
            vm.sendImage(image, dataService: dataService)
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                vm.sendPDF(url: url, dataService: dataService)
            case .failure(let error):
                vm.errorMessage = "File import failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            LibraryPicker(image: $selectedLibraryImage)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .task {
            await vm.requestPermissionsIfNeeded()
        }
        .onDisappear {
            vm.cancelCurrentRequest()
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { msg in
                        ChatBubbleView(message: msg)
                            .id(msg.id)
                    }
                    if vm.isLoading {
                        HStack {
                            TypingIndicatorView()
                            Spacer()
                            Button {
                                vm.cancelCurrentRequest()
                            } label: {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.trailing, AppTheme.padding)
                        }
                        .id("typing")
                    }
                    if !vm.isLoading {
                        suggestionChips
                            .id("chips")
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onChange(of: vm.messages.count) { _ in
                withAnimation {
                    if vm.isLoading {
                        proxy.scrollTo("typing")
                    } else if let lastId = vm.messages.last?.id {
                        proxy.scrollTo(lastId)
                    }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading { withAnimation { proxy.scrollTo("typing") } }
            }
        }
    }

    private var suggestionChips: some View {
        let chips = vm.currentSuggestions
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { chip in
                    Button {
                        vm.inputText = chip
                        vm.send(dataService: dataService)
                    } label: {
                        Text(chip)
                            .font(.caption)
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, AppTheme.padding)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                attachButton

                TextField("Ask anything about your cafe...", text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($inputFocused)
                    .onSubmit { vm.send(dataService: dataService) }

                micOrSendButton
            }
            .padding(.horizontal, AppTheme.padding)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var attachButton: some View {
        Menu {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    vm.errorMessage = "Camera is not available on this device/simulator."
                }
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
            }
            Button {
                showPhotoLibraryPicker = true
            } label: {
                Label("Open Photo Library", systemImage: "photo.on.rectangle")
            }
            Button {
                showDocumentPicker = true
            } label: {
                Label("Import PDF Invoice", systemImage: "doc.fill")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppTheme.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground))
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var micOrSendButton: some View {
        if vm.inputText.isEmpty && !vm.voiceManager.isListening {
            Button {
                inputFocused = false
                vm.toggleVoiceInput(dataService: dataService)
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(vm.voiceManager.permissionGranted ? AppTheme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Circle())
            }
            .disabled(!vm.voiceManager.permissionGranted)
        } else if vm.voiceManager.isListening {
            Button {
                vm.toggleVoiceInput(dataService: dataService)
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(LinearGradient(colors: [.red], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Circle())
                    .scaleEffect(vm.voiceManager.isListening ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: vm.voiceManager.isListening)
            }
        } else {
            Button {
                vm.send(dataService: dataService)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.primaryGradient)
                    .clipShape(Circle())
            }
            .disabled(vm.isLoading)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                vm.clearConversation()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.primary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                vm.toggleSpeech()
            } label: {
                Image(systemName: vm.isSpeechEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundColor(vm.isSpeechEnabled ? AppTheme.primary : .secondary)
            }
        }
    }

    // MARK: - Confirmation overlay

    @ViewBuilder
    private var confirmationOverlay: some View {
        if let confirmation = vm.pendingConfirmation {
            ZStack {
                Color.black.opacity(0.4)
                    .onTapGesture {}

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.warning)

                        Text(confirmation.title)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        Text(confirmation.detail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            confirmation.onDeny()
                            vm.pendingConfirmation = nil
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(AppTheme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))

                        Button("Confirm") {
                            confirmation.onConfirm()
                            vm.pendingConfirmation = nil
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.primaryGradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 20)
                .padding(.horizontal, 32)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.35), value: vm.pendingConfirmation != nil)
        }
    }
}

// MARK: - Voice transcript banner

private struct VoiceTranscriptBanner: View {
    let transcript: String

    var body: some View {
        if !transcript.isEmpty {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(AppTheme.primary)
                Text(transcript)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
            }
            .padding(.horizontal, AppTheme.padding)
            .padding(.vertical, 8)
            .background(AppTheme.accent)
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private struct LibraryPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: LibraryPicker

        init(_ parent: LibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
