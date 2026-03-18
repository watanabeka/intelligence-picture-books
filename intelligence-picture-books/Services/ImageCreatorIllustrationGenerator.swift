import Foundation
import UIKit
import ImagePlayground

/// Apple ImageCreator (Image Playground) を使ったイラスト生成サービス。
/// IllustrationPromptBuilder が構築した完成済みプロンプトを受け取って画像を生成する。
final class ImageCreatorIllustrationGenerator: IllustrationGenerating, @unchecked Sendable {

    // MARK: - Availability Check

    /// ImageCreator / ImagePlayground が使えるか事前チェック。
    ///
    /// **制限事項**: `ImageCreator.Error.unsupportedLanguage` は
    /// `ImageCreator()` 初期化ではなく `images(for:)` ストリーム内でスローされる。
    /// そのため、このメソッドは日本語UIデバイスで `.available` を返す場合がある。
    /// 実際の言語非対応は最初の生成試行で `classify()` が検出し、
    /// 呼び出し元が `imagePlaygroundUnavailable = true` にセットして以降の生成をスキップする。
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
            print("✅ [ImageCreator] 初期化OK (styles: \(creator.availableStyles))")
            print("ℹ️ [ImageCreator] 注意: unsupportedLanguage は生成時にのみ検出可能")
            return .available
        } catch {
            // unsupportedLanguage が init 時にスローされる iOS バージョンへの対応
            return classifyInitError(error)
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
                throw error
            case .safetyFilter:
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
            print("⚠️ [ImageCreator] 初期化失敗 [\(classifyInitError(error).reason)]: \(error)")
            throw error
        }

        print("ℹ️ [ImageCreator] availableStyles: \(creator.availableStyles)")

        let style: ImagePlaygroundStyle
        if creator.availableStyles.contains(.illustration) {
            style = .illustration
        } else if let first = creator.availableStyles.first {
            style = first
        } else {
            print("⚠️ [ImageCreator] 利用可能なスタイルなし [no_styles]")
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

    /// 生成フェーズのエラーを分類する。
    ///
    /// **分類根拠:**
    /// - `ImageCreator.Error.unsupportedLanguage`:
    ///   デバイスのシステム言語が原因。プロンプトの言語・内容は無関係。
    ///   日本語UI + 英語prompt でも発生する（シナリオ検証済み）。
    ///   → permanent（デバイス言語を変えない限り回復不能）
    ///
    /// - `ImageCreator.Error.contentPolicyViolation` / safety 系:
    ///   プロンプト内容が原因。フォールバックプロンプトで回避可能。
    ///   → safetyFilter
    ///
    /// - その他（ネットワーク・タイムアウト・未知エラーなど）:
    ///   広すぎる文字列マッチで permanent に誤分類しないよう transient とする。
    ///   → transient（呼び出し元が2回リトライ後にフォールバックへ）
    private func classify(_ error: Error) -> ErrorCategory {
        // 【優先】型安全なキャスト — 文字列表現に依存しない正確な判定
        if let ice = error as? ImageCreator.Error {
            switch ice {
            case .unsupportedLanguage:
                print("  → 型: ImageCreator.Error.unsupportedLanguage")
                print("  → 原因: デバイスのシステム言語が非対応（プロンプト言語は無関係）")
                print("  → 確認: Settings > General > Language が日本語になっていませんか？")
                return .permanent
            default:
                // 未知の ImageCreator.Error ケースは内容を記録して transient 扱い
                print("  → 型: ImageCreator.Error (ケース: \(ice)) — transient として扱う")
                return .transient
            }
        }

        // 型キャスト失敗時のフォールバック（文字列マッチ）
        // ※ 広すぎる語（"unavailable", "initialization"）は除外 — 一時的障害と混在するため
        let desc = String(describing: error).lowercased()
        print("  → 型: \(type(of: error))")
        print("  → 内容: \(String(describing: error))")

        // 言語非対応（型キャストが取りこぼした場合の保険）
        if desc.contains("unsupportedlanguage") {
            print("  → 判定: permanent (unsupportedLanguage — 文字列マッチ)")
            return .permanent
        }

        // 安全フィルター系
        if desc.contains("contentpolicyviolation") || desc.contains("unsafe")
            || desc.contains("safety") || desc.contains("guardrail") {
            print("  → 判定: safety_filter")
            return .safetyFilter
        }

        // それ以外はすべて transient — 2回リトライ後にフォールバックへ
        print("  → 判定: transient (未分類)")
        return .transient
    }

    /// 初期化フェーズのエラーから `ImageCreatorAvailability` を返す。
    private func classifyInitError(_ error: Error) -> ImageCreatorAvailability {
        print("⚠️ [ImageCreator] 初期化エラー: \(type(of: error)) — \(error)")
        if let ice = error as? ImageCreator.Error {
            switch ice {
            case .unsupportedLanguage:
                print("  → ImageCreator.Error.unsupportedLanguage (init 時に検出)")
                return .unsupportedLanguage
            default:
                print("  → ImageCreator.Error (ケース: \(ice))")
                return .unknown(String(describing: ice))
            }
        }
        // 型キャスト失敗 — 文字列マッチで補完
        let desc = String(describing: error).lowercased()
        if desc.contains("unsupportedlanguage") {
            return .unsupportedLanguage
        }
        return .unknown(String(describing: error))
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
