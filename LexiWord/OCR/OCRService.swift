import Vision
import UIKit
import os

private let logger = Logger(subsystem: "com.lexiword", category: "OCRService")

/// A single word token extracted from a Vision OCR pass.
///
/// Each word carries a reference to its parent `VNRecognizedTextObservation`
/// (one observation = one full line). Multiple `RecognizedWord` values from
/// the same line share the same `boundingBox` observation.
struct RecognizedWord {
    /// The individual word token, split from the OCR line by whitespace.
    let text: String
    /// The raw Vision observation for the line this word belongs to.
    /// Coordinate space: normalized, bottom-left origin, Y up.
    /// Use `CoordinateConverter` before using this for layout.
    let boundingBox: VNRecognizedTextObservation
    /// The full OCR line this word was extracted from. Used as the
    /// contextual sentence when saving an entry to the notebook.
    let sentence: String
}

// VNRecognizedTextObservation is an immutable Objective-C object. Once the
// Vision request completes it is never mutated, so crossing concurrency
// boundaries is safe despite the missing Sendable declaration.
extension RecognizedWord: @unchecked Sendable {}

enum OCRError: Error {
    case noTextFound
    case processingFailed(Error)
}

struct OCRService: Sendable {

    func recognize(image: UIImage) async throws -> [RecognizedWord] {
        // Run the synchronous Vision pipeline off the main thread.
        try await Task.detached(priority: .userInitiated) {
            try performRecognition(image: image)
        }.value
    }

    // MARK: - Private

    private func performRecognition(image: UIImage) throws -> [RecognizedWord] {
        guard let cgImage = image.cgImage else {
            throw OCRError.processingFailed(
                NSError(domain: "OCRService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "UIImage has no CGImage backing"])
            )
        }

        var words: [RecognizedWord] = []
        var handlerError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                handlerError = error
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                let sentence = candidate.string
                // Split the line into word tokens; filter removes artefacts from
                // consecutive whitespace characters.
                let tokens = sentence
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                for token in tokens {
                    words.append(RecognizedWord(text: token, boundingBox: observation, sentence: sentence))
                }
            }
        }

        request.recognitionLevel = .accurate

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.processingFailed(error)
        }

        if let error = handlerError {
            throw OCRError.processingFailed(error)
        }

        if words.isEmpty {
            logger.info("No text found in image")
            throw OCRError.noTextFound
        }

        logger.info("Recognized \(words.count) word token(s)")
        return words
    }
}
