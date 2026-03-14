import Foundation
import UIKit

protocol IllustrationGenerating: Sendable {
    func generateCoverImage(title: String, theme: String) async throws -> UIImage
    func generatePageImage(pageNumber: Int, prompt: String, mood: String) async throws -> UIImage
}
