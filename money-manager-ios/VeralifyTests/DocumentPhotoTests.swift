import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Veralify

/// A document photo goes into the database the user carries around, so what
/// actually gets stored matters: the first version of this shrank the image on
/// paper and then rendered it back at the screen's 3× scale, storing a 6MB file
/// that was every pixel of the original.
struct DocumentPhotoTests {

    /// A photograph-sized JPEG, big enough that a downscale has to do something.
    private func photo(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemPink.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            // Some detail, so the encoder has something to compress and the
            // byte count is not dominated by a flat colour.
            for x in stride(from: 0, to: width, by: 40) {
                UIColor(white: Double(x % 255) / 255, alpha: 1).setFill()
                context.fill(CGRect(x: x, y: 0, width: 20, height: height))
            }
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    private func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    @Test("A camera-sized photo is stored well under its original size")
    func downscalesLargePhoto() throws {
        let original = photo(width: 3000, height: 2250)
        let stored = try #require(DocumentDetailView.downscaledJPEG(original))
        let size = try #require(pixelSize(of: stored))

        #expect(max(size.width, size.height) == 2000)
        // Aspect ratio survives: 3000×2250 is 4:3.
        #expect(size.height == 1500)
        #expect(stored.count < original.count)
    }

    @Test("A photo already smaller than the cap is not blown up")
    func leavesSmallPhotoAlone() throws {
        let original = photo(width: 900, height: 1200)
        let stored = try #require(DocumentDetailView.downscaledJPEG(original))
        let size = try #require(pixelSize(of: stored))

        #expect(size.width == 900)
        #expect(size.height == 1200)
    }

    @Test("Where the photo was taken is not stored with it")
    func dropsLocationMetadata() throws {
        // Attach a GPS fix to a photo the way a phone camera does.
        let plain = photo(width: 2400, height: 1800)
        let source = try #require(CGImageSourceCreateWithData(plain as CFData, nil))
        let located = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(located, UTType.jpeg.identifier as CFString, 1, nil)
        )
        let gps: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: 45.4642,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 9.19,
            kCGImagePropertyGPSLongitudeRef: "E",
        ]
        CGImageDestinationAddImageFromSource(
            destination,
            source,
            0,
            [kCGImagePropertyGPSDictionary: gps] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))

        let withLocation = located as Data
        #expect(properties(of: withLocation)?[kCGImagePropertyGPSDictionary] != nil)

        let stored = try #require(DocumentDetailView.downscaledJPEG(withLocation))
        #expect(properties(of: stored)?[kCGImagePropertyGPSDictionary] == nil)
    }

    private func properties(of data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }
}
