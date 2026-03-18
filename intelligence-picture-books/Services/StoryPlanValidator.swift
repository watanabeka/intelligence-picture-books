import Foundation

/// StoryPlan の検証と修正を行うサービス。
/// 生成された StoryPlan をそのまま使わず、品質を担保する。
enum StoryPlanValidator {

    // MARK: - Validation Result

    struct ValidationResult: Sendable {
        var isValid: Bool
        var issues: [String]
        var correctedPlan: StoryPlan
    }

    // MARK: - Public

    /// StoryPlan を検証し、問題があれば自動修正した結果を返す。
    static func validate(_ plan: StoryPlan, expectedPageCount: Int) -> ValidationResult {
        var corrected = plan
        var issues: [String] = []

        // ページ数チェック
        if corrected.pages.count != expectedPageCount {
            issues.append("Page count mismatch: expected \(expectedPageCount), got \(corrected.pages.count)")
            corrected = fixPageCount(corrected, expected: expectedPageCount)
        }

        // ページ番号の正規化
        corrected = normalizePageNumbers(corrected)

        // キャラクターシートの検証
        if !isCharacterSheetValid(corrected.characterSheet) {
            issues.append("Character sheet incomplete")
            corrected.characterSheet = enforceCharacterConsistency(corrected.characterSheet, theme: corrected.theme)
        }

        // 各ページの検証
        for i in corrected.pages.indices {
            let page = corrected.pages[i]

            // narration が空でないか
            if page.narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Page \(page.pageNumber): narration is empty")
                corrected.pages[i].narration = fillMissingNarration(
                    pageNumber: page.pageNumber,
                    totalPages: corrected.pages.count,
                    theme: corrected.theme,
                    characterName: corrected.characterSheet.mainCharacterName
                )
            }

            // illustrationPrompt が空でないか
            if page.illustrationPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append("Page \(page.pageNumber): illustrationPrompt is empty")
                corrected.pages[i] = fillMissingPrompt(corrected.pages[i], theme: corrected.theme)
            }

            // forbiddenElements に文字禁止を必ず含める
            corrected.pages[i] = injectTextFreeConstraint(corrected.pages[i])

            // keyObjects があるか
            if page.keyObjects.isEmpty {
                issues.append("Page \(page.pageNumber): keyObjects is empty")
                corrected.pages[i].keyObjects = extractKeyObjects(from: page.illustrationPrompt)
            }

            // mood の正規化
            corrected.pages[i] = normalizeMood(corrected.pages[i])
        }

        // ページ間の一貫性チェック
        corrected = enforcePageContinuity(corrected)

        // 表紙プランの検証
        corrected = validateCoverPlan(corrected)

        let isValid = issues.isEmpty
        return ValidationResult(isValid: isValid, issues: issues, correctedPlan: corrected)
    }

    // MARK: - Fix Functions

    /// ページ数を期待値に合わせる
    private static func fixPageCount(_ plan: StoryPlan, expected: Int) -> StoryPlan {
        var corrected = plan
        if corrected.pages.count > expected {
            corrected.pages = Array(corrected.pages.prefix(expected))
        } else {
            while corrected.pages.count < expected {
                let num = corrected.pages.count + 1
                var page = PagePlan.empty(pageNumber: num)
                page.narration = fillMissingNarration(
                    pageNumber: num,
                    totalPages: expected,
                    theme: plan.theme,
                    characterName: plan.characterSheet.mainCharacterName
                )
                page.illustrationPrompt = "\(plan.characterSheet.species) in a \(plan.theme) scene"
                corrected.pages.append(page)
            }
        }
        return corrected
    }

    /// ページ番号を1から順に振り直す
    private static func normalizePageNumbers(_ plan: StoryPlan) -> StoryPlan {
        var corrected = plan
        for i in corrected.pages.indices {
            corrected.pages[i].pageNumber = i + 1
        }
        return corrected
    }

    /// キャラクターシートが有効か
    private static func isCharacterSheetValid(_ sheet: CharacterSheet) -> Bool {
        !sheet.species.isEmpty && !sheet.bodyColor.isEmpty
    }

    /// キャラクターシートの不足情報を補完
    static func enforceCharacterConsistency(_ sheet: CharacterSheet, theme: String) -> CharacterSheet {
        var fixed = sheet
        let lower = theme.lowercased()

        // species が空の場合、テーマからの推定
        if fixed.species.isEmpty {
            if lower.contains("うさぎ") || lower.contains("rabbit") || lower.contains("bunny") {
                fixed.species = "rabbit"
            } else if lower.contains("ねこ") || lower.contains("cat") || lower.contains("kitten") {
                fixed.species = "cat"
            } else if lower.contains("いぬ") || lower.contains("dog") || lower.contains("puppy") {
                fixed.species = "dog"
            } else if lower.contains("くま") || lower.contains("bear") {
                fixed.species = "bear"
            } else if lower.contains("とり") || lower.contains("bird") || lower.contains("ひよこ") {
                fixed.species = "bird"
            } else if lower.contains("トナカイ") || lower.contains("reindeer") || lower.contains("しか") || lower.contains("deer") {
                fixed.species = "reindeer"
            } else if lower.contains("きつね") || lower.contains("fox") {
                fixed.species = "fox"
            } else if lower.contains("うま") || lower.contains("horse") || lower.contains("pony") {
                fixed.species = "horse"
            } else if lower.contains("ぞう") || lower.contains("elephant") {
                fixed.species = "elephant"
            } else {
                fixed.species = "bear" // デフォルト（うさぎ固定を避ける）
            }
        }

        if fixed.mainCharacterName.isEmpty {
            let nameMap = [
                "rabbit": "ミミ", "cat": "ミケ", "dog": "ポチ",
                "bear": "クマタ", "bird": "ピピ", "fish": "プク",
                "reindeer": "ルル", "fox": "コン", "horse": "ポニー", "elephant": "ゾロ",
            ]
            fixed.mainCharacterName = nameMap[fixed.species] ?? "コロ"
        }

        if fixed.bodyColor.isEmpty {
            let colorMap = [
                "rabbit": "white", "cat": "orange tabby", "dog": "brown",
                "bear": "light brown", "bird": "yellow", "fish": "blue",
                "reindeer": "warm brown", "fox": "orange", "horse": "chestnut brown", "elephant": "gray",
            ]
            fixed.bodyColor = colorMap[fixed.species] ?? "light brown"
        }

        if fixed.earShape.isEmpty {
            let earMap = [
                "rabbit": "long floppy", "cat": "pointed", "dog": "floppy",
                "bear": "round small", "reindeer": "small round", "fox": "pointed",
                "horse": "upright", "elephant": "large round",
            ]
            fixed.earShape = earMap[fixed.species] ?? "small round"
        }

        if fixed.earSize.isEmpty {
            let earSizeMap = [
                "rabbit": "large", "cat": "medium", "dog": "medium", "bear": "small",
                "reindeer": "small", "fox": "medium", "horse": "medium", "elephant": "large",
            ]
            fixed.earSize = earSizeMap[fixed.species] ?? "medium"
        }

        if fixed.faceShape.isEmpty {
            let faceMap = [
                "rabbit": "oval", "cat": "round", "dog": "round", "bear": "round",
                "reindeer": "long oval", "fox": "pointed", "horse": "long", "elephant": "round",
            ]
            fixed.faceShape = faceMap[fixed.species] ?? "round"
        }

        if fixed.eyeStyle.isEmpty {
            let eyeMap = [
                "rabbit": "large round", "cat": "sparkly", "dog": "large round", "bear": "round",
                "reindeer": "large gentle", "fox": "bright", "horse": "large gentle", "elephant": "small kind",
            ]
            fixed.eyeStyle = eyeMap[fixed.species] ?? "large round"
        }

        if fixed.tailShape.isEmpty {
            let tailMap = [
                "rabbit": "fluffy round", "cat": "long fluffy", "dog": "wagging", "bear": "short stub",
                "reindeer": "short white", "fox": "long bushy", "horse": "long flowing", "elephant": "short thin",
            ]
            fixed.tailShape = tailMap[fixed.species] ?? "short"
        }

        if fixed.accessory.isEmpty {
            fixed.accessory = "a small blue scarf"
        }

        if fixed.ageFeeling.isEmpty {
            fixed.ageFeeling = "young and cute"
        }

        if fixed.personality.isEmpty {
            fixed.personality = "curious and kind"
        }

        return fixed
    }

    /// 空の narration を埋める
    private static func fillMissingNarration(pageNumber: Int, totalPages: Int, theme: String, characterName: String) -> String {
        let name = characterName.isEmpty ? "ちいさなともだち" : characterName
        if pageNumber == 1 {
            return "あるひ、\(name)は \(theme)の ぼうけんに でかけました。"
        } else if pageNumber == totalPages {
            return "\(name)は にっこりわらって、「たのしかったね」と いいました。"
        } else {
            return "\(name)は あるいていくと、すてきなものを みつけました。"
        }
    }

    /// 空の illustrationPrompt を埋める
    private static func fillMissingPrompt(_ page: PagePlan, theme: String) -> PagePlan {
        var fixed = page
        fixed.illustrationPrompt = "a scene related to \(theme), gentle and peaceful atmosphere"
        return fixed
    }

    /// mood を正規化（空なら「やさしい」に）
    private static func normalizeMood(_ page: PagePlan) -> PagePlan {
        var fixed = page
        if fixed.mood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fixed.mood = "やさしい"
        }
        return fixed
    }

    /// 文字禁止制約を注入
    static func injectTextFreeConstraint(_ page: PagePlan) -> PagePlan {
        var fixed = page
        let required = PagePlan.defaultForbiddenElements
        for element in required {
            if !fixed.forbiddenElements.contains(element) {
                fixed.forbiddenElements.append(element)
            }
        }
        return fixed
    }

    /// illustrationPrompt からキーオブジェクトを抽出
    private static func extractKeyObjects(from prompt: String) -> [String] {
        let keywords = [
            "rabbit", "cat", "dog", "bear", "bird", "fish", "tree", "flower",
            "mountain", "river", "cloud", "sun", "moon", "star", "house",
            "meadow", "forest", "garden", "hill", "bridge", "pond", "butterfly",
        ]
        let lower = prompt.lowercased()
        return keywords.filter { lower.contains($0) }
    }

    /// ページ間の一貫性を強制（continuityNotes の自動生成）
    private static func enforcePageContinuity(_ plan: StoryPlan) -> StoryPlan {
        var corrected = plan
        for i in corrected.pages.indices {
            if i > 0 && corrected.pages[i].continuityNotes.isEmpty {
                let prev = corrected.pages[i - 1]
                var notes: [String] = []
                notes.append("continues from page \(prev.pageNumber)")
                if !prev.location.isEmpty {
                    notes.append("previous location: \(prev.location)")
                }
                if !prev.keyObjects.isEmpty {
                    notes.append("objects from previous scene: \(prev.keyObjects.prefix(3).joined(separator: ", "))")
                }
                corrected.pages[i].continuityNotes = notes.joined(separator: "; ")
            }
        }
        return corrected
    }

    /// 表紙プランの検証と修正
    private static func validateCoverPlan(_ plan: StoryPlan) -> StoryPlan {
        var corrected = plan
        if corrected.coverPlan.coverPrompt.isEmpty {
            corrected.coverPlan = CoverPlan(
                title: corrected.title,
                subtitle: nil,
                mainCharacterDescription: corrected.characterSheet.promptFragment,
                worldKeywords: extractKeyObjects(from: corrected.theme),
                coverPrompt: "a children's picture book cover featuring \(corrected.characterSheet.promptFragment)"
            )
        }
        return corrected
    }
}
