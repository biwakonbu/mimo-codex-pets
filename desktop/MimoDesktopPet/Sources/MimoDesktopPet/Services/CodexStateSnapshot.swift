import Foundation
import MimoDesktopPetCore

struct CodexStateSnapshot: Equatable {
    var threadStatus: CodexThreadStatus?
    var latestTurnStatus: CodexTurnStatus?
    var hasRecentAssistantFinal: Bool
    var connectionAvailable: Bool
    var offlineBubbleText: String?

    static let offline = CodexStateSnapshot(
        threadStatus: nil,
        latestTurnStatus: nil,
        hasRecentAssistantFinal: false,
        connectionAvailable: false,
        offlineBubbleText: nil
    )
}
