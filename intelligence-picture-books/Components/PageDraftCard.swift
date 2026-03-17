import SwiftUI

/// 生成中/完了後のページカード（1列レイアウト用）
/// 画像 → 本文 → 操作行 の縦構成
struct PageDraftCard: View {
    let draft: PageDraft
    let totalPages: Int
    var isCompleted: Bool = false
    var onEdit: (() -> Void)?
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            // 画像エリア（16:9 統一）
            ImageFrame(aspectRatio: ImageAspect.page) {
                if let img = draft.image {
                    ZStack {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()

                        // 完了済み画像には常に小さなリトライオーバーレイ
                        if isCompleted, let onRetry {
                            RetryOverlayButton(action: onRetry)
                        }
                    }
                } else if draft.isImageLoading {
                    BouncingBookPlaceholder()
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primary.opacity(0.04))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(AppTheme.primary.opacity(0.2))
                        }
                }
            }

            // 本文
            Text(draft.text)
                .font(.subheadline)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            // 操作行（完了後のみ表示）
            if isCompleted {
                PageActionBar(
                    pageNumber: draft.pageNumber,
                    totalPages: totalPages,
                    onEdit: onEdit,
                    onRetry: onRetry
                )
            } else {
                Text("P.\(draft.pageNumber)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: AppTheme.primary.opacity(0.06), radius: 8, y: 3)
        )
    }
}
