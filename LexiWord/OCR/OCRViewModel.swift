// Updated: makePage() now clusters Vision observations by vertical midpoint (2% threshold),
// sorts each line group left-to-right, joins across observation blocks, and detects paragraph
// breaks at inter-line gaps > 1.5× average line height. Fixes truncated OCR text on curved pages.

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

    /// Reconstructs a BookPage from raw Vision observations.
    ///
    /// Vision may split a single visual line into multiple short
    /// VNRecognizedTextObservation blocks (especially on curved or angled pages).
    /// This method:
    ///   1. Collects unique observations via object identity.
    ///   2. Sorts top-to-bottom (Vision uses bottom-left origin, so descending midY = top first).
    ///   3. Groups observations whose vertical midpoints are within 2 % of image
    ///      height of each other into one reconstructed line.
    ///   4. Within each group, sorts left-to-right and joins texts with a space.
    ///   5. Detects paragraph breaks as inter-line gaps > 1.5 × the average line height.
    private func makePage(from words: [RecognizedWord]) -> BookPage {
        guard !words.isEmpty else { return BookPage(paragraphs: []) }

        // 1. Map each unique observation → its text, preserving the first-seen text.
        //    word.sentence = full text of the OCR observation this word came from.
        var obsText: [ObjectIdentifier: String] = [:]
        var obsObjects: [ObjectIdentifier: VNRecognizedTextObservation] = [:]
        for word in words {
            let key = ObjectIdentifier(word.boundingBox)
            if obsText[key] == nil {
                obsText[key]    = word.sentence
                obsObjects[key] = word.boundingBox
            }
        }

        // 2. Sort all observations top-to-bottom.
        let sorted = obsObjects.values.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        // 3. Cluster into visual lines (2 % threshold in normalized coords).
        let lineThreshold: CGFloat = 0.02
        var lineGroups: [[VNRecognizedTextObservation]] = []

        for obs in sorted {
            let midY = obs.boundingBox.midY
            if !lineGroups.isEmpty,
               let ref = lineGroups[lineGroups.count - 1].first,
               abs(ref.boundingBox.midY - midY) < lineThreshold {
                lineGroups[lineGroups.count - 1].append(obs)
            } else {
                lineGroups.append([obs])
            }
        }

        // 4. Sort each cluster left-to-right, then build line text strings.
        lineGroups = lineGroups.map { $0.sorted { $0.boundingBox.minX < $1.boundingBox.minX } }

        let lineTexts: [String] = lineGroups.map { group in
            group.compactMap { obsText[ObjectIdentifier($0)] }.joined(separator: " ")
        }

        // 5. Average line height (normalized). Fallback 0.04 for degenerate input.
        let lineHeights: [CGFloat] = lineGroups.map { group in
            let top    = group.map { $0.boundingBox.maxY }.max() ?? 0
            let bottom = group.map { $0.boundingBox.minY }.min() ?? 0
            return max(top - bottom, 0)
        }
        let avgLineHeight = lineHeights.isEmpty
            ? 0.04
            : lineHeights.reduce(0, +) / CGFloat(lineHeights.count)

        // 6. Split into paragraphs wherever the vertical gap between consecutive
        //    lines exceeds 1.5 × the average line height.
        var paragraphWordArrays: [[String]] = []
        var currentLines: [String] = []

        for i in lineTexts.indices {
            currentLines.append(lineTexts[i])

            if i < lineGroups.count - 1 {
                // In Vision coords Y increases upward, so:
                //   current line bottom = min(minY) of its observations
                //   next line top       = max(maxY) of its observations
                let currentBottom = lineGroups[i].map { $0.boundingBox.minY }.min() ?? 0
                let nextTop       = lineGroups[i + 1].map { $0.boundingBox.maxY }.max() ?? 0
                let gap           = currentBottom - nextTop   // positive = real gap

                if gap > avgLineHeight * 1.5 {
                    let paraWords = currentLines
                        .joined(separator: " ")
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                    paragraphWordArrays.append(paraWords)
                    currentLines = []
                }
            }
        }

        // Flush the last paragraph.
        if !currentLines.isEmpty {
            let paraWords = currentLines
                .joined(separator: " ")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
            paragraphWordArrays.append(paraWords)
        }

        logger.info("makePage: \(lineGroups.count) visual lines → \(paragraphWordArrays.count) paragraphs")
        return BookPage(paragraphs: paragraphWordArrays)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        isToastShowing = true
    }
}
