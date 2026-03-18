import SwiftUI

/// 画像のアスペクト比を全画面で統一するための定数
enum ImageAspect {
    /// ページ画像の統一アスペクト比（横長 16:9）
    static let page: CGFloat = 16.0 / 9.0
    /// 表紙画像のアスペクト比（縦長 3:4 — 絵本表紙らしい縦長フォーマット）
    static let cover: CGFloat = 3.0 / 4.0
}

// MARK: - 統一画像フレーム

/// 画像・プレースホルダー・リトライUIを統一アスペクト比で包むフレーム
struct ImageFrame<Content: View>: View {
    let aspectRatio: CGFloat
    let content: () -> Content

    init(aspectRatio: CGFloat = ImageAspect.page, @ViewBuilder content: @escaping () -> Content) {
        self.aspectRatio = aspectRatio
        self.content = content
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(alignment: .center) {
                content()
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - リトライオーバーレイ（成功画像上の小ボタン）

struct RetryOverlayButton: View {
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
}

// MARK: - 画像失敗プレースホルダー

struct ImageFailedPlaceholder: View {
    let action: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.primary.opacity(0.04))
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
}

// MARK: - リトライ中ローディング

struct ImageRetryingPlaceholder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.primary.opacity(0.04))

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
}

// MARK: - バウンシング絵本アイコン（生成中プレースホルダー）

struct BouncingBookPlaceholder: View {
    @State private var bouncing = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.primary.opacity(0.06))

            VStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(AppTheme.primary.opacity(0.55))
                    .offset(y: bouncing ? -8 : 6)
                    .animation(
                        .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                        value: bouncing
                    )
                    .onAppear { bouncing = true }

                Ellipse()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: bouncing ? 16 : 28, height: 5)
                    .animation(
                        .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                        value: bouncing
                    )
            }
        }
    }
}

// MARK: - ページ操作行

/// 各ページカード下部の操作行: ページ番号 | 編集 | 再生成
struct PageActionBar: View {
    let pageNumber: Int
    let totalPages: Int
    let onEdit: (() -> Void)?
    let onRetry: (() -> Void)?

    var body: some View {
        HStack {
            Text("P.\(pageNumber) / \(totalPages)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let onEdit {
                Button(action: onEdit) {
                    Label("編集", systemImage: "square.and.pencil")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }

            if let onRetry {
                Button(action: onRetry) {
                    Label("再生成", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
}
