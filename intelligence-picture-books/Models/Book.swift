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

    // キャラクター・スタイル情報（ReaderView でのリトライ時フォールバック用）
    var characterSpecies: String
    var characterBodyColor: String
    var characterAccessory: String
    var visualStyleRaw: String

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
        characterSpecies: String = "",
        characterBodyColor: String = "",
        characterAccessory: String = "",
        visualStyleRaw: String = VisualStyle.default.rawValue,
        pages: [BookPage] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.theme = theme
        self.pageCount = pageCount
        self.title = title
        self.coverImageLocalName = coverImageLocalName
        self.isComplete = isComplete
        self.characterSpecies = characterSpecies
        self.characterBodyColor = characterBodyColor
        self.characterAccessory = characterAccessory
        self.visualStyleRaw = visualStyleRaw
        self.pages = pages
    }

    var sortedPages: [BookPage] {
        pages.sorted { $0.pageNumber < $1.pageNumber }
    }

    /// フォールバック描画用の CharacterSheet を構築
    var characterSheet: CharacterSheet {
        CharacterSheet(
            mainCharacterName: "",
            species: characterSpecies,
            ageFeeling: "young and cute",
            bodyColor: characterBodyColor,
            earShape: "",
            accessory: characterAccessory,
            personality: "curious and kind"
        )
    }

    /// 保存された VisualStyle を復元
    var visualStyle: VisualStyle {
        VisualStyle(rawValue: visualStyleRaw) ?? .default
    }
}
