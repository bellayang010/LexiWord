import Foundation
import SwiftData

@Model
class NotebookEntry {
    var id: UUID
    var word: String
    var sentence: String
    var dateAdded: Date

    init(word: String, sentence: String) {
        self.id = UUID()
        self.word = word
        self.sentence = sentence
        self.dateAdded = Date()
    }

    static func mock() -> NotebookEntry {
        NotebookEntry(
            word: "ephemeral",
            sentence: "The ephemeral beauty of cherry blossoms draws crowds every spring."
        )
    }
}
