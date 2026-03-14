import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CreateBookViewModel?

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
                let repository = SwiftDataBookRepository(modelContainer: modelContext.container)
                viewModel = CreateBookViewModel(repository: repository)
            }
        }
    }
}
