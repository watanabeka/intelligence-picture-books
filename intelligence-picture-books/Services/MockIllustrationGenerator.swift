import Foundation
import UIKit

final class MockIllustrationGenerator: IllustrationGenerating {

    private let pastelColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1),
        UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1),
        UIColor(red: 0.85, green: 1.0, blue: 0.88, alpha: 1),
        UIColor(red: 1.0, green: 0.95, blue: 0.80, alpha: 1),
        UIColor(red: 0.92, green: 0.85, blue: 1.0, alpha: 1),
        UIColor(red: 1.0, green: 0.88, blue: 0.95, alpha: 1),
        UIColor(red: 0.85, green: 1.0, blue: 1.0, alpha: 1),
        UIColor(red: 1.0, green: 0.92, blue: 0.85, alpha: 1),
    ]

    func generateCoverImage(title: String, theme: String) async throws -> UIImage {
        try await Task.sleep(for: .seconds(1))
        return renderPlaceholder(
            text: title,
            icon: "book.fill",
            color: UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1),
            size: CGSize(width: 600, height: 800)
        )
    }

    func generatePageImage(pageNumber: Int, prompt: String, mood: String) async throws -> UIImage {
        try await Task.sleep(for: .milliseconds(800))
        let color = pastelColors[(pageNumber - 1) % pastelColors.count]
        let icons = ["sun.max.fill", "cloud.fill", "leaf.fill", "star.fill",
                     "heart.fill", "moon.fill", "sparkles", "rainbow"]
        let icon = icons[(pageNumber - 1) % icons.count]
        return renderPlaceholder(
            text: "P\(pageNumber)",
            icon: icon,
            color: color,
            size: CGSize(width: 600, height: 400)
        )
    }

    private func renderPlaceholder(text: String, icon: String, color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 16)
            path.fill()

            let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
            if let symbol = UIImage(systemName: icon, withConfiguration: config) {
                let symbolRect = CGRect(
                    x: (size.width - symbol.size.width) / 2,
                    y: size.height * 0.3 - symbol.size.height / 2,
                    width: symbol.size.width,
                    height: symbol.size.height
                )
                UIColor.gray.withAlphaComponent(0.3).setFill()
                symbol.draw(in: symbolRect)
            }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle,
            ]
            let textRect = CGRect(x: 20, y: size.height * 0.55, width: size.width - 40, height: 100)
            (text as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }
}
