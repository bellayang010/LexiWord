import Foundation
import os

private let logger = Logger(subsystem: "com.lexiword", category: "NotebookViewModel")

@MainActor
@Observable
class NotebookViewModel {
    var searchText: String = ""

    func filtered(_ entries: [NotebookEntry]) -> [NotebookEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }
    }
}
