import Foundation
import SwiftUI
import SwiftData
import Vision
import os

private let logger = Logger(subsystem: "com.lexiword", category: "OCRViewModel")

// MARK: - Translation overlay state

struct TranslationOverlay {
    let word: RecognizedWord
    let result: String
}

// MARK: - OCRViewModel

@MainActor
@Observable
class OCRViewModel {

    // MARK: - State

    var capturedImage: UIImage?
    var recognizedWords: [RecognizedWord] = []

    /// Set on successful OCR. Observed by OCRView to push BookReaderView.
    /// Reset to nil when the user navigates back (via the navigation binding setter).
    var readerPage: BookPage?

    /// True while OCRService.recognize is running.
    var isProcessing: Bool = false

    var toastMessage: String?
    var isToastShowing: Bool = false

    // MARK: - Services

    let translationService: TranslationService
    private let ocrService = OCRService()

    // MARK: - Init

    init() {
        let initialLanguage = Locale.Language(
            identifier: UserDefaults.standard.string(forKey: "selectedTargetLanguage")
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
        )
        self.translationService = TranslationService(targetLanguage: initialLanguage)
    }

    // MARK: - OCR

    func processImage(_ image: UIImage) async {
        capturedImage = image
        recognizedWords = []
        readerPage = nil
        isProcessing = true

        defer { isProcessing = false }

        do {
            let words = try await ocrService.recognize(image: image)
            recognizedWords = words

            // Debug: confirm OCR ran and what it found
            print("[OCR] words found: \(words.count)")
            print("[OCR] preview: \(words.prefix(20).map(\.text).joined(separator: " "))")

            let page = makePage(from: words)
            logger.info("OCR complete: \(words.count) words, \(page.paragraphs.count) paragraphs")
            readerPage = page          // ← triggers .navigationDestination in OCRView

        } catch OCRError.noTextFound {
            capturedImage = nil
            print("[OCR] no text found")
            showToast(String(localized: "No text found in this photo."))
        } catch {
            capturedImage = nil
            print("[OCR] error: \(error)")
            showToast(String(localized: "OCR failed. Please try again."))
            logger.error("OCR error: \(error)")
        }
    }

    /// Resets all scan state. Called when the user navigates back from BookReaderView
    /// (via the navigationDestination binding setter) or taps Rescan.
    func resetScan() {
        capturedImage = nil
        recognizedWords = []
        readerPage = nil
    }

    // MARK: - Language

    func languageDidChange(to language: Locale.Language) {
        translationService.updateTargetLanguage(language)
    }

    // MARK: - Private

    /// Converts a flat list of recognised words into a BookPage.
    /// Each unique OCR line (sentence) becomes one paragraph, preserving document order.
    private func makePage(from words: [RecognizedWord]) -> BookPage {
        var seen = Set<String>()
        var orderedSentences: [String] = []
        for word in words {
            if seen.insert(word.sentence).inserted {
                orderedSentences.append(word.sentence)
            }
        }
        let paragraphs = orderedSentences.map {
            $0.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        }
        return BookPage(paragraphs: paragraphs)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        isToastShowing = true
    }
}
