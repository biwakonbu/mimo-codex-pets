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
    public var displacementX: Double
    public var displacementY: Double

    public init(
        animation: PetAnimationState?,
        isMoving: Bool,
        velocityX: Double,
        accelerationX: Double,
        displacementX: Double = 0,
        displacementY: Double = 0
    ) {
        self.animation = animation
        self.isMoving = isMoving
        self.velocityX = velocityX
        self.accelerationX = accelerationX
        self.displacementX = displacementX
        self.displacementY = displacementY
    }
}

public struct PetMovementEventHandler: Sendable {
    public private(set) var isMoving = false

    public let activationDistance: Double
    public let horizontalDeadZone: Double

    private var originSample: PetMovementSample?
    private var lastSample: PetMovementSample?
    private var lastVelocityX = 0.0
    private var lastAnimation: PetAnimationState?

    public init(
        minimumSpeed: Double = 4.0,
        minimumAcceleration: Double = 80.0,
        stationarySampleLimit: Int = 3,
        activationDistance: Double = 8.0,
        horizontalDeadZone: Double = 1.0
    ) {
        _ = minimumSpeed
        _ = minimumAcceleration
        _ = stationarySampleLimit
        self.activationDistance = max(0, activationDistance)
        self.horizontalDeadZone = max(0, horizontalDeadZone)
    }

    public mutating func begin(sample: PetMovementSample) {
        originSample = sample
        lastSample = sample
        lastVelocityX = 0
        lastAnimation = nil
        isMoving = false
    }

    public mutating func update(sample: PetMovementSample) -> PetMovementUpdate {
        guard let origin = originSample else {
            begin(sample: sample)
            return PetMovementUpdate(
                animation: nil,
                isMoving: false,
                velocityX: 0,
                accelerationX: 0
            )
        }

        let previous = lastSample ?? origin
        let elapsed = sample.timestamp - previous.timestamp
        let velocityX: Double
        let accelerationX: Double
        if elapsed > 0 {
            velocityX = (sample.frame.x - previous.frame.x) / elapsed
            accelerationX = (velocityX - lastVelocityX) / elapsed
        } else {
            velocityX = lastVelocityX
            accelerationX = 0
        }

        let displacementX = sample.frame.x - origin.frame.x
        let displacementY = sample.frame.y - origin.frame.y
        let displacement = hypot(displacementX, displacementY)

        if displacement >= activationDistance {
            isMoving = true
            if abs(displacementX) > horizontalDeadZone {
                lastAnimation = displacementX > 0 ? .runningRight : .runningLeft
            } else if lastAnimation == nil, abs(velocityX) > horizontalDeadZone {
                lastAnimation = velocityX > 0 ? .runningRight : .runningLeft
            } else if lastAnimation == nil {
                lastAnimation = .runningRight
            }
        } else {
            isMoving = false
            lastAnimation = nil
        }

        lastSample = sample
        lastVelocityX = velocityX

        return PetMovementUpdate(
            animation: isMoving ? lastAnimation : nil,
            isMoving: isMoving,
            velocityX: velocityX,
            accelerationX: accelerationX,
            displacementX: displacementX,
            displacementY: displacementY
        )
    }

    public mutating func reset() {
        isMoving = false
        originSample = nil
        lastSample = nil
        lastVelocityX = 0
        lastAnimation = nil
    }
}
