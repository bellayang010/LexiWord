import Foundation
import os

private let logger = Logger(subsystem: "com.lexiword", category: "BookReaderViewModel")

// MARK: - WordSelection

/// Identifies a specific word token by its position in the page.
/// Needed because the same word string can appear multiple times.
struct WordSelection: Equatable {
    let paragraphIndex: Int
    let wordIndex: Int
    let word: String
    let sentence: String   // full paragraph text — used as notebook context
}

// MARK: - BookReaderViewModel

@MainActor
@Observable
final class BookReaderViewModel {

    // MARK: - Word sheet state

    var selection: WordSelection?
    var translationResult: String?
    var isTranslating: Bool = false
    var isSheetPresented: Bool = false

    // MARK: - Services

    let translationService: TranslationService

    // MARK: - Init

    init() {
        let langID = UserDefaults.standard.string(forKey: "selectedTargetLanguage")
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        self.translationService = TranslationService(targetLanguage: Locale.Language(identifier: langID))
    }

    // MARK: - Word tap

    func selectWord(_ selection: WordSelection, targetLanguage: Locale.Language) {
        self.selection = selection
        self.translationResult = nil
        self.isTranslating = true
        self.isSheetPresented = true

        Task {
            do {
                let result = try await translationService.translate(selection.word, to: targetLanguage)
                translationResult = result
            } catch TranslationError.unsupportedLanguagePair {
                translationResult = String(localized: "Unavailable for this language.")
            } catch {
                translationResult = String(localized: "Translation failed.")
                logger.error("Translation error: \(error)")
            }
            isTranslating = false
        }
    }

    // MARK: - Sheet dismiss

    /// Called by the sheet's onDismiss — clears state without toggling isSheetPresented.
    func clearSelection() {
        selection = nil
        translationResult = nil
        isTranslating = false
    }
}
