import SwiftUI

/// ページ本文をユーザーが手動で編集するシート
/// onSave(newText, shouldRegenerateImage) で保存する
struct EditPageTextSheet: View {
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, Bool) -> Void

    init(initialText: String, onSave: @escaping (String, Bool) -> Void) {
        _text = State(initialValue: initialText)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.title3)
                    .lineSpacing(6)
                    .padding(16)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                    )
                    .padding(20)

                Spacer()

                // 保存して画像も更新するボタン
                Button {
                    onSave(text, true)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("保存して絵も更新")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(AppTheme.primary))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(AppTheme.background)
            .navigationTitle("ぶんしょうをなおす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("もどる") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(text, false)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}
