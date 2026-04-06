import SwiftUI
import Vision

// MARK: - WordOverlayView

struct WordOverlayView: View {
    let words: [RecognizedWord]
    let imageSize: CGSize
    let onTranslate: (RecognizedWord) -> Void
    let onAddToNotebook: (RecognizedWord) -> Void

    /// Words whose text key is in this set receive a yellow underline highlight.
    /// Keyed by word text per spec — all tokens sharing the same text underline together.
    /// Cleared automatically on view disappear (session-only, per PRD OCR-11).
    @State private var underlinedWords: Set<String> = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    let rect = CoordinateConverter.convert(
                        observation: word.boundingBox,
                        imageSize: imageSize,
                        viewSize: geometry.size
                    )
                    WordTokenView(
                        word: word,
                        rect: rect,
                        isUnderlined: underlinedWords.contains(word.text),
                        onTranslate: { onTranslate(word) },
                        onUnderline: { underlinedWords.insert(word.text) },
                        onAddToNotebook: { onAddToNotebook(word) }
                    )
                }
            }
            // ZStack shrinks to zero when all children use .position() —
            // explicitly fill the GeometryReader so coordinates are correct.
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onDisappear {
            underlinedWords.removeAll()
        }
    }
}

// MARK: - WordTokenView

private struct WordTokenView: View {
    let word: RecognizedWord
    let rect: CGRect
    let isUnderlined: Bool
    let onTranslate: () -> Void
    let onUnderline: () -> Void
    let onAddToNotebook: () -> Void

    /// Minimum 44×44 pt per Apple HIG / PRD OCR-04.
    private var hitWidth:  CGFloat { max(44, rect.width) }
    private var hitHeight: CGFloat { max(44, rect.height) }

    var body: some View {
        Menu {
            Button(action: onTranslate) {
                Label(String(localized: "Translate"), systemImage: "character.book.closed")
            }
            Button(action: onUnderline) {
                Label(String(localized: "Underline"), systemImage: "underline")
            }
            Button(action: onAddToNotebook) {
                Label(String(localized: "Add to Notebook"), systemImage: "bookmark")
            }
        } label: {
            ZStack(alignment: .bottom) {
                // Transparent fill keeps the hit target interactive.
                Color.clear
                    .contentShape(Rectangle())

                if isUnderlined {
                    Color.yellow.opacity(0.65)
                        .frame(height: 3)
                }
            }
        }
        .frame(width: hitWidth, height: hitHeight)
        // .position() places the view's centre at the given point,
        // relative to the parent ZStack which fills the GeometryReader.
        .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Preview

#Preview("Word Overlay — 3 mock words") {
    // Use equal image and view dimensions so CoordinateConverter applies no
    // aspect-fit scaling — makes the preview positions easy to reason about.
    let imageSize = CGSize(width: 390, height: 600)

    // VNRecognizedTextObservation inherits init(boundingBox:) from
    // VNDetectedObjectObservation. WordOverlayView only ever reads
    // observation.boundingBox, which is set by this init, so the objects
    // are safe for preview use without a live Vision pipeline.
    let obs1 = VNRecognizedTextObservation(boundingBox: CGRect(x: 0.05, y: 0.78, width: 0.25, height: 0.08))
    let obs2 = VNRecognizedTextObservation(boundingBox: CGRect(x: 0.35, y: 0.48, width: 0.30, height: 0.08))
    let obs3 = VNRecognizedTextObservation(boundingBox: CGRect(x: 0.60, y: 0.14, width: 0.28, height: 0.08))

    let mockWords = [
        RecognizedWord(text: "HELLO", boundingBox: obs1, sentence: "HELLO WORLD"),
        RecognizedWord(text: "WORLD", boundingBox: obs2, sentence: "HELLO WORLD"),
        RecognizedWord(text: "SWIFT", boundingBox: obs3, sentence: "SWIFT IS FUN"),
    ]

    ZStack {
        // Stand-in for a captured photo.
        Color(white: 0.92).ignoresSafeArea()

        // Labeled markers show where each word token sits — visible because
        // the WordOverlayView hit targets are transparent.
        GeometryReader { geo in
            ForEach(Array(mockWords.enumerated()), id: \.offset) { _, word in
                let rect = CoordinateConverter.convert(
                    observation: word.boundingBox,
                    imageSize: imageSize,
                    viewSize: geo.size
                )
                Text(word.text)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    .position(x: rect.midX, y: rect.midY)
            }
        }

        // The live overlay — tap any label to see the context menu.
        WordOverlayView(
            words: mockWords,
            imageSize: imageSize,
            onTranslate:     { word in },
            onAddToNotebook: { word in }
        )
    }
    .frame(width: 390, height: 600)
}
