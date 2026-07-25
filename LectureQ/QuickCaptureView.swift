import SwiftUI
import SwiftData

/// The core capture flow: while listening to a lecture, hit ⌘⇧N,
/// type the question in the simplest words possible, press Return, done.
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var lecture: Lecture?

    @State private var text = ""
    @State private var timeMark = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.bubble.fill")
                    .foregroundStyle(.orange)
                Text(lecture?.title ?? "강의 없음")
                    .scaledFont(.headline)
                Spacer()
                Text("Return: 저장 · Esc: 닫기")
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("닫기")
            }

            TextField("궁금한 점을 최대한 쉬운 말로…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .scaledFont(.title3)
                .lineLimit(2...5)
                .focused($focused)
                .onSubmit { save() }

            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                TextField("강의 시점 (예: 12:34, 선택)", text: $timeMark)
                    .textFieldStyle(.plain)
                    .onSubmit { save() }

                Spacer()

                Button("저장하고 계속") { save(keepOpen: true) }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("저장") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .scaledFont(.callout)
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { focused = true }
    }

    private func save(keepOpen: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let lecture else { return }
        let q = Question(text: trimmed,
                         timeMark: timeMark.trimmingCharacters(in: .whitespaces),
                         lecture: lecture)
        context.insert(q)
        text = ""
        timeMark = ""
        if keepOpen {
            focused = true
        } else {
            dismiss()
        }
    }
}
