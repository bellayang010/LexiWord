import SwiftUI
import SwiftData
import Translation
import Vision
import UIKit
import PhotosUI

// MARK: - ImagePicker (camera)
//
// Must be presented via .fullScreenCover — UIImagePickerController rejects
// sheet presentation silently, which is why .sheet never opened the camera.

private struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.selectedImage = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - PHImagePicker (photo library fallback)

private struct PHImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHImagePicker
        init(_ parent: PHImagePicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                Task { @MainActor in
                    self.parent.selectedImage = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Sheet routing

private enum SheetDestination: Identifiable {
    case languagePicker
    case photoLibrary

    var id: Self { self }
}

// MARK: - OCRView

struct OCRView: View {
    @State private var viewModel = OCRViewModel()

    // Presentation state
    @State private var showCamera = false
    @State private var sheetDestination: SheetDestination?

    // Picker binding; .onChange(of: selectedImage) triggers OCR
    @State private var selectedImage: UIImage?

    @AppStorage("selectedTargetLanguage")
    private var targetLanguageID: String = Locale.current.language.languageCode?.identifier ?? "en"

    // MARK: - Navigation binding
    //
    // Derives a Bool binding from viewModel.readerPage.
    // When the user taps Back in BookReaderView, SwiftUI calls the setter with
    // false → resetScan() clears all state and returns to idle.

    private var showReader: Binding<Bool> {
        Binding(
            get: { viewModel.readerPage != nil },
            set: { if !$0 { viewModel.resetScan() } }
        )
    }

    var body: some View {
        ZStack {
            Color.notionBackground.ignoresSafeArea()

            if viewModel.isProcessing {
                loadingView
            } else {
                idleView
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.isProcessing)
        .navigationTitle(String(localized: "Camera"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        // ── Navigation ────────────────────────────────────────────────────
        // Fires when viewModel.readerPage becomes non-nil after successful OCR.
        // Back button calls the setter, which resets scan state.
        .navigationDestination(isPresented: showReader) {
            if let page = viewModel.readerPage {
                BookReaderView(page: page)
            }
        }
        // ── Camera / photo library ────────────────────────────────────────
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage)
                .ignoresSafeArea()
        }
        .sheet(item: $sheetDestination) { destination in
            switch destination {
            case .languagePicker:
                LanguagePickerView()
                    .onDisappear {
                        viewModel.languageDidChange(to: Locale.Language(identifier: targetLanguageID))
                    }
            case .photoLibrary:
                PHImagePicker(selectedImage: $selectedImage)
            }
        }
        // ── Toast ─────────────────────────────────────────────────────────
        .toast(
            message: viewModel.toastMessage ?? "",
            isShowing: $viewModel.isToastShowing
        )
        // ── Translation session (for language-picker preview) ─────────────
        .translationTask(viewModel.translationService.configuration) { @MainActor session in
            viewModel.translationService.prepareSession(session)
        }
        // ── OCR trigger ───────────────────────────────────────────────────
        // ImagePicker sets selectedImage when the user picks/captures a photo.
        // This onChange fires immediately after the picker sheet dismisses.
        .onChange(of: selectedImage) { _, newImage in
            guard let newImage else { return }
            Task { await viewModel.processImage(newImage) }
        }
    }

    // MARK: - Idle state

    private var idleView: some View {
        Button(action: openCamera) {
            VStack(spacing: 10) {
                Image(systemName: "camera")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(Color.notionText)
                Text(String(localized: "Scan page"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.notionSecondary)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(Color.notionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .notionBorderOverlay(cornerRadius: 8)
        }
    }

    // MARK: - Loading state

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.notionSecondary)
            Text(String(localized: "Reading text…"))
                .font(.subheadline)
                .foregroundStyle(Color.notionSecondary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                sheetDestination = .languagePicker
            } label: {
                Label(String(localized: "Language"), systemImage: "globe")
            }
        }
    }

    // MARK: - Actions

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCamera = true
        } else {
            sheetDestination = .photoLibrary
        }
    }
}

// MARK: - Preview

#Preview("OCR View — idle") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)

    return NavigationStack {
        OCRView()
    }
    .modelContainer(container)
}
