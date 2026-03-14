import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var theme: String
    var pageCount: Int
    var title: String
    var coverImageLocalName: String?
    var isComplete: Bool

    @Relationship(deleteRule: .cascade, inverse: \BookPage.book)
    var pages: [BookPage]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        theme: String,
        pageCount: Int,
        title: String = "",
        coverImageLocalName: String? = nil,
        isComplete: Bool = false,
        pages: [BookPage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.theme = theme
        self.pageCount = pageCount
        self.title = title
        self.coverImageLocalName = coverImageLocalName
        self.isComplete = isComplete
        self.pages = pages
    }

    var sortedPages: [BookPage] {
        pages.sorted { $0.pageNumber < $1.pageNumber }
    }
}
