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
        VStack(alignment: .leading, spacing: 14) {
            Text(lecture?.title ?? "강의 없음")
                .scaledFont(.headline)
                .foregroundStyle(.secondary)

            TextField("궁금한 점을 최대한 쉬운 말로…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .scaledFont(.title3)
                .lineLimit(2...5)
                .focused($focused)
                .onSubmit { save() }

            HStack(spacing: 6) {
                Text("시점")
                    .foregroundStyle(.secondary)
                // 지금 시각이 미리 채워지고, 그대로 고쳐 쓸 수 있다.
                TextField("HH:mm", text: $timeMark)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .onSubmit { save() }
                    .help("강의 시점 (24시간 HH:mm). 지우면 시점 없이 저장돼요")
                Button("지금") { timeMark = timeMarkString() }
                    .buttonStyle(.link)

                Spacer()

                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
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
        .onAppear {
            focused = true
            if timeMark.isEmpty { timeMark = timeMarkString() }   // 열 때 지금 시각으로 채움
            #if DEBUG
            if DemoMode.isOn {
                timeMark = DemoMode.captureTimeMark
                text = DemoMode.captureDraft
                // 포커스 시 전체 선택되므로, 입력 중인 모습이 되게 커서를 끝으로 옮긴다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
                        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
                    }
                }
            }
            #endif
        }
    }

    private func save(keepOpen: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let lecture else { return }
        let q = Question(text: trimmed,
                         timeMark: timeMark.trimmingCharacters(in: .whitespaces),
                         lecture: lecture)
        context.insert(q)
        text = ""
        timeMark = timeMarkString()   // 이어서 적을 다음 질문은 그때의 지금 시각으로
        if keepOpen {
            focused = true
        } else {
            dismiss()
        }
    }
}
