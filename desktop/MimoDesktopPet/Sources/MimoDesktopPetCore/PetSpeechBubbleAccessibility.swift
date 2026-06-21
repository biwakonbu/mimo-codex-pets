import Foundation

public enum PetSpeechBubbleAccessibility {
    public static let label = "Mimo Desktop Pet"
    public static let identifier = "MimoDesktopPet.productionSurface"

    public static func value(
        presentation: PetPresentationState,
        bubbles: [PetSpeechBubble],
        debugOverlay: Bool
    ) -> String {
        let mode = debugOverlay ? "デバッグ表示" : "本番表示"
        let bubbleSummary = bubbles
            .prefix(PetSpeechBubbleLayout.productionVisibleLimit)
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " / ")

        let base = "\(mode)。\(presentation.animation.rawValue)"
        guard !bubbleSummary.isEmpty else { return base }
        return "\(base)。\(bubbleSummary)"
    }
}
