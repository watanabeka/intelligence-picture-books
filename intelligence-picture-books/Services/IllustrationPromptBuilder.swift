import Foundation

/// PagePlan + CharacterSheet + VisualStyle から画像生成用プロンプトを組み立てるサービス。
/// narration を直接画像生成に渡さず、専用の構造化プロンプトを構築する。
enum IllustrationPromptBuilder {

    // MARK: - 固定フレーズ定数

    /// 文字・テキスト類の完全禁止フレーズ（先頭と末尾に重複配置して強調）
    private static let textFreeClause =
        "absolutely no text of any kind, no letters, no alphabet, no numbers, " +
        "no words, no writing, no captions, no labels, no subtitles, no watermarks, " +
        "no logos, no signs, no billboards, no storefronts, no road signs, no posters, " +
        "no book title text, no cover text, no typography, pure illustration only"

    /// 絵本スタイルの固定フレーズ
    /// "front cover" や "book cover" は意図的に除外（タイトル文字の描画を誘発するため）
    private static let pictureBookClause =
        "children's picture book interior page illustration, storybook art, " +
        "gentle and safe for young children, simple shapes, soft outlines, " +
        "full illustrated scene filling the frame, warm and friendly"

    /// 画像メディアの固定フレーズ（写真感・リアル感を排除）
    private static let illustrationMediumClause =
        "digital children's book illustration, flat art, soft lighting, no photorealism"

    // MARK: - Page Prompt

    /// ページ用の画像プロンプトを構築する。
    /// 文字禁止を先頭と末尾の両方に配置して AI への影響を最大化。
    static func buildPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle,
        storyTitle: String
    ) -> String {
        var segments: [String] = []

        // 1. 文字禁止を最初に強調（先頭に置くほど重みが増す）
        segments.append(textFreeClause)

        // 2. 絵本スタイル・媒体の固定
        segments.append(pictureBookClause)
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター記述（毎回全情報を注入、ヘッダーで強調）
        segments.append(characterSheet.promptFragment)

        // 4. シーン記述（危険要素を除去してから追加）
        let safeScene = sanitizeForIllustration(page.illustrationPrompt)
        if !safeScene.isEmpty {
            segments.append("scene: \(safeScene)")
        }

        // 5. カメラ
        if !page.camera.isEmpty {
            segments.append("camera: \(page.camera)")
        }

        // 6. 場所
        if !page.location.isEmpty {
            let safeLocation = sanitizeForIllustration(page.location)
            if !safeLocation.isEmpty { segments.append("setting: \(safeLocation)") }
        }

        // 7. ムード
        if !page.mood.isEmpty {
            segments.append("\(moodToEnglish(page.mood)) atmosphere")
        }

        // 8. キーオブジェクト
        if !page.keyObjects.isEmpty {
            let safeObjects = page.keyObjects.filter { !isTextTrigger($0) }
            if !safeObjects.isEmpty {
                segments.append("featuring: \(safeObjects.joined(separator: ", "))")
            }
        }

        // 9. 連続性ノート（ページ番号は含めない）
        if !page.continuityNotes.isEmpty {
            segments.append("visual continuity: \(page.continuityNotes)")
        }

        // 10. 文字禁止を末尾にも再配置（強化）
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Cover Prompt

    /// 表紙用の画像プロンプトを構築する。
    /// "book cover" や "front cover" というフレーズを意図的に使わない（タイトル文字生成を防ぐため）。
    /// タイトル文字は画像に入れず、UIレイヤーで重ねる。
    static func buildCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // 1. 文字禁止を先頭に
        segments.append(textFreeClause)

        // 2. 「キャラクターが主役の美しいシーン」として指示
        //    "book cover" は文字描画を強く誘発するため使用しない
        segments.append(
            "magical storybook character portrait scene, " +
            "hero character in a beautiful setting, " +
            "children's illustration, warm and inviting, " +
            "eye-catching composition, character as the clear focal point"
        )

        // 3. スタイル
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 4. キャラクター（完全記述）
        segments.append(characterSheet.promptFragment)

        // 5. ワールド・カバープロンプト（sanitize済み）
        let safeCoverPrompt = sanitizeForIllustration(coverPlan.coverPrompt)
        if !safeCoverPrompt.isEmpty {
            segments.append(safeCoverPrompt)
        }

        // 6. 世界観キーワード
        if !coverPlan.worldKeywords.isEmpty {
            let safeKeywords = coverPlan.worldKeywords.filter { !isTextTrigger($0) }
            if !safeKeywords.isEmpty {
                segments.append("world: \(safeKeywords.joined(separator: ", "))")
            }
        }

        // 7. 構図の固定
        segments.append("centered character, full body or three-quarters view, beautiful background, no empty space")

        // 8. 文字禁止を末尾にも再配置
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Retry Prompt (stronger constraints)

    /// リトライ時に適用する追加制約。文字・他キャラ混入・スタイル崩れを強力に抑制する。
    private static let retryEnforcementClause =
        "exact same main character as every other page of this book, " +
        "strictly consistent character appearance throughout, " +
        "only ONE character in the scene — no extra characters, no people in background, " +
        "same illustration style and color palette as the rest of the book"

    /// ページ画像のリトライ用プロンプトを構築する。通常生成より制約を強化してある。
    static func buildRetryPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle,
        storyTitle: String
    ) -> String {
        var segments: [String] = []

        // 1. 文字禁止 + リトライ制約を先頭に二重配置
        segments.append(textFreeClause)
        segments.append(retryEnforcementClause)

        // 2. 絵本スタイル
        segments.append(pictureBookClause)
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター（フル記述）
        segments.append(characterSheet.promptFragment)

        // 4. シーン
        let safeScene = sanitizeForIllustration(page.illustrationPrompt)
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        // 5. カメラ・ムード
        if !page.camera.isEmpty { segments.append("camera: \(page.camera)") }
        if !page.mood.isEmpty { segments.append("\(moodToEnglish(page.mood)) atmosphere") }

        // 6. キーオブジェクト
        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }

        // 7. 末尾にも二重強調（リトライなのでさらに重みを増やす）
        segments.append(retryEnforcementClause)
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    /// 表紙画像のリトライ用プロンプトを構築する。
    static func buildRetryCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        segments.append(textFreeClause)
        segments.append(retryEnforcementClause)

        segments.append(
            "magical storybook character portrait scene, " +
            "hero character in a beautiful setting, " +
            "children's illustration, warm and inviting, " +
            "eye-catching composition, character as the clear focal point"
        )
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)
        segments.append(characterSheet.promptFragment)

        let safeCover = sanitizeForIllustration(coverPlan.coverPrompt)
        if !safeCover.isEmpty { segments.append(safeCover) }

        segments.append("centered character, full body or three-quarters view, beautiful background")

        segments.append(retryEnforcementClause)
        segments.append(textFreeClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Fallback Prompt

    static func buildFallbackPagePrompt(page: PagePlan, characterSheet: CharacterSheet) -> String {
        var parts: [String] = []
        parts.append(characterSheet.species)
        if !characterSheet.bodyColor.isEmpty { parts.append(characterSheet.bodyColor) }
        if !page.keyObjects.isEmpty {
            parts.append(contentsOf: page.keyObjects.prefix(3).filter { !isTextTrigger($0) })
        }
        parts.append(page.mood)
        return parts.joined(separator: " ")
    }

    static func buildFallbackCoverPrompt(characterSheet: CharacterSheet, theme: String) -> String {
        return "\(characterSheet.species) \(characterSheet.bodyColor) \(theme)"
    }

    // MARK: - Sanitize

    /// 文字・テキストの生成を誘発しやすいフレーズをシーン記述から除去する
    static func sanitizeForIllustration(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let dangerousPatterns: [String] = [
            "book cover", "front cover", "back cover", "book title", "title text",
            "book jacket", "dust jacket", "cover art", "book spine", "book page",
            "billboard", "storefront", "shop sign", "road sign", "street sign",
            "advertisement", "poster with", "neon sign", "banner with",
            "label on", "text saying", "words saying", "it says", "caption",
            "titled", "entitled", "inscribed", "written on",
        ]
        var result = text
        for pattern in dangerousPatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        // 複数スペースを1つに
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// テキスト生成を誘発しやすいキーワードか判定
    private static func isTextTrigger(_ word: String) -> Bool {
        let lower = word.lowercased()
        let triggers = ["sign", "poster", "billboard", "label", "text", "book", "page", "title"]
        return triggers.contains(where: { lower.contains($0) })
    }

    // MARK: - Mood Translation

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
            ("うれしい", "joyful and delightful"),
        ]
        for entry in moodMap {
            if mood.contains(entry.japanese) { return entry.english }
        }
        return "gentle and warm"
    }
}
