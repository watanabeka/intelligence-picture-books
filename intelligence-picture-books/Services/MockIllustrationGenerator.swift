import Foundation
import UIKit

// FallbackRenderer を使ったテーマ連動のモック画像を生成
final class MockIllustrationGenerator: IllustrationGenerating {

    func generateCoverImage(title: String, theme: String) async throws -> UIImage {
        try await Task.sleep(for: .seconds(1))
        return FallbackRenderer.renderCover(title: title, theme: theme)
    }

    func generatePageImage(pageNumber: Int, prompt: String, mood: String) async throws -> UIImage {
        try await Task.sleep(for: .milliseconds(800))
        return FallbackRenderer.renderPage(pageNumber: pageNumber, prompt: prompt, mood: mood)
    }
}
