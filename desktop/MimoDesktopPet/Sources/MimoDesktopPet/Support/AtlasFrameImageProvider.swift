import AppKit
import CoreGraphics
import ImageIO
import MimoDesktopPetCore

final class AtlasFrameImageProvider {
    enum LoadError: Error {
        case imageSourceUnavailable
        case imageUnavailable
        case invalidAtlasSize(width: Int, height: Int)
        case cropFailed
    }

    private let atlas: CGImage
    private var cache: [String: NSImage] = [:]
    private var hitMaskCache: [String: PetSpriteAlphaMask] = [:]

    init(spritesheetURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(spritesheetURL as CFURL, nil) else {
            throw LoadError.imageSourceUnavailable
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw LoadError.imageUnavailable
        }
        guard image.width == PetAtlasContract.atlasWidth, image.height == PetAtlasContract.atlasHeight else {
            throw LoadError.invalidAtlasSize(width: image.width, height: image.height)
        }
        atlas = image
    }

    func image(for state: PetAnimationState, frame: Int) -> NSImage? {
        let spec = PetAtlasContract.spec(for: state)
        let normalizedFrame = max(0, min(frame, spec.frameCount - 1))
        let key = "\(state.rawValue)-\(normalizedFrame)"
        if let cached = cache[key] {
            return cached
        }
        guard let cropped = croppedFrame(spec: spec, frame: normalizedFrame) else {
            return nil
        }

        let image = NSImage(
            cgImage: cropped,
            size: NSSize(width: PetAtlasContract.cellWidth, height: PetAtlasContract.cellHeight)
        )
        cache[key] = image
        return image
    }

    func hitMask(for state: PetAnimationState, frame: Int) -> PetSpriteAlphaMask? {
        let spec = PetAtlasContract.spec(for: state)
        let normalizedFrame = max(0, min(frame, spec.frameCount - 1))
        let key = "\(state.rawValue)-\(normalizedFrame)"
        if let cached = hitMaskCache[key] {
            return cached
        }
        guard
            let cropped = croppedFrame(spec: spec, frame: normalizedFrame),
            let mask = PetSpriteAlphaMask(cgImage: cropped)
        else {
            return nil
        }
        hitMaskCache[key] = mask
        return mask
    }

    private func croppedFrame(spec: PetAnimationSpec, frame: Int) -> CGImage? {
        let rect = CGRect(
            x: frame * PetAtlasContract.cellWidth,
            y: spec.row * PetAtlasContract.cellHeight,
            width: PetAtlasContract.cellWidth,
            height: PetAtlasContract.cellHeight
        )
        return atlas.cropping(to: rect)
    }

}
