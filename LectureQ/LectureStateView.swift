import SwiftUI
import SwiftData

/// 강의별 학습 상태 메모: 지금 나의 상태 / 마쳤을 때 상태 / 배우고 싶은 것.
struct LectureStateView: View {
    @Bindable var lecture: Lecture
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("학습 상태")
                    .scaledFont(.headline)
                Text(lecture.title)
                    .scaledFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editor("지금 나의 상태",
                           text: $lecture.currentState,
                           placeholder: "이 강의를 듣기 전/지금 내가 아는 정도, 막히는 점…")

                    editor("학습을 마쳤을 때 나의 상태",
                           text: $lecture.goalState,
                           placeholder: "이 강의를 다 이해하면 어떤 상태이고 싶은지…")

                    editor("배우고 싶은 것",
                           text: $lecture.wantToLearn,
                           placeholder: "이 강의에서 꼭 얻고 싶은 것·궁금한 주제…")
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    private func editor(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .scaledFont(.subheadline, weight: .semibold)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .scaledFont(13)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .scaledFont(13)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 13)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
