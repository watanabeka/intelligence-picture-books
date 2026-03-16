import SwiftUI

struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @State private var currentSlide = 0

    init(book: Book, repository: any BookPersisting) {
        _viewModel = State(initialValue: ReaderViewModel(book: book, repository: repository))
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            TabView(selection: $currentSlide) {
                coverSlide.tag(0)
                ForEach(Array(viewModel.book.sortedPages.enumerated()), id: \.element.id) { i, page in
                    pageSlide(page: page).tag(i + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentSlide)

            tapOverlay
        }
        .overlay(alignment: .bottom) { pageIndicator }
        .navigationTitle(viewModel.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadImages() }
    }

    private var tapOverlay: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture { navigate(by: -1) }
            Color.clear.contentShape(Rectangle()).onTapGesture { navigate(by: 1) }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.totalSlides, id: \.self) { i in
                Circle()
                    .fill(i == currentSlide ? AppTheme.primary : AppTheme.primary.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 16)
    }

    private func navigate(by delta: Int) {
        let target = currentSlide + delta
        guard (0..<viewModel.totalSlides).contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.3)) { currentSlide = target }
    }

    private var coverSlide: some View {
        VStack(spacing: 24) {
            Spacer()
            if let cover = viewModel.coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, y: 6)
            } else {
                PlaceholderCard(height: 300, icon: "book.fill", label: "")
            }
            Text(viewModel.book.title).font(.title.bold()).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
    }

    private func pageSlide(page: BookPage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                if let img = viewModel.pageImages[page.pageNumber] {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(3/2, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: AppTheme.primary.opacity(0.1), radius: 6, y: 3)
                } else {
                    PlaceholderCard(height: 180, icon: "photo", label: "")
                }

                Text(page.text).font(.title3).lineSpacing(8).padding(.horizontal, 8)

                Text("\(page.pageNumber) / \(viewModel.book.pageCount)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }
}
