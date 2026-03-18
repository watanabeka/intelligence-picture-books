import Foundation

/// PagePlan + CharacterSheet + VisualStyle から画像生成用プロンプトを組み立てるサービス。
///
/// **4層構造:**
/// - Layer ①  Scene    — シーン・ムード・オブジェクト・カメラ・場所
/// - Layer ②  Character — 視覚的アンカー（species/color/ears/face/eyes/accessory）+ シーンモード
/// - Layer ③  Style     — pastel watercolor 絵本スタイル
/// - Layer ④  Constraint — "no text in image" のみ（最小限）
enum IllustrationPromptBuilder {

    // MARK: - Fixed clauses

    /// Layer ③: 絵本スタイル基盤フレーズ（全プロンプト共通）
    private static let styleBaseClause =
        "children's picture book page illustration, soft rounded shapes, warm and friendly"

    /// Layer ④: テキスト禁止（最小限）
    private static let constraintClause = "no text in image"

    /// 表紙構図指示
    private static let coverCompositionClause =
        "centered character, full body view, beautiful background, eye-catching composition"

    // MARK: - Sanitize constants

    private static let dangerousPatterns: [String] = [
        "book cover", "front cover", "back cover", "book title", "title text",
        "book jacket", "dust jacket", "cover art", "book spine", "book page",
        "billboard", "storefront", "shop sign", "road sign", "street sign",
        "advertisement", "poster with", "neon sign", "banner with",
        "label on", "text saying", "words saying", "it says", "caption",
        "titled", "entitled", "inscribed", "written on",
    ]

    private static let textTriggers = [
        "sign", "poster", "billboard", "label", "text", "book", "page", "title"
    ]

    // MARK: - Character anchor (Layer ②)

    /// キャラクターを視覚的アンカーとして自然な英語で記述する。
    /// 「same exact」系の命令を使わず、具体的な外見の積み重ねで一貫性を確保する。
    static func buildCharacterAnchor(_ sheet: CharacterSheet) -> String {
        var parts: [String] = []

        // コア外見（種族 + 体色）
        if !sheet.species.isEmpty && !sheet.bodyColor.isEmpty {
            parts.append("a \(sheet.bodyColor) \(sheet.species)")
        } else if !sheet.species.isEmpty {
            parts.append("a \(sheet.species)")
        }

        // 耳（size + shape を合わせて1フレーズ）
        let earDesc = [sheet.earSize, sheet.earShape].filter { !$0.isEmpty }.joined(separator: " ")
        if !earDesc.isEmpty { parts.append("with \(earDesc) ears") }

        // 顔印象（faceImpression を優先、なければ faceShape + eyeStyle を個別に使用）
        if !sheet.faceImpression.isEmpty {
            parts.append(sheet.faceImpression)
        } else {
            if !sheet.faceShape.isEmpty { parts.append("\(sheet.faceShape) face") }
            if !sheet.eyeStyle.isEmpty  { parts.append("\(sheet.eyeStyle) eyes") }
        }

        // 胸毛（視覚的差別化アンカー）
        if !sheet.chestFur.isEmpty { parts.append(sheet.chestFur) }

        // 尻尾
        if !sheet.tailShape.isEmpty { parts.append("\(sheet.tailShape) tail") }

        // アクセサリー（強いビジュアルアンカー）
        if !sheet.accessory.isEmpty { parts.append("wearing \(sheet.accessory)") }

        return parts.joined(separator: ", ")
    }

    /// リトライ用キャラクターアンカー（通常版と同じ内容を繰り返して強調）
    private static func buildRetryCharacterAnchor(_ sheet: CharacterSheet) -> String {
        var parts: [String] = []
        if !sheet.species.isEmpty && !sheet.bodyColor.isEmpty {
            parts.append("the same \(sheet.bodyColor) \(sheet.species)")
        } else if !sheet.species.isEmpty {
            parts.append("the same \(sheet.species)")
        }
        if !sheet.accessory.isEmpty { parts.append("wearing \(sheet.accessory) as in all other pages") }
        let earDesc = [sheet.earSize, sheet.earShape].filter { !$0.isEmpty }.joined(separator: " ")
        if !earDesc.isEmpty { parts.append("\(earDesc) ears") }
        if !sheet.faceImpression.isEmpty { parts.append(sheet.faceImpression) }
        if !sheet.chestFur.isEmpty { parts.append(sheet.chestFur) }
        return parts.joined(separator: ", ")
    }

    /// SceneMode に応じたキャラクター人数フレーズ（自然な表現）
    /// duoの場合は secondaryCharacterHint を使って友達を具体的に描写する
    private static func sceneModeClause(for page: PagePlan) -> String {
        switch page.sceneMode {
        case .solo:
            return "the character is alone in the scene"
        case .duo:
            if !page.secondaryCharacterHint.isEmpty {
                return "alongside a friend who is \(page.secondaryCharacterHint)"
            }
            return "the character is with one friend in the scene"
        }
    }

    /// カメラアングルから構図スケールヒントを導出する
    private static func compositionScaleHint(for camera: String) -> String {
        let lower = camera.lowercased()
        if lower.contains("wide") || lower.contains("overhead") || lower.contains("establishing") {
            return "appears small in the frame"
        }
        return "fills most of the frame"
    }

    // MARK: - Page Prompt

    /// ページ用プロンプトを4層構造で構築する。
    static func buildPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // Layer ①: Scene
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a cheerful natural setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }
        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }
        if !page.camera.isEmpty {
            segments.append(page.camera)
            segments.append(compositionScaleHint(for: page.camera))
        }
        if !page.location.isEmpty {
            let safeLoc = IllustrationPromptTranslator.sanitizeJapanese(sanitizeForIllustration(page.location))
            if !safeLoc.isEmpty { segments.append("setting: \(safeLoc)") }
        }

        // Layer ②: Character（"the main character:" で主役を明示）
        segments.append("the main character: \(buildCharacterAnchor(characterSheet))")
        segments.append(sceneModeClause(for: page))

        // Layer ③: Style
        segments.append(styleBaseClause)
        segments.append(visualStyle.promptFragment)

        // Layer ④: Constraint
        segments.append(constraintClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Cover Prompt

    static func buildCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        let safeCover = IllustrationPromptTranslator.sanitizeJapanese(
            sanitizeForIllustration(coverPlan.coverPrompt)
        )
        if !safeCover.isEmpty { segments.append("scene: \(safeCover)") }

        if !coverPlan.worldKeywords.isEmpty {
            let safe = coverPlan.worldKeywords.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("world: \(safe.joined(separator: ", "))") }
        }

        segments.append(buildCharacterAnchor(characterSheet))
        segments.append(coverCompositionClause)
        segments.append(styleBaseClause)
        segments.append(visualStyle.promptFragment)
        segments.append(constraintClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Retry Prompts

    /// ページ画像リトライ用。差分強調 + 最低限の一貫性維持のみ。強い命令は使わない。
    static func buildRetryPagePrompt(
        page: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        // Layer ①: Scene（同じシーン内容を再提示）
        let safeScene = buildSafeScene(page.illustrationPrompt, fallbackSetting: "in a gentle peaceful setting")
        if !safeScene.isEmpty { segments.append("scene: \(safeScene)") }

        if !page.mood.isEmpty {
            segments.append("\(IllustrationPromptTranslator.moodToEnglish(page.mood)) atmosphere")
        }
        if !page.keyObjects.isEmpty {
            let safe = page.keyObjects.filter { !isTextTrigger($0) }
            if !safe.isEmpty { segments.append("featuring: \(safe.joined(separator: ", "))") }
        }
        if !page.camera.isEmpty {
            segments.append(page.camera)
            segments.append(compositionScaleHint(for: page.camera))
        }

        // Layer ②: Character（外見を2回繰り返して差分強調 — 命令口調は使わない）
        segments.append("the main character: \(buildCharacterAnchor(characterSheet))")
        segments.append(sceneModeClause(for: page))
        segments.append(buildRetryCharacterAnchor(characterSheet))

        // Layer ③: Style
        segments.append(styleBaseClause)
        segments.append(visualStyle.promptFragment)

        // Layer ④: Constraint
        segments.append(constraintClause)

        return segments.joined(separator: ", ")
    }

    /// 表紙画像リトライ用。
    static func buildRetryCoverPrompt(
        coverPlan: CoverPlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> String {
        var segments: [String] = []

        let safeCover = IllustrationPromptTranslator.sanitizeJapanese(
            sanitizeForIllustration(coverPlan.coverPrompt)
        )
        if !safeCover.isEmpty { segments.append("scene: \(safeCover)") }

        segments.append(buildCharacterAnchor(characterSheet))
        segments.append(buildRetryCharacterAnchor(characterSheet))
        segments.append(coverCompositionClause)
        segments.append(styleBaseClause)
        segments.append(visualStyle.promptFragment)
        segments.append(constraintClause)

        return segments.joined(separator: ", ")
    }

    // MARK: - Fallback Prompts

    static func buildFallbackPagePrompt(page: PagePlan, characterSheet: CharacterSheet) -> String {
        var parts: [String] = []
        if !characterSheet.species.isEmpty { parts.append(characterSheet.species) }
        if !characterSheet.bodyColor.isEmpty { parts.append(characterSheet.bodyColor) }
        parts.append(contentsOf: page.keyObjects.prefix(3).filter { !isTextTrigger($0) })
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
            print("ℹ️ [Builder] Scene too short → enriched: \"\(enriched)\"")
            return enriched
        case .empty:
            print("ℹ️ [Builder] Scene empty → using fallback setting")
            return fallbackSetting
        }
    }

    private static func isTextTrigger(_ word: String) -> Bool {
        let lower = word.lowercased()
        return textTriggers.contains(where: { lower.contains($0) })
    }
}
