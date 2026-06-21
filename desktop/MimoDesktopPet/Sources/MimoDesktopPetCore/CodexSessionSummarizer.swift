import Foundation

public enum CodexSessionSummarizer {
    public static func summary(from text: String?) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        guard !CodexAmbientTextSafety.isUnsafeForAmbientDisplay(collapsed) else { return nil }

        let lowercased = collapsed.lowercased()
        if containsAny(lowercased, ["吹き出し", "bubble"]) &&
            containsAny(lowercased, ["要約", "summary", "会話", "セッション", "状況", "説明"]) {
            return "吹き出し要約"
        }
        if containsAny(lowercased, ["複数スレッド", "マルチスレッド", "multi-thread", "同時"]) &&
            containsAny(lowercased, ["吹き出し", "bubble", "表示", "thread"]) {
            return "複数スレッド表示"
        }
        if containsAny(lowercased, ["codex"]) &&
            containsAny(lowercased, ["app-server", "接続", "通信", "protocol", "プロトコル", "thread/read"]) {
            return "Codex 連携"
        }
        if containsAny(lowercased, ["セッション", "session"]) &&
            containsAny(lowercased, ["状態", "内容", "情報", "進捗"]) {
            return "セッション状況"
        }
        if containsAny(lowercased, ["computer use", "accessibility", "productionSurface", "画面", "アクセシビリティ"]) {
            return "画面確認"
        }
        if containsAny(lowercased, ["ドラッグ", "drag"]) {
            return "ドラッグ移動"
        }
        if containsAny(lowercased, ["体力", "スタミナ", "stamina", "休憩", "速度", "tween", "移動", "自律"]) {
            return "Mimo の動き"
        }
        if containsAny(lowercased, ["透明", "透過", "ウィンドウ", "最前面", "白表示", "panel"]) {
            return "表示まわり"
        }
        if containsAny(lowercased, ["e2e", "qa", "テスト", "検証", "swift test"]) {
            return "検証"
        }
        if containsAny(lowercased, ["readme", "docs", "ドキュメント", "研究メモ", "仕様", "contract"]) {
            return "仕様整理"
        }
        if containsAny(lowercased, ["commit", "push", "git"]) {
            return "git 反映"
        }
        if containsAny(lowercased, ["mimo", "ペット"]) &&
            containsAny(lowercased, ["実装", "修正", "改善", "作る", "対応"]) {
            return "Mimo 改善"
        }
        if containsAny(lowercased, ["実装", "修正", "改善", "対応", "作る"]) {
            return "実装対応"
        }
        return nil
    }

    private static func containsAny(_ text: String, _ fragments: [String]) -> Bool {
        fragments.contains { text.contains($0.lowercased()) }
    }
}
