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

    // キャラクター外見（CharacterSheet を個別フィールドで保持）
    // SwiftData は埋め込み struct を直接サポートしないため文字列で保持する
    var characterSpecies: String
    var characterBodyColor: String
    var characterAccessory: String
    var characterEarShape: String
    var characterEarSize: String
    var characterFaceShape: String
    var characterEyeStyle: String
    var characterFaceImpression: String
    var characterChestFur: String
    var characterTailShape: String
    var characterPersonality: String

    var visualStyleRaw: String

    // 画像生成統計
    var generatedImageCount: Int  // ImageCreator で生成した枚数
    var fallbackImageCount: Int   // FallbackRenderer で生成した枚数
    var imageGenerationModeRaw: String

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
        characterEarShape: String = "",
        characterEarSize: String = "",
        characterFaceShape: String = "",
        characterEyeStyle: String = "",
        characterFaceImpression: String = "",
        characterChestFur: String = "",
        characterTailShape: String = "",
        characterPersonality: String = "",
        visualStyleRaw: String = VisualStyle.default.rawValue,
        generatedImageCount: Int = 0,
        fallbackImageCount: Int = 0,
        imageGenerationModeRaw: String = ImageGenerationMode.fallbackOnly.rawValue,
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
        self.characterEarShape = characterEarShape
        self.characterEarSize = characterEarSize
        self.characterFaceShape = characterFaceShape
        self.characterEyeStyle = characterEyeStyle
        self.characterFaceImpression = characterFaceImpression
        self.characterChestFur = characterChestFur
        self.characterTailShape = characterTailShape
        self.characterPersonality = characterPersonality
        self.visualStyleRaw = visualStyleRaw
        self.generatedImageCount = generatedImageCount
        self.fallbackImageCount = fallbackImageCount
        self.imageGenerationModeRaw = imageGenerationModeRaw
        self.pages = pages
    }

    var sortedPages: [BookPage] {
        pages.sorted { $0.pageNumber < $1.pageNumber }
    }

    /// フォールバック描画・リトライ時に使用する CharacterSheet を完全な情報で再構築
    var characterSheet: CharacterSheet {
        CharacterSheet(
            mainCharacterName: "",
            species: characterSpecies,
            ageFeeling: "young and cute",
            bodyColor: characterBodyColor,
            earShape: characterEarShape,
            earSize: characterEarSize,
            faceShape: characterFaceShape,
            eyeStyle: characterEyeStyle,
            faceImpression: characterFaceImpression,
            chestFur: characterChestFur,
            tailShape: characterTailShape,
            accessory: characterAccessory,
            personality: characterPersonality.isEmpty ? "curious and kind" : characterPersonality
        )
    }

    /// 保存された VisualStyle を復元
    var visualStyle: VisualStyle {
        VisualStyle(rawValue: visualStyleRaw) ?? .default
    }

    /// 保存された ImageGenerationMode を復元
    var imageGenerationMode: ImageGenerationMode {
        ImageGenerationMode(rawValue: imageGenerationModeRaw) ?? .fallbackOnly
    }
}
