import SwiftUI

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel

    init(repository: any BookPersisting) {
        _viewModel = State(initialValue: LibraryViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else if viewModel.books.isEmpty {
                ContentUnavailableView(
                    "まだ絵本がありません",
                    systemImage: "books.vertical",
                    description: Text("ホーム画面から絵本をつくってみましょう")
                )
            } else {
                bookList
            }
        }
        .navigationTitle("ほんだな")
        .task {
            await viewModel.loadBooks()
        }
    }

    private var bookList: some View {
        List(viewModel.books, id: \.id) { book in
            NavigationLink {
                ReaderView(book: book, repository: viewModel.repository)
            } label: {
                BookRow(book: book)
            }
        }
        .listStyle(.plain)
    }
}
