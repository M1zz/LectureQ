import AppIntents
import Combine

/// 단축어·Spotlight·Siri 에서 들어온 "질문 추가" 요청을 화면(ContentView)에 넘기는 다리.
/// 앱이 꺼져 있다가 단축어로 켜져도, ContentView 가 구독하는 순간 현재 값(true)을 받아 입력창을 연다.
@MainActor
final class CaptureRequest: ObservableObject {
    static let shared = CaptureRequest()
    @Published var isPending = false
}

/// 질문 입력창을 바로 연다 — 앱에서 ⌘⇧N 을 누른 것과 같다.
struct AddQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "질문 추가"
    static let description = IntentDescription("질문 노트를 열고 지금 보고 있는 강의에 질문을 적는 창을 띄웁니다.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRequest.shared.isPending = true
        return .result()
    }
}

struct LectureQShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuestionIntent(),
            phrases: [
                "\(.applicationName)에 질문 추가",
                "\(.applicationName)에서 질문 적기",
                "\(.applicationName) 질문 추가"
            ],
            shortTitle: "질문 추가",
            systemImageName: "questionmark.bubble"
        )
    }
}
