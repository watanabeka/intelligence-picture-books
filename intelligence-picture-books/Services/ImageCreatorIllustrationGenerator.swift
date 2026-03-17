import Foundation
import UIKit
import ImagePlayground

/// Apple ImageCreator (Image Playground) を使ったイラスト生成サービス。
/// IllustrationPromptBuilder が構築した完成済みプロンプトを受け取って画像を生成する。
final class ImageCreatorIllustrationGenerator: IllustrationGenerating, @unchecked Sendable {

    func generateImage(prompt: String) async throws -> UIImage {
        let safePrompt = ensureTextFreeConstraint(prompt)
        return try await generateWithRetry(
            prompt: safePrompt,
            fallbackPrompt: "a cute cartoon animal in a peaceful nature scene, soft pastel watercolor, children's picture book illustration, gentle colors, no text, no letters, no watermark, no logo, no signage, no typography"
        )
    }

    /// 安全フィルターエラー時にフォールバックプロンプトで1回リトライ
    private func generateWithRetry(prompt: String, fallbackPrompt: String) async throws -> UIImage {
        do {
            return try await generateSingleImage(prompt: prompt)
        } catch {
            let desc = String(describing: error).lowercased()
            let isUnsafe = desc.contains("unsafe") || desc.contains("safety") || desc.contains("guardrail")
            if isUnsafe {
                print("⚠️ [ImageCreator] 安全フィルター検出。フォールバックプロンプトでリトライ")
                return try await generateSingleImage(prompt: fallbackPrompt)
            }
            throw error
        }
    }

    private func generateSingleImage(prompt: String) async throws -> UIImage {
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            print("⚠️ [ImageCreator] 初期化失敗: \(error)")
            throw GenerationError.imageGenerationFailed(underlying: "ImageCreator初期化失敗: \(error.localizedDescription)")
        }

        print("ℹ️ [ImageCreator] availableStyles: \(creator.availableStyles)")

        let style: ImagePlaygroundStyle
        if creator.availableStyles.contains(.illustration) {
            style = .illustration
        } else if let first = creator.availableStyles.first {
            style = first
        } else {
            print("⚠️ [ImageCreator] 利用可能なスタイルなし")
            throw GenerationError.imageGenerationFailed(underlying: "利用可能な画像スタイルがありません")
        }

        print("ℹ️ [ImageCreator] 生成開始 style=\(style), prompt=\(prompt.prefix(100))...")
        let images = creator.images(for: [.text(prompt)], style: style, limit: 1)
        for try await result in images {
            try Task.checkCancellation()
            print("✅ [ImageCreator] 画像生成成功")
            return UIImage(cgImage: result.cgImage)
        }
        print("⚠️ [ImageCreator] ストリームが空で終了")
        throw GenerationError.imageGenerationFailed(underlying: "画像が生成されませんでした")
    }

    /// プロンプトに文字禁止が含まれていなければ追加する
    private func ensureTextFreeConstraint(_ prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("no text") && lower.contains("no letters") {
            return prompt
        }
        return prompt + ", no text, no letters, no typography, no watermark, no logo, no signage"
    }
}
