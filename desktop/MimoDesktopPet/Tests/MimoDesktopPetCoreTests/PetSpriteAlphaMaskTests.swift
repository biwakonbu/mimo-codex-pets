import CoreGraphics
import ImageIO
import XCTest
@testable import MimoDesktopPetCore

final class PetSpriteAlphaMaskTests: XCTestCase {
    func testSamplesTopLeadingAlphaPixels() throws {
        let mask = try XCTUnwrap(PetSpriteAlphaMask(
            width: 2,
            height: 2,
            alphaValues: [0, 255, 8, 16]
        ))

        XCTAssertFalse(mask.contains(normalizedX: 0.25, normalizedY: 0.25))
        XCTAssertTrue(mask.contains(normalizedX: 0.75, normalizedY: 0.25))
        XCTAssertFalse(mask.contains(normalizedX: 0.25, normalizedY: 0.75))
        XCTAssertTrue(mask.contains(normalizedX: 0.75, normalizedY: 0.75))
    }

    func testRejectsPointsOutsideMask() throws {
        let mask = try XCTUnwrap(PetSpriteAlphaMask(width: 1, height: 1, alphaValues: [255]))

        XCTAssertFalse(mask.contains(normalizedX: -0.01, normalizedY: 0.5))
        XCTAssertFalse(mask.contains(normalizedX: 0.5, normalizedY: 1.01))
    }

    func testRejectsInvalidStorageSize() {
        XCTAssertNil(PetSpriteAlphaMask(width: 2, height: 2, alphaValues: [255]))
    }

    func testCGImageExtractionKeepsTopLeadingRowOrder() throws {
        let sourceAlpha: [UInt8] = [0, 255, 8, 16]
        var pixels: [UInt8] = []
        for alpha in sourceAlpha {
            pixels.append(contentsOf: [0, 0, 0, alpha])
        }
        let data = Data(pixels) as CFData
        let provider = try XCTUnwrap(CGDataProvider(data: data))
        let image = try XCTUnwrap(CGImage(
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: 8,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
                rawValue: CGImageAlphaInfo.premultipliedLast.rawValue |
                    CGBitmapInfo.byteOrder32Big.rawValue
            ),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
        let mask = try XCTUnwrap(PetSpriteAlphaMask(cgImage: image))

        XCTAssertFalse(mask.contains(normalizedX: 0.25, normalizedY: 0.25))
        XCTAssertTrue(mask.contains(normalizedX: 0.75, normalizedY: 0.25))
        XCTAssertFalse(mask.contains(normalizedX: 0.25, normalizedY: 0.75))
        XCTAssertTrue(mask.contains(normalizedX: 0.75, normalizedY: 0.75))
    }

    func testMimoSpritesheetFrameUsesTransparentPixelHitTesting() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let spritesheetURL = repositoryRoot
            .appendingPathComponent("pets/mimo/spritesheet.webp")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(spritesheetURL as CFURL, nil))
        let atlas = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let idleFrame = try XCTUnwrap(atlas.cropping(to: CGRect(
            x: 0,
            y: 0,
            width: PetAtlasContract.cellWidth,
            height: PetAtlasContract.cellHeight
        )))
        let mask = try XCTUnwrap(PetSpriteAlphaMask(cgImage: idleFrame))

        XCTAssertEqual(mask.width, PetAtlasContract.cellWidth)
        XCTAssertEqual(mask.height, PetAtlasContract.cellHeight)
        XCTAssertFalse(mask.contains(normalizedX: 0.01, normalizedY: 0.01))
        XCTAssertTrue(mask.contains(normalizedX: 0.5, normalizedY: 0.5))
    }
}
