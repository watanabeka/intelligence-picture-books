import SwiftUI

/// 生成中/完了後のページカード（1列レイアウト用）
/// 画像 → 本文 → 操作行 の縦構成
struct PageDraftCard: View {
    let draft: PageDraft
    let totalPages: Int
    var isCompleted: Bool = false
    var onEdit: (() -> Void)?
    var onRetry: (() -> Void)?
    var showDebug: Bool = false
    var characterSheet: CharacterSheet? = nil

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

            #if DEBUG
            if showDebug {
                draftDebugInfo
            }
            #endif
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: AppTheme.primary.opacity(0.06), radius: 8, y: 3)
        )
    }

    #if DEBUG
    private var draftDebugInfo: some View {
        let promptLen = draft.finalImagePrompt.count
        return VStack(alignment: .leading, spacing: 6) {
            Text("Debug — P.\(draft.pageNumber)").font(.caption.bold()).foregroundStyle(.orange)

            // Scene meta
            draftDebugRow("Camera", draft.camera.isEmpty ? "(none)" : draft.camera)
            draftDebugRow("Scene Mode", draft.sceneMode.rawValue)
            draftDebugRow("Mood", "\(draft.mood) → \(IllustrationPromptTranslator.moodToEnglish(draft.mood))")

            // Character
            if let cs = characterSheet {
                draftDebugRow("Character", "\(cs.species) / \(cs.bodyColor) / \(cs.accessory)")
            }

            // Prompt
            draftDebugRow("Prompt Length", "\(promptLen) chars")
            draftDebugRow("Style Clause", draft.styleClauseHint.isEmpty ? "(none)" : draft.styleClauseHint)
            if !draft.finalImagePrompt.isEmpty {
                let preview = String(draft.finalImagePrompt.prefix(220))
                draftDebugRow("Prompt (EN)", preview + (promptLen > 220 ? "…" : ""))
            }

            // Generation state
            draftDebugRow("Image State", "\(draft.imageState)")
            draftDebugRow("Retry Count", "\(draft.retryCount)")
            draftDebugRow("Aspect Ratio", "16:9 (\(String(format: "%.4f", ImageAspect.page)))")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
    }

    private func draftDebugRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
            Text(value).font(.caption2).foregroundStyle(.primary)
        }
    }
    #endif
}
