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
    var imageState: PageImageState = .loading
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
    /// internal でアクセス可能にして GenerationView → ReaderView に渡す
    let illustrationGenerator: any IllustrationGenerating
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
                mood: page.mood,
                imageState: .loading
            )
        }
    }

    // MARK: - STEP 3-4: 画像生成（2回リトライ → フォールバック）

    /// ImagePlayground が利用できないことが確定したら true にして以降はフォールバックに直行
    private var imagePlaygroundUnavailable = false

    private func generateImages(plan: StoryPlan) async {
        imagePlaygroundUnavailable = false

        // 表紙生成（本文ページとは独立）
        phase = .generatingCover
        progressText = "表紙を描いています..."

        let coverPrompt = IllustrationPromptBuilder.buildCoverPrompt(
            coverPlan: plan.coverPlan,
            characterSheet: plan.characterSheet,
            visualStyle: plan.visualStyle
        )
        debugLog("Cover prompt: \(coverPrompt)")

        await generateCoverImage(plan: plan, prompt: coverPrompt)

        // 各ページの画像生成
        let total = pageDrafts.count
        for i in pageDrafts.indices {
            guard !Task.isCancelled else { return }

            let draft = pageDrafts[i]
            guard i < plan.pages.count else { continue }
            let page = plan.pages[i]

            pageDrafts[i].isImageLoading = true
            pageDrafts[i].imageState = .loading
            phase = .generatingImages(current: i + 1, total: total)

            let finalPrompt = draft.finalImagePrompt
            debugLog("Page \(draft.pageNumber) prompt: \(finalPrompt)")

            if imagePlaygroundUnavailable {
                pageDrafts[i].image = FallbackRenderer.renderPage(
                    pageNumber: draft.pageNumber,
                    pagePlan: page,
                    characterSheet: plan.characterSheet,
                    visualStyle: plan.visualStyle
                )
                pageDrafts[i].imageState = .fallback
                pageDrafts[i].quality = .fallback
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵ができました"
            } else {
                await generatePageImage(index: i, draft: draft, page: page, plan: plan, prompt: finalPrompt)
            }

            pageDrafts[i].isImageLoading = false
        }
    }

    private func generateCoverImage(plan: StoryPlan, prompt: String) async {
        var success = false
        for attempt in 1...2 {
            guard !Task.isCancelled else { return }
            do {
                coverImage = try await illustrationGenerator.generateImage(prompt: prompt)
                success = true
                debugLog("Cover: success on attempt \(attempt)")
                break
            } catch {
                if Task.isCancelled { return }
                debugLog("Cover: attempt \(attempt) failed: \(error)")
                let desc = String(describing: error).lowercased()
                if desc.contains("unavailable") || desc.contains("initialization") || desc.contains("初期化") {
                    imagePlaygroundUnavailable = true
                    break
                }
                if attempt < 2 { progressText = "表紙をもう一度試しています..." }
            }
        }

        if !success {
            imagePlaygroundUnavailable = true
            progressText = "Image Playground が利用できないため、イラスト画像で代替します"
            coverImage = FallbackRenderer.renderCover(
                title: plan.title,
                characterSheet: plan.characterSheet,
                theme: plan.theme,
                visualStyle: plan.visualStyle
            )
        }
    }

    private func generatePageImage(
        index: Int,
        draft: PageDraft,
        page: PagePlan,
        plan: StoryPlan,
        prompt: String
    ) async {
        progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵を描いています..."
        var success = false

        for attempt in 1...2 {
            guard !Task.isCancelled else { return }
            do {
                let img = try await illustrationGenerator.generateImage(prompt: prompt)
                guard !Task.isCancelled else { return }
                pageDrafts[index].image = img
                pageDrafts[index].imageState = .ready
                pageDrafts[index].quality = GeneratedIllustrationQuality(
                    hasPossibleTextArtifacts: false,
                    consistencyScore: 0.8,
                    matchesSceneKeywords: true,
                    usedFallback: false
                )
                debugLog("Page \(draft.pageNumber): success attempt \(attempt)")
                success = true
                break
            } catch {
                if Task.isCancelled { return }
                debugLog("Page \(draft.pageNumber): attempt \(attempt) failed: \(error)")
                let desc = String(describing: error).lowercased()
                if desc.contains("unavailable") || desc.contains("initialization") || desc.contains("初期化") {
                    imagePlaygroundUnavailable = true
                    break
                }
                if attempt < 2 {
                    progressText = "\(draft.pageNumber)/\(pageCount) ページ もう一度試しています..."
                }
            }
        }

        if !success {
            pageDrafts[index].image = FallbackRenderer.renderPage(
                pageNumber: draft.pageNumber,
                pagePlan: page,
                characterSheet: plan.characterSheet,
                visualStyle: plan.visualStyle
            )
            pageDrafts[index].imageState = .fallback
            pageDrafts[index].quality = .fallback
        }
    }

    // MARK: - Save

    private func saveBook(plan: StoryPlan) async throws -> Book {
        let book = Book(
            theme: theme,
            pageCount: pageCount,
            title: plan.title,
            isComplete: true,
            characterSpecies: plan.characterSheet.species,
            characterBodyColor: plan.characterSheet.bodyColor,
            characterAccessory: plan.characterSheet.accessory,
            visualStyleRaw: plan.visualStyle.rawValue
        )

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
                mood: draft.mood,
                isFallback: draft.imageState == .fallback
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

    // MARK: - 個別画像リトライ（GenerationView 完了後）

    func retryCoverImage() {
        guard let plan = debugStoryPlan, !phase.isGenerating else { return }
        Task {
            coverImage = nil
            let prompt = IllustrationPromptBuilder.buildCoverPrompt(
                coverPlan: plan.coverPlan,
                characterSheet: plan.characterSheet,
                visualStyle: plan.visualStyle
            )
            if let img = try? await illustrationGenerator.generateImage(prompt: prompt) {
                coverImage = img
            } else {
                coverImage = FallbackRenderer.renderCover(
                    title: plan.title,
                    characterSheet: plan.characterSheet,
                    theme: plan.theme,
                    visualStyle: plan.visualStyle
                )
            }
        }
    }

    func retryPageImage(at index: Int) {
        guard let plan = debugStoryPlan, !phase.isGenerating,
              pageDrafts.indices.contains(index), index < plan.pages.count else { return }
        Task {
            pageDrafts[index].image = nil
            pageDrafts[index].isImageLoading = true
            let page = plan.pages[index]
            let prompt = pageDrafts[index].finalImagePrompt
            if let img = try? await illustrationGenerator.generateImage(prompt: prompt) {
                pageDrafts[index].image = img
                pageDrafts[index].imageState = .ready
            } else {
                pageDrafts[index].image = FallbackRenderer.renderPage(
                    pageNumber: pageDrafts[index].pageNumber,
                    pagePlan: page,
                    characterSheet: plan.characterSheet,
                    visualStyle: plan.visualStyle
                )
                pageDrafts[index].imageState = .fallback
            }
            pageDrafts[index].isImageLoading = false
        }
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
