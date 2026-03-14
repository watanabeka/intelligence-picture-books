import Foundation
import SwiftUI

@MainActor
@Observable
final class ReaderViewModel {
    let book: Book
    var currentPage: Int = 0
    var coverImage: UIImage?
    var pageImages: [Int: UIImage] = [:]

    private let repository: any BookPersisting

    init(book: Book, repository: any BookPersisting) {
        self.book = book
        self.repository = repository
    }

    var totalSlides: Int {
        book.sortedPages.count + 1 // cover + pages
    }

    func loadImages() async {
        if let coverName = book.coverImageLocalName {
            coverImage = await repository.loadImage(name: coverName)
        }
        for page in book.sortedPages {
            if let imgName = page.imageLocalName {
                if let img = await repository.loadImage(name: imgName) {
                    pageImages[page.pageNumber] = img
                }
            }
        }
    }
}
