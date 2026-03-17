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
            // スキーマ変更で既存ストアが読めない場合、Application Support 以下を全削除して再作成する
            // 画像は Documents/BookImages に保存されているため影響なし
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: appSupport)
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
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
