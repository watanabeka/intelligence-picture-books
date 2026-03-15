import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CreateBookViewModel?

    // useMock = true にするとオフラインモック動作
    private static let useMock = false

    var body: some View {
        Group {
            if let viewModel {
                HomeView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                let repo = SwiftDataBookRepository(modelContainer: modelContext.container)
                viewModel = Self.makeViewModel(repository: repo)
            }
        }
    }

    private static func makeViewModel(repository: any BookPersisting) -> CreateBookViewModel {
        if useMock {
            CreateBookViewModel(
                storyGenerator: MockStoryGenerator(),
                illustrationGenerator: MockIllustrationGenerator(),
                repository: repository
            )
        } else {
            CreateBookViewModel(
                storyGenerator: FoundationModelsStoryGenerator(),
                illustrationGenerator: ImageCreatorIllustrationGenerator(),
                repository: repository
            )
        }
    }
}
