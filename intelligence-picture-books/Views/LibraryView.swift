import SwiftUI

struct LibraryView: View {
    @State private var viewModel: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    init(repository: any BookPersisting) {
        _viewModel = State(initialValue: LibraryViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("読み込み中...")
            } else if viewModel.books.isEmpty {
                emptyLibrary
            } else {
                bookList
            }
        }
        .background(AppTheme.background)
        .navigationTitle("ほんだな")
        .task {
            await viewModel.loadBooks()
        }
    }

    // MARK: - 空状態

    private var emptyLibrary: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ファンタジー空背景 + 本イラスト
                ZStack(alignment: .bottom) {
                    FantasySkyBackground(height: 280)

                    // 本のイラスト
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 130, height: 130)
                            .blur(radius: 10)

                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: 0x9B8CFF), Color(hex: 0x7B6CDF)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, y: 4)

                        // 装飾の星
                        Image(systemName: "sparkle")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.accent)
                            .offset(x: 45, y: -30)

                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.8))
                            .offset(x: -40, y: -20)

                        Image(systemName: "sparkle")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.accent.opacity(0.6))
                            .offset(x: 35, y: 25)
                    }
                    .offset(y: -30)
                }

                VStack(spacing: 24) {
                    Text("まだえほんがないよ")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    MagicButton(title: "物語をつくろう", action: {
                        dismiss()
                    })
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
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
