import Foundation
import UIKit

protocol IllustrationGenerating: Sendable {
    /// 構築済みプロンプトから画像を生成する
    func generateImage(prompt: String) async throws -> UIImage
    /// ImageCreator が使えるか事前チェック
    func checkAvailability() async -> ImageCreatorAvailability
}

extension IllustrationGenerating {
    /// デフォルト実装 — モック実装など常に利用可能とみなす実装向け
    func checkAvailability() async -> ImageCreatorAvailability { .available }
}
