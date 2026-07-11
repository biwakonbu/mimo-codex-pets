import CoreGraphics
import Foundation

public struct PetSpriteAlphaMask: Equatable, Sendable {
    public static let defaultHitThreshold: UInt8 = 16

    public let width: Int
    public let height: Int
    private let alphaValues: [UInt8]

    public init?(width: Int, height: Int, alphaValues: [UInt8]) {
        guard width > 0, height > 0, alphaValues.count == width * height else {
            return nil
        }
        self.width = width
        self.height = height
        self.alphaValues = alphaValues
    }

    public init?(cgImage image: CGImage) {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue |
                    CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            context.setBlendMode(.copy)
            context.interpolationQuality = .none
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        self.width = width
        self.height = height
        alphaValues = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    public func contains(
        normalizedX: Double,
        normalizedY: Double,
        threshold: UInt8 = defaultHitThreshold
    ) -> Bool {
        guard normalizedX >= 0, normalizedX <= 1,
              normalizedY >= 0, normalizedY <= 1 else {
            return false
        }
        let x = min(width - 1, Int(normalizedX * Double(width)))
        let y = min(height - 1, Int(normalizedY * Double(height)))
        return alphaValues[y * width + x] >= threshold
    }
}
