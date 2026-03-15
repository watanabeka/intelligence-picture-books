import Foundation
import SwiftUI
import SwiftData

enum GenerationPhase: Equatable {
    case idle
    case generatingStory
    case generatingCover
    case generatingImages(current: Int, total: Int)
    case completed
    case failed(String)

    var isGenerating: Bool {
        switch self {
        case .generatingStory, .generatingCover, .generatingImages: true
        case .idle, .completed, .failed: false
        }
    }
}

struct PageDraft: Identifiable {
    let id = UUID()
    let pageNumber: Int
    var text: String
    var illustrationPrompt: String
    var mood: String
    var image: UIImage?
    var isImageLoading = false
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

    let availablePageCounts = [5,8,10,12,15]

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

    private func runGeneration() async {
        do {
            let stream = storyGenerator.generateStory(theme: theme, pageCount: pageCount)
            for try await event in stream {
                guard !Task.isCancelled else { return }
                handleStoryEvent(event)
            }
            guard !Task.isCancelled else { return }

            await generateImages()
            guard !Task.isCancelled else { return }

            let book = try await saveBook()
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

    private func handleStoryEvent(_ event: StoryGenerationEvent) {
        switch event {
        case .started:
            phase = .generatingStory
            progressText = "物語を生成しています..."
        case .titleGenerated(let title):
            generatedTitle = title
            progressText = "タイトル「\(title)」が決まりました"
        case .pageTextGenerated(let page, let text, let prompt, let mood):
            pageDrafts.append(PageDraft(pageNumber: page, text: text, illustrationPrompt: prompt, mood: mood))
            progressText = "\(page)/\(pageCount) ページの本文ができました"
        case .storyFinished:
            progressText = "本文がすべて完成しました。挿絵を生成します..."
        }
    }

    // 表紙 → 各ページの順で画像生成。ImageCreator 失敗時はフォールバック画像で続行
    private var usingFallbackImages = false

    private func generateImages() async {
        phase = .generatingCover
        progressText = "表紙を描いています..."
        do {
            coverImage = try await illustrationGenerator.generateCoverImage(title: generatedTitle, theme: theme)
        } catch {
            if Task.isCancelled { return }
            usingFallbackImages = true
            print("⚠️ [画像生成] 表紙生成失敗: \(error)")
            progressText = "Image Playground が利用できないため、イラスト画像で代替します（\(error.localizedDescription)）"
            coverImage = FallbackRenderer.renderCover(title: generatedTitle, theme: theme)
        }

        let total = pageDrafts.count
        for i in pageDrafts.indices {
            guard !Task.isCancelled else { return }
            let draft = pageDrafts[i]
            pageDrafts[i].isImageLoading = true
            phase = .generatingImages(current: i, total: total)

            if usingFallbackImages {
                // ImageCreator が使えない場合は全ページフォールバックで高速生成
                pageDrafts[i].image = FallbackRenderer.renderPage(
                    pageNumber: draft.pageNumber, prompt: draft.illustrationPrompt, mood: draft.mood
                )
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵ができました"
            } else {
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵を描いています..."
                do {
                    let img = try await illustrationGenerator.generatePageImage(
                        pageNumber: draft.pageNumber,
                        prompt: draft.illustrationPrompt,
                        mood: draft.mood
                    )
                    guard !Task.isCancelled else { return }
                    pageDrafts[i].image = img
                } catch {
                    if Task.isCancelled { return }
                    pageDrafts[i].image = FallbackRenderer.renderPage(
                        pageNumber: draft.pageNumber, prompt: draft.illustrationPrompt, mood: draft.mood
                    )
                }
            }
            pageDrafts[i].isImageLoading = false
        }
    }

    private func saveBook() async throws -> Book {
        let book = Book(theme: theme, pageCount: pageCount, title: generatedTitle, isComplete: true)

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
}
