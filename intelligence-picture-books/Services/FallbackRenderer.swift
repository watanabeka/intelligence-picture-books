import Foundation
import UIKit

/// ImageCreator が使えない環境でのフォールバック画像生成。
/// SF Symbols + CoreGraphics で絵本風のシーンを構築する。
/// キャラクターシートとビジュアルスタイルを受け取り、一貫性のある画像を生成する。
enum FallbackRenderer {

    // MARK: - Public

    /// 表紙を描画する。characterSheet の情報を使ってキャラクターを固定する。
    static func renderCover(
        title: String,
        characterSheet: CharacterSheet,
        theme: String,
        visualStyle: VisualStyle
    ) -> UIImage {
        let size = CGSize(width: 600, height: 800)
        let palette = paletteForStyle(visualStyle)
        let mainSymbol = symbolForSpecies(characterSheet.species)

        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            drawGround(in: ctx, rect: rect, color: UIColor(hex: 0xC8E6C9))
            drawSun(in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12), radius: 35, color: UIColor(hex: 0xFFE082))
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.2, y: rect.height * 0.1), scale: 1.2)
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.65, y: rect.height * 0.22), scale: 0.8)

            // メインキャラクター（キャラクターシートから一貫した外見）
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width / 2, y: rect.height * 0.4),
                       size: 100, color: colorForCharacter(characterSheet))

            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent)

            // タイトル（UIレイヤーで重ねるため、フォールバックでは簡易表示）
            drawTitle(title, in: ctx, rect: rect, color: palette.accent)
        }
    }

    /// ページを描画する。キャラクターシートで一貫した見た目を維持する。
    static func renderPage(
        pageNumber: Int,
        pagePlan: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> UIImage {
        let size = CGSize(width: 600, height: 400)
        let palette = paletteForStyle(visualStyle, mood: pagePlan.mood)
        let mainSymbol = symbolForSpecies(characterSheet.species)
        let extraSymbol = findSymbolFromKeyObjects(pagePlan.keyObjects)
        let isNightScene = pagePlan.mood.contains("しんみり") || pagePlan.mood.contains("おだやか")
            || pagePlan.illustrationPrompt.lowercased().contains("night")
            || pagePlan.illustrationPrompt.lowercased().contains("moon")

        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            if isNightScene {
                drawGround(in: ctx, rect: rect, color: UIColor(hex: 0x37474F).withAlphaComponent(0.4))
                drawSymbol("moon.fill", in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12),
                           size: 36, color: UIColor(hex: 0xFFE082))
                drawStars(in: ctx, rect: rect, count: 8)
            } else {
                drawGround(in: ctx, rect: rect, color: UIColor(hex: 0xC8E6C9))
                drawSun(in: ctx, at: CGPoint(x: rect.width * 0.82, y: rect.height * 0.1), radius: 24, color: UIColor(hex: 0xFFE082))
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.18, y: rect.height * 0.08), scale: 0.7)
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.55, y: rect.height * 0.15), scale: 0.5)
            }

            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.12, y: rect.height * 0.63), scale: 0.7, color: UIColor(hex: 0x81C784))
            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.88, y: rect.height * 0.63), scale: 0.5, color: UIColor(hex: 0xA5D6A7))

            // メインキャラクター（常に同じ見た目）
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width * 0.4, y: rect.height * 0.48),
                       size: 72, color: colorForCharacter(characterSheet))

            // シーン固有のオブジェクト
            if let extra = extraSymbol {
                drawSymbol(extra, in: ctx, at: CGPoint(x: rect.width * 0.65, y: rect.height * 0.52),
                           size: 40, color: palette.accent.withAlphaComponent(0.7))
            }

            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent)
        }
    }

    /// レガシー互換: 旧 API からの呼び出し用
    static func renderCoverLegacy(title: String, theme: String) -> UIImage {
        renderCover(
            title: title,
            characterSheet: .empty,
            theme: theme,
            visualStyle: .default
        )
    }

    /// レガシー互換: 旧 API からの呼び出し用
    static func renderPageLegacy(pageNumber: Int, prompt: String, mood: String) -> UIImage {
        let pagePlan = PagePlan(
            pageNumber: pageNumber,
            sceneTitle: "",
            narration: "",
            illustrationPrompt: prompt,
            forbiddenElements: [],
            camera: "",
            location: "",
            mood: mood,
            keyObjects: [],
            continuityNotes: ""
        )
        return renderPage(
            pageNumber: pageNumber,
            pagePlan: pagePlan,
            characterSheet: .empty,
            visualStyle: .default
        )
    }

    // MARK: - Character/Style helpers

    /// キャラクターの species から SF Symbol を決定
    private static func symbolForSpecies(_ species: String) -> String {
        let lower = species.lowercased()
        let speciesMap: [(keywords: [String], symbol: String)] = [
            (["rabbit", "bunny", "hare", "うさぎ"], "hare.fill"),
            (["cat", "kitten", "ねこ", "猫"], "cat.fill"),
            (["dog", "puppy", "いぬ", "犬"], "dog.fill"),
            (["bird", "とり", "鳥"], "bird.fill"),
            (["fish", "さかな", "魚"], "fish.fill"),
            (["turtle", "tortoise", "かめ", "亀"], "tortoise.fill"),
            (["bear", "くま", "熊"], "pawprint.fill"),
            (["bug", "ladybug", "むし", "虫"], "ladybug.fill"),
        ]
        for entry in speciesMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.symbol
            }
        }
        return "hare.fill" // デフォルト
    }

    /// キャラクターの体の色からUIColorを決定
    private static func colorForCharacter(_ sheet: CharacterSheet) -> UIColor {
        let lower = sheet.bodyColor.lowercased()
        let colorMap: [(keywords: [String], color: UIColor)] = [
            (["white"], UIColor(hex: 0xEEEEEE)),
            (["brown", "茶"], UIColor(hex: 0x8D6E63)),
            (["orange", "tabby"], UIColor(hex: 0xFFB74D)),
            (["black", "黒"], UIColor(hex: 0x424242)),
            (["gray", "grey", "灰"], UIColor(hex: 0x9E9E9E)),
            (["yellow", "黄"], UIColor(hex: 0xFFD54F)),
            (["blue", "青"], UIColor(hex: 0x64B5F6)),
            (["pink", "ピンク"], UIColor(hex: 0xF48FB1)),
        ]
        for entry in colorMap {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return entry.color
            }
        }
        return UIColor(hex: 0xEEEEEE) // デフォルト白
    }

    /// VisualStyle からパレットを決定
    private static func paletteForStyle(_ style: VisualStyle, mood: String = "") -> (bg: [UIColor], accent: UIColor) {
        // まず mood でパレットを探す
        if !mood.isEmpty, let moodPalette = findMoodPalette(mood) {
            return moodPalette
        }

        // style に基づくデフォルト
        switch style {
        case .pastelWatercolor:
            return ([UIColor(hex: 0xE8F5E9), UIColor(hex: 0xC8E6C9)], UIColor(hex: 0x66BB6A))
        case .softCrayon:
            return ([UIColor(hex: 0xFFF8E1), UIColor(hex: 0xFFECB3)], UIColor(hex: 0xFFD54F))
        case .bedtimeSoft:
            return ([UIColor(hex: 0xEDE7F6), UIColor(hex: 0xD1C4E9)], UIColor(hex: 0x9575CD))
        }
    }

    /// keyObjects から追加シンボルを検索
    private static func findSymbolFromKeyObjects(_ objects: [String]) -> String? {
        let combined = objects.joined(separator: " ").lowercased()
        let objectSymbols: [(keywords: [String], symbol: String)] = [
            (["flower", "flowers", "はな"], "leaf.fill"),
            (["star", "stars", "ほし"], "star.fill"),
            (["cloud", "clouds", "くも"], "cloud.fill"),
            (["mountain", "やま"], "mountain.2.fill"),
            (["rainbow", "にじ"], "rainbow"),
            (["sun", "ひ", "たいよう"], "sun.max.fill"),
            (["moon", "つき"], "moon.fill"),
            (["tree", "trees", "き"], "tree.fill"),
            (["water", "sea", "ocean", "うみ"], "water.waves"),
            (["heart", "ハート"], "heart.fill"),
            (["butterfly", "ちょうちょ"], "leaf.fill"),
        ]
        for entry in objectSymbols {
            if entry.keywords.contains(where: { combined.contains($0) }) {
                return entry.symbol
            }
        }
        return nil
    }

    // MARK: - Mood palette

    private static let moodPalettes: [(keywords: [String], bg: [UIColor], accent: UIColor)] = [
        (["わくわく", "たのしい", "にぎやか", "cheerful"],
         [UIColor(hex: 0xFFF3E0), UIColor(hex: 0xFFE0B2)], UIColor(hex: 0xFFB74D)),
        (["どきどき", "ゆうき", "brave"],
         [UIColor(hex: 0xFCE4EC), UIColor(hex: 0xF8BBD0)], UIColor(hex: 0xF06292)),
        (["しんみり", "おだやか", "calm"],
         [UIColor(hex: 0xE3F2FD), UIColor(hex: 0xBBDEFB)], UIColor(hex: 0x64B5F6)),
        (["ふしぎ", "きらきら", "mysterious"],
         [UIColor(hex: 0xEDE7F6), UIColor(hex: 0xD1C4E9)], UIColor(hex: 0x9575CD)),
        (["やさしい", "あたたかい", "ほっこり", "gentle"],
         [UIColor(hex: 0xFFF8E1), UIColor(hex: 0xFFECB3)], UIColor(hex: 0xFFD54F)),
    ]

    private static func findMoodPalette(_ mood: String) -> (bg: [UIColor], accent: UIColor)? {
        let lower = mood.lowercased()
        for entry in moodPalettes {
            if entry.keywords.contains(where: { lower.contains($0) }) {
                return (entry.bg, entry.accent)
            }
        }
        return nil
    }

    // MARK: - Scene drawing helpers

    private static func renderSceneImage(size: CGSize, palette: (bg: [UIColor], accent: UIColor),
                                         draw: (UIGraphicsImageRendererContext, CGRect) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cgCtx = ctx.cgContext
            let colors = palette.bg.map { $0.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                cgCtx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            } else {
                palette.bg.first?.setFill()
                UIBezierPath(rect: rect).fill()
            }
            let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: 20)
            cardPath.addClip()
            draw(ctx, rect)
        }
    }

    private static func drawGround(in ctx: UIGraphicsImageRendererContext, rect: CGRect, color: UIColor) {
        let groundY = rect.height * 0.65
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: groundY + 15))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.5, y: groundY - 10),
                          controlPoint: CGPoint(x: rect.width * 0.25, y: groundY - 20))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: groundY + 5),
                          controlPoint: CGPoint(x: rect.width * 0.75, y: groundY + 15))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.close()
        color.setFill()
        path.fill()

        let frontY = rect.height * 0.78
        let frontPath = UIBezierPath()
        frontPath.move(to: CGPoint(x: 0, y: frontY + 5))
        frontPath.addQuadCurve(to: CGPoint(x: rect.width, y: frontY - 8),
                               controlPoint: CGPoint(x: rect.width * 0.6, y: frontY - 25))
        frontPath.addLine(to: CGPoint(x: rect.width, y: rect.height))
        frontPath.addLine(to: CGPoint(x: 0, y: rect.height))
        frontPath.close()
        color.withAlphaComponent(0.6).setFill()
        frontPath.fill()
    }

    private static func drawSun(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, radius: CGFloat, color: UIColor) {
        color.withAlphaComponent(0.15).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 2, y: center.y - radius * 2,
                                     width: radius * 4, height: radius * 4)).fill()
        color.withAlphaComponent(0.3).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 1.3, y: center.y - radius * 1.3,
                                     width: radius * 2.6, height: radius * 2.6)).fill()
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2)).fill()
    }

    private static func drawCloud(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, scale: CGFloat) {
        let color = UIColor.white.withAlphaComponent(0.8)
        color.setFill()
        let w: CGFloat = 60 * scale
        let h: CGFloat = 25 * scale
        UIBezierPath(ovalIn: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)).fill()
        UIBezierPath(ovalIn: CGRect(x: center.x - w * 0.6, y: center.y, width: w * 0.7, height: h * 0.8)).fill()
        UIBezierPath(ovalIn: CGRect(x: center.x + w * 0.05, y: center.y + h * 0.1, width: w * 0.6, height: h * 0.75)).fill()
    }

    private static func drawTree(in ctx: UIGraphicsImageRendererContext, at base: CGPoint, scale: CGFloat, color: UIColor) {
        let trunkW: CGFloat = 8 * scale
        let trunkH: CGFloat = 20 * scale
        UIColor(hex: 0x8D6E63).setFill()
        UIBezierPath(roundedRect: CGRect(x: base.x - trunkW / 2, y: base.y - trunkH,
                                          width: trunkW, height: trunkH), cornerRadius: 2).fill()
        let crownR: CGFloat = 28 * scale
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: base.x - crownR, y: base.y - trunkH - crownR * 1.5,
                                     width: crownR * 2, height: crownR * 2)).fill()
        color.withAlphaComponent(0.7).setFill()
        UIBezierPath(ovalIn: CGRect(x: base.x - crownR * 0.7, y: base.y - trunkH - crownR * 2,
                                     width: crownR * 1.4, height: crownR * 1.4)).fill()
    }

    private static func drawStars(in ctx: UIGraphicsImageRendererContext, rect: CGRect, count: Int) {
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .light)
        let starColor = UIColor(hex: 0xFFF9C4)
        let positions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.3, 0.15), (0.5, 0.05), (0.7, 0.18),
            (0.15, 0.28), (0.45, 0.22), (0.85, 0.08), (0.65, 0.3),
        ]
        for i in 0..<min(count, positions.count) {
            let p = positions[i]
            let alpha = CGFloat.random(in: 0.5...1.0)
            if let img = UIImage(systemName: "sparkle", withConfiguration: config) {
                starColor.withAlphaComponent(alpha).setFill()
                img.draw(at: CGPoint(x: rect.width * p.0, y: rect.height * p.1))
            }
        }
    }

    private static func drawGroundDecorations(in ctx: UIGraphicsImageRendererContext, rect: CGRect, accent: UIColor) {
        let flowerPositions: [(CGFloat, CGFloat)] = [
            (0.15, 0.82), (0.35, 0.78), (0.55, 0.85), (0.75, 0.80), (0.9, 0.83),
        ]
        let flowerConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let flowerColors = [UIColor(hex: 0x66BB6A), UIColor(hex: 0x81C784), UIColor(hex: 0x4CAF50),
                           UIColor(hex: 0xAED581), UIColor(hex: 0x66BB6A)]

        for (i, pos) in flowerPositions.enumerated() {
            let color = flowerColors[i % flowerColors.count]
            if let img = UIImage(systemName: "leaf.fill", withConfiguration: flowerConfig) {
                color.withAlphaComponent(0.5).setFill()
                img.draw(at: CGPoint(x: rect.width * pos.0, y: rect.height * pos.1))
            }
        }

        let dotColors = [UIColor(hex: 0xF48FB1), UIColor(hex: 0xFFE082), UIColor(hex: 0xCE93D8), accent.withAlphaComponent(0.5)]
        let dotPositions: [(CGFloat, CGFloat)] = [
            (0.22, 0.84), (0.42, 0.8), (0.62, 0.86), (0.82, 0.82),
            (0.28, 0.88), (0.5, 0.9), (0.7, 0.87),
        ]
        for (i, pos) in dotPositions.enumerated() {
            let r: CGFloat = CGFloat.random(in: 3...5)
            dotColors[i % dotColors.count].setFill()
            UIBezierPath(ovalIn: CGRect(x: rect.width * pos.0, y: rect.height * pos.1, width: r * 2, height: r * 2)).fill()
        }
    }

    private static func drawSymbol(_ name: String, in ctx: UIGraphicsImageRendererContext,
                                   at center: CGPoint, size: CGFloat, color: UIColor) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color, color.withAlphaComponent(0.7)]))
        if let img = UIImage(systemName: name, withConfiguration: config) {
            color.withAlphaComponent(0.15).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - img.size.width * 0.3, y: center.y + img.size.height * 0.35,
                                         width: img.size.width * 0.6, height: img.size.height * 0.15)).fill()
            img.draw(at: CGPoint(x: center.x - img.size.width / 2, y: center.y - img.size.height / 2))
        }
    }

    private static func drawTitle(_ title: String, in ctx: UIGraphicsImageRendererContext, rect: CGRect, color: UIColor) {
        guard !title.isEmpty else { return }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let bannerRect = CGRect(x: rect.width * 0.1, y: rect.height * 0.85, width: rect.width * 0.8, height: 50)
        UIColor.white.withAlphaComponent(0.7).setFill()
        UIBezierPath(roundedRect: bannerRect, cornerRadius: 25).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let textRect = CGRect(x: bannerRect.minX + 10, y: bannerRect.minY + 12, width: bannerRect.width - 20, height: 30)
        (title as NSString).draw(in: textRect, withAttributes: attrs)
    }
}

// MARK: - UIColor hex extension

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1.0
        )
    }
}
