import Translation
import os

private let logger = Logger(subsystem: "com.lexiword", category: "TranslationService")

// MARK: - Error

enum TranslationError: Error {
    /// The requested language is not supported by the on-device Translation framework.
    case unsupportedLanguagePair
    /// The translation session encountered an error during setup or translation.
    case sessionFailed(Error)
}

// MARK: - Service

/// Wraps Apple's Translation framework for single-word, on-device translation.
///
/// **Lifecycle:**
/// The hosting view must attach `.translationTask(service.configuration)` and call
/// `service.prepareSession(_:)` inside the action closure. `TranslationService`
/// cannot create its own session — the framework vends sessions via that modifier.
///
/// **Language changes:**
/// Call `updateTargetLanguage(_:)` to switch the target. This replaces `configuration`,
/// which the view observes, causing `.translationTask` to fire again with a fresh session.
///
/// **Thread safety:**
/// All methods are `@MainActor`-isolated. `TranslationSession` itself requires the
/// main actor, so the class-level annotation satisfies the framework's requirement.
@MainActor
@Observable
final class TranslationService {

    // Observed by the hosting view through .translationTask(service.configuration).
    // Replacing this value is the signal that a new session is needed.
    private(set) var configuration: TranslationSession.Configuration

    private var session: TranslationSession?

    // LexiWord always OCRs English text, so English is the fixed source language.
    private static let sourceLanguage = Locale.Language(identifier: "en")

    init(targetLanguage: Locale.Language) {
        self.configuration = TranslationSession.Configuration(
            source: Self.sourceLanguage,
            target: targetLanguage
        )
    }

    // MARK: - Session lifecycle

    /// Stores the session provided by the view's `.translationTask` modifier.
    /// Call this inside the modifier's `action` closure:
    /// ```swift
    /// .translationTask(service.configuration) { session in
    ///     service.prepareSession(session)
    /// }
    /// ```
    func prepareSession(_ session: TranslationSession) {
        self.session = session
        logger.debug("Translation session ready for target: \(self.configuration.target?.minimalIdentifier ?? "unknown")")
    }

    /// Switches the target language and invalidates the current session.
    /// The hosting view's `.translationTask` will re-fire with the new configuration
    /// and call `prepareSession` with a fresh session.
    func updateTargetLanguage(_ language: Locale.Language) {
        configuration = TranslationSession.Configuration(
            source: Self.sourceLanguage,
            target: language
        )
        session = nil
    }

    // MARK: - Translation

    /// Translates a word to the given target language using the on-device Translation engine.
    ///
    /// - Parameters:
    ///   - word: The word (or short phrase) to translate.
    ///   - language: The desired target language.
    /// - Returns: The translated string.
    /// - Throws: `TranslationError.unsupportedLanguagePair` if the language is not
    ///   supported by the Translation framework, or `TranslationError.sessionFailed`
    ///   if the session is unavailable or encounters an error.
    func translate(_ word: String, to language: Locale.Language) async throws -> String {
        // Upfront availability check — catches unsupported languages before
        // wasting a round-trip through the session.
        let availability = LanguageAvailability()
        let status = await availability.status(from: Self.sourceLanguage, to: language)

        if status == .unsupported {
            logger.warning("Unsupported language pair: en → \(language.minimalIdentifier)")
            throw TranslationError.unsupportedLanguagePair
        }
        // .supported means models may need to download; the framework handles
        // that transparently when translate() is called. No special case needed.

        guard let session else {
            throw TranslationError.sessionFailed(
                NSError(
                    domain: "TranslationService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "No active session. Attach .translationTask(service.configuration) to the view."]
                )
            )
        }

        do {
            let response = try await session.translate(word)
            logger.info("'\(word)' → '\(response.targetText)' [\(response.targetLanguage.minimalIdentifier)]")
            return response.targetText
        } catch {
            throw TranslationError.sessionFailed(error)
        }
    }
}
