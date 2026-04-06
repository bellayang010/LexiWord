import XCTest
import UIKit
@testable import LexiWord

final class OCRServiceTests: XCTestCase {

    private let service = OCRService()

    // MARK: - Helpers

    /// Renders `text` as 72-pt bold black on a white background.
    /// Large font + high contrast gives Vision's .accurate pipeline the
    /// best chance of clean recognition in the simulator test environment.
    private func makeImage(text: String, size: CGSize = CGSize(width: 600, height: 120)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 72),
                .foregroundColor: UIColor.black,
            ]
            let nsText = text as NSString
            let textSize = nsText.size(withAttributes: attrs)
            let origin = CGPoint(
                x: (size.width  - textSize.width)  / 2,
                y: (size.height - textSize.height) / 2
            )
            nsText.draw(at: origin, withAttributes: attrs)
        }
    }

    /// Blank white image — no text to find.
    private func makeBlankImage(size: CGSize = CGSize(width: 300, height: 150)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Recognition tests

    func testRecognizesWordsFromKnownImage() async throws {
        let image = makeImage(text: "HELLO WORLD")
        let words = try await service.recognize(image: image)
        let texts = words.map { $0.text.uppercased() }
        XCTAssertTrue(texts.contains("HELLO"), "Expected HELLO in \(texts)")
        XCTAssertTrue(texts.contains("WORLD"), "Expected WORLD in \(texts)")
    }

    func testBlankImageThrowsNoTextFound() async {
        let image = makeBlankImage()
        do {
            _ = try await service.recognize(image: image)
            XCTFail("Expected OCRError.noTextFound to be thrown")
        } catch OCRError.noTextFound {
            // expected — pass
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Sentence tests

    func testAllWordsOnOneLineShareTheSameSentence() async throws {
        let image = makeImage(text: "QUICK BROWN FOX")
        let words = try await service.recognize(image: image)

        // Guard: we need at least some words recognized to make this test meaningful.
        try XCTSkipIf(words.isEmpty, "OCR returned no words — skipping sentence-grouping test")

        let uniqueSentences = Set(words.map { $0.sentence })
        XCTAssertEqual(
            uniqueSentences.count, 1,
            "All tokens from a single OCR line should carry the same sentence. Got: \(uniqueSentences)"
        )
    }

    func testSentenceMatchesFullLineNotJustTheWord() async throws {
        let image = makeImage(text: "SWIFT IS FUN")
        let words = try await service.recognize(image: image)

        try XCTSkipIf(words.isEmpty, "OCR returned no words — skipping")

        for word in words {
            XCTAssertTrue(
                word.sentence.uppercased().contains(word.text.uppercased()),
                "Word '\(word.text)' should be contained in its sentence '\(word.sentence)'"
            )
            // The sentence must be longer than (or equal to) the word itself
            // because it represents the full OCR line.
            XCTAssertGreaterThanOrEqual(
                word.sentence.count, word.text.count,
                "sentence should be at least as long as the word"
            )
        }
    }

    // MARK: - Struct integrity

    func testRecognizedWordBoundingBoxIsNonZero() async throws {
        let image = makeImage(text: "TEST")
        let words = try await service.recognize(image: image)

        try XCTSkipIf(words.isEmpty, "OCR returned no words — skipping")

        for word in words {
            let box = word.boundingBox.boundingBox
            XCTAssertFalse(box.isNull,  "\(word.text): boundingBox is null")
            XCTAssertFalse(box.isEmpty, "\(word.text): boundingBox is empty")
        }
    }
}
