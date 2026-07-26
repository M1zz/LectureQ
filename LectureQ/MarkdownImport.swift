import Foundation
import SwiftData

/// 대화형 마크다운(`**화자** — 내용` 반복)을 강의 구조로 해석해 가져오는 임포터.
///
/// 해석 규칙
/// - `# 제목`(H1)        → 강의 제목
/// - `## 섹션`(H2)       → 하나의 주제 묶음. 섹션의 첫 질문이 "원질문", 이어지는 질문들이 그 "꼬리질문"
/// - `**리오** — 질문`   → Question.text (질문자 = 파일에 처음 등장하는 화자)
/// - 바로 뒤 `**Claude** — 답` → 그 질문의 Question.answer (= 배운 점), 답이 있으면 isResolved = true
/// - `> 메타`, `---`, 화자 없는 본문 → 무시. 코드펜스(```)와 여러 줄 답변은 직전 발화에 이어붙임.
enum LectureMarkdownImporter {

    // MARK: 파싱 결과 (SwiftData 와 무관한 순수 값 — 테스트 용이)

    struct ParsedTurn: Equatable {
        var speaker: String
        var text: String
    }

    struct ParsedSection: Equatable {
        var title: String            // ## 헤더 (도입부는 "")
        var turns: [ParsedTurn]
    }

    struct ParsedDialogue: Equatable {
        var title: String            // # 헤더
        var questioner: String       // 첫 화자 = 질문자
        var sections: [ParsedSection]

        var questionCount: Int {
            sections.reduce(0) { $0 + $1.turns.filter { $0.speaker == questioner }.count }
        }
    }

    // MARK: 파싱

    static func parse(_ markdown: String) -> ParsedDialogue {
        var title = ""
        var sections: [ParsedSection] = []
        var current = ParsedSection(title: "", turns: [])
        var pendingSpeaker: String?
        var pendingText: [String] = []
        var firstSpeaker: String?
        var inFence = false

        func flushTurn() {
            if let s = pendingSpeaker {
                let body = pendingText.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                current.turns.append(ParsedTurn(speaker: s, text: body))
            }
            pendingSpeaker = nil
            pendingText = []
        }

        func flushSection() {
            flushTurn()
            if !current.turns.isEmpty || !current.title.isEmpty {
                sections.append(current)
            }
            current = ParsedSection(title: "", turns: [])
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // 코드펜스 토글 — 펜스 안에서는 헤더/화자 파싱을 하지 않고 그대로 이어붙인다.
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                if pendingSpeaker != nil { pendingText.append(rawLine) }
                continue
            }
            if inFence {
                if pendingSpeaker != nil { pendingText.append(rawLine) }
                continue
            }

            if trimmed.hasPrefix("# ") {
                if title.isEmpty {
                    title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if trimmed.hasPrefix("## ") {
                flushSection()
                current.title = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushTurn()
                continue
            }
            if trimmed.hasPrefix(">") {
                continue        // 인용 메타(일자/형식/참여) 무시
            }

            // 화자 라인?  **이름** — 내용   ( — – - : 모두 허용 )
            if let (name, rest) = matchSpeaker(trimmed) {
                flushTurn()
                pendingSpeaker = name
                if firstSpeaker == nil { firstSpeaker = name }
                pendingText = rest.isEmpty ? [] : [rest]
                continue
            }

            // 그 외: 진행 중인 발화의 연속(여러 줄 답변 등). 화자 없는 본문은 버린다.
            if pendingSpeaker != nil {
                pendingText.append(rawLine)
            }
        }
        flushSection()

        return ParsedDialogue(title: title.isEmpty ? "가져온 대화" : title,
                              questioner: firstSpeaker ?? "",
                              sections: sections)
    }

    /// `**이름** — 내용` 형태를 (이름, 내용)으로. 아니면 nil.
    private static func matchSpeaker(_ line: String) -> (name: String, rest: String)? {
        guard line.hasPrefix("**") else { return nil }
        let afterOpen = line.index(line.startIndex, offsetBy: 2)
        guard let close = line.range(of: "**", range: afterOpen..<line.endIndex) else { return nil }
        let name = String(line[afterOpen..<close.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        var rest = String(line[close.upperBound...]).trimmingCharacters(in: .whitespaces)
        for dash in ["—", "–", "-", ":"] where rest.hasPrefix(dash) {
            rest = String(rest.dropFirst(dash.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return (name, rest)
    }

    // MARK: 강의 생성

    /// 파싱 결과를 SwiftData 강의로 만들어 context 에 삽입하고 반환한다.
    @discardableResult
    static func makeLecture(from dialogue: ParsedDialogue, in context: ModelContext) -> Lecture {
        let lecture = Lecture(title: dialogue.title)
        context.insert(lecture)

        // 시간 정보가 없는 임포트 — 질문 작성시각(now)을 모두 담는 넉넉한 블록 하나를
        // 미리 만들어 커버리지 로직이 헛블록을 만들지 않게 한다.
        let block = Block(startTime: Date.now.addingTimeInterval(-120),
                          durationMinutes: 90)
        block.lecture = lecture
        context.insert(block)

        let questioner = dialogue.questioner

        for section in dialogue.sections {
            var sectionRoot: Question?
            var currentQuestion: Question?

            for turn in section.turns {
                if turn.speaker == questioner {
                    // 질문자 발화 → 새 질문
                    let q = Question(text: turn.text, lecture: lecture)
                    context.insert(q)
                    if let root = sectionRoot {
                        root.related.append(q)      // 섹션 첫 질문의 꼬리질문으로 연결
                    } else {
                        sectionRoot = q             // 섹션 첫 질문 = 원질문
                    }
                    currentQuestion = q
                } else if let q = currentQuestion {
                    // 답변자 발화 → 현재 질문에 누적(= 배운 점)
                    q.answer = q.answer.isEmpty ? turn.text : q.answer + "\n\n" + turn.text
                    if !q.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        q.isResolved = true
                    }
                }
                // 첫 질문 전에 나온 답변자 발화는 붙일 곳이 없어 건너뛴다.
            }
        }
        return lecture
    }

    /// 파일 URL 에서 바로 강의를 생성한다. (샌드박스에서 선택한 파일 읽기 권한 처리 포함)
    @discardableResult
    static func importFile(at url: URL, in context: ModelContext) throws -> Lecture {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        return makeLecture(from: parse(text), in: context)
    }
}
