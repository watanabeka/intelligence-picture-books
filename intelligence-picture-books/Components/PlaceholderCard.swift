import SwiftUI

struct PlaceholderCard: View {
    let height: CGFloat
    let icon: String
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.12))
            .frame(height: height)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    if !label.isEmpty {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }
}
