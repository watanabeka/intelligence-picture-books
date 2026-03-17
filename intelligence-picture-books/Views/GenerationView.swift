import SwiftUI

struct GenerationView: View {
    @Bindable var viewModel: CreateBookViewModel
    @Binding var showReader: Bool
    @State private var navigateToReader = false
    @State private var showRegenerateConfirm = false
    @State private var editingDraftIndex: Int?

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
            EditPageTextSheet(initialText: draft.text) { _, _ in
                // 生成中画面でのテキスト編集は保存のみ（画像再生成はReaderView側で行う）
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
        }
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
                    onEdit: isCompleted ? { editingDraftIndex = index } : nil,
                    onRetry: isCompleted ? { viewModel.retryPageImage(at: index) } : nil
                )
            }
        }
    }

    // MARK: - CTA

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            MagicButton(title: "よむ") { navigateToReader = true }

            Button {
                showRegenerateConfirm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("作り直す")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(AppTheme.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    /// editingDraftIndex を Binding<PageDraft?> に変換するヘルパー
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
