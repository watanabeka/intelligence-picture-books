import Foundation
import UIKit

protocol IllustrationGenerating: Sendable {
    /// 構築済みプロンプトから画像を生成する
    func generateImage(prompt: String) async throws -> UIImage
}
