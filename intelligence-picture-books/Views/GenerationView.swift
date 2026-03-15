import SwiftUI

struct GenerationView: View {
    @Bindable var viewModel: CreateBookViewModel
    @Binding var showReader: Bool
    @State private var navigateToReader = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressHeader
                if !viewModel.generatedTitle.isEmpty { titleCard }
                if viewModel.coverImage != nil || viewModel.phase.isGenerating { coverSection }
                pagesGrid
                if viewModel.phase == .completed { readButton }
            }
            .padding(24)
        }
        .background(AppTheme.background)
        .navigationTitle("生成中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase.isGenerating)
        .toolbar {
            if viewModel.phase.isGenerating {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        viewModel.cancelGeneration()
                        showReader = false
                    }
                }
            }
        }
        .navigationDestination(isPresented: $navigateToReader) {
            if let book = viewModel.completedBook {
                ReaderView(book: book, repository: viewModel.repository)
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            phaseIcon
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white)
                .shadow(color: AppTheme.primary.opacity(0.1), radius: 10, y: 3)
        )
    }

    @ViewBuilder
    private var phaseIcon: some View {
        if viewModel.phase.isGenerating {
            ZStack {
                Circle().fill(AppTheme.primary.opacity(0.08)).frame(width: 64, height: 64)
                ProgressView().controlSize(.large).tint(AppTheme.primary)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12)).foregroundStyle(AppTheme.accent)
                    .offset(x: 24, y: -24)
            }
        } else if viewModel.phase == .completed {
            ZStack {
                Circle().fill(Color.green.opacity(0.1)).frame(width: 64, height: 64)
                Image(systemName: "checkmark.circle.fill").font(.largeTitle).foregroundStyle(.green)
            }
        } else if case .failed = viewModel.phase {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(.red)
        }
    }

    private var titleCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(AppTheme.accent)
            Text(viewModel.generatedTitle).font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.primary.opacity(0.07)))
    }

    private var coverSection: some View {
        VStack(spacing: 8) {
            Text("表紙").font(.caption).foregroundStyle(.secondary)
            if let cover = viewModel.coverImage {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(3/4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxHeight: 300)
            } else {
                PlaceholderCard(height: 200, icon: "photo", label: "表紙を描いています...")
            }
        }
    }

    private var pagesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(viewModel.pageDrafts) { draft in
                PageDraftCard(draft: draft)
            }
        }
    }

    private var readButton: some View {
        MagicButton(title: "よむ") { navigateToReader = true }
    }
}
