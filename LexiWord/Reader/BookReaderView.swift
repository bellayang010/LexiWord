import SwiftUI
import SwiftData
import Translation
import UIKit

// MARK: - ActivityViewController

/// Wraps UIActivityViewController for SwiftUI sheet presentation.
private struct ActivityViewController: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - FlowLayout

/// Wraps child views left-to-right, breaking to a new line when the available
/// width is exhausted. Mirrors how typesetting engines handle inline content.
private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                height += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
        height += lineHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Font size steps

private enum ReaderFontSize: Int, CaseIterable {
    case small  = 0
    case medium = 1
    case large  = 2

    var pointSize: CGFloat {
        switch self {
        case .small:  15
        case .medium: 17
        case .large:  20
        }
    }

    var next: ReaderFontSize {
        ReaderFontSize(rawValue: (rawValue + 1) % ReaderFontSize.allCases.count) ?? .medium
    }

    var accessibilityLabel: String {
        switch self {
        case .small:  "Small"
        case .medium: "Default"
        case .large:  "Large"
        }
    }
}

// MARK: - BookReaderView

struct BookReaderView: View {
    let page: BookPage

    @State private var viewModel = BookReaderViewModel()
    @State private var showShareSheet = false

    /// Stored as Int to avoid @AppStorage / @Observable _varName collision.
    @AppStorage("readerFontSize") private var fontSizeRaw: Int = ReaderFontSize.medium.rawValue
    @AppStorage("selectedTargetLanguage")
    private var targetLanguageID: String = Locale.current.language.languageCode?.identifier ?? "en"

    @Environment(\.modelContext) private var modelContext

    private var fontSize: CGFloat {
        ReaderFontSize(rawValue: fontSizeRaw)?.pointSize ?? 17
    }

    /// Added between wrapped lines. fontSize × 0.82 ≈ 1.8× total line-height.
    private var lineSpacing: CGFloat { fontSize * 0.82 }

    var body: some View {
        ZStack(alignment: .topTrailing) {

            // ── Scrollable content ──────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(page.paragraphs.indices, id: \.self) { pi in
                        paragraphView(paragraphIndex: pi, words: page.paragraphs[pi])
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }

            // ── Aa font-size toggle — fixed to top-right of content area ────
            Button(action: cycleFontSize) {
                Text("Aa")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.notionSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.notionBackground)
                    .notionBorderOverlay(cornerRadius: 6)
            }
            .padding(.top, 12)
            .padding(.trailing, 20)
            .accessibilityLabel(
                "Font size: \(ReaderFontSize(rawValue: fontSizeRaw)?.accessibilityLabel ?? "Default")"
            )
        }
        .background(Color.notionBackground.ignoresSafeArea())
        // ── Navigation bar ──────────────────────────────────────────────────
        .toolbar {
            // Title: 15pt semibold, centered
            ToolbarItem(placement: .principal) {
                Text(String(localized: "Scanned Page"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.notionText)
            }
            // Share icon: UIActivityViewController
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .fontWeight(.regular)
                }
            }
        }
        .toolbarBackground(Color.notionBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // Nav-bar bottom border via UIKit appearance — most reliable approach
        .onAppear(perform: applyNavBarBorder)
        .onDisappear(perform: restoreNavBarBorder)
        // ── Sheets ──────────────────────────────────────────────────────────
        // Word detail sheet
        .sheet(
            isPresented: $viewModel.isSheetPresented,
            onDismiss: { viewModel.clearSelection() }
        ) {
            wordSheet
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.notionBackground)
        }
        // Share sheet
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(text: page.rawText)
        }
        // Translation session
        .translationTask(viewModel.translationService.configuration) { @MainActor session in
            viewModel.translationService.prepareSession(session)
        }
    }

    // MARK: - Paragraph

    @ViewBuilder
    private func paragraphView(paragraphIndex: Int, words: [String]) -> some View {
        let sentence = words.joined(separator: " ")

        FlowLayout(horizontalSpacing: 5, lineSpacing: lineSpacing) {
            ForEach(words.indices, id: \.self) { wi in
                let word = words[wi]
                let sel = WordSelection(
                    paragraphIndex: paragraphIndex,
                    wordIndex: wi,
                    word: word,
                    sentence: sentence
                )
                let isSelected = viewModel.selection == sel

                Text(word)
                    .font(.custom("Georgia", size: fontSize))
                    .foregroundStyle(.notionText)
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ? Color.notionSurface : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectWord(
                            sel,
                            targetLanguage: Locale.Language(identifier: targetLanguageID)
                        )
                    }
                    .animation(.easeOut(duration: 0.15), value: isSelected)
            }
        }
    }

    // MARK: - Word sheet

    private var wordSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Word title
            Text(viewModel.selection?.word ?? "")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.notionText)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Divider
            Color.notionBorder
                .frame(height: 1)

            // Translation — secondary while loading, text when ready
            Group {
                if viewModel.isTranslating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.notionSecondary)
                        Text(String(localized: "Translating…"))
                            .font(.system(size: 16))
                            .foregroundStyle(.notionSecondary)
                    }
                } else {
                    Text(viewModel.translationResult ?? "—")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            viewModel.translationResult != nil
                                ? Color.notionText
                                : Color.notionSecondary
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Add to Notebook
            Button(action: addToNotebook) {
                Text("— \(String(localized: "Add to Notebook"))")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 35 / 255, green: 131 / 255, blue: 226 / 255))
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func cycleFontSize() {
        let current = ReaderFontSize(rawValue: fontSizeRaw) ?? .medium
        fontSizeRaw = current.next.rawValue
    }

    private func addToNotebook() {
        guard let sel = viewModel.selection else { return }
        let entry = NotebookEntry(word: sel.word, sentence: sel.sentence)
        modelContext.insert(entry)
        viewModel.isSheetPresented = false
    }

    // MARK: - Nav bar appearance

    /// Sets a 1pt notionBorder (#E9E9E7) shadow under the navigation bar.
    /// Scoped to this view via onAppear / onDisappear so it doesn't leak.
    private func applyNavBarBorder() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.notionBackground)
        appearance.shadowColor = UIColor(
            red: 233 / 255, green: 233 / 255, blue: 231 / 255, alpha: 1
        )
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    private func restoreNavBarBorder() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = nil
    }
}

// MARK: - Preview

#Preview("Book Reader — mock page") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: NotebookEntry.self, configurations: config)

    return NavigationStack {
        BookReaderView(page: BookPage.mock())
    }
    .modelContainer(container)
}
