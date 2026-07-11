import Foundation

public enum PetSpeechBubbleAccessibility {
    public static let label = "Mimo Desktop Pet"
    public static let identifier = "MimoDesktopPet.productionSurface"

    public static func bubbleIdentifier(index: Int, role: PetSpeechBubbleRole) -> String {
        "\(identifier).bubble.\(index).\(role.rawValue)"
    }

    public static func bubbleSortPriority(index: Int) -> Double {
        Double(PetSpeechBubbleLayout.productionVisibleLimit - index)
    }

    public static func bubbleLabel(index: Int, role: PetSpeechBubbleRole) -> String {
        let ordinal = index + 1
        switch role {
        case .status:
            return "Mimoのひとこと \(ordinal)"
        case .focus:
            return "Mimoが伝える主なチャット \(ordinal)"
        case .conversation:
            return "Mimoが見ているチャット \(ordinal)"
        case .overflow:
            return "Mimoが見ているほかのチャット \(ordinal)"
        }
    }

    public static func bubbleElementLabel(index: Int, role: PetSpeechBubbleRole, text: String) -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = bubbleLabel(index: index, role: role)
        guard !trimmedText.isEmpty else { return label }
        return "\(label): \(trimmedText)"
    }

    public static func value(
        presentation: PetPresentationState,
        bubbles: [PetSpeechBubble],
        debugOverlay: Bool
    ) -> String {
        let mode = debugOverlay ? "デバッグ表示" : "本番表示"
        let bubbleSummary = bubbles
            .prefix(PetSpeechBubbleLayout.productionVisibleLimit)
            .map { bubble in
                if PetSpeechBubbleTextParts.parse(bubble.text).threadTitle != nil {
                    return bubble.text
                }
                if let title = bubble.threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    return "「\(title)」\(bubble.text)"
                }
                return bubble.text
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " / ")

        let base = "\(mode)。\(presentation.animation.rawValue)"
        guard !bubbleSummary.isEmpty else { return base }
        return "\(base)。\(bubbleSummary)"
    }
}
