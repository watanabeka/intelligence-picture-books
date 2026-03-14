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
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func fetchBook(id: UUID) async throws -> Book? {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first
    }

    func saveImage(_ image: UIImage, name: String) async throws {
        guard let data = image.pngData() else { return }
        let url = imageDirectoryURL().appendingPathComponent(name)
        try data.write(to: url)
    }

    func loadImage(name: String) async -> UIImage? {
        let url = imageDirectoryURL().appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func imageDirectoryURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BookImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
