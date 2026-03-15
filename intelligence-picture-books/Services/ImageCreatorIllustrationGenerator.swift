import Foundation
import UIKit
import ImagePlayground

/// Apple ImageCreator (Image Playground) を使ったイラスト生成サービス。
/// ImageCreator が利用できない場合はエラーをスローし、呼び出し側で FallbackRenderer を使う。
final class ImageCreatorIllustrationGenerator: IllustrationGenerating, @unchecked Sendable {

    func generateCoverImage(title: String, theme: String) async throws -> UIImage {
        let prompt = "A warm and cheerful children's picture book cover about \(theme), soft pastel watercolor style, no text"
        return try await generateWithRetry(prompt: prompt, fallbackPrompt: "A cheerful children's book cover with a cute animal in a sunny meadow, soft pastel watercolor, no text")
    }

    func generatePageImage(pageNumber: Int, prompt: String, mood: String) async throws -> UIImage {
        return try await generateWithRetry(prompt: prompt, fallbackPrompt: "A gentle children's book illustration of a peaceful nature scene with soft pastel colors, cute cartoon animals")
    }

    /// 安全フィルターエラー時にフォールバックプロンプトで1回リトライ
    private func generateWithRetry(prompt: String, fallbackPrompt: String) async throws -> UIImage {
        do {
            return try await generateSingleImage(prompt: prompt)
        } catch {
            let desc = String(describing: error).lowercased()
            let isUnsafe = desc.contains("unsafe") || desc.contains("safety") || desc.contains("guardrail")
            if isUnsafe {
                return try await generateSingleImage(prompt: fallbackPrompt)
            }
            throw error
        }
    }

    private func generateSingleImage(prompt: String) async throws -> UIImage {
        let creator: ImageCreator
        do {
            creator = try await ImageCreator()
        } catch {
            print("⚠️ [ImageCreator] 初期化失敗: \(error)")
            throw GenerationError.imageGenerationFailed(underlying: "ImageCreator初期化失敗: \(error.localizedDescription)")
        }

        print("ℹ️ [ImageCreator] availableStyles: \(creator.availableStyles)")

        let style: ImagePlaygroundStyle
        if creator.availableStyles.contains(.illustration) {
            style = .illustration
        } else if let first = creator.availableStyles.first {
            style = first
        } else {
            print("⚠️ [ImageCreator] 利用可能なスタイルなし")
            throw GenerationError.imageGenerationFailed(underlying: "利用可能な画像スタイルがありません")
        }

        print("ℹ️ [ImageCreator] 生成開始 style=\(style), prompt=\(prompt.prefix(80))...")
        let images = creator.images(for: [.text(prompt)], style: style, limit: 1)
        for try await result in images {
            try Task.checkCancellation()
            print("✅ [ImageCreator] 画像生成成功")
            return UIImage(cgImage: result.cgImage)
        }
        print("⚠️ [ImageCreator] ストリームが空で終了")
        throw GenerationError.imageGenerationFailed(underlying: "画像が生成されませんでした")
    }
}

// MARK: - テーマ連動フォールバック描画

/// ImageCreator が使えない環境でのフォールバック画像生成。
/// SF Symbols + CoreGraphics で絵本風のシーンを構築する。
enum FallbackRenderer {

    // MARK: - Public

    static func renderCover(title: String, theme: String) -> UIImage {
        let size = CGSize(width: 600, height: 800)
        let palette = findPalette(for: "やさしい")
        let mainSymbol = findSymbol(in: theme, from: animalKeywords) ?? "book.fill"

        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            // 草原（下部 35%）
            drawGround(in: ctx, rect: rect, color: UIColor(hex: 0xC8E6C9))

            // 太陽
            drawSun(in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12), radius: 35, color: UIColor(hex: 0xFFE082))

            // 雲
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.2, y: rect.height * 0.1), scale: 1.2)
            drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.65, y: rect.height * 0.22), scale: 0.8)

            // メインキャラクター（中央やや上）
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width / 2, y: rect.height * 0.4),
                       size: 100, color: palette.accent)

            // 地面の装飾（花・草）
            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent)

            // タイトル
            drawTitle(title, in: ctx, rect: rect, color: palette.accent)
        }
    }

    static func renderPage(pageNumber: Int, prompt: String, mood: String) -> UIImage {
        let size = CGSize(width: 600, height: 400)
        let palette = findPalette(for: mood)
        let searchText = prompt + " " + mood
        let mainSymbol = findSymbol(in: searchText, from: animalKeywords)
            ?? findSymbol(in: searchText, from: natureKeywords)
            ?? pickDefaultSymbol(for: pageNumber)
        let isNightScene = mood.contains("しんみり") || mood.contains("おだやか")
            || searchText.contains("moon") || searchText.contains("night") || searchText.contains("つき")

        return renderSceneImage(size: size, palette: palette) { ctx, rect in
            if isNightScene {
                // 夜のシーン
                drawGround(in: ctx, rect: rect, color: UIColor(hex: 0x37474F).withAlphaComponent(0.4))
                drawSymbol("moon.fill", in: ctx, at: CGPoint(x: rect.width * 0.8, y: rect.height * 0.12),
                           size: 36, color: UIColor(hex: 0xFFE082))
                drawStars(in: ctx, rect: rect, count: 8)
            } else {
                // 昼のシーン
                drawGround(in: ctx, rect: rect, color: UIColor(hex: 0xC8E6C9))
                drawSun(in: ctx, at: CGPoint(x: rect.width * 0.82, y: rect.height * 0.1), radius: 24, color: UIColor(hex: 0xFFE082))
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.18, y: rect.height * 0.08), scale: 0.7)
                drawCloud(in: ctx, at: CGPoint(x: rect.width * 0.55, y: rect.height * 0.15), scale: 0.5)
            }

            // 遠景の木
            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.12, y: rect.height * 0.63), scale: 0.7, color: UIColor(hex: 0x81C784))
            drawTree(in: ctx, at: CGPoint(x: rect.width * 0.88, y: rect.height * 0.63), scale: 0.5, color: UIColor(hex: 0xA5D6A7))

            // メインキャラクター
            drawSymbol(mainSymbol, in: ctx, at: CGPoint(x: rect.width / 2, y: rect.height * 0.48),
                       size: 72, color: palette.accent)

            // 地面の装飾
            drawGroundDecorations(in: ctx, rect: rect, accent: palette.accent)
        }
    }

    // MARK: - Scene drawing helpers

    private static func renderSceneImage(size: CGSize, palette: (bg: [UIColor], accent: UIColor),
                                         draw: (UIGraphicsImageRendererContext, CGRect) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // 空のグラデーション背景
            let cgCtx = ctx.cgContext
            let colors = palette.bg.map { $0.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil) {
                cgCtx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            } else {
                palette.bg.first?.setFill()
                UIBezierPath(rect: rect).fill()
            }

            // 角丸クリップ（カード風）
            let cardPath = UIBezierPath(roundedRect: rect, cornerRadius: 20)
            cardPath.addClip()

            draw(ctx, rect)
        }
    }

    /// 地面を描画（丘のような曲線）
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

        // 少し暗い色で手前の丘
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

    /// 太陽を描画
    private static func drawSun(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, radius: CGFloat, color: UIColor) {
        // 光のグロー
        color.withAlphaComponent(0.15).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 2, y: center.y - radius * 2,
                                     width: radius * 4, height: radius * 4)).fill()
        color.withAlphaComponent(0.3).setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius * 1.3, y: center.y - radius * 1.3,
                                     width: radius * 2.6, height: radius * 2.6)).fill()
        // 太陽本体
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius,
                                     width: radius * 2, height: radius * 2)).fill()
    }

    /// 雲を描画（3つの楕円の合成）
    private static func drawCloud(in ctx: UIGraphicsImageRendererContext, at center: CGPoint, scale: CGFloat) {
        let color = UIColor.white.withAlphaComponent(0.8)
        color.setFill()
        let w: CGFloat = 60 * scale
        let h: CGFloat = 25 * scale
        UIBezierPath(ovalIn: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)).fill()
        UIBezierPath(ovalIn: CGRect(x: center.x - w * 0.6, y: center.y, width: w * 0.7, height: h * 0.8)).fill()
        UIBezierPath(ovalIn: CGRect(x: center.x + w * 0.05, y: center.y + h * 0.1, width: w * 0.6, height: h * 0.75)).fill()
    }

    /// 木を描画（三角形の樹冠 + 幹）
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

    /// 星を描画
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

    /// 地面の装飾（花・草）
    private static func drawGroundDecorations(in ctx: UIGraphicsImageRendererContext, rect: CGRect, accent: UIColor) {
        let flowerPositions: [(CGFloat, CGFloat)] = [
            (0.15, 0.82), (0.35, 0.78), (0.55, 0.85), (0.75, 0.80), (0.9, 0.83),
        ]
        let flowerConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let flowerSymbols = ["leaf.fill", "leaf.fill", "leaf.fill", "leaf.fill", "leaf.fill"]
        let flowerColors = [UIColor(hex: 0x66BB6A), UIColor(hex: 0x81C784), UIColor(hex: 0x4CAF50),
                           UIColor(hex: 0xAED581), UIColor(hex: 0x66BB6A)]

        for (i, pos) in flowerPositions.enumerated() {
            let sym = flowerSymbols[i % flowerSymbols.count]
            let color = flowerColors[i % flowerColors.count]
            if let img = UIImage(systemName: sym, withConfiguration: flowerConfig) {
                color.withAlphaComponent(0.5).setFill()
                img.draw(at: CGPoint(x: rect.width * pos.0, y: rect.height * pos.1))
            }
        }

        // 小さな花のドット
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

    /// SF Symbol を描画
    private static func drawSymbol(_ name: String, in ctx: UIGraphicsImageRendererContext,
                                   at center: CGPoint, size: CGFloat, color: UIColor) {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color, color.withAlphaComponent(0.7)]))
        if let img = UIImage(systemName: name, withConfiguration: config) {
            // 影
            color.withAlphaComponent(0.15).setFill()
            UIBezierPath(ovalIn: CGRect(x: center.x - img.size.width * 0.3, y: center.y + img.size.height * 0.35,
                                         width: img.size.width * 0.6, height: img.size.height * 0.15)).fill()
            img.draw(at: CGPoint(x: center.x - img.size.width / 2, y: center.y - img.size.height / 2))
        }
    }

    /// タイトルテキスト描画（表紙用）
    private static func drawTitle(_ title: String, in ctx: UIGraphicsImageRendererContext, rect: CGRect, color: UIColor) {
        guard !title.isEmpty else { return }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        // 背景のバナー
        let bannerRect = CGRect(x: rect.width * 0.1, y: rect.height * 0.85, width: rect.width * 0.8, height: 50)
        UIColor.white.withAlphaComponent(0.7).setFill()
        UIBezierPath(roundedRect: bannerRect, cornerRadius: 25).fill()
        // テキスト
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle,
        ]
        let textRect = CGRect(x: bannerRect.minX + 10, y: bannerRect.minY + 12, width: bannerRect.width - 20, height: 30)
        (title as NSString).draw(in: textRect, withAttributes: attrs)
    }

    // MARK: - Keyword matching tables

    private static let animalKeywords: [(keywords: [String], symbol: String)] = [
        (["うさぎ", "rabbit", "hare", "bunny"], "hare.fill"),
        (["ねこ", "猫", "cat", "kitten"], "cat.fill"),
        (["いぬ", "犬", "dog", "puppy"], "dog.fill"),
        (["とり", "鳥", "bird"], "bird.fill"),
        (["さかな", "魚", "fish"], "fish.fill"),
        (["かめ", "亀", "turtle", "tortoise"], "tortoise.fill"),
        (["くま", "熊", "bear"], "pawprint.fill"),
        (["むし", "虫", "ladybug", "bug"], "ladybug.fill"),
    ]

    private static let natureKeywords: [(keywords: [String], symbol: String)] = [
        (["やま", "山", "mountain"], "mountain.2.fill"),
        (["うみ", "海", "sea", "ocean", "wave"], "water.waves"),
        (["そら", "空", "sky", "cloud", "雲", "くも"], "cloud.fill"),
        (["ほし", "星", "star"], "star.fill"),
        (["はな", "花", "flower"], "leaf.fill"),
        (["もり", "森", "forest", "tree", "木"], "tree.fill"),
        (["にじ", "虹", "rainbow"], "rainbow"),
        (["つき", "月", "moon"], "moon.fill"),
    ]

    private static let moodPalettes: [(keywords: [String], bg: [UIColor], accent: UIColor)] = [
        (["わくわく", "たのしい", "にぎやか", "cheerful"],
         [.init(hex: 0xFFF3E0), .init(hex: 0xFFE0B2)], .init(hex: 0xFFB74D)),
        (["どきどき", "ゆうき", "brave"],
         [.init(hex: 0xFCE4EC), .init(hex: 0xF8BBD0)], .init(hex: 0xF06292)),
        (["しんみり", "おだやか", "calm"],
         [.init(hex: 0xE3F2FD), .init(hex: 0xBBDEFB)], .init(hex: 0x64B5F6)),
        (["ふしぎ", "きらきら", "mysterious"],
         [.init(hex: 0xEDE7F6), .init(hex: 0xD1C4E9)], .init(hex: 0x9575CD)),
        (["やさしい", "あたたかい", "ほっこり", "gentle"],
         [.init(hex: 0xFFF8E1), .init(hex: 0xFFECB3)], .init(hex: 0xFFD54F)),
    ]

    private static let defaultPalette: (bg: [UIColor], accent: UIColor) = (
        [.init(hex: 0xE8F5E9), .init(hex: 0xC8E6C9)], .init(hex: 0x66BB6A)
    )

    private static func findSymbol(in text: String, from table: [(keywords: [String], symbol: String)]) -> String? {
        let lower = text.lowercased()
        for entry in table { if entry.keywords.contains(where: { lower.contains($0) }) { return entry.symbol } }
        return nil
    }

    private static func findPalette(for mood: String) -> (bg: [UIColor], accent: UIColor) {
        let lower = mood.lowercased()
        for entry in moodPalettes { if entry.keywords.contains(where: { lower.contains($0) }) { return (entry.bg, entry.accent) } }
        return defaultPalette
    }

    private static func pickDefaultSymbol(for pageNumber: Int) -> String {
        let symbols = ["hare.fill", "bird.fill", "star.fill", "cloud.fill",
                       "leaf.fill", "fish.fill", "sun.max.fill", "heart.fill"]
        return symbols[(pageNumber - 1) % symbols.count]
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1.0
        )
    }
}
