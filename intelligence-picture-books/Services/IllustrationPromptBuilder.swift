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
    private static let pictureBookClause =
        "children's picture book interior page illustration, storybook art, " +
        "gentle and safe for young children, simple shapes, soft outlines, " +
        "full illustrated scene filling the frame, warm and friendly"

    /// 画像メディアの固定フレーズ（写真感・リアル感を排除）
    private static let illustrationMediumClause =
        "digital children's book illustration, flat art, soft lighting, no photorealism"

    /// キャラクター一貫性フレーズ（全ページ・全生成に必須）。
    /// キャラクターのズレ・追加キャラ混入を抑制する。
    private static let characterConsistencyClause =
        "same exact main character with identical appearance throughout the entire book, " +
        "same face shape and body proportions, same color — no character variation allowed, " +
        "only ONE character in the scene — absolutely no extra characters, " +
        "no additional animals, no people in background"

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

        // 1. 文字禁止を最初に強調
        segments.append(textFreeClause)

        // 2. 絵本スタイル・媒体の固定
        segments.append(pictureBookClause)
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター記述 + 一貫性強制（全ページ必須）
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        // 4. シーン記述（日本語除去 + 品質チェック + 意味補充）
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a cheerful natural setting")
        if !safeScene.isEmpty {
            segments.append("scene: \(safeScene)")
        }

        // 5. カメラ
        if !page.camera.isEmpty {
            segments.append("camera: \(page.camera)")
        }

        // 6. 場所（日本語除去）
        if !page.location.isEmpty {
            let safeLocation = IllustrationPromptTranslator.sanitizeJapanese(
                sanitizeForIllustration(page.location)
            )
            if !safeLocation.isEmpty { segments.append("setting: \(safeLocation)") }
        }

        // 7. ムード（包括的な変換テーブルを使用）
        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        // 8. キーオブジェクト
        if !page.keyObjects.isEmpty {
            let safeObjects = page.keyObjects.filter { !isTextTrigger($0) }
            if !safeObjects.isEmpty {
                segments.append("featuring: \(safeObjects.joined(separator: ", "))")
            }
        }

        // 9. 連続性ノート
        if !page.continuityNotes.isEmpty {
            segments.append("visual continuity: \(page.continuityNotes)")
        }

        // 10. 文字禁止を末尾にも再配置（強化）
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

        // 1. 文字禁止を先頭に
        segments.append(textFreeClause)

        // 2. キャラクターが主役の美しいシーンとして指示
        segments.append(
            "magical storybook character portrait scene, " +
            "hero character in a beautiful setting, " +
            "children's illustration, warm and inviting, " +
            "eye-catching composition, character as the clear focal point"
        )

        // 3. スタイル
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 4. キャラクター（完全記述）+ 一貫性強制
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        // 5. ワールド・カバープロンプト（日本語テーマ混入を除去）
        let safeCoverPrompt = IllustrationPromptTranslator.sanitizeJapanese(
            sanitizeForIllustration(coverPlan.coverPrompt)
        )
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

    /// リトライ時に適用するキャラクター固定フレーズ。
    /// キャラクターの種族・体色・アクセサリーを明示的に注入して AI の揺らぎを防ぐ。
    private static func retryEnforcementClause(for character: CharacterSheet) -> String {
        // キャラクターの具体的な外見を直接引用してロックする
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
        parts += [
            "ABSOLUTE RULE: only ONE character in the entire image",
            "zero extra animals anywhere in the scene",
            "zero additional people or creatures in background",
            "same flat soft-outline illustration style",
            "same pastel color palette as the rest of the book",
        ]
        return parts.joined(separator: ", ")
    }

    /// ページ画像のリトライ用プロンプトを構築する。通常生成より制約を強化してある。
    static func buildRetryPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle,
        storyTitle: String
    ) -> String {
        var segments: [String] = []

        // 1. 文字禁止 + キャラクターロックを先頭に二重配置
        segments.append(textFreeClause)
        segments.append(retryEnforcementClause(for: characterSheet))

        // 2. 絵本スタイル
        segments.append(pictureBookClause)
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)

        // 3. キャラクター（フル記述）+ 一貫性強制
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        // 4. シーン（品質保証付き日本語除去）
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a gentle peaceful setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        // 5. カメラ・ムード
        if !page.camera.isEmpty { segments.append("camera: \(page.camera)") }
        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }

        // 6. キーオブジェクト
        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }

        // 7. 末尾に強制フレーズを再配置（リトライなので三重強調）
        segments.append(characterConsistencyClause)
        segments.append(retryEnforcementClause(for: characterSheet))
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

        segments.append(
            "magical storybook character portrait scene, " +
            "hero character in a beautiful setting, " +
            "children's illustration, warm and inviting, " +
            "eye-catching composition, character as the clear focal point"
        )
        segments.append(illustrationMediumClause)
        segments.append(visualStyle.promptFragment)
        segments.append(characterSheet.promptFragment)
        segments.append(characterConsistencyClause)

        let safeCover = IllustrationPromptTranslator.sanitizeJapanese(
            sanitizeForIllustration(coverPlan.coverPrompt)
        )
        if !safeCover.isEmpty { segments.append(safeCover) }

        segments.append("centered character, full body or three-quarters view, beautiful background")

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
        return "\(characterSheet.species) \(characterSheet.bodyColor) \(IllustrationPromptTranslator.translateTheme(theme))"
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
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Private Helpers

    /// シーン記述を日本語除去 + 品質チェックして返す。
    /// sanitize 後に意味が薄すぎる場合は `fallbackSetting` を補充する。
    private static func buildSafeScene(_ raw: String, fallbackSetting: String) -> String {
        let sanitized = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(raw))
        switch IllustrationPromptTranslator.assessQuality(sanitized) {
        case .good:
            return sanitized
        case .tooShort:
            let enriched = "\(sanitized) \(fallbackSetting)"
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
        let triggers = ["sign", "poster", "billboard", "label", "text", "book", "page", "title"]
        return triggers.contains(where: { lower.contains($0) })
    }
}
