import Foundation
import UIKit

protocol BookPersisting: Sendable {
    func saveBook(_ book: Book) async throws
    func fetchAllBooks() async throws -> [Book]
    func fetchBook(id: UUID) async throws -> Book?
    func saveImage(_ image: UIImage, name: String) async throws
    func loadImage(name: String) async -> UIImage?
}
