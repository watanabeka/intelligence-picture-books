import SwiftUI

struct GenerationView: View {
    @Bindable var viewModel: CreateBookViewModel
    @Binding var showReader: Bool
    @State private var navigateToReader = false
    @State private var showRegenerateConfirm = false
    @State private var editingDraftIndex: Int?
    @State private var showDebugOverlay = false

    private var isCompleted: Bool { viewModel.phase == .completed }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !viewModel.generatedTitle.isEmpty { titleCard }
                coverSection
                pagesList
                if isCompleted { ctaButtons }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(AppTheme.background)
        .navigationTitle(isCompleted ? "できあがり" : "生成中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase.isGenerating)
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $navigateToReader) {
            if let book = viewModel.completedBook {
                ReaderView(
                    book: book,
                    repository: viewModel.repository,
                    illustrationGenerator: viewModel.illustrationGenerator,
                    onRegenerate: {
                        navigateToReader = false
                        viewModel.startGeneration()
                    }
                )
            }
        }
        .sheet(item: editingBinding) { draft in
            EditPageTextSheet(initialText: draft.text) { newText, shouldRetryImage in
                // テキストを即座にドラフトに反映
                if let idx = viewModel.pageDrafts.firstIndex(where: { $0.id == draft.id }) {
                    viewModel.pageDrafts[idx].text = newText
                    // 完了後かつ画像再生成が要求された場合のみリトライ
                    if shouldRetryImage && isCompleted {
                        viewModel.retryPageImage(at: idx)
                    }
                }
            }
        }
        .confirmationDialog(
            "絵本をもういちどつくりますか？",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("もういちど作る", role: .destructive) {
                viewModel.startGeneration()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("いまの絵本を上書きして、もういちど作りますか？")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.phase.isGenerating {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    viewModel.cancelGeneration()
                    showReader = false
                }
            }
        } else if !viewModel.generatedTitle.isEmpty {
            // 生成完了後は「作り直す」をツールバーに常時表示
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showRegenerateConfirm = true
                } label: {
                    Label("作り直す", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
            }
        }
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
    }

    // MARK: - Title

    private var titleCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(AppTheme.accent)
            Text(viewModel.generatedTitle).font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.primary.opacity(0.07)))
    }

    // MARK: - Cover

    private var coverSection: some View {
        VStack(spacing: 8) {
            Text("表紙").font(.caption).foregroundStyle(.secondary)

            ImageFrame(aspectRatio: ImageAspect.cover) {
                if let cover = viewModel.coverImage {
                    ZStack {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                        // 完了・フォールバック問わず常にリトライボタンを表示
                        if isCompleted {
                            RetryOverlayButton { viewModel.retryCoverImage() }
                        }
                    }
                } else if viewModel.phase.isGenerating {
                    BouncingBookPlaceholder()
                } else {
                    PlaceholderCard(height: 300, icon: "photo", label: "")
                }
            }
        }
    }

    // MARK: - Pages (1列)

    private var pagesList: some View {
        LazyVStack(spacing: 16) {
            ForEach(Array(viewModel.pageDrafts.enumerated()), id: \.element.id) { index, draft in
                PageDraftCard(
                    draft: draft,
                    totalPages: viewModel.pageCount,
                    isCompleted: isCompleted,
                    // 画像が確定（ready/fallback）していれば生成中でもボタンを表示
                    onEdit: (draft.imageState == .ready || draft.imageState == .fallback)
                        ? { editingDraftIndex = index }
                        : nil,
                    onRetry: (draft.imageState == .ready || draft.imageState == .fallback) && isCompleted
                        ? { viewModel.retryPageImage(at: index) }
                        : nil,
                    showDebug: showDebugOverlay,
                    characterSheet: viewModel.debugStoryPlan?.characterSheet
                )
            }
        }
    }

    // MARK: - CTA

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            MagicButton(title: "よむ") { navigateToReader = true }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var editingBinding: Binding<PageDraft?> {
        Binding(
            get: {
                guard let i = editingDraftIndex, viewModel.pageDrafts.indices.contains(i) else { return nil }
                return viewModel.pageDrafts[i]
            },
            set: { newValue in
                if newValue == nil { editingDraftIndex = nil }
            }
        )
    }
}
