import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                OCRView()
            }
            .tabItem {
                Label(String(localized: "Camera"), systemImage: "camera")
            }

            NavigationStack {
                NotebookView()
            }
            .tabItem {
                Label(String(localized: "Notebook"), systemImage: "book.closed")
            }
        }
        // Global accent: near-black keeps the Notion monochrome feel
        // (tab selection, navigation links, focussed controls).
        .tint(.notionText)
    }
}
