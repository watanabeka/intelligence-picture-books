import Foundation
import UIKit

protocol BookPersisting: Sendable {
    func saveBook(_ book: Book) async throws
    func fetchAllBooks() async throws -> [Book]
    func fetchBook(id: UUID) async throws -> Book?
    func saveImage(_ image: UIImage, name: String) async throws
    func loadImage(name: String) async -> UIImage?
    /// ページのテキストを更新して永続化する
    func updatePageText(_ text: String, pageId: UUID) async throws
    /// ページの画像ファイル名を更新して永続化する（リトライ成功後に使用）
    func updatePageImageName(_ name: String, pageId: UUID) async throws
}
