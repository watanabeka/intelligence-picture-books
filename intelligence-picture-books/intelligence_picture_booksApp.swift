import SwiftUI
import SwiftData

@main
struct intelligence_picture_booksApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            BookPage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // スキーマ変更で既存ストアが読めない場合、削除して再作成する
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeURL = supportDir.appendingPathComponent("default.store")
            for ext in ["", "-wal", "-shm"] {
                let url = storeURL.deletingPathExtension().appendingPathExtension("store\(ext)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
