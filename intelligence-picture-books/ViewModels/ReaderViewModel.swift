import Foundation
import SwiftUI

@MainActor
@Observable
final class ReaderViewModel {
    let book: Book
    var coverImage: UIImage?
    var pageImages: [Int: UIImage] = [:]

    private let repository: any BookPersisting

    init(book: Book, repository: any BookPersisting) {
        self.book = book
        self.repository = repository
    }

    var totalSlides: Int { book.sortedPages.count + 1 }

    func loadImages() async {
        if let name = book.coverImageLocalName {
            coverImage = await repository.loadImage(name: name)
        }
        for page in book.sortedPages {
            if let name = page.imageLocalName,
               let img = await repository.loadImage(name: name) {
                pageImages[page.pageNumber] = img
            }
        }
    }
}
