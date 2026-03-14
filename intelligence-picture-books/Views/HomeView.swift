import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: CreateBookViewModel
    @State private var showGeneration = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    themeSection
                    pageCountSection
                    generateButton
                    libraryButton
                }
                .padding(24)
            }
            .navigationTitle("えほんメーカー")
            .navigationDestination(isPresented: $showGeneration) {
                GenerationView(viewModel: viewModel, showReader: $showGeneration)
            }
            .navigationDestination(isPresented: $showLibrary) {
                LibraryView(repository: viewModel.repository)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.pages")
                .font(.system(size: 48))
                .foregroundStyle(.brown)
            Text("AIがえほんをつくるよ！")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("テーマ")
                .font(.headline)
            TextField("例: うさぎが雲に触りたくて冒険する話", text: $viewModel.theme, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private var pageCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ページ数")
                .font(.headline)
            Picker("ページ数", selection: $viewModel.pageCount) {
                ForEach(viewModel.availablePageCounts, id: \.self) { count in
                    Text("\(count)ページ").tag(count)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var generateButton: some View {
        Button {
            viewModel.startGeneration()
            showGeneration = true
        } label: {
            Label("絵本をつくる", systemImage: "wand.and.stars")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.brown)
        .disabled(!viewModel.canGenerate)
    }

    private var libraryButton: some View {
        Button {
            showLibrary = true
        } label: {
            Label("ほんだな", systemImage: "books.vertical")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.bordered)
    }
}
