/// 絵本の画像生成モードを表す型
enum ImageGenerationMode: String, Sendable {
    case fullAI       = "fullAI"       // すべて ImageCreator で生成
    case mixed        = "mixed"         // AI + フォールバック混在
    case fallbackOnly = "fallbackOnly"  // すべて FallbackRenderer で生成

    /// UI 表示用の短いラベル
    var displayName: String {
        switch self {
        case .fullAI:       return "AI生成"
        case .mixed:        return "AI+イラスト"
        case .fallbackOnly: return "イラスト"
        }
    }
}
