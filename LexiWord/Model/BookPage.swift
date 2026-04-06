import Foundation

// MARK: - BookPage

/// A page of OCR-extracted text, split into paragraphs of word tokens.
/// Does not depend on Vision or SwiftData — it is a pure value type
/// created from [RecognizedWord] at the call site.
struct BookPage {

    /// Each element is one paragraph; each paragraph is an ordered list of word tokens.
    let paragraphs: [[String]]

    /// Full plain text, used for sharing.
    var rawText: String {
        paragraphs
            .map { $0.joined(separator: " ") }
            .joined(separator: "\n\n")
    }

    // MARK: - Init

    init(paragraphs: [[String]]) {
        self.paragraphs = paragraphs
    }

    // MARK: - Mock

    static func mock() -> BookPage {
        let p1 = """
        The morning light fell softly through the tall oak trees, casting long \
        shadows across the mossy forest floor. A gentle breeze carried the scent \
        of pine and earth, filling the air with the quiet promise of a new day. \
        Birds called to one another from their hidden perches high in the canopy, \
        their songs weaving together into a natural symphony that echoed through \
        the still morning.
        """

        let p2 = """
        Far below, a narrow stream wound its way between smooth gray stones, its \
        clear water catching the early sun and scattering it into tiny sparkling \
        fragments. A heron stood motionless at the water's edge, patient and alert, \
        watching for movement beneath the surface. The forest was alive with small, \
        purposeful motion — a squirrel darting between roots, leaves trembling in \
        the wind, water flowing over ancient rock.
        """

        let p3 = """
        Walking here each morning had become a kind of ritual, a way of returning \
        to something essential and unhurried. There was no schedule to keep, no \
        message to answer. Just the trees, the water, and the slow, reassuring \
        rhythm of a world that had no need of you at all.
        """

        return BookPage(paragraphs: [p1, p2, p3].map {
            $0.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        })
    }
}
