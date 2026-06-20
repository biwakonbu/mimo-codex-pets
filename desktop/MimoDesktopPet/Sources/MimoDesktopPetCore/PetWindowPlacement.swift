import Foundation

public enum PetWindowPlacement {
    public static func defaultOrigin(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double
    ) -> PetWanderPoint {
        clampedOrigin(
            PetWanderPoint(
                x: visibleFrame.x + visibleFrame.width - petWidth - 32,
                y: visibleFrame.y + 80
            ),
            visibleFrame: visibleFrame,
            petWidth: petWidth,
            petHeight: petHeight
        )
    }

    public static func origin(
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double,
        override: String?
    ) -> PetWanderPoint {
        guard let parsed = parseOriginOverride(override) else {
            return defaultOrigin(
                visibleFrame: visibleFrame,
                petWidth: petWidth,
                petHeight: petHeight
            )
        }

        return clampedOrigin(
            parsed,
            visibleFrame: visibleFrame,
            petWidth: petWidth,
            petHeight: petHeight
        )
    }

    public static func parseOriginOverride(_ value: String?) -> PetWanderPoint? {
        guard let value else { return nil }
        let parts = value
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2,
              let x = Double(parts[0]),
              let y = Double(parts[1])
        else {
            return nil
        }
        return PetWanderPoint(x: x, y: y)
    }

    private static func clampedOrigin(
        _ origin: PetWanderPoint,
        visibleFrame: PetDragFrame,
        petWidth: Double,
        petHeight: Double
    ) -> PetWanderPoint {
        let maxX = max(visibleFrame.x, visibleFrame.x + visibleFrame.width - petWidth)
        let maxY = max(visibleFrame.y, visibleFrame.y + visibleFrame.height - petHeight)
        return PetWanderPoint(
            x: min(max(origin.x, visibleFrame.x), maxX),
            y: min(max(origin.y, visibleFrame.y), maxY)
        )
    }
}
