import Foundation
import SwiftUI
import ImagePlayground

@MainActor
@Observable
final class ReaderViewModel {
    let book: Book
    var coverImage: UIImage?
    var coverImageState: PageImageState = .loading
    var pageImages: [Int: UIImage] = [:]
    var pageImageStates: [Int: PageImageState] = [:]

    /// デバッグ用: ページ番号 → リトライ回数
    var pageRetryCounts: [Int: Int] = [:]
    /// デバッグ用: ページ番号 → 最後に使用したリトライプロンプト
    var pageRetryPrompts: [Int: String] = [:]
    /// デバッグ用: 表紙のリトライ回数
    var coverRetryCount: Int = 0
    /// デバッグ用: 表紙の最後のリトライプロンプト
    var coverRetryPrompt: String = ""
    /// デバッグ用: ImageCreator が利用可能か
    var isImageCreatorAvailable = true
    /// デバッグ用: ImageCreator の利用不可理由
    var imageCreatorUnavailableReason: String?
    /// デバッグ用: 最後に発生した画像生成エラー
    var lastImageError: String?

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
        // ImageCreator の利用可否を一度だけ確認（シミュレーター・言語・モデル非対応を早期検出）
        if imageCreatorUnavailableReason == nil {
            let avail = await illustrationGenerator.checkAvailability()
            isImageCreatorAvailable = avail.isUsable
            if !avail.isUsable {
                imageCreatorUnavailableReason = avail.reason
                debugLog("ImageCreator 非対応: \(avail.reason)")
            }
        }

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

    /// `unsupportedLanguage` 発生時に最小限英語プロンプトで確認リトライする。
    /// これでも失敗したらデバイス言語の問題として確定し `unsupportedLanguage` を再スロー。
    private func generateWithLanguageRetry(prompt: String) async throws -> UIImage {
        do {
            return try await illustrationGenerator.generateImage(prompt: prompt)
        } catch {
            guard let ice = error as? ImageCreator.Error, case .unsupportedLanguage = ice else {
                throw error
            }
            debugLog("⚠️ unsupportedLanguage 検出 — 最小限英語プロンプトで確認リトライ中")
            let minimalPrompt = IllustrationPromptTranslator.buildMinimalEnglishPrompt(
                characterSheet: book.characterSheet
            )
            return try await illustrationGenerator.generateImage(prompt: minimalPrompt)
        }
    }

    func retryImage(for page: BookPage) async {
        let pageNum = page.pageNumber
        pageImageStates[pageNum] = .retrying

        // リトライ回数をカウント
        pageRetryCounts[pageNum] = (pageRetryCounts[pageNum] ?? 0) + 1

        // リトライ専用プロンプトを構築（通常生成より制約が強い）
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
            continuityNotes: "",
            sceneMode: .solo,
            secondaryCharacterHint: ""
        )
        let retryPrompt = IllustrationPromptBuilder.buildRetryPagePrompt(
            page: pagePlan,
            characterSheet: book.characterSheet,
            visualStyle: book.visualStyle
        )
        pageRetryPrompts[pageNum] = retryPrompt
        debugLog("Page \(pageNum): retry #\(pageRetryCounts[pageNum]!) with strengthened prompt")

        for attempt in 1...2 {
            do {
                let image = try await generateWithLanguageRetry(prompt: retryPrompt)
                let imageName = "\(book.id.uuidString)_page\(pageNum).png"
                try await repository.saveImage(image, name: imageName)
                try await repository.updatePageImageName(imageName, pageId: page.id)
                pageImages[pageNum] = image
                pageImageStates[pageNum] = .ready
                debugLog("Page \(pageNum): retry success on attempt \(attempt)")
                return
            } catch {
                lastImageError = String(describing: error)
                debugLog("Page \(pageNum): retry attempt \(attempt) failed: \(error)")
                if let ice = error as? ImageCreator.Error, case .unsupportedLanguage = ice {
                    // 最小限英語でも失敗 → デバイス言語の問題として確定
                    isImageCreatorAvailable = false
                    imageCreatorUnavailableReason = "デバイス言語が非対応 (unsupportedLanguage)"
                    debugLog("Page \(pageNum): 最小英語でも unsupportedLanguage → フォールバックに移行")
                    break
                }
            }
        }

        // 2回失敗 → フォールバック画像を生成
        let fallbackImage = FallbackRenderer.renderPage(
            pageNumber: pageNum,
            pagePlan: pagePlan,
            characterSheet: book.characterSheet,
            visualStyle: book.visualStyle
        )
        let imageName = "\(book.id.uuidString)_page\(pageNum).png"
        try? await repository.saveImage(fallbackImage, name: imageName)
        pageImages[pageNum] = fallbackImage
        pageImageStates[pageNum] = .fallback
    }

    // MARK: - 表紙画像リトライ

    func retryCover() async {
        coverImageState = .retrying
        coverRetryCount += 1

        // リトライ専用プロンプトを構築
        let coverPlan = CoverPlan(
            title: book.title,
            subtitle: nil,
            mainCharacterDescription: book.characterSheet.promptFragment,
            worldKeywords: [],
            coverPrompt: "\(book.characterSheet.promptFragment) in a \(book.theme) world"
        )
        let retryPrompt = IllustrationPromptBuilder.buildRetryCoverPrompt(
            coverPlan: coverPlan,
            characterSheet: book.characterSheet,
            visualStyle: book.visualStyle
        )
        coverRetryPrompt = retryPrompt
        debugLog("Cover: retry #\(coverRetryCount) with strengthened prompt")

        for attempt in 1...2 {
            do {
                let image = try await generateWithLanguageRetry(prompt: retryPrompt)
                let imageName = "\(book.id.uuidString)_cover.png"
                try await repository.saveImage(image, name: imageName)
                coverImage = image
                coverImageState = .ready
                debugLog("Cover: retry success on attempt \(attempt)")
                return
            } catch {
                lastImageError = String(describing: error)
                debugLog("Cover: retry attempt \(attempt) failed: \(error)")
                if let ice = error as? ImageCreator.Error, case .unsupportedLanguage = ice {
                    // 最小限英語でも失敗 → デバイス言語の問題として確定
                    isImageCreatorAvailable = false
                    imageCreatorUnavailableReason = "デバイス言語が非対応 (unsupportedLanguage)"
                    debugLog("Cover: 最小英語でも unsupportedLanguage → フォールバックに移行")
                    break
                }
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
