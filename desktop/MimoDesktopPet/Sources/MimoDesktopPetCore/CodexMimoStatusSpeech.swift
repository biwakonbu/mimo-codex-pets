import Foundation

public enum CodexMimoStatusSpeech {
    public static let idle = "いまはのんびり待ってるよ"
    public static let connecting = "Codex につながるのを待ってるよ"
    public static let disconnected = "Codex の声が途切れちゃった。つなぎ直してるよ"
    public static let timedOut = "Codex の返事が遅いみたい。もう一度つないでるよ"
    public static let active = "Codex が作業を進めているよ"
    public static let waiting = "確認してほしいことがあるみたい"
    public static let failed = "うまくいかなかったところがあるみたい"
    public static let systemError = "Codex が困ってるみたい。様子を見てるよ"
    public static let review = "確認してよさそうだよ"
    public static let moving = "よいしょ、移動するよ"
}
