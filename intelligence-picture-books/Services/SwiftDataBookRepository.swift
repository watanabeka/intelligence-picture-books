import Foundation
import SwiftData
import UIKit

@ModelActor
actor SwiftDataBookRepository: BookPersisting {

    func saveBook(_ book: Book) async throws {
        modelContext.insert(book)
        try modelContext.save()
    }

    func fetchAllBooks() async throws -> [Book] {
        try modelContext.fetch(FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
    }

    func fetchBook(id: UUID) async throws -> Book? {
        try modelContext.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })).first
    }

    func saveImage(_ image: UIImage, name: String) async throws {
        guard let data = image.pngData() else { return }
        try data.write(to: imageDirectory.appendingPathComponent(name))
    }

    func loadImage(name: String) async -> UIImage? {
        guard let data = try? Data(contentsOf: imageDirectory.appendingPathComponent(name)) else { return nil }
        return UIImage(data: data)
    }

    func updatePageText(_ text: String, pageId: UUID) async throws {
        let pages = try modelContext.fetch(
            FetchDescriptor<BookPage>(predicate: #Predicate { $0.id == pageId })
        )
        if let page = pages.first {
            page.text = text
            try modelContext.save()
        }
    }

    func updatePageImageName(_ name: String, pageId: UUID) async throws {
        let pages = try modelContext.fetch(
            FetchDescriptor<BookPage>(predicate: #Predicate { $0.id == pageId })
        )
        if let page = pages.first {
            page.imageLocalName = name
            page.isFallback = false
            try modelContext.save()
        }
    }

    private var imageDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
