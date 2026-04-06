import XCTest
@testable import LexiWord

final class CoordinateConverterTests: XCTestCase {

    // MARK: - Helpers

    /// 100×100 view showing a 100×100 image: scale = 1.0, no offsets.
    /// Makes expected values easy to reason about.
    private let squareImage = CGSize(width: 100, height: 100)
    private let squareView  = CGSize(width: 100, height: 100)

    private func convert(_ box: CGRect, image: CGSize? = nil, view: CGSize? = nil) -> CGRect {
        CoordinateConverter.convert(
            boundingBox: box,
            imageSize: image ?? squareImage,
            viewSize:  view  ?? squareView
        )
    }

    // MARK: - Y-axis flip (core correctness)

    /// A word near the TOP of the image has a high Vision Y (close to 1.0).
    /// After flipping it should have a LOW SwiftUI Y (close to 0 = near top of view).
    func testTopLeftWord_yIsSmall() {
        // Vision: left edge at x=0, bottom of word at y=0.80, top at y=0.90
        let result = convert(CGRect(x: 0.0, y: 0.80, width: 0.10, height: 0.10))
        XCTAssertEqual(result.origin.x,  0,  accuracy: 0.001)
        XCTAssertEqual(result.origin.y,  10, accuracy: 0.001,
                       "Top of image in Vision (y≈0.9) must map to small SwiftUI Y")
        XCTAssertEqual(result.width,     10, accuracy: 0.001)
        XCTAssertEqual(result.height,    10, accuracy: 0.001)
    }

    /// A word near the BOTTOM-RIGHT of the image has a low Vision Y and high Vision X.
    /// After flipping it should have a HIGH SwiftUI Y (close to viewHeight = near bottom).
    func testBottomRightWord_yIsLarge() {
        // Vision: right side x=0.80, bottom of word at y=0.00, top at y=0.10
        let result = convert(CGRect(x: 0.80, y: 0.00, width: 0.10, height: 0.10))
        XCTAssertEqual(result.origin.x,  80, accuracy: 0.001)
        XCTAssertEqual(result.origin.y,  90, accuracy: 0.001,
                       "Bottom of image in Vision (y≈0.0) must map to large SwiftUI Y")
        XCTAssertEqual(result.width,     10, accuracy: 0.001)
        XCTAssertEqual(result.height,    10, accuracy: 0.001)
    }

    /// A word at the centre of the image should land at the centre of the view.
    func testCenterWord_mapsToCenter() {
        let result = convert(CGRect(x: 0.45, y: 0.45, width: 0.10, height: 0.10))
        XCTAssertEqual(result.origin.x,  45, accuracy: 0.001)
        XCTAssertEqual(result.origin.y,  45, accuracy: 0.001,
                       "A centred Vision box should map to the centre of the view")
        XCTAssertEqual(result.width,     10, accuracy: 0.001)
        XCTAssertEqual(result.height,    10, accuracy: 0.001)
    }

    // MARK: - Aspect-fit scaling & letterbox offset

    /// Wide image (200×100) in a square view (100×100).
    /// scale = 0.5  → scaledSize = (100, 50)
    /// xOffset = 0, yOffset = (100-50)/2 = 25
    func testAspectFitWideImage_pillarboxOffsetApplied() {
        let imageSize = CGSize(width: 200, height: 100)
        let viewSize  = CGSize(width: 100, height: 100)

        // Top-left word in Vision coordinates
        let result = convert(CGRect(x: 0.0, y: 0.80, width: 0.10, height: 0.10),
                             image: imageSize, view: viewSize)

        // x: 0.0 * 100 + 0 = 0
        // y: (1 - 0.90) * 50 + 25 = 5 + 25 = 30
        // w: 0.10 * 100 = 10  |  h: 0.10 * 50 = 5
        XCTAssertEqual(result.origin.x,  0,  accuracy: 0.001)
        XCTAssertEqual(result.origin.y,  30, accuracy: 0.001,
                       "Letterbox yOffset of 25 must be added after the Y flip")
        XCTAssertEqual(result.width,     10, accuracy: 0.001)
        XCTAssertEqual(result.height,    5,  accuracy: 0.001)
    }

    /// Tall image (100×200) in a square view (100×100).
    /// scale = 0.5  → scaledSize = (50, 100)
    /// xOffset = (100-50)/2 = 25, yOffset = 0
    func testAspectFitTallImage_pillarboxOffsetApplied() {
        let imageSize = CGSize(width: 100, height: 200)
        let viewSize  = CGSize(width: 100, height: 100)

        // Bottom-right word
        let result = convert(CGRect(x: 0.80, y: 0.00, width: 0.10, height: 0.10),
                             image: imageSize, view: viewSize)

        // x: 0.80 * 50 + 25 = 40 + 25 = 65
        // y: (1 - 0.10) * 100 + 0 = 90
        // w: 0.10 * 50 = 5  |  h: 0.10 * 100 = 10
        XCTAssertEqual(result.origin.x,  65, accuracy: 0.001,
                       "Pillarbox xOffset of 25 must be added to x coordinate")
        XCTAssertEqual(result.origin.y,  90, accuracy: 0.001)
        XCTAssertEqual(result.width,     5,  accuracy: 0.001)
        XCTAssertEqual(result.height,    10, accuracy: 0.001)
    }
}
