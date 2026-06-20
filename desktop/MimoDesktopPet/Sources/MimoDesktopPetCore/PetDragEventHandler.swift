import Foundation

public struct PetDragFrame: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func offsetBy(screenDeltaX: Double, screenDeltaY: Double) -> PetDragFrame {
        PetDragFrame(
            x: x + screenDeltaX,
            y: y + screenDeltaY,
            width: width,
            height: height
        )
    }
}

public struct PetDragUpdate: Equatable, Sendable {
    public var frame: PetDragFrame
    public var animation: PetAnimationState?

    public init(frame: PetDragFrame, animation: PetAnimationState?) {
        self.frame = frame
        self.animation = animation
    }
}

public struct PetDragEventHandler: Sendable {
    public private(set) var isDragging = false

    private var startFrame: PetDragFrame?
    private var lastAnimation: PetAnimationState?

    public init() {}

    public mutating func begin(frame: PetDragFrame) {
        startFrame = frame
        lastAnimation = nil
        isDragging = true
    }

    public mutating func update(
        screenDeltaX: Double,
        screenDeltaY: Double,
        fallbackFrame: PetDragFrame
    ) -> PetDragUpdate {
        if startFrame == nil {
            begin(frame: fallbackFrame)
        }

        if screenDeltaX > 0 {
            lastAnimation = .runningRight
        } else if screenDeltaX < 0 {
            lastAnimation = .runningLeft
        }

        let frame = (startFrame ?? fallbackFrame).offsetBy(
            screenDeltaX: screenDeltaX,
            screenDeltaY: screenDeltaY
        )
        return PetDragUpdate(frame: frame, animation: lastAnimation)
    }

    public mutating func end() {
        startFrame = nil
        lastAnimation = nil
        isDragging = false
    }
}
