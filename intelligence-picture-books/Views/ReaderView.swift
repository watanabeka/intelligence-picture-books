import SwiftUI

struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @State private var currentSlide: Int = 0

    init(book: Book, repository: any BookPersisting) {
        _viewModel = State(initialValue: ReaderViewModel(book: book, repository: repository))
    }

    var body: some View {
        TabView(selection: $currentSlide) {
            coverSlide
                .tag(0)
            ForEach(Array(viewModel.book.sortedPages.enumerated()), id: \.element.id) { index, page in
                pageSlide(page: page, index: index + 1)
                    .tag(index + 1)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .navigationTitle(viewModel.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadImages()
        }
    }

    private var coverSlide: some View {
        VStack(spacing: 24) {
            if let cover = viewModel.coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                PlaceholderCard(height: 300, icon: "book.fill", label: "")
            }
            Text(viewModel.book.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private func pageSlide(page: BookPage, index: Int) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = viewModel.pageImages[page.pageNumber] {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(3/2, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    PlaceholderCard(height: 180, icon: "photo", label: "")
                }

                Text(page.text)
                    .font(.title3)
                    .lineSpacing(8)
                    .padding(.horizontal, 8)

                Text("\(page.pageNumber) / \(viewModel.book.pageCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}
