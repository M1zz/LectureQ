import Foundation
import SwiftData

@Model
final class Lecture {
    var uuid: UUID
    var title: String
    var createdAt: Date

    // 레거시(구버전) 필드 — 기존 데이터 보존용. 이제 메모/시간은 Block 으로 옮겨감.
    var notes: String = ""
    var startTime: Date = Date.now
    var durationMinutes: Int = 60

    // 사용자가 블록을 직접 지운 강의는 자동 블록 생성(커버리지 보정)을 멈춘다.
    // 끄지 않으면 지운 블록 시간대의 질문 때문에 블록이 곧장 다시 생겨 "삭제가 안 되는" 것처럼 보인다.
    var autoBlockCoverage: Bool = true

    // 학습 상태 메모 (평소엔 숨겨두고, 버튼으로 열어 적는다)
    var currentState: String = ""   // 지금 나의 상태
    var goalState: String = ""      // 학습을 마쳤을 때 나의 상태
    var wantToLearn: String = ""    // 배우고 싶은 것

    @Relationship(deleteRule: .cascade, inverse: \Question.lecture)
    var questions: [Question] = []

    // 한 강의 안의 여러 시간 블록
    @Relationship(deleteRule: .cascade, inverse: \Block.lecture)
    var blocks: [Block] = []

    init(title: String) {
        self.uuid = UUID()
        self.title = title
        self.createdAt = .now
    }
}

@Model
final class Block {
    var uuid: UUID = UUID()
    var startTime: Date = Date.now
    var durationMinutes: Int = 60
    var notes: String = ""
    var createdAt: Date = Date.now
    var colorHue: Double = -1   // 0~1 사용자 지정 색상, 음수면 uuid 기반 자동색

    var lecture: Lecture?

    init(startTime: Date = .now, durationMinutes: Int = 60, notes: String = "") {
        self.uuid = UUID()
        self.startTime = startTime
        self.durationMinutes = durationMinutes
        self.notes = notes
        self.createdAt = .now
    }

    var endTime: Date {
        startTime.addingTimeInterval(TimeInterval(durationMinutes) * 60)
    }
}

@Model
final class Question {
    var uuid: UUID
    var text: String          // the question itself
    var answer: String        // the answer, filled in later
    var isResolved: Bool
    // "배운 점"으로 포함할지 — 해결된 질문 중에서도 실제로 배운 것만 고를 수 있게 한다.
    // 기본 true(포함), 사용자가 제외 가능. 배운 점 = isResolved && isLearned.
    var isLearned: Bool = true
    var timeMark: String      // e.g. "12:34" — where in the lecture it came up
    var createdAt: Date

    var lecture: Lecture?

    // Self-referencing many-to-many: "this question is related to..."
    @Relationship(inverse: \Question.linkedFrom)
    var related: [Question] = []
    var linkedFrom: [Question] = []

    init(text: String, timeMark: String = "", lecture: Lecture? = nil) {
        self.uuid = UUID()
        self.text = text
        self.answer = ""
        self.isResolved = false
        self.timeMark = timeMark
        self.createdAt = .now
        self.lecture = lecture
    }

    /// All connections regardless of direction (used by the graph).
    var allRelated: [Question] {
        var seen = Set<UUID>()
        return (related + linkedFrom).filter { seen.insert($0.uuid).inserted }
    }
}
