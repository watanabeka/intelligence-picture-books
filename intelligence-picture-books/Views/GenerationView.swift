import SwiftUI

struct GenerationView: View {
    @Bindable var viewModel: CreateBookViewModel
    @Binding var showReader: Bool
    @State private var navigateToReader = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressHeader
                if !viewModel.generatedTitle.isEmpty {
                    titleCard
                }
                if viewModel.coverImage != nil || viewModel.phase == .generating {
                    coverSection
                }
                pagesGrid
                if viewModel.phase == .completed {
                    readButton
                }
            }
            .padding(24)
        }
        .navigationTitle("生成中")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase == .generating)
        .toolbar {
            if viewModel.phase == .generating {
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
            if viewModel.phase == .generating {
                ProgressView()
                    .controlSize(.large)
            } else if viewModel.phase == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            } else if case .failed = viewModel.phase {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
            }
            Text(viewModel.progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var titleCard: some View {
        Text(viewModel.generatedTitle)
            .font(.title2.bold())
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.brown.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var coverSection: some View {
        VStack(spacing: 8) {
            Text("表紙")
                .font(.caption)
                .foregroundStyle(.secondary)
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
        Button {
            navigateToReader = true
        } label: {
            Label("よむ", systemImage: "book.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.brown)
    }
}
