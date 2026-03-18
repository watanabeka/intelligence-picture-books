/// ImagePlayground / ImageCreator の利用可否を表す型
enum ImageCreatorAvailability: Sendable {
    case available
    case simulator           // シミュレーター環境（ImageCreator 非対応）
    case modelUnavailable    // モデル未ダウンロード / iOS バージョン非対応
    case unsupportedLanguage // デバイス言語が非対応（日本語など）
    case noStylesAvailable   // availableStyles が空
    case unknown(String)     // その他のエラー

    var isUsable: Bool {
        if case .available = self { return true }
        return false
    }

    var reason: String {
        switch self {
        case .available:           return "利用可能"
        case .simulator:           return "シミュレーター環境 (ImageCreator 非対応)"
        case .modelUnavailable:    return "モデル未ダウンロード / iOS バージョン非対応"
        case .unsupportedLanguage: return "デバイス言語が ImagePlayground 非対応（日本語など）"
        case .noStylesAvailable:   return "利用可能なスタイルなし（モデル未ダウンロードの可能性）"
        case .unknown(let msg):    return "不明なエラー: \(msg)"
        }
    }
}
