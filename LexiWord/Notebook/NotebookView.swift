import SwiftUI
import SwiftData

// MARK: - NotebookView

struct NotebookView: View {
    @Query(sort: \NotebookEntry.dateAdded, order: .reverse)
    private var entries: [NotebookEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText: String = ""

    private var filteredEntries: [NotebookEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                if entries.isEmpty {
                    emptyStateNoWords
                } else if filteredEntries.isEmpty {
                    emptyStateNoResults
                } else {
                    cardList
                }
            }
        }
        .background(Color.notionBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: NotebookEntry.self) { entry in
            WordDetailView(entry: entry)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Notebook"))
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.notionText)
            Text(wordCountLabel)
                .font(.system(size: 14))
                .foregroundStyle(.notionSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var wordCountLabel: String {
        let n = entries.count
        return n == 1
            ? String(localized: "1 word")
            : String(localized: "\(n) words")
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.notionSecondary)

            TextField(String(localized: "Search words"), text: $searchText)
                .font(.system(size: 15))
                .foregroundStyle(.notionText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.notionSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.notionSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Card list

    private var cardList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredEntries) { entry in
                EntryCard(entry: entry, onDelete: { delete(entry) })
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Empty states

    private var emptyStateNoWords: some View {
        emptyState(
            icon: "book.closed",
            title: String(localized: "No words yet"),
            subtitle: String(localized: "Scan a page and tap any word to save it.")
        )
    }

    private var emptyStateNoResults: some View {
        emptyState(
            icon: "magnifyingglass",
            title: String(localized: "No results"),
            subtitle: String(format: String(localized: "No words match \"%@\"."), searchText)
        )
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.notionSecondary)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.notionText)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.notionSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 40)
    }

    // MARK: - Delete

    private func delete(_ entry: NotebookEntry) {
        modelContext.delete(entry)
    }
}

// MARK: - EntryCard

private struct EntryCard: View {
    let entry: NotebookEntry
    let onDelete: () -> Void

    @State private var swipeOffset: CGFloat = 0
    private let maxSwipe: CGFloat = 80

    var body: some View {
        cardContent
            // Card slides left; delete background grows from trailing edge behind it
            .offset(x: swipeOffset)
            .background(alignment: .trailing) {
                deleteReveal
                    .frame(width: max(-swipeOffset, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .gesture(swipeGesture)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label(String(localized: "Delete"), systemImage: "trash")
                }
            }
    }

    // MARK: Card face

    private var cardContent: some View {
        NavigationLink(value: entry) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(entry.word)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.notionText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(entry.dateAdded, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 12))
                        .foregroundStyle(.notionSecondary)
                        .fixedSize()
                }

                Text(entry.sentence)
                    .font(.system(size: 14))
                    .foregroundStyle(.notionSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color.notionBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .notionBorderOverlay(cornerRadius: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Swipe delete reveal

    private var deleteReveal: some View {
        Button {
            onDelete()
            withAnimation(.spring(response: 0.3)) { swipeOffset = 0 }
        } label: {
            ZStack {
                Color.red
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    // Fade icon in once there is enough room to show it
                    .opacity(-swipeOffset > maxSwipe * 0.5 ? 1 : 0)
                    .animation(.easeIn(duration: 0.1), value: swipeOffset)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Drag gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                if dx < 0 {
                    // Swiping left — clamp at maxSwipe
                    swipeOffset = max(dx, -maxSwipe)
                } else if swipeOffset < 0 {
                    // Swiping right — close
                    swipeOffset = min(0, swipeOffset + dx)
                }
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    swipeOffset = swipeOffset < -(maxSwipe / 2) ? -maxSwipe : 0
                }
            }
    }
}

// MARK: - Preview

#Preview("Notebook — 5 entries") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)

    let entries: [NotebookEntry] = [
        NotebookEntry(word: "ephemeral",    sentence: "The ephemeral beauty of cherry blossoms draws crowds every spring."),
        NotebookEntry(word: "ubiquitous",   sentence: "Smartphones have become ubiquitous in modern daily life."),
        NotebookEntry(word: "serendipity",  sentence: "It was pure serendipity that brought them together at the conference."),
        NotebookEntry(word: "melancholy",   sentence: "A deep melancholy settled over the town after the factory closed."),
        NotebookEntry(word: "resilience",   sentence: "Her resilience in the face of adversity inspired everyone around her."),
    ]
    entries.forEach { container.mainContext.insert($0) }

    return NavigationStack {
        NotebookView()
    }
    .modelContainer(container)
}

#Preview("Notebook — empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)

    return NavigationStack {
        NotebookView()
    }
    .modelContainer(container)
}
