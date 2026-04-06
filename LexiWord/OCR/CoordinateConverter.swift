import Vision
import CoreGraphics

/// Converts Vision framework bounding boxes to SwiftUI layout rects.
///
/// Vision uses a normalized coordinate space with the origin at the bottom-left
/// and Y increasing upward. SwiftUI uses a top-left origin with Y increasing
/// downward, measured in points. When the image is displayed with aspect-fit
/// scaling (centred inside the view), the rendered image may not fill the full
/// view — this converter accounts for that letterbox/pillarbox offset.
enum CoordinateConverter {

    /// Converts a `VNRecognizedTextObservation` bounding box to a `CGRect`
    /// suitable for use as a SwiftUI `.frame` or overlay position.
    ///
    /// - Parameters:
    ///   - observation: The Vision observation whose `boundingBox` to convert.
    ///   - imageSize: The pixel dimensions of the source image.
    ///   - viewSize: The point dimensions of the SwiftUI view displaying the image.
    /// - Returns: A `CGRect` in SwiftUI coordinates (top-left origin, Y down, in points).
    static func convert(
        observation: VNRecognizedTextObservation,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        convert(boundingBox: observation.boundingBox, imageSize: imageSize, viewSize: viewSize)
    }

    /// The actual conversion math. Exposed as `internal` so unit tests can
    /// drive it with plain `CGRect` values without needing a live Vision pipeline.
    static func convert(
        boundingBox: CGRect,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        // Aspect-fit scale factor — the same scale Xcode/SwiftUI applies when
        // the image is displayed with .scaledToFit() inside the view.
        let scale = min(viewSize.width / imageSize.width,
                        viewSize.height / imageSize.height)
        let scaledWidth  = imageSize.width  * scale
        let scaledHeight = imageSize.height * scale

        // Centering offsets (letterbox / pillarbox bars).
        let xOffset = (viewSize.width  - scaledWidth)  / 2
        let yOffset = (viewSize.height - scaledHeight) / 2

        // X: same direction in both spaces — scale and offset only.
        let x = boundingBox.minX * scaledWidth + xOffset

        // Y: flip the axis.
        // Vision maxY  = top edge measured from the bottom of the image.
        // SwiftUI origin wants the top edge measured from the top of the view.
        let y = (1.0 - boundingBox.maxY) * scaledHeight + yOffset

        let width  = boundingBox.width  * scaledWidth
        let height = boundingBox.height * scaledHeight

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
