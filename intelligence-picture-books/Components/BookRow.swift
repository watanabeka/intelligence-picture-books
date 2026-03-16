import SwiftUI

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.primary.opacity(0.1))
                .frame(width: 50, height: 66)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(AppTheme.primary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.theme)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(book.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("\(book.pageCount)P")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppTheme.primary.opacity(0.08))
                )
        }
        .padding(.vertical, 4)
    }
}
