import Foundation
import SwiftUI
import SwiftData

enum GenerationPhase: Equatable {
    case idle
    case generating
    case completed
    case failed(String)
}

struct PageDraft: Identifiable {
    let id = UUID()
    let pageNumber: Int
    var text: String
    var illustrationPrompt: String
    var mood: String
    var image: UIImage?
    var isImageLoading: Bool = false
}

@MainActor
@Observable
final class CreateBookViewModel {
    var theme: String = ""
    var pageCount: Int = 8
    var phase: GenerationPhase = .idle
    var progressText: String = ""
    var generatedTitle: String = ""
    var coverImage: UIImage?
    var pageDrafts: [PageDraft] = []
    var completedBook: Book?

    let availablePageCounts = [6, 8, 10, 12]

    private let storyGenerator: any StoryGenerating
    private let illustrationGenerator: any IllustrationGenerating
    let repository: any BookPersisting
    private var generationTask: Task<Void, Never>?

    init(
        storyGenerator: any StoryGenerating = MockStoryGenerator(),
        illustrationGenerator: any IllustrationGenerating = MockIllustrationGenerator(),
        repository: any BookPersisting
    ) {
        self.storyGenerator = storyGenerator
        self.illustrationGenerator = illustrationGenerator
        self.repository = repository
    }

    var canGenerate: Bool {
        !theme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .generating
    }

    func startGeneration() {
        guard canGenerate else { return }
        resetState()
        phase = .generating
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

    private func resetState() {
        generatedTitle = ""
        coverImage = nil
        pageDrafts = []
        completedBook = nil
    }

    private func runGeneration() async {
        do {
            let stream = storyGenerator.generateStory(theme: theme, pageCount: pageCount)
            for try await event in stream {
                guard !Task.isCancelled else { return }
                handleStoryEvent(event)
            }

            guard !Task.isCancelled else { return }

            // Generate images after story text is ready
            await generateImages()

            guard !Task.isCancelled else { return }

            // Save
            let book = try await saveBook()
            completedBook = book
            phase = .completed
            progressText = "絵本が完成しました！"
        } catch is CancellationError {
            // User cancelled – do nothing
        } catch {
            phase = .failed(error.localizedDescription)
            progressText = "エラーが発生しました: \(error.localizedDescription)"
        }
    }

    private func handleStoryEvent(_ event: StoryGenerationEvent) {
        switch event {
        case .started:
            progressText = "物語を生成しています..."
        case .titleGenerated(let title):
            generatedTitle = title
            progressText = "タイトル「\(title)」が決まりました"
        case .pageTextGenerated(let page, let text, let prompt, let mood):
            let draft = PageDraft(pageNumber: page, text: text, illustrationPrompt: prompt, mood: mood)
            pageDrafts.append(draft)
            progressText = "\(page)/\(pageCount) ページの本文ができました"
        case .storyFinished:
            progressText = "本文がすべて完成しました。挿絵を生成します..."
        default:
            break
        }
    }

    private func generateImages() async {
        // Cover
        progressText = "表紙を描いています..."
        do {
            let img = try await illustrationGenerator.generateCoverImage(title: generatedTitle, theme: theme)
            guard !Task.isCancelled else { return }
            coverImage = img
        } catch {
            if Task.isCancelled { return }
        }

        // Pages
        for i in pageDrafts.indices {
            guard !Task.isCancelled else { return }
            let draft = pageDrafts[i]
            pageDrafts[i].isImageLoading = true
            progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵を描いています..."

            do {
                let img = try await illustrationGenerator.generatePageImage(
                    pageNumber: draft.pageNumber,
                    prompt: draft.illustrationPrompt,
                    mood: draft.mood
                )
                guard !Task.isCancelled else { return }
                pageDrafts[i].image = img
                pageDrafts[i].isImageLoading = false
                progressText = "\(draft.pageNumber)/\(pageCount) ページの挿絵ができました"
            } catch {
                if Task.isCancelled { return }
                pageDrafts[i].isImageLoading = false
            }
        }
    }

    private func saveBook() async throws -> Book {
        let book = Book(theme: theme, pageCount: pageCount, title: generatedTitle, isComplete: true)

        // Save cover image
        if let cover = coverImage {
            let coverName = "\(book.id.uuidString)_cover.png"
            try await repository.saveImage(cover, name: coverName)
            book.coverImageLocalName = coverName
        }

        // Create pages
        for draft in pageDrafts {
            let page = BookPage(
                pageNumber: draft.pageNumber,
                text: draft.text,
                illustrationPrompt: draft.illustrationPrompt,
                mood: draft.mood
            )
            if let img = draft.image {
                let imgName = "\(book.id.uuidString)_page\(draft.pageNumber).png"
                try await repository.saveImage(img, name: imgName)
                page.imageLocalName = imgName
            }
            book.pages.append(page)
        }

        try await repository.saveBook(book)
        return book
    }
}
