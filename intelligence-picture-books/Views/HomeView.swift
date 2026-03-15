import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: CreateBookViewModel
    @State private var showGeneration = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroArea
                    formArea
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AppTheme.background)
            .navigationTitle("えほんメーカー")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showGeneration) {
                GenerationView(viewModel: viewModel, showReader: $showGeneration)
            }
            .navigationDestination(isPresented: $showLibrary) {
                LibraryView(repository: viewModel.repository)
            }
        }
    }

    // MARK: - ヒーローエリア（ファンタジー空 + 本イラスト）

    private var heroArea: some View {
        ZStack(alignment: .bottom) {
            FantasySkyBackground(height: 280)

            // 中央のイラスト（本 + 城）
            ZStack {
                // 光輪
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 10)

                // 本アイコン
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0x9B8CFF), Color(hex: 0x7B6CDF)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, y: 4)

                // 城アイコン（本の上）
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: 0xE8A0B0))
                    .offset(y: -42)

                // 装飾の星
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)
                    .offset(x: 50, y: -30)

                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
                    .offset(x: -45, y: -20)
            }
            .offset(y: -30)
        }
    }

    // MARK: - フォームエリア

    private var formArea: some View {
        VStack(spacing: 20) {
            // サブタイトル
            Text("AIがきみだけの物語をつくるよ")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            // テーマ入力
            themeSection

            // ページ数
            pageCountSection

            // 生成ボタン
            MagicButton(title: "えほんをつくる", action: {
                viewModel.startGeneration()
                showGeneration = true
            }, isEnabled: viewModel.canGenerate)

            // ほんだなボタン
            libraryButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    // MARK: - テーマ入力

    private var themeSection: some View {
        TextField("どんなおはなし？\n例: うさぎが雲をつかまにいく", text: $viewModel.theme, axis: .vertical)
            .lineLimit(3...5)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.white)
                    .shadow(color: AppTheme.primary.opacity(0.06), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
    }

    // MARK: - ページ数選択

    private var pageCountSection: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.availablePageCounts, id: \.self) { count in
                let isSelected = viewModel.pageCount == count
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.pageCount = count
                    }
                } label: {
                    Text("\(count)ページ")
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? AppTheme.primary.opacity(0.08) : .clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? AppTheme.primary.opacity(0.4) : Color.gray.opacity(0.25),
                                    lineWidth: 1
                                )
                        )
                        .foregroundStyle(isSelected ? AppTheme.primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - ほんだなボタン

    private var libraryButton: some View {
        Button {
            showLibrary = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .foregroundStyle(AppTheme.primary)
                Text("ほんだな")
                    .foregroundStyle(AppTheme.primary)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(AppTheme.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}
