import SwiftUI

struct PlaceholderCard: View {
    let height: CGFloat
    let icon: String
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(AppTheme.primary.opacity(0.06))
            .frame(height: height)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(AppTheme.primary.opacity(0.4))
                    if !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }
}
