import Foundation

/// PagePlan + CharacterSheet + VisualStyle から画像生成用プロンプトを組み立てるサービス。
/// narration を直接画像生成に渡さず、専用の構造化プロンプトを構築する。
enum IllustrationPromptBuilder {

    // MARK: - 固定フレーズ定数

    /// 文字・テキスト類の完全禁止フレーズ（末尾に配置して強調）
    private static let textFreeClause =
        "absolutely no text of any kind, no letters, no alphabet, no numbers, " +
        "no words, no writing, no captions, no labels, no subtitles, no watermarks, " +
        "no logos, no signs, no billboards, no storefronts, no road signs, no posters, " +
        "no book title text, no cover text, no typography, pure illustration only"

    /// 絵本スタイルの固定フレーズ
    private static let pictureBookClause =
        "children's picture book interior page illustration, storybook art, " +
        "gentle and safe for young children, simple shapes, soft outlines, " +
        "full illustrated scene filling the frame, warm and friendly"

    /// 画像メディアの固定フレーズ（写真感・リアル感を排除）
    private static let illustrationMediumClause =
        "digital children's book illustration, flat art, soft lighting, no photorealism"

    /// 1キャラクターのみ（通常ページ）
    private static let singleCharacterClause =
        "main character only — no extra animals, no additional people in background"

    /// キャラクター一貫性フレーズ（全ページ共通部分）
    private static let characterConsistencyClause =
        "same exact main character with identical appearance throughout the entire book, " +
        "same face shape and body proportions, same color — no character variation allowed"

    /// ページのシーンが複数キャラクターを含む出会い・共演シーンか判定する
    private static func isCoCharacterScene(_ page: PagePlan) -> Bool {
        let lower = page.illustrationPrompt.lowercased()
        let triggers = [
            "meet", "friend", "together", "greet", "both", "two character",
            "playing with", "sitting with", "standing with", "walks with",
            "encounters", "introduce", "companion", "side by side", "with a "
        ]
        return triggers.contains(where: { lower.contains($0) })
    }

    /// ページ状況に応じたキャラクター人数制限フレーズを返す
    private static func characterCountClause(for page: PagePlan) -> String {
        if isCoCharacterScene(page) {
            return "exactly TWO characters in the scene — main character and one friend character only, " +
                   "no additional animals or people beyond these two"
        } else {
            return singleCharacterClause
        }
    }

    /// 表紙・表紙リトライで共通の「キャラクター主役シーン」指示
    private static let coverSceneClause =
        "magical storybook character portrait scene, " +
        "hero character in a beautiful setting, " +
        "children's illustration, warm and inviting, " +
        "eye-catching composition, character as the clear focal point"

    /// 表紙・表紙リトライで共通の構図指示
    private static let coverCompositionClause =
        "centered character, full body or three-quarters view, beautiful background, no empty space"

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

        // ① シーン内容を先頭に — AI の注意が最も強い位置に配置
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a cheerful natural setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        if !page.keyObjects.isEmpty {
            let safeObjects = page.keyObjects.filter { !isTextTrigger($0) }
            if !safeObjects.isEmpty { segments.append("featuring: \(safeObjects.joined(separator: ", "))") }
        }

        if !page.camera.isEmpty { segments.append("camera: \(page.camera)") }

        if !page.location.isEmpty {
            let safeLocation = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(page.location))
            if !safeLocation.isEmpty { segments.append("setting: \(safeLocation)") }
        }

        if !page.continuityNotes.isEmpty { segments.append("visual continuity: \(page.continuityNotes)") }

        // ② キャラクター情報（キャラ固定はシーン直後）
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)
        segments.append(characterCountClause(for: page))

        // ③ スタイル・制約は後半（シーン内容への干渉を最小化）
        segments.append(pictureBookClause)
        segments.append(visualStyle.promptFragment)
        segments.append(illustrationMediumClause)
        segments.append(textFreeClause)
        return segments.joined(separator: ", ")
    }

    // MARK: - Cover Prompt

    /// 表紙用の画像プロンプトを構築する。
    /// "book cover" や "front cover" は意図的に使わない（タイトル文字生成を防ぐため）。
    static func buildCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        segments.append(textFreeClause)
        segments.append(coverSceneClause)
        segments.append(illustrationMediumClause)
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

    // MARK: - Retry Prompt (stronger constraints)

    /// リトライ時に適用するキャラクター固定フレーズ。
    /// キャラクターの種族・体色・アクセサリーを明示的に注入して AI の揺らぎを防ぐ。
    private static func retryEnforcementClause(for character: CharacterSheet, page: PagePlan) -> String {
        var lock = "STRICT CHARACTER LOCK"
        if !character.species.isEmpty && !character.bodyColor.isEmpty {
            lock += ": the \(character.bodyColor) \(character.species) must look IDENTICAL to all other pages"
        } else if !character.species.isEmpty {
            lock += ": the \(character.species) must look IDENTICAL to all other pages"
        }

        var parts = [
            lock,
            "same exact face shape, same exact body proportions, same exact \(!character.bodyColor.isEmpty ? "\(character.bodyColor) color" : "color scheme")",
        ]
        if !character.accessory.isEmpty {
            parts.append("must be wearing \(character.accessory) — same as every other page")
        }
        if isCoCharacterScene(page) {
            parts += [
                "exactly TWO characters — main character and one friend, no others",
                "same flat soft-outline illustration style",
                "same pastel color palette as the rest of the book",
            ]
        } else {
            parts += [
                "ABSOLUTE RULE: only ONE character in the entire image",
                "zero extra animals anywhere in the scene",
                "zero additional people or creatures in background",
                "same flat soft-outline illustration style",
                "same pastel color palette as the rest of the book",
            ]
        }
        return parts.joined(separator: ", ")
    }

    /// ページ画像のリトライ用プロンプトを構築する。通常生成より制約を強化してある。
    static func buildRetryPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // ① シーン内容を先頭に
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a gentle peaceful setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }

        if !page.camera.isEmpty { segments.append("camera: \(page.camera)") }

        // ② キャラクター固定（リトライ専用: 二重強調）
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)
        segments.append(characterCountClause(for: page))
        segments.append(retryEnforcementClause(for: characterSheet, page: page))
        segments.append(retryEnforcementClause(for: characterSheet, page: page))

        // ③ スタイル・制約
        segments.append(pictureBookClause)
        segments.append(visualStyle.promptFragment)
        segments.append(illustrationMediumClause)
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
        segments.append(retryEnforcementClause(for: characterSheet))
        segments.append(coverSceneClause)
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        let safeCover = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(coverPlan.coverPrompt))
        if !safeCover.isEmpty { segments.append(safeCover) }

        segments.append(coverCompositionClause)
        segments.append(characterConsistencyClause)
        segments.append(retryEnforcementClause(for: characterSheet))
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

    /// 文字・テキストの生成を誘発しやすいフレーズをシーン記述から除去する
    private static func sanitizeForIllustration(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        for pattern in dangerousPatterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
        }
        // 複数スペースを1つに（O(n) 単一パス）
        result = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        return result
    }

    // MARK: - Private Helpers

    /// シーン記述を日本語除去 + 品質チェックして返す。
    /// sanitize 後に意味が薄すぎる場合は `fallbackSetting` を補充する。
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

    /// テキスト生成を誘発しやすいキーワードか判定
    private static func isTextTrigger(_ word: String) -> Bool {
        let lower = word.lowercased()
        return textTriggers.contains(where: { lower.contains($0) })
    }
}
