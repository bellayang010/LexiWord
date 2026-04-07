// LexiWord v1.2
// Notion-style iOS vocabulary app — OCR camera → e-reader → personal notebook.
// No backend, no accounts, fully on-device using Apple Vision + Translation frameworks.

import SwiftUI
import SwiftData

@main
struct LexiWordApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: NotebookEntry.self)
    }
}
