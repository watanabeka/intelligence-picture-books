import Foundation
import FoundationModels

// MARK: - Generable types (英語 Guide でオンデバイスモデルとの互換性を確保)

/// 一括生成用: タイトル + 全ページ
@Generable
struct StoryOutput {
    @Guide(description: "The picture book title in Japanese, short and memorable for children")
    var title: String

    @Guide(description: "The pages of the picture book, with pageNumber starting from 1")
    var pages: [StoryPageOutput]
}

@Generable
struct StoryPageOutput {
    @Guide(description: "Page number starting from 1")
    var pageNumber: Int

    @Guide(description: "Story text for this page in Japanese, 2-3 simple sentences using hiragana")
    var text: String

    @Guide(description: "Illustration prompt in English describing a gentle, safe scene for a children's book")
    var illustrationPrompt: String

    @Guide(description: "A single Japanese word for the mood of this page, e.g. わくわく, しんみり")
    var mood: String
}

/// タイトルのみ生成用
@Generable
struct TitleOutput {
    @Guide(description: "The picture book title in Japanese, short and memorable for children")
    var title: String
}

/// 1ページ分の生成用
@Generable
struct SinglePageOutput {
    @Guide(description: "Story text in Japanese, 2-3 simple sentences using hiragana")
    var text: String

    @Guide(description: "Illustration prompt in English describing a gentle, safe scene for a children's book")
    var illustrationPrompt: String

    @Guide(description: "A single Japanese word for the mood, e.g. わくわく, しんみり")
    var mood: String
}

// MARK: - FoundationModelsStoryGenerator

final class FoundationModelsStoryGenerator: StoryGenerating, @unchecked Sendable {

    func generateStory(
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

        // 方式1: ストリーミング一括生成（最も高速）
        do {
            try await generateStreaming(theme: theme, pageCount: pageCount, continuation: continuation)
            return
        } catch {
            try Task.checkCancellation()
            // 失敗 → 方式2 へ
        }

        // 方式2: 非ストリーミング一括生成（ストリーミング API の問題を回避）
        do {
            try await generateAtOnce(theme: theme, pageCount: pageCount, continuation: continuation)
            return
        } catch {
            try Task.checkCancellation()
            // 失敗 → 方式3 へ
        }

        // 方式3: ページ個別生成（構造化出力の複雑さを最小化）
        do {
            try await generatePageByPage(theme: theme, pageCount: pageCount, continuation: continuation)
        } catch {
            try Task.checkCancellation()
            let detail = "\(String(reflecting: type(of: error))): \(error.localizedDescription)"
            throw GenerationError.generationFailed(underlying: detail)
        }
    }

    // MARK: - 方式1: ストリーミング一括生成

    private func generateStreaming(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws {
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.makePrompt(theme: theme, pageCount: pageCount)
        let stream = session.streamResponse(to: prompt, generating: StoryOutput.self)

        var titleEmitted = false
        var emittedPageNumbers: Set<Int> = []

        for try await snapshot in stream {
            try Task.checkCancellation()
            let partial = snapshot.content

            if !titleEmitted, let title = partial.title, !title.isEmpty {
                titleEmitted = true
                continuation.yield(.titleGenerated(title))
            }

            if let pages = partial.pages {
                for page in pages {
                    guard let pageNumber = page.pageNumber,
                          let text = page.text, !text.isEmpty,
                          let prompt = page.illustrationPrompt, !prompt.isEmpty,
                          !emittedPageNumbers.contains(pageNumber)
                    else { continue }

                    emittedPageNumbers.insert(pageNumber)
                    continuation.yield(.pageTextGenerated(
                        page: pageNumber, text: text, prompt: prompt,
                        mood: page.mood ?? ""
                    ))
                }
            }
        }

        continuation.yield(.storyFinished)
    }

    // MARK: - 方式2: 非ストリーミング一括生成

    private func generateAtOnce(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws {
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = Self.makePrompt(theme: theme, pageCount: pageCount)
        let response = try await session.respond(to: prompt, generating: StoryOutput.self)
        let story = response.content

        continuation.yield(.titleGenerated(story.title))

        for page in story.pages.sorted(by: { $0.pageNumber < $1.pageNumber }) {
            try Task.checkCancellation()
            guard !page.text.isEmpty else { continue }
            continuation.yield(.pageTextGenerated(
                page: page.pageNumber, text: page.text,
                prompt: page.illustrationPrompt, mood: page.mood
            ))
        }

        continuation.yield(.storyFinished)
    }

    // MARK: - 方式3: ページ個別生成（最もシンプルな構造化出力）

    private func generatePageByPage(
        theme: String,
        pageCount: Int,
        continuation: AsyncThrowingStream<StoryGenerationEvent, Error>.Continuation
    ) async throws {
        // タイトル生成
        let titleSession = LanguageModelSession(instructions:
            "You are a children's picture book author. Given a theme, create a short memorable title in Japanese."
        )
        let titleResponse = try await titleSession.respond(
            to: "Create a title for a children's picture book about: \(theme)",
            generating: TitleOutput.self
        )
        let title = titleResponse.content.title
        continuation.yield(.titleGenerated(title))

        // 各ページを個別に生成
        let pageSession = LanguageModelSession(instructions: """
            You are a children's picture book author writing a story titled "\(title)" about "\(theme)".
            The book has \(pageCount) pages total. Write one page at a time.
            - text: 2-3 sentences in simple Japanese using hiragana
            - illustrationPrompt: In English, start with "A gentle children's book illustration of"
            - mood: A single Japanese word for the atmosphere
            """)

        for pageNum in 1...pageCount {
            try Task.checkCancellation()

            let position: String
            if pageNum == 1 { position = "the opening" }
            else if pageNum == pageCount { position = "the ending" }
            else { position = "page \(pageNum) of \(pageCount)" }

            let pageResponse = try await pageSession.respond(
                to: "Write \(position) of the story.",
                generating: SinglePageOutput.self
            )
            let page = pageResponse.content

            continuation.yield(.pageTextGenerated(
                page: pageNum, text: page.text,
                prompt: page.illustrationPrompt, mood: page.mood
            ))
        }

        continuation.yield(.storyFinished)
    }

    // MARK: - 共通プロンプト

    private static let instructions = """
        You are a children's picture book author. Create a story based on the given theme.
        - title: A short, memorable Japanese title for children
        - Each page: 2-3 sentences in simple Japanese (use hiragana as much as possible)
        - The story should have a clear beginning, development, and conclusion
        - illustrationPrompt: In English, start with "A gentle children's book illustration of",
          use only safe subjects like nature, animals, landscapes, friendship.
          Use "a cheerful cartoon character" for any human figures.
        - mood: A single Japanese word describing the page's atmosphere (e.g. わくわく, しんみり)
        """

    private static func makePrompt(theme: String, pageCount: Int) -> String {
        "Create a \(pageCount)-page picture book about: \(theme). Number pages from 1 to \(pageCount)."
    }
}
