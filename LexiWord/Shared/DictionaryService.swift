import UIKit
import os

private let logger = Logger(subsystem: "com.lexiword", category: "DictionaryService")

struct DictionaryResult {
    var phoneticSpelling: String?
    var partOfSpeech: String?
    var definition: String?

    var hasContent: Bool {
        phoneticSpelling != nil || partOfSpeech != nil || definition != nil
    }
}

struct DictionaryService {

    func lookup(word: String) -> DictionaryResult {
        guard UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word) else {
            return DictionaryResult()
        }
        guard let raw = rawDefinition(for: word) else {
            logger.warning("dictionaryHasDefinition returned true but DCSCopyTextDefinition returned nil for '\(word)'")
            return DictionaryResult()
        }
        return parse(raw: raw)
    }

    // MARK: - Private

    /// Loads DCSCopyTextDefinition from the private DictionaryServices dylib.
    /// DictionaryServices is a private framework on iOS — every step guards against nil.
    private func rawDefinition(for word: String) -> String? {
        let path = "/System/Library/PrivateFrameworks/DictionaryServices.framework/DictionaryServices"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            logger.warning("Could not open DictionaryServices: \(String(cString: dlerror()))")
            return nil
        }
        defer { dlclose(handle) }

        typealias DCSFunc = @convention(c) (AnyObject?, CFString, CFRange) -> Unmanaged<CFString>?
        guard let sym = dlsym(handle, "DCSCopyTextDefinition") else {
            logger.warning("DCSCopyTextDefinition symbol not found")
            return nil
        }
        let dcs = unsafeBitCast(sym, to: DCSFunc.self)

        let cfWord = word as CFString
        let range = CFRangeMake(0, CFStringGetLength(cfWord))
        guard let unmanaged = dcs(nil, cfWord, range) else { return nil }
        return unmanaged.takeRetainedValue() as String
    }

    /// Parses the raw DCSCopyTextDefinition string into structured fields.
    /// The format is not officially documented and varies by system version.
    /// Example: "e·phem·er·al | iˈfem(ə)rəl | adjective\n1. lasting for a very short time…"
    /// All fields fall back to nil if the format doesn't match expectations.
    private func parse(raw: String) -> DictionaryResult {
        let segments = raw.components(separatedBy: " | ")

        var phonetic: String?
        var partOfSpeech: String?
        var definition: String?

        if segments.count >= 2 {
            let candidate = segments[1].trimmingCharacters(in: .whitespaces)
            if !candidate.isEmpty { phonetic = candidate }
        }

        if segments.count >= 3 {
            let body = segments[2]
            let lines = body.components(separatedBy: "\n")

            let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
            if !firstLine.isEmpty { partOfSpeech = firstLine }

            let remaining = lines.dropFirst()
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty { definition = remaining }
        }

        // Fallback: surface the raw text as the definition so the caller always
        // gets something rather than silently returning empty.
        if definition == nil {
            let fallback = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fallback.isEmpty { definition = fallback }
        }

        return DictionaryResult(phoneticSpelling: phonetic, partOfSpeech: partOfSpeech, definition: definition)
    }
}
