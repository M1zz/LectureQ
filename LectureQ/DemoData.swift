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

    static var mainLectureTitle: String { DemoText.t("mainTitle") }
    static var focusQuestion: String { DemoText.t("focusQuestion") }
    static var captureDraft: String { DemoText.t("captureDraft") }
    static let captureTimeMark = "11:52"

    static func makeContainer(schema: Schema) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
        let D = DemoText.t
        // 이전 강의 (강의 메뉴·타임블록 시트에 함께 보이도록)
        let prev = Lecture(title: D("prevTitle"))
        prev.createdAt = today(8, 30)
        prev.autoBlockCoverage = false
        context.insert(prev)
        addBlock(prev, start: today(8, 30), minutes: 60, hue: 0.08, context: context, notes: D("prevNotes"))
        addQuestion(prev, D("prevQ1"), "08:47", context: context, answer: D("prevA1"), resolved: true)

        // 메인 강의
        let lecture = Lecture(title: mainLectureTitle)
        lecture.createdAt = today(10, 0)
        lecture.autoBlockCoverage = false
        lecture.currentState = D("currentState")
        lecture.goalState = D("goalState")
        lecture.wantToLearn = D("wantToLearn")
        context.insert(lecture)

        addBlock(lecture, start: today(10, 0), minutes: 60, hue: 0.58, context: context, notes: D("block1Notes"))
        addBlock(lecture, start: today(11, 10), minutes: 50, hue: 0.45, context: context, notes: D("block2Notes"))

        let q1 = addQuestion(lecture, D("q1"), "10:12", context: context, answer: D("a1"), resolved: true)
        let q11 = addQuestion(lecture, focusQuestion, "10:18", context: context, answer: D("a11"), resolved: true)
        let q111 = addQuestion(lecture, D("q111"), "10:41", context: context)
        let q12 = addQuestion(lecture, D("q12"), "10:26", context: context)
        addQuestion(lecture, D("q2"), "10:50", context: context, answer: D("a2"), resolved: true)
        let q3 = addQuestion(lecture, D("q3"), "11:22", context: context)
        let q31 = addQuestion(lecture, D("q31"), "11:35", context: context, answer: D("a31"))
        addQuestion(lecture, D("q4"), "11:48", context: context, answer: D("a4"), resolved: true)

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
