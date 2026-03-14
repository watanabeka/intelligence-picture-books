import Foundation
import SwiftData

@Model
final class BookPage {
    @Attribute(.unique) var id: UUID
    var pageNumber: Int
    var text: String
    var imageLocalName: String?
    var illustrationPrompt: String
    var mood: String

    var book: Book?

    init(
        id: UUID = UUID(),
        pageNumber: Int,
        text: String = "",
        imageLocalName: String? = nil,
        illustrationPrompt: String = "",
        mood: String = ""
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageLocalName = imageLocalName
        self.illustrationPrompt = illustrationPrompt
        self.mood = mood
    }
}
