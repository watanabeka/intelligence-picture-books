import SwiftUI

struct PageDraftCard: View {
    let draft: PageDraft

    var body: some View {
        VStack(spacing: 8) {
            if let img = draft.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(3/2, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if draft.isImageLoading {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.primary.opacity(0.06))
                    .aspectRatio(3/2, contentMode: .fit)
                    .overlay {
                        ProgressView()
                            .tint(AppTheme.primary)
                    }
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
}
