import Foundation

/// PagePlan + CharacterSheet + VisualStyle から画像生成用プロンプトを組み立てるサービス。
/// narration を直接画像生成に渡さず、専用の構造化プロンプトを構築する。
///
/// **プロンプト設計方針（生成成功率優先）:**
/// - negative clause は最小限（"no text in image" のみ）— 長い禁止リストは fallback を誘発しやすい
/// - シーン内容を先頭に配置 — AI の注意が最も強い位置に重要情報を置く
/// - キャラクター表現は自然な英語 — 命令口調・ALL CAPS は避ける
enum IllustrationPromptBuilder {

    // MARK: - 固定フレーズ定数

    /// テキスト禁止（最小限）
    private static let textFreeClause = "no text in image"

    /// 絵本スタイル（簡略版）
    private static let pictureBookClause =
        "children's picture book illustration, soft outlines, warm and friendly"

    /// キャラクター一貫性（自然な表現）
    private static let characterConsistencyClause =
        "consistent main character throughout the book, same color and appearance"

    /// 表紙・表紙リトライで共通の「キャラクター主役シーン」指示
    private static let coverSceneClause =
        "storybook character portrait, hero character in a beautiful setting, " +
        "warm and inviting, character as the clear focal point"

    /// 表紙・表紙リトライで共通の構図指示
    private static let coverCompositionClause =
        "centered character, full body or three-quarters view, beautiful background"

    // MARK: - Co-character detection

    /// ページのシーンが出会い・共演シーンか判定する
    private static func isCoCharacterScene(_ page: PagePlan) -> Bool {
        let lower = page.illustrationPrompt.lowercased()
        let triggers = [
            "meet", "friend", "together", "greet", "both",
            "playing with", "sitting with", "standing with", "walks with",
            "encounters", "introduce", "companion", "side by side", "with a "
        ]
        return triggers.contains(where: { lower.contains($0) })
    }

    /// ページに応じたキャラクター人数フレーズを返す（自然な表現）
    private static func characterCountClause(for page: PagePlan) -> String {
        isCoCharacterScene(page)
            ? "main character and a friend in the scene"
            : "main character in the scene"
    }

    // MARK: - Sanitize 定数

    /// 文字・テキスト生成を誘発しやすいフレーズパターン
    private static let dangerousPatterns: [String] = [
        "book cover", "front cover", "back cover", "book title", "title text",
        "book jacket", "dust jacket", "cover art", "book spine", "book page",
        "billboard", "storefront", "shop sign", "road sign", "street sign",
        "advertisement", "poster with", "neon sign", "banner with",
        "label on", "text saying", "words saying", "it says", "caption",
        "titled", "entitled", "inscribed", "written on",
    ]

    /// テキスト生成を誘発しやすいキーワード（keyObjects フィルタ用）
    private static let textTriggers = ["sign", "poster", "billboard", "label", "text", "book", "page", "title"]

    // MARK: - Page Prompt

    /// ページ用の画像プロンプトを構築する。
    /// シーン内容を先頭に配置し、スタイル・禁止制約は末尾に集約する。
    static func buildPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // ① シーン内容（先頭 — AI の注意が最も強い位置）
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a cheerful natural setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        if !page.keyObjects.isEmpty {
            let safeObjects = page.keyObjects.filter { !isTextTrigger($0) }
            if !safeObjects.isEmpty { segments.append("featuring: \(safeObjects.joined(separator: ", "))") }
        }

        if !page.camera.isEmpty { segments.append(page.camera) }

        if !page.location.isEmpty {
            let safeLocation = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(page.location))
            if !safeLocation.isEmpty { segments.append("setting: \(safeLocation)") }
        }

        // ② キャラクター（シーン直後）
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)
        segments.append(characterCountClause(for: page))

        // ③ スタイル・制約（末尾）
        segments.append(pictureBookClause)
        segments.append(visualStyle.promptFragment)
        segments.append(textFreeClause)
        return segments.joined(separator: ", ")
    }

    // MARK: - Cover Prompt

    /// 表紙用の画像プロンプトを構築する。
    static func buildCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        segments.append(coverSceneClause)
        segments.append(visualStyle.promptFragment)
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        let safeCoverPrompt = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(coverPlan.coverPrompt))
        if !safeCoverPrompt.isEmpty { segments.append(safeCoverPrompt) }

        if !coverPlan.worldKeywords.isEmpty {
            let safeKeywords = coverPlan.worldKeywords.filter { !isTextTrigger($0) }
            if !safeKeywords.isEmpty { segments.append("world: \(safeKeywords.joined(separator: ", "))") }
        }

        segments.append(coverCompositionClause)
        segments.append(textFreeClause)
        return segments.joined(separator: ", ")
    }

    // MARK: - Retry Prompt

    /// リトライ時のキャラクター固定フレーズ（軽量版）
    private static func retryCharacterClause(for character: CharacterSheet) -> String {
        var parts: [String] = []
        if !character.species.isEmpty && !character.bodyColor.isEmpty {
            parts.append("the \(character.bodyColor) \(character.species) with the same appearance as all other pages")
        } else if !character.species.isEmpty {
            parts.append("the \(character.species) with the same appearance as all other pages")
        }
        if !character.accessory.isEmpty {
            parts.append("wearing \(character.accessory)")
        }
        return parts.isEmpty ? characterConsistencyClause : parts.joined(separator: ", ")
    }

    /// ページ画像のリトライ用プロンプトを構築する。
    static func buildRetryPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // ① シーン内容（先頭）
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a gentle peaceful setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }

        if !page.camera.isEmpty { segments.append(page.camera) }

        // ② キャラクター固定（リトライ: 2回繰り返し）
        segments.append(characterSheet.promptFragment)
        segments.append(retryCharacterClause(for: characterSheet))
        segments.append(characterCountClause(for: page))
        segments.append(retryCharacterClause(for: characterSheet))

        // ③ スタイル・制約（末尾）
        segments.append(pictureBookClause)
        segments.append(visualStyle.promptFragment)
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

        segments.append(coverSceneClause)
        segments.append(visualStyle.promptFragment)
        segments.append(characterSheet.promptFragment)
        segments.append(retryCharacterClause(for: characterSheet))
        segments.append(characterConsistencyClause)

        let safeCover = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(coverPlan.coverPrompt))
        if !safeCover.isEmpty { segments.append(safeCover) }

        segments.append(coverCompositionClause)
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
        parts.append(IllustrationPromptTranslator.moodToEnglish(page.mood))
        return parts.joined(separator: " ")
    }

    static func buildFallbackCoverPrompt(characterSheet: CharacterSheet, theme: String) -> String {
        "\(characterSheet.species) \(characterSheet.bodyColor) \(IllustrationPromptTranslator.translateTheme(theme))"
    }

    // MARK: - Sanitize

    private static func sanitizeForIllustration(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for pattern in dangerousPatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        result = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        return result
    }

    // MARK: - Private Helpers

    private static func buildSafeScene(_ raw: String, fallbackSetting: String) -> String {
        let result = IllustrationPromptTranslator.sanitizeJapaneseVerbose(sanitizeForIllustration(raw))
        switch result.quality {
        case .good:
            return result.text
        case .tooShort:
            let enriched = "\(result.text) \(fallbackSetting)"
            print("ℹ️ [Builder] Scene too short after sanitize → enriched: \"\(enriched)\"")
            return enriched
        case .empty:
            print("ℹ️ [Builder] Scene empty after sanitize → using fallback setting")
            return fallbackSetting
        }
    }

    private static func isTextTrigger(_ word: String) -> Bool {
        let lower = word.lowercased()
        return textTriggers.contains(where: { lower.contains($0) })
    }
}
