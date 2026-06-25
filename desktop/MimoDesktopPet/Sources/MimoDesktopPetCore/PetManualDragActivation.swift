import Foundation

public struct PetManualDragActivationUpdate: Equatable, Sendable {
    public let isActive: Bool
    public let didActivate: Bool
    public let screenDeltaX: Double
    public let screenDeltaY: Double

    public init(
        isActive: Bool,
        didActivate: Bool,
        screenDeltaX: Double,
        screenDeltaY: Double
    ) {
        self.isActive = isActive
        self.didActivate = didActivate
        self.screenDeltaX = screenDeltaX
        self.screenDeltaY = screenDeltaY
    }
}

public struct PetManualDragActivation: Sendable {
    public private(set) var isActive = false
    public let activationDistance: Double

    private var startPoint: PetWanderPoint?

    public init(activationDistance: Double = 4.0) {
        self.activationDistance = max(0, activationDistance)
    }

    public mutating func begin(at point: PetWanderPoint) {
        startPoint = point
        isActive = false
    }

    public mutating func update(to point: PetWanderPoint) -> PetManualDragActivationUpdate {
        guard let startPoint else {
            begin(at: point)
            return PetManualDragActivationUpdate(
                isActive: false,
                didActivate: false,
                screenDeltaX: 0,
                screenDeltaY: 0
            )
        }

        let deltaX = point.x - startPoint.x
        let deltaY = point.y - startPoint.y
        let wasActive = isActive
        if !isActive, hypot(deltaX, deltaY) >= activationDistance {
            isActive = true
        }

        return PetManualDragActivationUpdate(
            isActive: isActive,
            didActivate: isActive && !wasActive,
            screenDeltaX: deltaX,
            screenDeltaY: deltaY
        )
    }

    @discardableResult
    public mutating func end() -> Bool {
        let wasActive = isActive
        startPoint = nil
        isActive = false
        return wasActive
    }
}
