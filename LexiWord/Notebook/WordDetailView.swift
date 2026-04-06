import SwiftUI
import SwiftData

// MARK: - WordDetailView

struct WordDetailView: View {
    let entry: NotebookEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var dictionaryResult: DictionaryResult?
    @State private var showRemoveAlert = false

    private let preloadedResult: DictionaryResult?

    init(entry: NotebookEntry, preloadedResult: DictionaryResult? = nil) {
        self.entry = entry
        self.preloadedResult = preloadedResult
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                wordHeading
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                Color.notionBorder.frame(height: 1)

                definitionSection
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                contextSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)

                footerSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .background(Color.notionBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.notionBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            dictionaryResult = preloadedResult ?? DictionaryService().lookup(word: entry.word)
        }
        .alert(String(localized: "Remove word"), isPresented: $showRemoveAlert) {
            Button(String(localized: "Remove"), role: .destructive, action: remove)
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This word will be removed from your notebook."))
        }
    }

    // MARK: - Word heading

    private var wordHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.word)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.notionText)

            if let phonetic = dictionaryResult?.phoneticSpelling {
                Text(phonetic)
                    .font(.system(size: 16))
                    .foregroundStyle(.notionSecondary)
            }
        }
    }

    // MARK: - Definition section

    @ViewBuilder
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("DEFINITION")

            if let result = dictionaryResult {
                if result.hasContent {
                    VStack(alignment: .leading, spacing: 10) {
                        if let pos = result.partOfSpeech {
                            posTag(pos)
                        }
                        if let definition = result.definition {
                            Text(definition)
                                .font(.system(size: 17))
                                .foregroundStyle(.notionText)
                                .lineSpacing(17 * 0.7)  // ≈ 1.7× line height
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Text(String(localized: "No definition found."))
                        .font(.system(size: 17))
                        .italic()
                        .foregroundStyle(.notionSecondary)
                }
            } else {
                ProgressView()
                    .tint(.notionSecondary)
            }
        }
    }

    // MARK: - Context section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("FROM YOUR SCAN")
            sentenceBlock
        }
    }

    private var sentenceBlock: some View {
        HStack(spacing: 0) {
            // 3px left accent border
            Color.notionBorder
                .frame(width: 3)

            Text(entry.sentence)
                .font(.custom("Georgia", size: 16))
                .italic()
                .foregroundStyle(.notionText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(red: 248 / 255, green: 247 / 255, blue: 245 / 255))
    }

    // MARK: - Footer section

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button(action: openDictionaryCom) {
                Text(String(localized: "Study on Dictionary.com →"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 35 / 255, green: 131 / 255, blue: 226 / 255))
            }
            .buttonStyle(.plain)

            Button {
                showRemoveAlert = true
            } label: {
                Text(String(localized: "Remove word"))
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 235 / 255, green: 87 / 255, blue: 87 / 255))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Subviews

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.notionSecondary)
            .kerning(0.6)
    }

    private func posTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.notionSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.notionSurface, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Actions

    private func remove() {
        modelContext.delete(entry)
        dismiss()
    }

    private func openDictionaryCom() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.dictionary.com"
        components.path = "/browse/\(entry.word.lowercased())"
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Previews

#Preview("Definition found") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)
    let entry = NotebookEntry(
        word: "ephemeral",
        sentence: "The ephemeral beauty of cherry blossoms draws crowds every spring."
    )
    container.mainContext.insert(entry)

    return NavigationStack {
        WordDetailView(
            entry: entry,
            preloadedResult: DictionaryResult(
                phoneticSpelling: "iˈfem(ə)rəl",
                partOfSpeech: "adjective",
                definition: "1. Lasting for a very short time.\n\"fashions are ephemeral\"\n\n2. (chiefly of plants) Having a very short life cycle."
            )
        )
    }
    .modelContainer(container)
}

#Preview("No definition found") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)
    let entry = NotebookEntry(
        word: "zymurgy",
        sentence: "The zymurgy lab at the university produced award-winning craft ales."
    )
    container.mainContext.insert(entry)

    return NavigationStack {
        WordDetailView(entry: entry, preloadedResult: DictionaryResult())
    }
    .modelContainer(container)
}
