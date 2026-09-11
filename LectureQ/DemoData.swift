import Foundation
import SwiftData
import AppKit

/// 앱스토어 스크린샷용 데모 모드 (Debug 빌드 전용).
/// 실행 인자 예: `-DemoMode YES -DemoScreen graph`
/// - 실제 저장 파일 대신 메모리 저장소에 예시 강의·질문을 채운다(사용자 데이터는 건드리지 않음).
/// - DemoScreen: main / capture / graph / summary / timeline / state
enum DemoMode {
    #if DEBUG
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "DemoMode") }
    #else
    static let isOn = false
    #endif
}

#if DEBUG
extension DemoMode {
    static var screen: String { UserDefaults.standard.string(forKey: "DemoScreen") ?? "main" }

    static let mainLectureTitle = "머신러닝 입문 · 3강 경사하강법"
    static let focusQuestion = "한 걸음은 얼마나 커야 하나요? 학습률은 누가 정하죠?"
    static let captureDraft = "검증 손실이 오르기 시작하는 시점은 어떻게 알아채나요?"
    static let captureTimeMark = "11:52"

    static func makeContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        seed(ModelContext(container))
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        return container
    }

    /// 스크린샷 크기에 맞춰 메인 창 크기를 고정한다.
    static func sizeMainWindow() {
        let w = UserDefaults.standard.double(forKey: "DemoWidth")
        let h = UserDefaults.standard.double(forKey: "DemoHeight")
        let size = NSSize(width: w > 0 ? w : 1280, height: h > 0 ? h : 800)
        guard let window = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }) else { return }
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true)
        // 비활성 창은 툴바·선택 색이 흐리게 찍히므로 앞으로 가져온다.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private static func today(_ h: Int, _ m: Int, dayOffset: Int = 0) -> Date {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: .now))!
        return cal.date(bySettingHour: h, minute: m, second: 0, of: day)!
    }

    private static func seed(_ context: ModelContext) {
        // 이전 강의 (강의 메뉴·타임블록 시트에 함께 보이도록)
        let prev = Lecture(title: "선형대수 복습 · 행렬 곱")
        prev.createdAt = today(8, 30)
        prev.autoBlockCoverage = false
        context.insert(prev)
        addBlock(prev, start: today(8, 30), minutes: 60, hue: 0.08, context: context, notes: """
        행렬 곱 AB = A의 행 · B의 열 내적
        순서를 바꾸면 결과가 달라진다 (AB ≠ BA)
        """)
        let p1 = addQuestion(prev, "행렬 곱은 왜 순서를 바꾸면 안 되나요?", "08:47", context: context,
                             answer: "변환을 차례로 적용하는 것이라, 회전 후 이동과 이동 후 회전의 결과가 다르기 때문.",
                             resolved: true)
        _ = p1

        // 메인 강의
        let lecture = Lecture(title: mainLectureTitle)
        lecture.createdAt = today(10, 0)
        lecture.autoBlockCoverage = false
        lecture.currentState = "파이썬은 쓸 줄 알지만 미분은 기억이 가물가물하다. 모델이 ‘학습한다’는 게 정확히 무슨 뜻인지 모르겠다."
        lecture.goalState = "경사하강법을 그림 없이 말로 설명할 수 있다. 학습률과 배치 크기를 직접 골라 손실 곡선으로 확인할 수 있다."
        lecture.wantToLearn = "학습률을 고르는 감각\n손실 곡선을 읽는 법\n과적합을 알아채는 신호"
        context.insert(lecture)

        addBlock(lecture, start: today(10, 0), minutes: 60, hue: 0.58, context: context, notes: """
        손실 함수 = 예측이 얼마나 틀렸는지 재는 값
        경사하강법: 기울기의 반대 방향으로 조금씩 이동
          w ← w − η · ∂L/∂w

        학습률 η 가 크면 발산, 작으면 너무 느림
        → 보통 0.01 근처에서 시작해 손실 곡선을 보며 조정
        """)
        addBlock(lecture, start: today(11, 10), minutes: 50, hue: 0.45, context: context, notes: """
        미니배치: 전체 데이터 대신 일부로 기울기를 추정
        에폭 = 전체 데이터를 한 번 다 보는 것

        과제: 학습률 3가지로 손실 곡선 비교해 보기
        """)

        let q1 = addQuestion(lecture, "기울기의 반대 방향으로 가면 왜 손실이 줄어드나요?", "10:12", context: context,
                             answer: "기울기는 함수가 가장 가파르게 커지는 방향이다. 그 반대로 아주 조금 움직이면 값이 가장 빠르게 작아진다. 산에서 발밑이 제일 급한 아래쪽으로 한 걸음씩 내려가는 것과 같다.",
                             resolved: true)
        let q11 = addQuestion(lecture, focusQuestion, "10:18", context: context,
                              answer: """
                              학습률은 사람이 정하는 값(하이퍼파라미터)이다.
                              너무 크면 골짜기를 건너뛰어 손실이 오히려 튀고, 너무 작으면 한참 걸린다.

                              → 0.01 근처에서 시작해서 손실 곡선이 꾸준히 내려가는지 보고 10배씩 조정.
                              """,
                              resolved: true)
        let q111 = addQuestion(lecture, "학습 도중에 학습률을 바꾸기도 하나요?", "10:41", context: context)
        let q12 = addQuestion(lecture, "골짜기가 여러 개면 가장 낮은 곳을 못 찾지 않나요?", "10:26", context: context)
        let q2 = addQuestion(lecture, "손실 함수는 꼭 제곱 오차여야 하나요?", "10:50", context: context,
                             answer: "아니다. 회귀는 보통 제곱 오차, 분류는 교차 엔트로피를 쓴다. 문제에 맞게 ‘틀린 정도’를 정의하는 것.",
                             resolved: true)
        let q3 = addQuestion(lecture, "미니배치 크기는 어떻게 고르나요?", "11:22", context: context)
        let q31 = addQuestion(lecture, "배치가 작으면 기울기가 흔들리는데 괜찮은가요?", "11:35", context: context,
                              answer: "흔들림이 오히려 얕은 골짜기를 빠져나오는 데 도움이 된다고 함 — 더 찾아보기")
        let q4 = addQuestion(lecture, "에폭을 너무 많이 돌리면 어떻게 되나요?", "11:48", context: context,
                             answer: "훈련 데이터에만 딱 맞춰지는 과적합이 생긴다. 검증 손실이 다시 오르기 시작하면 멈춘다(조기 종료).",
                             resolved: true)
        _ = (q2, q4)

        q1.related.append(q11)
        q1.related.append(q12)
        q11.related.append(q111)
        q3.related.append(q31)

        try? context.save()
    }

    private static func addBlock(_ lecture: Lecture, start: Date, minutes: Int, hue: Double,
                                 context: ModelContext, notes: String) {
        let block = Block(startTime: start, durationMinutes: minutes, notes: notes)
        block.colorHue = hue
        block.createdAt = start
        block.lecture = lecture
        context.insert(block)
    }

    @discardableResult
    private static func addQuestion(_ lecture: Lecture, _ text: String, _ mark: String,
                                    context: ModelContext, answer: String = "",
                                    resolved: Bool = false) -> Question {
        let q = Question(text: text, timeMark: mark, lecture: lecture)
        q.answer = answer
        q.isResolved = resolved
        if let t = parseClock(mark) { q.createdAt = today(t.h, t.m) }
        context.insert(q)
        return q
    }
}
#endif
