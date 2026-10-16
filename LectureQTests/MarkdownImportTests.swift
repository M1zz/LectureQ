import XCTest
import SwiftData
@testable import LectureQ

/// 대화 마크다운 → 강의 구조 해석 (LectureMarkdownImporter).
final class MarkdownImportTests: XCTestCase {

    private let sample = """
    # 스위프트 동시성
    > 일자: 2026-10-01

    ## actor
    **리오** — actor 는 왜 필요해?
    **Claude** — 데이터 경쟁을 막기 위해서예요.
    여러 줄로 이어지는 답입니다.
    **리오** — 그럼 class 와 뭐가 달라?
    **Claude** — 격리가 있어요.

    ## Sendable
    **리오** — Sendable 은?
    ---
    본문만 있는 줄은 버린다
    """

    func testTitleQuestionerAndSections() {
        let d = LectureMarkdownImporter.parse(sample)
        XCTAssertEqual(d.title, "스위프트 동시성")
        XCTAssertEqual(d.questioner, "리오")
        XCTAssertEqual(d.sections.map(\.title), ["actor", "Sendable"])
        XCTAssertEqual(d.questionCount, 3)
    }

    func testMultilineAnswerIsJoinedToPreviousTurn() {
        let d = LectureMarkdownImporter.parse(sample)
        let first = d.sections[0].turns[1]
        XCTAssertEqual(first.speaker, "Claude")
        XCTAssertEqual(first.text, "데이터 경쟁을 막기 위해서예요.\n여러 줄로 이어지는 답입니다.")
    }

    func testQuoteMetaAndTextAfterRuleAreIgnored() {
        let d = LectureMarkdownImporter.parse(sample)
        // `---` 뒤의 화자 없는 본문은 앞 발화에 붙지 않는다.
        XCTAssertEqual(d.sections[1].turns, [.init(speaker: "리오", text: "Sendable 은?")])
        XCTAssertFalse(d.sections.flatMap(\.turns).contains { $0.text.contains("일자") })
    }

    func testCodeFenceIsNotParsedAsHeaderOrSpeaker() {
        let md = """
        **나** — 코드 봐줘
        **AI** — 이렇게요
        ```
        # 이건 제목이 아님
        **가짜** — 화자 아님
        ```
        """
        let d = LectureMarkdownImporter.parse(md)
        XCTAssertEqual(d.title, "가져온 대화")   // 제목이 없으면 기본 제목
        XCTAssertEqual(d.sections.count, 1)
        XCTAssertEqual(d.sections[0].turns.count, 2)
        XCTAssertTrue(d.sections[0].turns[1].text.contains("# 이건 제목이 아님"))
        XCTAssertTrue(d.sections[0].turns[1].text.contains("**가짜** — 화자 아님"))
    }

    func testSpeakerSeparatorsVariants() {
        let md = """
        **A** – en dash
        **B** - hyphen
        **A**: colon
        **B**
        """
        let turns = LectureMarkdownImporter.parse(md).sections[0].turns
        XCTAssertEqual(turns.map(\.speaker), ["A", "B", "A", "B"])
        XCTAssertEqual(turns.map(\.text), ["en dash", "hyphen", "colon", ""])
    }

    func testEmptyInput() {
        let d = LectureMarkdownImporter.parse("")
        XCTAssertEqual(d.title, "가져온 대화")
        XCTAssertEqual(d.questioner, "")
        XCTAssertTrue(d.sections.isEmpty)
        XCTAssertEqual(d.questionCount, 0)
    }

    // MARK: 강의 생성 (메모리 저장소)

    @MainActor
    func testMakeLectureBuildsRootAndFollowUpsWithAnswers() throws {
        let container = try ModelContainer(
            for: Lecture.self, Question.self, Block.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext

        let lecture = LectureMarkdownImporter.makeLecture(
            from: LectureMarkdownImporter.parse(sample), in: context)

        XCTAssertEqual(lecture.title, "스위프트 동시성")
        XCTAssertEqual(lecture.blocks.count, 1)
        XCTAssertEqual(lecture.questions.count, 3)

        let root = try XCTUnwrap(lecture.questions.first { $0.text == "actor 는 왜 필요해?" })
        XCTAssertTrue(root.isResolved)
        XCTAssertTrue(root.answer.hasPrefix("데이터 경쟁을"))
        XCTAssertEqual(root.related.map(\.text), ["그럼 class 와 뭐가 달라?"])

        // 답이 없는 질문은 미해결로 남는다.
        let open = try XCTUnwrap(lecture.questions.first { $0.text == "Sendable 은?" })
        XCTAssertFalse(open.isResolved)
        XCTAssertEqual(open.answer, "")
        XCTAssertTrue(open.related.isEmpty)
    }
}
