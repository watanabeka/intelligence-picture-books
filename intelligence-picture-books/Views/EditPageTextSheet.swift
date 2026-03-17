import SwiftUI

/// ページ本文をユーザーが手動で編集するシート
struct EditPageTextSheet: View {
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void

    init(initialText: String, onSave: @escaping (String) -> Void) {
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
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }
}
