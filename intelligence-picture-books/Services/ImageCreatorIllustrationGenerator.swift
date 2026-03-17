import Foundation
import UIKit
import ImagePlayground

/// Apple ImageCreator (Image Playground) を使ったイラスト生成サービス。
/// IllustrationPromptBuilder が構築した完成済みプロンプトを受け取って画像を生成する。
final class ImageCreatorIllustrationGenerator: IllustrationGenerating, @unchecked Sendable {

    // MARK: - Availability Check

    /// ImageCreator / ImagePlayground が使えるか事前チェック。
    /// シミュレーター・モデル未ダウンロード・言語非対応を早期検出してログに出す。
    func checkAvailability() async -> ImageCreatorAvailability {
        #if targetEnvironment(simulator)
        print("ℹ️ [ImageCreator] シミュレーター環境 — ImageCreator は利用不可")
        return .simulator
        #else
        do {
            let creator = try await ImageCreator()
            if creator.availableStyles.isEmpty {
                print("⚠️ [ImageCreator] availableStyles が空 — モデル未ダウンロードの可能性")
                return .noStylesAvailable
            }
            print("✅ [ImageCreator] 利用可能 (styles: \(creator.availableStyles))")
            return .available
        } catch {
            let desc = String(describing: error).lowercased()
            print("⚠️ [ImageCreator] 利用可否チェック失敗: \(error)")
            if desc.contains("unsupportedlanguage") || desc.contains("unsupported_language") {
                print("  → 原因: デバイス言語が非対応 — Settings > General > Language で English に変更してください")
                return .unsupportedLanguage
            }
            if desc.contains("unavailable") || desc.contains("initialization") || desc.contains("初期化")
                || desc.contains("asset") || desc.contains("model") {
                print("  → 原因: モデル未ダウンロードまたはデバイス非対応")
                return .modelUnavailable
            }
            print("  → 原因: 不明 (\(desc))")
            return .unknown(String(describing: error))
        }
        #endif
    }

    // MARK: - Generate

    func generateImage(prompt: String) async throws -> UIImage {
        let safePrompt = ensureTextFreeConstraint(prompt)
        return try await generateWithRetry(
            prompt: safePrompt,
            fallbackPrompt: "a cute cartoon animal in a peaceful nature scene, soft pastel watercolor, children's picture book illustration, gentle colors, no text, no letters, no watermark, no logo, no signage, no typography"
        )
    }

    /// 安全フィルターエラー時にフォールバックプロンプトで1回リトライ。
    /// 永続的エラー（言語非対応など）はリトライせず即 throw。
    private func generateWithRetry(prompt: String, fallbackPrompt: String) async throws -> UIImage {
        do {
            return try await generateSingleImage(prompt: prompt)
        } catch {
            let category = classify(error)
            print("⚠️ [ImageCreator] 生成失敗 [\(category.logLabel)]: \(error)")
            switch category {
            case .permanent:
                // デバイス非対応・言語非対応など — リトライしても無意味
                throw error
            case .safetyFilter:
                // コンテンツフィルター — フォールバックプロンプトでリトライ
                print("ℹ️ [ImageCreator] 安全フィルター → フォールバックプロンプトでリトライ")
                return try await generateSingleImage(prompt: fallbackPrompt)
            case .transient:
                throw error
            }
        }
    }

    private func generateSingleImage(prompt: String) async throws -> UIImage {
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            let category = classify(error)
            print("⚠️ [ImageCreator] 初期化失敗 [\(category.logLabel)]: \(error)")
            throw error
        }

        print("ℹ️ [ImageCreator] availableStyles: \(creator.availableStyles)")

        let style: ImagePlaygroundStyle
        if creator.availableStyles.contains(.illustration) {
            style = .illustration
        } else if let first = creator.availableStyles.first {
            style = first
        } else {
            print("⚠️ [ImageCreator] 利用可能なスタイルなし [device_not_supported]")
            throw GenerationError.imageGenerationFailed(underlying: "利用可能な画像スタイルがありません")
        }

        print("ℹ️ [ImageCreator] 生成開始 style=\(style), prompt=\(prompt.prefix(100))...")
        let images = creator.images(for: [.text(prompt)], style: style, limit: 1)
        for try await result in images {
            try Task.checkCancellation()
            print("✅ [ImageCreator] 画像生成成功")
            return UIImage(cgImage: result.cgImage)
        }
        print("⚠️ [ImageCreator] ストリームが空で終了 [empty_stream]")
        throw GenerationError.imageGenerationFailed(underlying: "画像が生成されませんでした")
    }

    // MARK: - Error Classification

    private enum ErrorCategory {
        case permanent    // デバイス非対応・言語非対応など — リトライ不要
        case safetyFilter // コンテンツフィルター — フォールバックプロンプトでリトライ
        case transient    // 一時的エラー — 呼び出し元でリトライ

        var logLabel: String {
            switch self {
            case .permanent:    return "permanent"
            case .safetyFilter: return "safety_filter"
            case .transient:    return "transient"
            }
        }
    }

    private func classify(_ error: Error) -> ErrorCategory {
        let desc = String(describing: error).lowercased()
        if desc.contains("unsupportedlanguage") || desc.contains("unsupported_language") {
            print("  → 原因: デバイス言語が非対応 (unsupportedLanguage) — 永続的エラー")
            return .permanent
        }
        if desc.contains("unavailable") || desc.contains("initialization") || desc.contains("初期化")
            || desc.contains("asset") || desc.contains("model") {
            print("  → 原因: モデル未ダウンロードまたはデバイス非対応 — 永続的エラー")
            return .permanent
        }
        if desc.contains("unsafe") || desc.contains("safety") || desc.contains("guardrail") {
            print("  → 原因: 安全フィルター — フォールバックプロンプトでリトライ")
            return .safetyFilter
        }
        print("  → 原因: 不明 (transient) [\(desc)]")
        return .transient
    }

    // MARK: - Helpers

    /// プロンプトに文字禁止制約が含まれていなければ追加する
    private func ensureTextFreeConstraint(_ prompt: String) -> String {
        let lower = prompt.lowercased()
        if lower.contains("no text") && lower.contains("no letters") {
            return prompt
        }
        return prompt + ", no text, no letters, no typography, no watermark, no logo, no signage"
    }
}
