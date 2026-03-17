import SwiftUI

struct PageDraftCard: View {
    let draft: PageDraft

    @State private var bouncing = false

    var body: some View {
        VStack(spacing: 8) {
            if let img = draft.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(3/2, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if draft.isImageLoading {
                bouncingBookPlaceholder
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.primary.opacity(0.04))
                    .aspectRatio(3/2, contentMode: .fit)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.primary.opacity(0.2))
                    }
            }

            Text(draft.text)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)

            Text("P.\(draft.pageNumber)")
                .font(.caption2)
                .foregroundStyle(AppTheme.primary.opacity(0.5))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white)
                .shadow(color: AppTheme.primary.opacity(0.06), radius: 6, y: 2)
        )
    }

    private var bouncingBookPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.primary.opacity(0.06))
                .aspectRatio(3/2, contentMode: .fit)

            VStack(spacing: 4) {
                Image(systemName: "book.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(AppTheme.primary.opacity(0.55))
                    .offset(y: bouncing ? -7 : 5)
                    .animation(
                        .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                        value: bouncing
                    )
                    .onAppear { bouncing = true }
                    .onDisappear { bouncing = false }

                // 影: キャラクターが上にいるとき影は小さく、下にいるとき大きく
                Ellipse()
                    .fill(AppTheme.primary.opacity(0.1))
                    .frame(width: bouncing ? 18 : 26, height: 5)
                    .animation(
                        .easeInOut(duration: 0.65).repeatForever(autoreverses: true),
                        value: bouncing
                    )
            }
        }
    }
}
