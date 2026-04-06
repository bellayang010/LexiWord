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
