import Foundation

/// ページ画像の表示状態。
/// 生成フェーズ（PageDraft）と閲覧フェーズ（ReaderViewModel）で共用する。
enum PageImageState: Sendable {
    /// 読み込み中 / 生成中
    case loading
    /// 通常の生成画像が表示されている
    case ready
    /// 画像なし（生成失敗 or 未生成）- リトライUIを表示
    case failed
    /// フォールバック画像が表示されている - リトライUIをオーバーレイ表示
    case fallback
    /// 現在リトライ中
    case retrying

    /// リトライUIを表示するべき状態か
    var needsRetry: Bool {
        switch self {
        case .failed, .fallback: true
        default: false
        }
    }
}
