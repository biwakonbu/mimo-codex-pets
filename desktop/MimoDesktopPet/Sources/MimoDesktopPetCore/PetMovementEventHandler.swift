import Foundation

public struct PetMovementSample: Equatable, Sendable {
    public var frame: PetDragFrame
    public var timestamp: TimeInterval

    public init(frame: PetDragFrame, timestamp: TimeInterval) {
        self.frame = frame
        self.timestamp = timestamp
    }
}

public struct PetMovementUpdate: Equatable, Sendable {
    public var animation: PetAnimationState?
    public var isMoving: Bool
    public var velocityX: Double
    public var accelerationX: Double

    public init(
        animation: PetAnimationState?,
        isMoving: Bool,
        velocityX: Double,
        accelerationX: Double
    ) {
        self.animation = animation
        self.isMoving = isMoving
        self.velocityX = velocityX
        self.accelerationX = accelerationX
    }
}

public struct PetMovementEventHandler: Sendable {
    public private(set) var isMoving = false

    private let minimumSpeed: Double
    private let minimumAcceleration: Double
    private let stationarySampleLimit: Int

    private var lastSample: PetMovementSample?
    private var lastVelocityX = 0.0
    private var lastAnimation: PetAnimationState?
    private var stationarySamples = 0

    public init(
        minimumSpeed: Double = 4.0,
        minimumAcceleration: Double = 80.0,
        stationarySampleLimit: Int = 3
    ) {
        self.minimumSpeed = minimumSpeed
        self.minimumAcceleration = minimumAcceleration
        self.stationarySampleLimit = max(1, stationarySampleLimit)
    }

    public mutating func update(sample: PetMovementSample) -> PetMovementUpdate {
        guard let previous = lastSample else {
            lastSample = sample
            return PetMovementUpdate(animation: nil, isMoving: false, velocityX: 0, accelerationX: 0)
        }

        let elapsed = sample.timestamp - previous.timestamp
        guard elapsed > 0 else {
            lastSample = sample
            return PetMovementUpdate(
                animation: isMoving ? lastAnimation : nil,
                isMoving: isMoving,
                velocityX: lastVelocityX,
                accelerationX: 0
            )
        }

        let deltaX = sample.frame.x - previous.frame.x
        let deltaY = sample.frame.y - previous.frame.y
        let velocityX = deltaX / elapsed
        let velocityY = deltaY / elapsed
        let accelerationX = (velocityX - lastVelocityX) / elapsed
        let speed = hypot(velocityX, velocityY)
        let hasMovement = speed >= minimumSpeed || abs(accelerationX) >= minimumAcceleration

        if hasMovement {
            stationarySamples = 0
            if abs(velocityX) >= minimumSpeed {
                lastAnimation = velocityX > 0 ? .runningRight : .runningLeft
            } else if lastAnimation == nil, abs(accelerationX) >= minimumAcceleration {
                lastAnimation = accelerationX > 0 ? .runningRight : .runningLeft
            }
            isMoving = true
        } else {
            stationarySamples += 1
            if stationarySamples >= stationarySampleLimit {
                isMoving = false
                lastAnimation = nil
            }
        }

        lastSample = sample
        lastVelocityX = velocityX

        return PetMovementUpdate(
            animation: isMoving ? lastAnimation : nil,
            isMoving: isMoving,
            velocityX: velocityX,
            accelerationX: accelerationX
        )
    }

    public mutating func reset() {
        isMoving = false
        lastSample = nil
        lastVelocityX = 0
        lastAnimation = nil
        stationarySamples = 0
    }
}
