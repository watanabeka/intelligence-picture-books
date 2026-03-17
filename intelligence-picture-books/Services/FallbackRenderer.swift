import Foundation
import UIKit

/// ImageCreator が使えない環境でのフォールバック画像生成。
/// CoreGraphics + UIBezierPath で絵本風のシーンを構築する。
/// キャラクターシートとビジュアルスタイルを受け取り、一貫性のある画像を生成する。
enum FallbackRenderer {

    // MARK: - Public

    /// 表紙を描画する。タイトル文字は描かない（UIレイヤーで重ねる）。
    static func renderCover(
        title: String,
        characterSheet: CharacterSheet,
        theme: String,
        visualStyle: VisualStyle
    ) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        let palette = paletteForStyle(visualStyle)
        let mainSymbol = symbolForSpecies(characterSheet.species)

        let scene = sceneColors(for: visualStyle)
        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            drawGround(in: ctx, rect: rect, frontColor: scene.groundFront, backColor: scene.groundBack)
            drawSun(in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12), radius: 35, color: UIColor(hex: 0xFFE082))
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.2, y: rect.height * 0.1), scale: 1.2)
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.65, y: rect.height * 0.22), scale: 0.8)

            // メインキャラクター（キャラクターシートから一貫した外見）
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width / 2, y: rect.height * 0.42),
                       size: 110, color: colorForCharacter(characterSheet))

            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent, dotBase: scene.groundDotBase)
            drawVignette(in: ctx, rect: rect)
            // タイトルテキストは描かない — UI レイヤーで Text ビューを重ねる
        }
    }

    /// ページを描画する。キャラクターシートで一貫した見た目を維持する。
    static func renderPage(
        pageNumber: Int,
        pagePlan: PagePlan,
        characterSheet: CharacterSheet,
        visualStyle: VisualStyle
    ) -> UIImage {
        let size = CGSize(width: 640, height: 360)
        let palette = paletteForStyle(visualStyle, mood: pagePlan.mood)
        let mainSymbol = symbolForSpecies(characterSheet.species)
        let extraSymbol = findSymbolFromKeyObjects(pagePlan.keyObjects)
        let isNightScene = pagePlan.mood.contains("しんみり") || pagePlan.mood.contains("おだやか")
            || pagePlan.illustrationPrompt.lowercased().contains("night")
            || pagePlan.illustrationPrompt.lowercased().contains("moon")

        let scene = sceneColors(for: visualStyle)
        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            if isNightScene {
                let nightFront = scene.groundFront.withAlphaComponent(0.35)
                let nightBack = UIColor(hex: 0x37474F).withAlphaComponent(0.4)
                drawGround(in: ctx, rect: rect, frontColor: nightFront, backColor: nightBack)
                drawMoon(in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12), radius: 20,
                         color: UIColor(hex: 0xFFE082))
                drawStars(in: ctx, rect: rect, count: 8)
            } else {
                drawGround(in: ctx, rect: rect, frontColor: scene.groundFront, backColor: scene.groundBack)
                drawSun(in: ctx, at: CGPoint(x: rect.width * 0.82, y: rect.height * 0.1), radius: 24, color: UIColor(hex: 0xFFE082))
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.18, y: rect.height * 0.08), scale: 0.7)
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.55, y: rect.height * 0.15), scale: 0.5)
            }

            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.12, y: rect.height * 0.63), scale: 0.7, color: scene.treeMain)
            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.88, y: rect.height * 0.63), scale: 0.5, color: scene.treeLighter)

            // メインキャラクター（常に同じ見た目）
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width * 0.4, y: rect.height * 0.48),
                       size: 72, color: colorForCharacter(characterSheet))

            // シーン固有のオブジェクト
            if let extra = extraSymbol {
                drawSymbol(extra, in: ctx, at: CGPoint(x: rect.width * 0.65, y: rect.height * 0.52),
                           size: 40, color: palette.accent.withAlphaComponent(0.7))
            }

            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent, dotBase: scene.groundDotBase)
            drawVignette(in: ctx, rect: rect)
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

    // MARK: - Style-aware scene colors

    private struct SceneColors {
        var groundFront: UIColor
        var groundBack: UIColor
        var treeMain: UIColor
        var treeLighter: UIColor
        var groundDotBase: UIColor
    }

    private static func sceneColors(for visualStyle: VisualStyle) -> SceneColors {
        switch visualStyle {
        case .pastelWatercolor:
            return SceneColors(
                groundFront: UIColor(hex: 0xA5D6A7),
                groundBack: UIColor(hex: 0xC8E6C9),
                treeMain: UIColor(hex: 0x81C784),
                treeLighter: UIColor(hex: 0xA5D6A7),
                groundDotBase: UIColor(hex: 0x66BB6A)
            )
        case .softCrayon:
            return SceneColors(
                groundFront: UIColor(hex: 0xFFF176),
                groundBack: UIColor(hex: 0xFFF9C4),
                treeMain: UIColor(hex: 0xAED581),
                treeLighter: UIColor(hex: 0xCDDC39).withAlphaComponent(0.7),
                groundDotBase: UIColor(hex: 0xFFB74D)
            )
        case .bedtimeSoft:
            return SceneColors(
                groundFront: UIColor(hex: 0xB39DDB),
                groundBack: UIColor(hex: 0xD1C4E9),
                treeMain: UIColor(hex: 0x9575CD),
                treeLighter: UIColor(hex: 0xB39DDB),
                groundDotBase: UIColor(hex: 0xCE93D8)
            )
        }
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
            (["star", "stars", "ほし"], "star.fill"),
            (["cloud", "clouds", "くも"], "cloud.fill"),
            (["mountain", "やま"], "mountain.2.fill"),
            (["rainbow", "にじ"], "rainbow"),
            (["sun", "ひ", "たいよう"], "sun.max.fill"),
            (["moon", "つき"], "moon.fill"),
            (["tree", "trees", "き"], "tree.fill"),
            (["water", "sea", "ocean", "うみ"], "water.waves"),
            (["heart", "ハート"], "heart.fill"),
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

            // 3-color sky gradient: sky blue top → warm horizon → ground
            let skyTop = palette.bg.first ?? UIColor(hex: 0xE8F5E9)
            let skyMid = skyTop.withAlphaComponent(0.7).blended(with: UIColor(hex: 0xFFF9E7), alpha: 0.4)
            let skyBot = palette.bg.last ?? UIColor(hex: 0xC8E6C9)
            let colors = [skyTop.cgColor, skyMid.cgColor, skyBot.cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.55, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
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

    private static func drawGround(in ctx: UIGraphicsImageRendererContext, rect: CGRect,
                                    frontColor: UIColor, backColor: UIColor) {
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
        backColor.setFill()
        path.fill()

        let frontY = rect.height * 0.78
        let frontPath = UIBezierPath()
        frontPath.move(to: CGPoint(x: 0, y: frontY + 5))
        frontPath.addQuadCurve(to: CGPoint(x: rect.width, y: frontY - 8),
                               controlPoint: CGPoint(x: rect.width * 0.6, y: frontY - 25))
        frontPath.addLine(to: CGPoint(x: rect.width, y: rect.height))
        frontPath.addLine(to: CGPoint(x: 0, y: rect.height))
        frontPath.close()
        frontColor.setFill()
        frontPath.fill()
    }

    private static func drawSun(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, radius: CGFloat, color: UIColor) {
        color.withAlphaComponent(0.12).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 2.2, y: center.y - radius * 2.2,
                                     width: radius * 4.4, height: radius * 4.4)).fill()
        color.withAlphaComponent(0.25).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 1.4, y: center.y - radius * 1.4,
                                     width: radius * 2.8, height: radius * 2.8)).fill()
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2)).fill()
    }

    private static func drawMoon(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, radius: CGFloat, color: UIColor) {
        // Crescent moon using two overlapping circles
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2)).fill()
        // Subtract with background-ish color to make crescent
        let bgColor = UIColor(hex: 0x1A237E).withAlphaComponent(0.7)
        bgColor.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.3, y: center.y - radius * 1.1,
                                     width: radius * 1.8, height: radius * 1.8)).fill()
    }

    private static func drawCloud(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, scale: CGFloat) {
        // Rounder, multi-bubble cloud using bezier arcs
        let color = UIColor.white.withAlphaComponent(0.88)
        color.setFill()
        let w: CGFloat = 70 * scale
        let h: CGFloat = 28 * scale
        let r = h * 0.5

        // Main elongated body
        let bodyPath = UIBezierPath(roundedRect: CGRect(x: center.x - w * 0.46, y: center.y - h * 0.3,
                                                          width: w * 0.92, height: h), cornerRadius: r)
        bodyPath.fill()

        // Large top bubble
        UIBezierPath(ovalIn: CGRect(x: center.x - w * 0.18, y: center.y - h * 0.9,
                                     width: w * 0.46, height: h * 0.9)).fill()

        // Left smaller bubble
        UIBezierPath(ovalIn: CGRect(x: center.x - w * 0.45, y: center.y - h * 0.6,
                                     width: w * 0.32, height: h * 0.65)).fill()

        // Right smaller bubble
        UIBezierPath(ovalIn: CGRect(x: center.x + w * 0.1, y: center.y - h * 0.5,
                                     width: w * 0.28, height: h * 0.55)).fill()
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
        let starColor = UIColor(hex: 0xFFF9C4)
        let positions: [(CGFloat, CGFloat)] = [
            (0.1, 0.08), (0.3, 0.15), (0.5, 0.05), (0.7, 0.18),
            (0.15, 0.28), (0.45, 0.22), (0.85, 0.08), (0.65, 0.3),
        ]
        for i in 0..<min(count, positions.count) {
            let p = positions[i]
            let alpha = CGFloat.random(in: 0.5...1.0)
            let cx = rect.width * p.0
            let cy = rect.height * p.1
            let r: CGFloat = CGFloat.random(in: 2...3.5)
            starColor.withAlphaComponent(alpha).setFill()
            UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
        }
    }

    /// パス描画の花（SF Symbol leaf.fill の代替）
    private static func drawFlower(in ctx: UIGraphicsImageRendererContext,
                                   at center: CGPoint, radius: CGFloat,
                                   petalColor: UIColor, centerColor: UIColor) {
        let petalCount = 5
        petalColor.setFill()
        for i in 0..<petalCount {
            let angle = CGFloat(i) / CGFloat(petalCount) * .pi * 2
            let px = center.x + cos(angle) * radius
            let py = center.y + sin(angle) * radius
            UIBezierPath(ovalIn: CGRect(x: px - radius * 0.55, y: py - radius * 0.55,
                                         width: radius * 1.1, height: radius * 1.1)).fill()
        }
        // 中心
        centerColor.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.45, y: center.y - radius * 0.45,
                                     width: radius * 0.9, height: radius * 0.9)).fill()
    }

    private static func drawGroundDecorations(in ctx: UIGraphicsImageRendererContext, rect: CGRect,
                                               accent: UIColor, dotBase: UIColor) {
        let flowerPositions: [(CGFloat, CGFloat)] = [
            (0.12, 0.80), (0.28, 0.76), (0.48, 0.83), (0.68, 0.78), (0.85, 0.82),
        ]
        let petalColorSets: [(UIColor, UIColor)] = [
            (UIColor(hex: 0xF48FB1), UIColor(hex: 0xFFE082)),
            (UIColor(hex: 0xCE93D8), UIColor(hex: 0xFFF9C4)),
            (UIColor(hex: 0x80CBC4), UIColor(hex: 0xFFE082)),
            (UIColor(hex: 0xFF8A65), UIColor(hex: 0xFFF9C4)),
            (UIColor(hex: 0xAED581), UIColor(hex: 0xFFE082)),
        ]

        for (i, pos) in flowerPositions.enumerated() {
            let cx = rect.width * pos.0
            let cy = rect.height * pos.1
            let r: CGFloat = 5.5
            let colors = petalColorSets[i % petalColorSets.count]
            drawFlower(in: ctx, at: CGPoint(x: cx, y: cy), radius: r,
                       petalColor: colors.0.withAlphaComponent(0.75),
                       centerColor: colors.1)
        }

        // 地面の小さい草ドット
        let grassPositions: [(CGFloat, CGFloat)] = [
            (0.22, 0.86), (0.38, 0.84), (0.55, 0.88), (0.72, 0.85), (0.90, 0.87),
        ]
        dotBase.withAlphaComponent(0.45).setFill()
        for pos in grassPositions {
            let r: CGFloat = 3
            UIBezierPath(ovalIn: CGRect(x: rect.width * pos.0, y: rect.height * pos.1,
                                         width: r * 2, height: r * 2)).fill()
        }
    }

    /// 周辺をわずかに暗くするビネット（絵本らしい温かみを演出）
    private static func drawVignette(in ctx: UIGraphicsImageRendererContext, rect: CGRect) {
        let cgCtx = ctx.cgContext
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = max(rect.width, rect.height) * 0.72
        let innerR = max(rect.width, rect.height) * 0.3
        let colors: [CGColor] = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.08).cgColor,
        ]
        let locs: [CGFloat] = [0, 1]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray, locations: locs) {
            cgCtx.drawRadialGradient(gradient,
                                     startCenter: center, startRadius: innerR,
                                     endCenter: center, endRadius: outerR,
                                     options: [.drawsAfterEndLocation])
        }
    }

    private static func drawSymbol(_ name: String, in ctx: UIGraphicsImageRendererContext,
                                   at center: CGPoint, size: CGFloat, color: UIColor) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color, color.withAlphaComponent(0.7)]))
        if let img = UIImage(systemName: name, withConfiguration: config) {
            // キャラクターの足元にソフトな影楕円
            let shadowW = img.size.width * 0.7
            let shadowH = img.size.height * 0.14
            let shadowX = center.x - shadowW / 2
            let shadowY = center.y + img.size.height * 0.42
            UIColor.black.withAlphaComponent(0.12).setFill()
            UIBezierPath(ovalIn: CGRect(x: shadowX, y: shadowY, width: shadowW, height: shadowH)).fill()

            img.draw(at: CGPoint(x: center.x - img.size.width / 2, y: center.y - img.size.height / 2))
        }
    }
}

// MARK: - UIColor blend helper

private extension UIColor {
    func blended(with other: UIColor, alpha: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 * (1 - alpha) + r2 * alpha,
            green: g1 * (1 - alpha) + g2 * alpha,
            blue: b1 * (1 - alpha) + b2 * alpha,
            alpha: 1.0
        )
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
