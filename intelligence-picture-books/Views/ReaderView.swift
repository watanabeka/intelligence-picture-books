import SwiftUI

struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @State private var currentSlide = 0
    @State private var showDebugOverlay = false
    @State private var editingPage: BookPage?
    @State private var showRegenerateConfirm = false

    /// GenerationView から渡される。存在する場合のみ「作り直す」ボタンを表示する。
    let onRegenerate: (() -> Void)?

    init(
        book: Book,
        repository: any BookPersisting,
        illustrationGenerator: any IllustrationGenerating,
        onRegenerate: (() -> Void)? = nil
    ) {
        _viewModel = State(
            initialValue: ReaderViewModel(
                book: book,
                repository: repository,
                illustrationGenerator: illustrationGenerator
            )
        )
        self.onRegenerate = onRegenerate
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
        .toolbar { toolbarItems }
        .task { await viewModel.loadImages() }
        .sheet(item: $editingPage) { page in
            EditPageTextSheet(initialText: page.text) { newText in
                Task { await viewModel.updatePageText(newText, for: page) }
            }
        }
        .confirmationDialog(
            "絵本をもういちどつくりますか？",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("もういちど作る", role: .destructive) { onRegenerate?() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("いまの絵本を上書きして、もういちど作りますか？")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        #if DEBUG
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showDebugOverlay.toggle()
            } label: {
                Image(systemName: showDebugOverlay ? "ladybug.fill" : "ladybug")
                    .foregroundStyle(showDebugOverlay ? .red : .secondary)
            }
        }
        #endif
        if onRegenerate != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showRegenerateConfirm = true
                } label: {
                    Label("作り直す", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Navigation

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

    // MARK: - Cover Slide

    private var coverSlide: some View {
        VStack(spacing: 24) {
            Spacer()
            coverImageArea
            Text(viewModel.book.title).font(.title.bold()).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
    }

    @ViewBuilder
    private var coverImageArea: some View {
        let state = viewModel.coverImageState
        ZStack {
            if let cover = viewModel.coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, y: 6)

                // フォールバック画像の場合はリトライオーバーレイを重ねる
                if state == .fallback {
                    retryOverlayOnImage { Task { await viewModel.retryCover() } }
                        .aspectRatio(3/4, contentMode: .fit)
                }
            } else if state == .retrying {
                imageRetryingPlaceholder(height: 300)
            } else {
                // .failed / .loading
                imageFailedArea(height: 300) { Task { await viewModel.retryCover() } }
            }
        }
    }

    // MARK: - Page Slide

    private func pageSlide(page: BookPage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                pageImageArea(for: page)

                // テキスト + 鉛筆ボタン
                HStack(alignment: .top, spacing: 8) {
                    Text(page.text)
                        .font(.title3)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)

                    Button {
                        editingPage = page
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body)
                            .foregroundStyle(AppTheme.primary.opacity(0.55))
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }

                Text("\(page.pageNumber) / \(viewModel.book.pageCount)")
                    .font(.caption).foregroundStyle(.secondary)

                #if DEBUG
                if showDebugOverlay {
                    debugInfo(for: page)
                }
                #endif
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func pageImageArea(for page: BookPage) -> some View {
        let state = viewModel.pageImageStates[page.pageNumber] ?? .failed

        ZStack {
            if let img = viewModel.pageImages[page.pageNumber] {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(3/2, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: AppTheme.primary.opacity(0.1), radius: 6, y: 3)

                // フォールバック画像の場合はリトライボタンをオーバーレイ
                if state == .fallback {
                    retryOverlayOnImage { Task { await viewModel.retryImage(for: page) } }
                        .aspectRatio(3/2, contentMode: .fit)
                }
            } else if state == .retrying {
                imageRetryingPlaceholder(height: 180)
            } else {
                // .failed / .loading
                imageFailedArea(height: 180) { Task { await viewModel.retryImage(for: page) } }
            }
        }
    }

    // MARK: - Retry UI Parts

    /// 画像の上に半透明でリトライボタンをオーバーレイ（フォールバック画像時）
    private func retryOverlayOnImage(action: @escaping () -> Void) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    /// 画像なし（完全失敗）のリトライUI
    private func imageFailedArea(height: CGFloat, action: @escaping () -> Void) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.primary.opacity(0.04))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.primary.opacity(0.1), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Button(action: action) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.1))
                            .frame(width: 60, height: 60)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                .buttonStyle(.plain)

                Text("もういちどえをつくる")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// リトライ中のローディング表示
    private func imageRetryingPlaceholder(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.primary.opacity(0.04))
                .frame(maxWidth: .infinity)
                .frame(height: height)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppTheme.primary)
                Text("えをつくっています...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Debug

    #if DEBUG
    private func debugInfo(for page: BookPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info").font(.caption.bold()).foregroundStyle(.orange)
            debugRow("Mood", page.mood)
            debugRow("Illustration Prompt", page.illustrationPrompt)
            if !page.finalImagePrompt.isEmpty {
                debugRow("Final Image Prompt", page.finalImagePrompt)
            }
            debugRow("Is Fallback", "\(page.isFallback)")
            let state = viewModel.pageImageStates[page.pageNumber]
            debugRow("Image State", "\(String(describing: state))")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.caption2).foregroundStyle(.primary)
        }
    }
    #endif
}
