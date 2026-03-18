import SwiftUI

struct ReaderView: View {
    @State private var viewModel: ReaderViewModel
    @State private var currentSlide = 0
    @State private var showDebugOverlay = false
    @State private var editingPage: BookPage?
    @State private var showRegenerateConfirm = false

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
            EditPageTextSheet(initialText: page.text) { newText, shouldRetryImage in
                Task {
                    await viewModel.updatePageText(newText, for: page)
                    if shouldRetryImage {
                        await viewModel.retryImage(for: page)
                    }
                }
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
            #if DEBUG
            if showDebugOverlay {
                coverDebugInfo
            }
            #endif
        }
        .padding(32)
    }

    @ViewBuilder
    private var coverImageArea: some View {
        let state = viewModel.coverImageState

        ImageFrame(aspectRatio: ImageAspect.cover) {
            ZStack {
                if let cover = viewModel.coverImage {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()

                    if state == .fallback || state == .ready {
                        RetryOverlayButton { Task { await viewModel.retryCover() } }
                    }
                } else if state == .retrying {
                    ImageRetryingPlaceholder()
                } else {
                    ImageFailedPlaceholder { Task { await viewModel.retryCover() } }
                }
            }
        }
        .shadow(color: AppTheme.primary.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - Page Slide

    private func pageSlide(page: BookPage) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                pageImageArea(for: page)

                HStack(alignment: .top, spacing: 8) {
                    Text(page.text)
                        .font(.title3)
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)

                    Button { editingPage = page } label: {
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

        ImageFrame(aspectRatio: ImageAspect.page) {
            ZStack {
                if let img = viewModel.pageImages[page.pageNumber] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()

                    if state == .fallback || state == .ready {
                        RetryOverlayButton { Task { await viewModel.retryImage(for: page) } }
                    }
                } else if state == .retrying {
                    ImageRetryingPlaceholder()
                } else {
                    ImageFailedPlaceholder { Task { await viewModel.retryImage(for: page) } }
                }
            }
        }
        .shadow(color: AppTheme.primary.opacity(0.1), radius: 6, y: 3)
    }

    // MARK: - Debug

    #if DEBUG
    /// 全デバッグ情報をテキストにまとめてクリップボードにコピーする
    private func copyDebugLog() {
        let character = viewModel.book.characterSheet
        var lines: [String] = ["=== Debug Log ==="]
        lines.append("Book: \(viewModel.book.title)")
        lines.append("Character Species: \(character.species)")
        lines.append("Character BodyColor: \(character.bodyColor)")
        lines.append("Character Accessory: \(character.accessory)")
        lines.append("ImageCreator Available: \(viewModel.isImageCreatorAvailable)")
        if let reason = viewModel.imageCreatorUnavailableReason {
            lines.append("Unavailable Reason: \(reason)")
        }
        lines.append("Image Mode: \(viewModel.book.imageGenerationMode.rawValue)")
        lines.append("AI Images: \(viewModel.book.generatedImageCount), Fallback: \(viewModel.book.fallbackImageCount)")
        lines.append("Cover State: \(viewModel.coverImageState), Retry: \(viewModel.coverRetryCount)")
        if !viewModel.coverRetryPrompt.isEmpty {
            lines.append("Cover Retry Prompt: \(viewModel.coverRetryPrompt)")
        }
        if let err = viewModel.lastImageError {
            lines.append("Last Error: \(err)")
        }
        for page in viewModel.book.sortedPages {
            let state = viewModel.pageImageStates[page.pageNumber] ?? .failed
            let retry = viewModel.pageRetryCounts[page.pageNumber] ?? 0
            let retryPrompt = viewModel.pageRetryPrompts[page.pageNumber]
            lines.append("--- Page \(page.pageNumber) ---")
            lines.append("State: \(state), Fallback: \(page.isFallback), Retry: \(retry)")
            lines.append("Prompt Hash: #\(abs(page.finalImagePrompt.hashValue) % 100000)")
            let sr = IllustrationPromptTranslator.sanitizeJapaneseVerbose(page.illustrationPrompt)
            lines.append("Mood: \(page.mood) → \(IllustrationPromptTranslator.moodToEnglish(page.mood))")
            lines.append("Scene Quality: \(sr.quality.description), Removed Tokens: \(sr.removedTokenCount)")
            lines.append("Prompt Length: \(page.finalImagePrompt.count) chars")
            if !page.illustrationPrompt.isEmpty {
                lines.append("① Scene (LLM raw): \(page.illustrationPrompt)")
            }
            if let rp = retryPrompt {
                lines.append("② Retry Prompt (EN): \(rp)")
            } else if !page.finalImagePrompt.isEmpty {
                lines.append("② Image Prompt (EN): \(page.finalImagePrompt)")
            }
        }
        lines.append("=================")
        UIPasteboard.general.string = lines.joined(separator: "\n")
    }

    private var coverDebugInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Info (Cover)").font(.caption.bold()).foregroundStyle(.orange)
                Spacer()
                Button {
                    copyDebugLog()
                } label: {
                    Label("ログをコピー", systemImage: "doc.on.clipboard")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            debugRow("Image Mode", viewModel.book.imageGenerationMode.displayName)
            debugRow("AI / Fallback", "\(viewModel.book.generatedImageCount) / \(viewModel.book.fallbackImageCount)")
            debugRow("ImageCreator Available", "\(viewModel.isImageCreatorAvailable)")
            if let reason = viewModel.imageCreatorUnavailableReason {
                debugRow("Unavailable Reason", reason)
            }
            debugRow("Cover State", "\(viewModel.coverImageState)")
            debugRow("Cover Retry Count", "\(viewModel.coverRetryCount)")
            if let err = viewModel.lastImageError {
                debugRow("Last Error", err)
            }
            if !viewModel.coverRetryPrompt.isEmpty {
                debugRow("Cover Retry Prompt", viewModel.coverRetryPrompt)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func debugInfo(for page: BookPage) -> some View {
        let retryCount = viewModel.pageRetryCounts[page.pageNumber] ?? 0
        let retryPrompt = viewModel.pageRetryPrompts[page.pageNumber]
        let state = viewModel.pageImageStates[page.pageNumber]
        let character = viewModel.book.characterSheet

        // プロンプト品質情報（デバッグ計算）
        let sanitizeResult = IllustrationPromptTranslator.sanitizeJapaneseVerbose(page.illustrationPrompt)
        let promptLength = page.finalImagePrompt.count
        let promptHash = abs(page.finalImagePrompt.hashValue) % 100000

        return VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info — Page \(page.pageNumber)").font(.caption.bold()).foregroundStyle(.orange)

            // キャラクター情報
            debugRow("Character Species", character.species.isEmpty ? "(empty)" : character.species)
            debugRow("Character BodyColor", character.bodyColor.isEmpty ? "(empty)" : character.bodyColor)
            debugRow("Character Accessory", character.accessory.isEmpty ? "(empty)" : character.accessory)

            // アスペクト比
            debugRow("Aspect Ratio Applied", "16:9 (\(String(format: "%.4f", ImageAspect.page)))")

            // 利用可否
            debugRow("ImageCreator Available", "\(viewModel.isImageCreatorAvailable)")
            if let reason = viewModel.imageCreatorUnavailableReason {
                debugRow("Unavailable Reason", reason)
            }

            // 画像状態
            debugRow("Image State", "\(String(describing: state))")
            debugRow("Is Fallback", "\(page.isFallback)")
            debugRow("Retry Count", "\(retryCount)")

            // エラー
            if let err = viewModel.lastImageError {
                debugRow("Last Error", err)
            }

            // プロンプト品質
            debugRow("Prompt Hash", "#\(promptHash)")
            debugRow("Mood", "\(page.mood) → \(IllustrationPromptTranslator.moodToEnglish(page.mood))")
            debugRow("Scene Quality", sanitizeResult.quality.description)
            debugRow("Removed Tokens", "\(sanitizeResult.removedTokenCount)")
            debugRow("Prompt Length", "\(promptLength) chars")

            // プロンプト比較（元シーン vs 構築済み英語プロンプト）
            if !page.illustrationPrompt.isEmpty {
                debugRow("① Scene (LLM raw)", page.illustrationPrompt)
            }
            if let rp = retryPrompt {
                debugRow("② Retry Prompt (EN)", rp)
            } else if !page.finalImagePrompt.isEmpty {
                let preview = String(page.finalImagePrompt.prefix(300))
                debugRow("② Image Prompt (EN)", preview + (page.finalImagePrompt.count > 300 ? "…" : ""))
            }
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
