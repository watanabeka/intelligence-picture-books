import Foundation
import UIKit

/// FallbackRenderer を使ったモック画像生成。
/// キャラクターシートが利用できないため、レガシー互換 API を使用する。
final class MockIllustrationGenerator: IllustrationGenerating {

    func generateImage(prompt: String) async throws -> UIImage {
        try await Task.sleep(for: .milliseconds(800))
        // フォールバックレンダラーのレガシー API で簡易画像を生成
        return FallbackRenderer.renderPageLegacy(pageNumber: 1, prompt: prompt, mood: "やさしい")
    }
}
