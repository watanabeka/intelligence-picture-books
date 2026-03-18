import Foundation

// MARK: - VisualStyle

/// 絵柄スタイル。すべてのページで同一スタイルを使用し、統一感を確保する。
enum VisualStyle: String, Sendable, CaseIterable {
    case pastelWatercolor
    case softCrayon
    case bedtimeSoft

    /// 画像プロンプトに注入するスタイル記述
    var promptFragment: String {
        switch self {
        case .pastelWatercolor:
            return "pastel watercolor, soft color washes, gentle brushwork, warm paper texture, rounded soft shapes, light and airy"
        case .softCrayon:
            return "soft crayon illustration, warm textured strokes, rounded shapes, matte finish, hand-drawn feel"
        case .bedtimeSoft:
            return "soft dreamy illustration, muted warm tones, gentle glow, cozy nighttime atmosphere, starlit"
        }
    }

    /// デフォルトスタイル
    static let `default`: VisualStyle = .pastelWatercolor
}

// MARK: - CharacterSheet

/// キャラクターの外見・性格を固定するシート。
/// すべてのページの画像プロンプトにこの情報を注入する。
struct CharacterSheet: Sendable, Equatable {
    var mainCharacterName: String
    var species: String
    var ageFeeling: String
    var bodyColor: String
    var earShape: String
    var earSize: String = ""       // 例: "large", "small", "medium"
    var faceShape: String = ""     // 例: "round", "chubby", "oval"
    var eyeStyle: String = ""      // 例: "large round", "sparkly", "wide"
    var tailShape: String = ""     // 例: "fluffy round", "short stub", "long bushy"
    var accessory: String
    var personality: String

    /// 画像プロンプトに注入するキャラクター記述（英語）
    /// "CONSISTENT CHARACTER:" ヘッダーで AI に一貫性を強調する
    /// 画像プロンプトに注入するキャラクターの視覚的アンカー記述（英語・自然な文体）
    var promptFragment: String {
        var parts: [String] = []
        if !species.isEmpty && !bodyColor.isEmpty {
            parts.append("a \(bodyColor) \(species)")
        } else if !species.isEmpty {
            parts.append("a \(species)")
        }
        let earDesc = [earSize, earShape].filter { !$0.isEmpty }.joined(separator: " ")
        if !earDesc.isEmpty { parts.append("with \(earDesc) ears") }
        if !faceShape.isEmpty { parts.append("\(faceShape) face") }
        if !eyeStyle.isEmpty { parts.append("\(eyeStyle) eyes") }
        if !tailShape.isEmpty { parts.append("\(tailShape) tail") }
        if !accessory.isEmpty { parts.append("wearing \(accessory)") }
        return parts.joined(separator: ", ")
    }

    /// キャラ固定のために毎回含めるべき特徴（短縮版）
    var mustKeepTraits: [String] {
        var traits: [String] = []
        if !species.isEmpty { traits.append(species) }
        if !bodyColor.isEmpty { traits.append(bodyColor) }
        let earDesc = [earSize, earShape].filter { !$0.isEmpty }.joined(separator: " ")
        if !earDesc.isEmpty { traits.append("\(earDesc) ears") }
        if !accessory.isEmpty { traits.append(accessory) }
        return traits
    }

    /// デフォルト（未設定状態）
    static let empty = CharacterSheet(
        mainCharacterName: "",
        species: "",
        ageFeeling: "",
        bodyColor: "",
        earShape: "",
        earSize: "",
        faceShape: "",
        eyeStyle: "",
        tailShape: "",
        accessory: "",
        personality: ""
    )
}

// MARK: - SceneMode

/// ページに登場するキャラクターの構成。
/// 文字列解析による推定を廃止し、Validator が明示的に設定する。
enum SceneMode: String, Sendable {
    case solo  // 主人公のみ
    case duo   // 主人公 + 友達キャラ（1人）
}

// MARK: - PagePlan

/// 1ページ分の計画。LLMが生成した内容 + 検証後の補完情報を含む。
struct PagePlan: Sendable, Identifiable {
    let id = UUID()
    var pageNumber: Int
    var sceneTitle: String
    var narration: String
    var illustrationPrompt: String
    var forbiddenElements: [String]
    var camera: String
    var location: String
    var mood: String
    var keyObjects: [String]
    var continuityNotes: String
    var sceneMode: SceneMode

    static func empty(pageNumber: Int) -> PagePlan {
        PagePlan(
            pageNumber: pageNumber,
            sceneTitle: "",
            narration: "",
            illustrationPrompt: "",
            forbiddenElements: Self.defaultForbiddenElements,
            camera: "medium shot",
            location: "",
            mood: "やさしい",
            keyObjects: [],
            continuityNotes: "",
            sceneMode: .solo
        )
    }

    /// すべての画像プロンプトに含めるべき禁止要素
    static let defaultForbiddenElements = [
        "text", "letters", "typography", "writing",
        "watermark", "logo", "signage", "book cover title text",
        "words", "numbers", "caption", "labels", "subtitles",
        "billboards", "storefronts", "road signs", "posters"
    ]
}

// MARK: - CoverPlan

/// 表紙の計画。本文ページとは独立して生成する。
struct CoverPlan: Sendable {
    var title: String
    var subtitle: String?
    var mainCharacterDescription: String
    var worldKeywords: [String]
    var coverPrompt: String
}

// MARK: - StoryPlan

/// 物語全体の計画。STEP 1 で生成し、STEP 2 で検証する。
struct StoryPlan: Sendable {
    var title: String
    var theme: String
    var visualStyle: VisualStyle
    var characterSheet: CharacterSheet
    var pages: [PagePlan]
    var coverPlan: CoverPlan

    /// デバッグ用のサマリー
    var debugSummary: String {
        var lines: [String] = []
        lines.append("=== StoryPlan Debug ===")
        lines.append("Title: \(title)")
        lines.append("Theme: \(theme)")
        lines.append("Style: \(visualStyle.rawValue)")
        lines.append("Character: \(characterSheet.mainCharacterName) (\(characterSheet.species))")
        lines.append("  Body: \(characterSheet.bodyColor), EarSize: \(characterSheet.earSize), EarShape: \(characterSheet.earShape)")
        lines.append("  Face: \(characterSheet.faceShape), Eyes: \(characterSheet.eyeStyle), Tail: \(characterSheet.tailShape)")
        lines.append("  Accessory: \(characterSheet.accessory)")
        lines.append("Pages: \(pages.count)")
        for page in pages {
            lines.append("  P\(page.pageNumber): \(page.sceneTitle) [\(page.sceneMode.rawValue)] [\(page.camera)]")
            lines.append("    Narration: \(page.narration.prefix(50))...")
            lines.append("    Scene: \(page.illustrationPrompt.prefix(50))...")
            lines.append("    Mood: \(page.mood), Objects: \(page.keyObjects.joined(separator: ", "))")
        }
        lines.append("Cover prompt: \(coverPlan.coverPrompt.prefix(80))...")
        lines.append("======================")
        return lines.joined(separator: "\n")
    }
}
