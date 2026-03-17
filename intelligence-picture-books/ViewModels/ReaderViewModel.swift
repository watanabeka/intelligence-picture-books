import Foundation
import SwiftUI

@MainActor
@Observable
final class ReaderViewModel {
    let book: Book
    var coverImage: UIImage?
    var coverImageState: PageImageState = .loading
    var pageImages: [Int: UIImage] = [:]
    var pageImageStates: [Int: PageImageState] = [:]

    private let repository: any BookPersisting
    let illustrationGenerator: any IllustrationGenerating

    init(book: Book, repository: any BookPersisting, illustrationGenerator: any IllustrationGenerating) {
        self.book = book
        self.repository = repository
        self.illustrationGenerator = illustrationGenerator
    }

    var totalSlides: Int { book.sortedPages.count + 1 }

    // MARK: - 画像ロード

    func loadImages() async {
        coverImageState = .loading
        if let name = book.coverImageLocalName {
            coverImage = await repository.loadImage(name: name)
        }
        coverImageState = coverImage != nil ? .ready : .failed

        for page in book.sortedPages {
            pageImageStates[page.pageNumber] = .loading
            if let name = page.imageLocalName,
               let img = await repository.loadImage(name: name) {
                pageImages[page.pageNumber] = img
                pageImageStates[page.pageNumber] = page.isFallback ? .fallback : .ready
            } else {
                pageImageStates[page.pageNumber] = .failed
            }
        }
    }

    // MARK: - ページ画像リトライ

    func retryImage(for page: BookPage) async {
        let pageNum = page.pageNumber
        pageImageStates[pageNum] = .retrying

        let prompt = page.finalImagePrompt.isEmpty ? page.illustrationPrompt : page.finalImagePrompt

        for attempt in 1...2 {
            do {
                let image = try await illustrationGenerator.generateImage(prompt: prompt)
                let imageName = "\(book.id.uuidString)_page\(pageNum).png"
                try await repository.saveImage(image, name: imageName)
                try await repository.updatePageImageName(imageName, pageId: page.id)
                pageImages[pageNum] = image
                pageImageStates[pageNum] = .ready
                debugLog("Page \(pageNum): retry success on attempt \(attempt)")
                return
            } catch {
                debugLog("Page \(pageNum): retry attempt \(attempt) failed: \(error)")
            }
        }

        // 2回失敗 → フォールバック画像を生成
        let pagePlan = PagePlan(
            pageNumber: pageNum,
            sceneTitle: "",
            narration: page.text,
            illustrationPrompt: page.illustrationPrompt,
            forbiddenElements: PagePlan.defaultForbiddenElements,
            camera: "medium shot",
            location: "",
            mood: page.mood,
            keyObjects: [],
            continuityNotes: ""
        )
        let fallbackImage = FallbackRenderer.renderPage(
            pageNumber: pageNum,
            pagePlan: pagePlan,
            characterSheet: book.characterSheet,
            visualStyle: book.visualStyle
        )
        // フォールバックも保存して次回から表示できるようにする
        let imageName = "\(book.id.uuidString)_page\(pageNum).png"
        try? await repository.saveImage(fallbackImage, name: imageName)
        pageImages[pageNum] = fallbackImage
        pageImageStates[pageNum] = .fallback
    }

    // MARK: - 表紙画像リトライ

    func retryCover() async {
        coverImageState = .retrying

        let prompt: String
        if let name = book.coverImageLocalName, !name.isEmpty {
            // プロンプトが取れないので汎用的なものを使う
            prompt = IllustrationPromptBuilder.buildCoverPrompt(
                coverPlan: CoverPlan(
                    title: book.title,
                    subtitle: nil,
                    mainCharacterDescription: book.characterSheet.promptFragment,
                    worldKeywords: [],
                    coverPrompt: "\(book.characterSheet.promptFragment) in a \(book.theme) world"
                ),
                characterSheet: book.characterSheet,
                visualStyle: book.visualStyle
            )
        } else {
            prompt = "children's picture book front cover illustration, \(book.characterSheet.promptFragment), \(book.theme), warm inviting composition, centered character, no text, no letters, no watermark"
        }

        for attempt in 1...2 {
            do {
                let image = try await illustrationGenerator.generateImage(prompt: prompt)
                let imageName = "\(book.id.uuidString)_cover.png"
                try await repository.saveImage(image, name: imageName)
                coverImage = image
                coverImageState = .ready
                debugLog("Cover: retry success on attempt \(attempt)")
                return
            } catch {
                debugLog("Cover: retry attempt \(attempt) failed: \(error)")
            }
        }

        // 2回失敗 → フォールバック表示
        let fallback = FallbackRenderer.renderCover(
            title: book.title,
            characterSheet: book.characterSheet,
            theme: book.theme,
            visualStyle: book.visualStyle
        )
        coverImage = fallback
        coverImageState = .fallback
    }

    // MARK: - テキスト編集

    func updatePageText(_ newText: String, for page: BookPage) async {
        // 即座にインメモリを更新（UI反映）
        page.text = newText
        // データベースにも永続化
        do {
            try await repository.updatePageText(newText, pageId: page.id)
            debugLog("Page \(page.pageNumber): text updated")
        } catch {
            debugLog("Page \(page.pageNumber): text update failed: \(error)")
        }
    }

    // MARK: - Debug

    private func debugLog(_ message: String) {
        #if DEBUG
        print("📖 [ReaderVM] \(message)")
        #endif
    }
}
