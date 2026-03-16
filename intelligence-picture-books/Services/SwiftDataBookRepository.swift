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

    private var imageDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
