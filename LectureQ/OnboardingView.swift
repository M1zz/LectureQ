import SwiftUI

/// 첫 실행 안내 — 강의를 하나도 만들지 않은 처음 사용자에게 한 번만 보여 준다.
/// "강의 만들기 → ⌘⇧N 으로 질문 → 나중에 답하고 해결" 세 단계가 이 앱의 전부라, 그것만 짧게 알린다.
/// 이미 강의가 있는 사람(업데이트 사용자)에게는 띄우지 않는다 → ContentView.
struct LectureQOnboardingView: View {
    /// "첫 강의 만들기" — 강의를 하나 만들고 안내를 닫는다.
    var onCreateLecture: () -> Void
    /// "둘러보기" — 아무것도 만들지 않고 닫는다.
    var onDismiss: () -> Void

    private struct Step: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(id: 1, symbol: "books.vertical",
             title: String(localized: "강의를 만들어요"),
             detail: String(localized: "툴바 왼쪽 강의 메뉴에서 새 강의를 추가하거나, 대화 마크다운 파일을 가져올 수 있어요.")),
        Step(id: 2, symbol: "keyboard",
             title: String(localized: "궁금하면 바로 ⌘⇧N"),
             detail: String(localized: "강의를 듣다 떠오른 질문을 가장 쉬운 말로 적어 두세요. 시점은 지금 시각으로 채워져요.")),
        Step(id: 3, symbol: "checkmark.circle",
             title: String(localized: "답을 적고 해결해요"),
             detail: String(localized: "나중에 내 말로 답을 정리하고, 질문 앞 ? 를 눌러 해결로 바꾸세요. 보기 메뉴의 요약에 배운 점이 모여요."))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("질문 노트에 오신 걸 환영해요")
                    .scaledFont(.title, weight: .bold)
                Text("강의 중 생긴 질문을 놓치지 않고, 나중에 내 말로 답하는 노트예요.")
                    .scaledFont(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.symbol)
                            .scaledFont(20)
                            .foregroundStyle(.tint)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .scaledFont(.headline)
                            Text(step.detail)
                                .scaledFont(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(step.id)단계, \(step.title). \(step.detail)")
                }
            }

            HStack {
                Spacer()
                Button("둘러보기", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Button("첫 강의 만들기", action: onCreateLecture)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}
