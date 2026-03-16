import Foundation
import SwiftUI
import SwiftData

enum GenerationPhase: Equatable {
    case idle
    case generatingStory
    case validatingPlan
    case generatingCover
    case generatingImages(current: Int, total: Int)
    case completed
    case failed(String)

    var isGenerating: Bool {
        switch self {
        case .generatingStory, .validatingPlan, .generatingCover, .generatingImages: true
        case .idle, .completed, .failed: false
        }
    }
}

struct PageDraft: Identifiable {
    let id = UUID()
    let pageNumber: Int
    var text: String
    var illustrationPrompt: String
    var finalImagePrompt: String
    var mood: String
    var image: UIImage?
    var isImageLoading = false
    var quality: GeneratedIllustrationQuality = .unknown
}

@MainActor
@Observable
final class CreateBookViewModel {
    var theme = ""
    var pageCount = 8
    var phase: GenerationPhase = .idle
    var progressText = ""
    var generatedTitle = ""
    var coverImage: UIImage?
    var pageDrafts: [PageDraft] = []
    var completedBook: Book?

    /// デバッグ情報（ReaderView で表示可能）
    var debugStoryPlan: StoryPlan?

    let availablePageCounts = [5, 8, 10, 12, 15]

    private let storyGenerator: any StoryGenerating
    private let illustrationGenerator: any IllustrationGenerating
    let repository: any BookPersisting
    private var generationTask: Task<Void, Never>?

    init(
        storyGenerator: any StoryGenerating,
        illustrationGenerator: any IllustrationGenerating,
        repository: any BookPersisting
    ) {
        self.storyGenerator = storyGenerator
        self.illustrationGenerator = illustrationGenerator
        self.repository = repository
    }

    var canGenerate: Bool {
        !theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !phase.isGenerating
    }

    func startGeneration() {
        guard canGenerate else { return }
        generatedTitle = ""
        coverImage = nil
        pageDrafts = []
        completedBook = nil
        debugStoryPlan = nil
        phase = .generatingStory
        progressText = "物語を準備しています..."

        generationTask = Task { [weak self] in
            guard let self else { return }
            await self.runGeneration()
        }
    }

    func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        phase = .idle
        progressText = ""
    }

    // MARK: - Generation Pipeline

    private func runGeneration() async {
        do {
            // STEP 1: StoryPlan を生成
            let rawPlan = try await generateStoryPlan()
            guard !Task.isCancelled else { return }

            // STEP 2: StoryPlan を検証・修正
            phase = .validatingPlan
            progressText = "構成を確認しています..."
            let validatedPlan = validatePlan(rawPlan)
            guard !Task.isCancelled else { return }

            debugStoryPlan = validatedPlan
            debugLogPlan(validatedPlan)

            // ページドラフトを作成
            createPageDrafts(from: validatedPlan)

            // STEP 3-4: 画像を生成（IllustrationPromptBuilder でプロンプト構築）
            await generateImages(plan: validatedPlan)
            guard !Task.isCancelled else { return }

            // STEP 5: 保存
            let book = try await saveBook(plan: validatedPlan)
            completedBook = book
            phase = .completed
            progressText = "絵本が完成しました！"
        } catch is CancellationError {
            // キャンセルは無視
        } catch {
            phase = .failed(error.localizedDescription)
            progressText = "エラーが発生しました: \(error.localizedDescription)"
        }
    }

    // MARK: - STEP 1: StoryPlan 生成

    private func generateStoryPlan() async throws -> StoryPlan {
        let stream = storyGenerator.generateStoryPlan(theme: theme, pageCount: pageCount)
        var plan: StoryPlan?

        for try await event in stream {
            guard !Task.isCancelled else { throw CancellationError() }

            switch event {
            case .started:
                phase = .generatingStory
                progressText = "物語を生成しています..."

            case .progress(let message):
                progressText = message

            case .planGenerated(let generatedPlan):
                plan = generatedPlan
                generatedTitle = generatedPlan.title
                progressText = "タイトル「\(generatedPlan.title)」の物語ができました"
            }
        }

        guard let finalPlan = plan else {
            throw GenerationError.invalidResponse
        }
        return finalPlan
    }

    // MARK: - STEP 2: StoryPlan 検証

    private func validatePlan(_ plan: StoryPlan) -> StoryPlan {
        let result = StoryPlanValidator.validate(plan, expectedPageCount: pageCount)

        if !result.isValid {
            print("⚠️ [Validator] Issues found:")
            for issue in result.issues {
                print("  - \(issue)")
            }
        } else {
            print("✅ [Validator] Plan is valid")
        }

        return result.correctedPlan
    }

    // MARK: - ページドラフト作成

    private func createPageDrafts(from plan: StoryPlan) {
        pageDrafts = plan.pages.map { page in
            let finalPrompt = IllustrationPromptBuilder.buildPagePrompt(
                page: page,
                characterSheet: plan.characterSheet,
                visualStyle: plan.visualStyle,
                storyTitle: plan.title
            )
            return PageDraft(
                pageNumber: page.pageNumber,
                text: page.narration,
                illustrationPrompt: page.illustrationPrompt,
                finalImagePrompt: finalPrompt,
                mood: page.mood
            )
        }
    }

    // MARK: - STEP 3-4: 画像生成

    private var usingFallbackImages = false

    private func generateImages(plan: StoryPlan) async {
        // 表紙生成（本文ページとは独立）
        phase = .generatingCover
        progressText = "表紙を描いています..."

        let coverPrompt = IllustrationPromptBuilder.buildCoverPrompt(
            coverPlan: plan.coverPlan,
            characterSheet: plan.characterSheet,
            visualStyle: plan.visualStyle
        )
        debugLog("Cover prompt: \(coverPrompt)")

        do {
            coverImage = try await illustrationGenerator.generateImage(prompt: coverPrompt)
        } catch {
            if Task.isCancelled { return }
            usingFallbackImages = true
            print("⚠️ [画像生成] 表紙生成失敗: \(error)")
            progressText = "Image Playground が利用できないため、イラスト画像で代替します"
            coverImage = FallbackRenderer.renderCover(
                title: plan.title,
                characterSheet: plan.characterSheet,
                theme: plan.theme,
                visualStyle: plan.visualStyle
            )
        }

        // 各ページの画像生成
        let total = pageDrafts.count
        for i in pageDrafts.indices {
            guard !Task.isCancelled else { return }

            let draft = pageDrafts[i]
            let page = plan.pages[i]
            pageDrafts[i].isImageLoading = true
            phase = .generatingImages(current: i + 1, total: total)

            let finalPrompt = draft.finalImagePrompt
            debugLog("Page \(draft.pageNumber) prompt: \(finalPrompt)")

            if usingFallbackImages {
                // フォールバック: キャラクターシートを使って一貫した画像を生成
                pageDrafts[i].image = FallbackRenderer.renderPage(
                    pageNumber: draft.pageNumber,
                    pagePlan: page,
                    characterSheet: plan.characterSheet,
                    visualStyle: plan.visualStyle
                )
                pageDrafts[i].quality = .fallback
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵ができました"
            } else {
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵を描いています..."
                do {
                    let img = try await illustrationGenerator.generateImage(prompt: finalPrompt)
                    guard !Task.isCancelled else { return }
                    pageDrafts[i].image = img
                    pageDrafts[i].quality = GeneratedIllustrationQuality(
                        hasPossibleTextArtifacts: false,
                        consistencyScore: 0.8,
                        matchesSceneKeywords: true,
                        usedFallback: false
                    )
                } catch {
                    if Task.isCancelled { return }
                    pageDrafts[i].image = FallbackRenderer.renderPage(
                        pageNumber: draft.pageNumber,
                        pagePlan: page,
                        characterSheet: plan.characterSheet,
                        visualStyle: plan.visualStyle
                    )
                    pageDrafts[i].quality = .fallback
                }
            }
            pageDrafts[i].isImageLoading = false
        }
    }

    // MARK: - Save

    private func saveBook(plan: StoryPlan) async throws -> Book {
        let book = Book(theme: theme, pageCount: pageCount, title: plan.title, isComplete: true)

        if let cover = coverImage {
            let name = "\(book.id.uuidString)_cover.png"
            try await repository.saveImage(cover, name: name)
            book.coverImageLocalName = name
        }

        for draft in pageDrafts {
            let page = BookPage(
                pageNumber: draft.pageNumber,
                text: draft.text,
                illustrationPrompt: draft.illustrationPrompt,
                finalImagePrompt: draft.finalImagePrompt,
                mood: draft.mood
            )
            if let img = draft.image {
                let name = "\(book.id.uuidString)_page\(draft.pageNumber).png"
                try await repository.saveImage(img, name: name)
                page.imageLocalName = name
            }
            book.pages.append(page)
        }

        try await repository.saveBook(book)
        return book
    }

    // MARK: - Debug Logging

    private func debugLog(_ message: String) {
        #if DEBUG
        print("📖 [Pipeline] \(message)")
        #endif
    }

    private func debugLogPlan(_ plan: StoryPlan) {
        #if DEBUG
        print(plan.debugSummary)
        #endif
    }
}
