import Foundation
import SwiftUI

@MainActor
@Observable
final class LibraryViewModel {
    var books: [Book] = []
    var isLoading: Bool = false

    let repository: any BookPersisting

    init(repository: any BookPersisting) {
        self.repository = repository
    }

    func loadBooks() async {
        isLoading = true
        do {
            books = try await repository.fetchAllBooks()
        } catch {
            books = []
        }
        isLoading = false
    }
}
