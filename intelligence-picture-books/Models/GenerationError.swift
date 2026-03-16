import Foundation

enum GenerationError: Error, LocalizedError, Sendable {
    case modelNotAvailable
    case generationFailed(underlying: String)
    case cancelled
    case invalidResponse
    case imageGenerationFailed(underlying: String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable: "オンデバイスモデルが利用できません。対応デバイスか確認してください。"
        case .generationFailed(let msg): "物語の生成に失敗しました: \(msg)"
        case .cancelled: "生成がキャンセルされました。"
        case .invalidResponse: "モデルからの応答を解析できませんでした。"
        case .imageGenerationFailed(let msg): "画像の生成に失敗しました: \(msg)"
        }
    }
}
