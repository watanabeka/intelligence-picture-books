import Foundation

/// PagePlan + CharacterSheet + VisualStyle から画像生成用プロンプトを組み立てるサービス。
/// narration を直接画像生成に渡さず、専用の構造化プロンプトを構築する。
enum IllustrationPromptBuilder {

    // MARK: - 固定プロンプト要素

    /// すべての画像に含める文字禁止フレーズ
    private static let textFreeClause =
        "no text, no letters, no typography, no writing, no watermark, no logo, no signage, no book cover title text, no words, no numbers, no caption"

    /// すべての画像に含める絵本スタイルフレーズ
    private static let pictureBookClause =
        "children's picture book illustration, gentle and safe for young children, simple shapes, soft outlines"

    // MARK: - Page Prompt

    /// ページ用の画像プロンプトを構築する。
    /// 毎回 characterSheet, visualStyle, 文字禁止, カメラ等を含める。
    static func buildPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle,
        storyTitle: String
    ) -> String {
        var segments: [String] = []

        // 1. 絵本スタイルの固定文
        segments.append(pictureBookClause)

        // 2. ビジュアルスタイル
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター記述（毎回注入）
        segments.append(characterSheet.promptFragment)

        // 4. シーン記述
        if !page.illustrationPrompt.isEmpty {
            segments.append("scene: \(page.illustrationPrompt)")
        }

        // 5. カメラ
        if !page.camera.isEmpty {
            segments.append("camera: \(page.camera)")
        }

        // 6. 場所
        if !page.location.isEmpty {
            segments.append("setting: \(page.location)")
        }

        // 7. ムード
        if !page.mood.isEmpty {
            let moodEnglish = moodToEnglish(page.mood)
            segments.append("\(moodEnglish) atmosphere")
        }

        // 8. キーオブジェクト
        if !page.keyObjects.isEmpty {
            segments.append("featuring: \(page.keyObjects.joined(separator: ", "))")
        }

        // 9. 連続性ノート
        if !page.continuityNotes.isEmpty {
            segments.append("continuity: \(page.continuityNotes)")
        }

        // 10. ページ位置情報
        segments.append("page \(page.pageNumber) of a picture book")

        // 11. 文字禁止（最後に強調）
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Cover Prompt

    /// 表紙用の画像プロンプトを構築する。
    /// 表紙は本文ページとは独立。タイトル文字は画像に入れない。
    static func buildCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // 1. 表紙であることを明示
        segments.append("children's picture book front cover illustration")

        // 2. ビジュアルスタイル
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター（メイン）
        segments.append(characterSheet.promptFragment)

        // 4. カバープロンプト
        if !coverPlan.coverPrompt.isEmpty {
            segments.append(coverPlan.coverPrompt)
        }

        // 5. ワールドキーワード
        if !coverPlan.worldKeywords.isEmpty {
            segments.append("world elements: \(coverPlan.worldKeywords.joined(separator: ", "))")
        }

        // 6. 明るく魅力的な表紙
        segments.append("warm, inviting, eye-catching composition, centered character")

        // 7. 文字禁止（表紙テキストは UI レイヤーで重ねる）
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Fallback Prompt

    /// フォールバック用の簡易プロンプトを構築する。
    /// FallbackRenderer でも本文とモチーフを一致させる。
    static func buildFallbackPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet
    ) -> String {
        var parts: [String] = []
        parts.append(characterSheet.species)
        if !page.keyObjects.isEmpty {
            parts.append(contentsOf: page.keyObjects.prefix(3))
        }
        parts.append(page.mood)
        return parts.joined(separator: " ")
    }

    /// フォールバック用の表紙プロンプト
    static func buildFallbackCoverPrompt(
        characterSheet: CharacterSheet,
        theme: String
    ) -> String {
        return "\(characterSheet.species) \(theme)"
    }

    // MARK: - Mood Translation

    /// 日本語のムードを英語に変換
    private static func moodToEnglish(_ mood: String) -> String {
        let moodMap: [(japanese: String, english: String)] = [
            ("わくわく", "exciting and adventurous"),
            ("たのしい", "cheerful and happy"),
            ("にぎやか", "lively and bustling"),
            ("どきどき", "thrilling and suspenseful"),
            ("ゆうき", "brave and courageous"),
            ("しんみり", "calm and contemplative"),
            ("おだやか", "peaceful and serene"),
            ("ふしぎ", "mysterious and wondrous"),
            ("きらきら", "sparkling and magical"),
            ("やさしい", "gentle and tender"),
            ("あたたかい", "warm and cozy"),
            ("ほっこり", "heartwarming"),
            ("かなしい", "bittersweet and touching"),
            ("うれしい", "joyful"),
        ]
        for entry in moodMap {
            if mood.contains(entry.japanese) {
                return entry.english
            }
        }
        return "gentle and warm"
    }
}
