import Foundation
import FoundationModels

// MARK: - Generable types for StoryPlan generation

/// 一括生成用: キャラクター + タイトル + 全ページ
@Generable
struct StoryPlanOutput {
    @Guide(description: "The picture book title in Japanese, short and memorable for children")
    var title: String

    @Guide(description: "Main character's name in Japanese (e.g. ミミ, ポチ)")
    var characterName: String

    @Guide(description: "Main character's species in English (e.g. rabbit, cat, dog, bear)")
    var characterSpecies: String

    @Guide(description: "Main character's body color in English (e.g. white, orange tabby, brown)")
    var characterBodyColor: String

    @Guide(description: "Main character's distinguishing accessory in English (e.g. a small blue scarf, a red ribbon)")
    var characterAccessory: String

    @Guide(description: "Main character's ear size in English (e.g. large, small, medium)")
    var characterEarSize: String

    @Guide(description: "Main character's eye style in English (e.g. large round, sparkly, wide)")
    var characterEyeStyle: String

    @Guide(description: "All pages of the story in order")
    var pages: [StoryPagePlanOutput]
}

@Generable
struct StoryPagePlanOutput {
    @Guide(description: "Page number starting from 1")
    var pageNumber: Int

    @Guide(description: "Short internal scene title in English (e.g. 'Setting Out', 'Meeting a Friend')")
    var sceneTitle: String

    @Guide(description: "Story text for this page in Japanese, 2-3 simple sentences using hiragana. One event per page.")
    var narration: String

    @Guide(description: "Scene description in English for illustration. Be specific and concrete. Describe what the character is doing and where. Example: 'a small white rabbit walking through a sunlit flower meadow with butterflies'")
    var sceneDescription: String

    @Guide(description: "A single Japanese word for the mood, e.g. わくわく, しんみり, やさしい")
    var mood: String

    @Guide(description: "Key visual objects in the scene in English, comma-separated (e.g. 'flowers, butterflies, path')")
    var keyObjects: String
}

/// タイトルとキャラクターのみ生成用（フォールバック tier 3）
@Generable
struct TitleAndCharacterOutput {
    @Guide(description: "The picture book title in Japanese, short and memorable for children")
    var title: String

    @Guide(description: "Main character's name in Japanese")
    var characterName: String

    @Guide(description: "Main character's species in English (e.g. rabbit, cat, dog)")
    var characterSpecies: String

    @Guide(description: "Main character's body color in English (e.g. white, brown)")
    var characterBodyColor: String

    @Guide(description: "Main character's accessory in English (e.g. a small blue scarf)")
    var characterAccessory: String

    @Guide(description: "Main character's ear size in English (e.g. large, small, medium)")
    var characterEarSize: String

    @Guide(description: "Main character's eye style in English (e.g. large round, sparkly, wide)")
    var characterEyeStyle: String
}

/// 1ページ分の生成用（フォールバック tier 3）
@Generable
struct SinglePagePlanOutput {
    @Guide(description: "Story text in Japanese, 2-3 simple sentences using hiragana. One event only.")
    var narration: String

    @Guide(description: "Scene description in English for illustration. Be specific: describe what the character is doing and where.")
    var sceneDescription: String

    @Guide(description: "A single Japanese word for the mood, e.g. わくわく, しんみり")
    var mood: String

    @Guide(description: "Key visual objects in English, comma-separated")
    var keyObjects: String
}

// MARK: - FoundationModelsStoryGenerator

final class FoundationModelsStoryGenerator: StoryGenerating, @unchecked Sendable {

    func generateStoryPlan(
        theme: String,
        pageCount: Int
    ) -> AsyncThrowingStream<StoryGenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await self.produce(theme: theme, pageCount: pageCount, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func produce(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw GenerationError.modelNotAvailable
        }

        continuation.yield(.started)

        // 方式1: 一括生成（最も高速）
        do {
            let plan = try await generateAtOnce(theme: theme, pageCount: pageCount, continuation: continuation)
            continuation.yield(.planGenerated(plan))
            return
        } catch {
            try Task.checkCancellation()
            print("⚠️ [StoryPlan] 方式1（一括）失敗: \(error)")
        }

        // 方式2: ページ個別生成（構造化出力の複雑さを最小化）
        do {
            let plan = try await generatePageByPage(theme: theme, pageCount: pageCount, continuation: continuation)
            continuation.yield(.planGenerated(plan))
            return
        } catch {
            try Task.checkCancellation()
            let detail = "\(String(reflecting: type(of: error))): \(error.localizedDescription)"
            throw GenerationError.generationFailed(underlying: detail)
        }
    }

    // MARK: - 方式1: 一括生成

    private func generateAtOnce(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws -> StoryPlan {
        let instructions = Self.makeInstructions(pageCount: pageCount)
        let session = LanguageModelSession(instructions: instructions)
        let prompt = Self.makePrompt(theme: theme, pageCount: pageCount)

        continuation.yield(.progress("物語の構成を考えています..."))

        let response = try await session.respond(to: prompt, generating: StoryPlanOutput.self)
        let output = response.content

        continuation.yield(.progress("タイトル「\(output.title)」が決まりました"))

        return Self.convertToStoryPlan(output: output, theme: theme)
    }

    // MARK: - 方式2: ページ個別生成

    private func generatePageByPage(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws -> StoryPlan {
        continuation.yield(.progress("キャラクターを考えています..."))

        // Step 1: タイトルとキャラクター生成
        let charSession = LanguageModelSession(instructions: """
            You are a children's picture book author.
            Given a theme, create a title and main character for a picture book.
            The character should be a cute animal that fits the theme.
            """)

        let charResponse = try await charSession.respond(
            to: "Create a title and main character for a \(pageCount)-page children's picture book about: \(theme)",
            generating: TitleAndCharacterOutput.self
        )
        let charOutput = charResponse.content

        continuation.yield(.progress("タイトル「\(charOutput.title)」が決まりました"))

        let characterSheet = CharacterSheet(
            mainCharacterName: charOutput.characterName,
            species: charOutput.characterSpecies,
            ageFeeling: "young and cute",
            bodyColor: charOutput.characterBodyColor,
            earShape: "",
            earSize: charOutput.characterEarSize,
            eyeStyle: charOutput.characterEyeStyle,
            accessory: charOutput.characterAccessory,
            personality: "curious and kind"
        )

        // Step 2: 各ページを個別に生成
        let styleGuide = StoryStyleGuide.default
        let pageSession = LanguageModelSession(instructions: """
            You are a children's picture book author writing a story titled "\(charOutput.title)" about "\(theme)".
            The main character is \(charOutput.characterName), a \(charOutput.characterBodyColor) \(charOutput.characterSpecies) wearing \(charOutput.characterAccessory).
            The book has \(pageCount) pages total. Write one page at a time.

            \(styleGuide.asPromptInstructions)

            Rules:
            - narration: 2-3 sentences in simple Japanese using hiragana. ONE event per page.
            - sceneDescription: In English, describe specifically what the character is doing and where. Be concrete and visual.
            - mood: A single Japanese word for the atmosphere
            - keyObjects: List 2-4 concrete visual objects in the scene, in English, comma-separated
            - Each page must connect naturally to the next
            - The main character \(charOutput.characterName) must appear in every scene
            """)

        var pages: [PagePlan] = []
        var previousContext = ""

        for pageNum in 1...pageCount {
            try Task.checkCancellation()

            continuation.yield(.progress("\(pageNum)/\(pageCount) ページの本文を書いています..."))

            let position: String
            if pageNum == 1 { position = "the opening page" }
            else if pageNum == pageCount { position = "the final page (gentle, warm ending)" }
            else { position = "page \(pageNum) of \(pageCount)" }

            let contextNote = previousContext.isEmpty ? "" : " Previous page: \(previousContext)"
            let pagePrompt = "Write \(position) of the story.\(contextNote)"

            let pageResponse = try await pageSession.respond(
                to: pagePrompt,
                generating: SinglePagePlanOutput.self
            )
            let pageOutput = pageResponse.content

            let pagePlan = PagePlan(
                pageNumber: pageNum,
                sceneTitle: "Page \(pageNum)",
                narration: pageOutput.narration,
                illustrationPrompt: pageOutput.sceneDescription,
                forbiddenElements: PagePlan.defaultForbiddenElements,
                camera: "medium shot",
                location: "",
                mood: pageOutput.mood,
                keyObjects: pageOutput.keyObjects.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                continuityNotes: previousContext.isEmpty ? "" : "continues from previous scene"
            )
            pages.append(pagePlan)

            // 次のページのコンテキストとして使う
            previousContext = pageOutput.narration.prefix(40) + "..."
        }

        let plan = StoryPlan(
            title: charOutput.title,
            theme: theme,
            visualStyle: .default,
            characterSheet: characterSheet,
            pages: pages,
            coverPlan: CoverPlan(
                title: charOutput.title,
                subtitle: nil,
                mainCharacterDescription: characterSheet.promptFragment,
                worldKeywords: [],
                coverPrompt: "a \(charOutput.characterBodyColor) \(charOutput.characterSpecies) wearing \(charOutput.characterAccessory) in a \(theme) world"
            )
        )

        return plan
    }

    // MARK: - Conversion

    private static func convertToStoryPlan(output: StoryPlanOutput, theme: String) -> StoryPlan {
        let characterSheet = CharacterSheet(
            mainCharacterName: output.characterName,
            species: output.characterSpecies,
            ageFeeling: "young and cute",
            bodyColor: output.characterBodyColor,
            earShape: "",
            earSize: output.characterEarSize,
            eyeStyle: output.characterEyeStyle,
            accessory: output.characterAccessory,
            personality: "curious and kind"
        )

        let pages = output.pages.sorted(by: { $0.pageNumber < $1.pageNumber }).map { pageOutput in
            PagePlan(
                pageNumber: pageOutput.pageNumber,
                sceneTitle: pageOutput.sceneTitle,
                narration: pageOutput.narration,
                illustrationPrompt: pageOutput.sceneDescription,
                forbiddenElements: PagePlan.defaultForbiddenElements,
                camera: "medium shot",
                location: "",
                mood: pageOutput.mood,
                keyObjects: pageOutput.keyObjects.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                continuityNotes: ""
            )
        }

        let coverPlan = CoverPlan(
            title: output.title,
            subtitle: nil,
            mainCharacterDescription: characterSheet.promptFragment,
            worldKeywords: [],
            coverPrompt: "a \(output.characterBodyColor) \(output.characterSpecies) wearing \(output.characterAccessory) in a \(theme) world"
        )

        return StoryPlan(
            title: output.title,
            theme: theme,
            visualStyle: .default,
            characterSheet: characterSheet,
            pages: pages,
            coverPlan: coverPlan
        )
    }

    // MARK: - Prompt Construction

    private static func makeInstructions(pageCount: Int) -> String {
        let styleGuide = StoryStyleGuide.default
        return """
            You are a professional children's picture book author and illustrator.
            You must create a complete story plan with a consistent main character.

            CRITICAL RULES:
            - The main character must be a cute animal (rabbit, cat, dog, bear, bird, etc.)
            - Give the character a Japanese name and describe their appearance in English
            - The character must appear in EVERY page's scene description
            - Each page has exactly ONE event - do not cram multiple events
            - Pages must flow naturally: beginning → development → gentle conclusion
            - Scene descriptions must be SPECIFIC and CONCRETE for illustration
            - Bad example: "a happy scene" (too vague)
            - Good example: "a small white rabbit picking red flowers in a sunny meadow with butterflies around"

            \(styleGuide.asPromptInstructions)
            """
    }

    private static func makePrompt(theme: String, pageCount: Int) -> String {
        """
        Create a \(pageCount)-page children's picture book about: \(theme)

        Requirements:
        - Number pages from 1 to \(pageCount)
        - Each page's narration: 2-3 sentences in simple Japanese (hiragana)
        - Each page's sceneDescription: specific, concrete English description for illustration
        - The SAME main character must appear in every scene description
        - Story must have clear flow: opening → adventure/discovery → warm ending
        - keyObjects: list 2-4 concrete visual objects per scene
        """
    }
}
