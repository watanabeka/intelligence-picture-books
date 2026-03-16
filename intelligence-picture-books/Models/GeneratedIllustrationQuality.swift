import Foundation

/// 生成された画像の品質情報。
/// 完全なOCRではなく、フラグベースの簡易検査結果を保持する。
struct GeneratedIllustrationQuality: Sendable {
    /// 画像に文字らしきものが含まれている可能性があるか
    var hasPossibleTextArtifacts: Bool

    /// キャラクター一貫性スコア (0.0-1.0)。現時点ではプロンプト一致度で推定。
    var consistencyScore: Double

    /// シーンのキーワードとの一致度
    var matchesSceneKeywords: Bool

    /// フォールバック画像が使われたか
    var usedFallback: Bool

    /// 再生成を推奨するか
    var shouldRetry: Bool {
        hasPossibleTextArtifacts && !usedFallback
    }

    /// デフォルト（品質不明）
    static let unknown = GeneratedIllustrationQuality(
        hasPossibleTextArtifacts: false,
        consistencyScore: 0.5,
        matchesSceneKeywords: true,
        usedFallback: false
    )

    /// フォールバック使用時
    static let fallback = GeneratedIllustrationQuality(
        hasPossibleTextArtifacts: false,
        consistencyScore: 0.3,
        matchesSceneKeywords: true,
        usedFallback: true
    )
}
