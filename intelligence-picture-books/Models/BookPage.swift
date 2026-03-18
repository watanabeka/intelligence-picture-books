import Foundation
import SwiftData

@Model
final class BookPage {
    @Attribute(.unique) var id: UUID
    var pageNumber: Int
    var text: String
    var imageLocalName: String?
    var illustrationPrompt: String
    var finalImagePrompt: String
    var mood: String
    /// ImageCreator が失敗してフォールバック画像が使われたか
    var isFallback: Bool
    var book: Book?

    init(
        id: UUID = UUID(),
        pageNumber: Int,
        text: String = "",
        imageLocalName: String? = nil,
        illustrationPrompt: String = "",
        finalImagePrompt: String = "",
        mood: String = "",
        isFallback: Bool = false
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageLocalName = imageLocalName
        self.illustrationPrompt = illustrationPrompt
        self.finalImagePrompt = finalImagePrompt
        self.mood = mood
        self.isFallback = isFallback
    }
}
