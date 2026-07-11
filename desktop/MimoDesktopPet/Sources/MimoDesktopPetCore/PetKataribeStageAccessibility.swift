import Foundation

public enum PetKataribeStageAccessibility {
    public static func value(
        stage: PetKataribeStagePresentation,
        debugOverlay: Bool
    ) -> String {
        let mode = debugOverlay ? "デバッグ表示" : "本番表示"
        let reportTitle = stage.report.threadTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reportParts = PetSpeechBubbleTextParts.parse(stage.report.text)
        let body = reportParts.threadTitle == nil ? stage.report.text : reportParts.summary
        let report: String
        if let reportTitle, !reportTitle.isEmpty {
            report = "Mimoの報告。\(reportTitle): \(body)"
        } else {
            report = "Mimoのひとこと。\(body)"
        }
        let chatNames = stage.charms.map(\.title).joined(separator: "、")
        guard !chatNames.isEmpty else { return "\(mode)。\(report)" }
        return "\(mode)。\(report)。見ているチャット: \(chatNames)"
    }
}
