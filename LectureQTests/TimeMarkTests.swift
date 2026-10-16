import XCTest
import SwiftData
@testable import LectureQ

/// 질문 시점(timeMark) 해석과 블록 위 배치.
final class TimeMarkTests: XCTestCase {

    private var calendar: Calendar { .current }

    private func date(_ h: Int, _ m: Int, _ s: Int = 0) -> Date {
        var dc = DateComponents()
        dc.year = 2026; dc.month = 10; dc.day = 17
        dc.hour = h; dc.minute = m; dc.second = s
        return calendar.date(from: dc)!
    }

    func testParseClock() {
        XCTAssertEqual(parseClock("12:34")?.h, 12)
        XCTAssertEqual(parseClock("12:34")?.m, 34)
        XCTAssertEqual(parseClock("12:34")?.s, 0)
        XCTAssertEqual(parseClock(" 9 : 05 : 30 ")?.s, 30)
        XCTAssertNil(parseClock(""))
        XCTAssertNil(parseClock("12"))
        XCTAssertNil(parseClock("ab:cd"))
        XCTAssertNil(parseClock("1:2:3:4"))
    }

    func testTimeMarkStringIsFixed24HourAndRoundTrips() {
        let s = timeMarkString(date(15, 7))
        XCTAssertEqual(s, "15:07")
        let back = clockDate(on: date(0, 0), timeMark: s)
        XCTAssertEqual(back, date(15, 7))
    }

    func testClockDateUsesDayOfReference() {
        XCTAssertEqual(clockDate(on: date(23, 59), timeMark: "08:30:15"), date(8, 30, 15))
        XCTAssertNil(clockDate(on: date(8, 0), timeMark: "곧"))
    }

    @MainActor
    func testQuestionTimeFallsBackToCreatedAt() {
        let q = Question(text: "?", timeMark: "")
        XCTAssertEqual(questionTime(q, onDay: date(9, 0)), q.createdAt)
        q.timeMark = "10:15"
        XCTAssertEqual(questionTime(q, onDay: date(9, 0)), date(10, 15))
    }

    @MainActor
    func testBlockMarkersPlaceQuestionsInTheirBlock() throws {
        let container = try ModelContainer(
            for: Lecture.self, Question.self, Block.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext

        let lecture = Lecture(title: "강의")
        context.insert(lecture)
        let morning = Block(startTime: date(9, 0), durationMinutes: 60)
        let afternoon = Block(startTime: date(13, 0), durationMinutes: 120)
        for b in [morning, afternoon] { b.lecture = lecture; context.insert(b) }

        let q1 = Question(text: "처음", timeMark: "09:00", lecture: lecture)
        let q2 = Question(text: "가운데", timeMark: "14:00", lecture: lecture)
        let q3 = Question(text: "블록 밖", timeMark: "20:00", lecture: lecture)
        for q in [q1, q2, q3] { context.insert(q) }

        let markers = computeBlockMarkers(for: lecture)

        XCTAssertEqual(markers[morning.uuid]?.map(\.q.text), ["처음"])
        XCTAssertEqual(try XCTUnwrap(markers[morning.uuid]?.first).frac, 0, accuracy: 0.0001)

        // 오후 블록 13:00~15:00 의 14:00 은 한가운데. 어느 블록에도 안 드는 질문은 마지막 블록 끝에 둔다.
        let pm = try XCTUnwrap(markers[afternoon.uuid])
        XCTAssertEqual(Set(pm.map(\.q.text)), ["가운데", "블록 밖"])
        XCTAssertEqual(try XCTUnwrap(pm.first { $0.q.text == "가운데" }).frac, 0.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(pm.first { $0.q.text == "블록 밖" }).frac, 1, accuracy: 0.0001)
    }
}
