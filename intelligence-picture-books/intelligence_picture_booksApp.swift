import SwiftUI
import SwiftData

@main
struct intelligence_picture_booksApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Book.self, BookPage.self])

        // STEP 1: 通常ロード
        let storeConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [storeConfig]) {
            return container
        }

        // STEP 2: スキーマ不一致 → Application Support を全削除して再作成
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        print("[ModelContainer] store load failed — wiping \(appSupport.path)")
        if let items = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
            items.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        if let container = try? ModelContainer(for: schema, configurations: [storeConfig]) {
            return container
        }

        // STEP 3: それでも失敗する場合はインメモリで起動（データは揮発するが落ちない）
        print("[ModelContainer] persistent store failed after wipe — falling back to in-memory")
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [memConfig]) else {
            fatalError("Could not create ModelContainer (even in-memory): check @Model definitions")
        }
        return container
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
