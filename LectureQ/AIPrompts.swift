import Foundation

/// 질문 노트에 이미 적힌 것들(질문·강의·그 시점 메모·학습 상태·원질문)을
/// "AI로 답 찾기" 5단계 프롬프트에 채워 넣는다.
/// docs/ai-guide.html 의 단계와 1:1로 대응한다.
enum AIPrompt: String, CaseIterable, Identifiable {
    case refine      // ① 질문 다듬기
    case ask         // ② 맥락 붙여 묻기
    case verify      // ③ 되묻기(검증)
    case followUps   // ④ 꼬리질문 뽑기
    case grade       // ⑤ 내 말로 쓴 답 채점받기

    var id: String { rawValue }

    var title: String {
        switch self {
        case .refine:    return "질문 다듬기"
        case .ask:       return "답 찾기"
        case .verify:    return "답 되묻기"
        case .followUps: return "꼬리질문 뽑기"
        case .grade:     return "내 답 채점받기"
        }
    }

    /// 이 단계를 쓸 수 없는 경우의 이유 (nil이면 사용 가능)
    func unavailableReason(for question: Question) -> String? {
        switch self {
        case .grade:
            return question.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "먼저 답 칸에 내 말로 한두 줄 적어 주세요" : nil
        default:
            return nil
        }
    }
}

/// 프롬프트 본문을 만든다. 비어 있는 맥락은 넣지 않는다(빈 칸을 채우라고 AI에게 시키지 않기 위해).
func makePrompt(_ kind: AIPrompt, for question: Question) -> String {
    let q = question.text.trimmingCharacters(in: .whitespacesAndNewlines)

    switch kind {
    case .refine:
        return """
        아래는 내가 강의를 들으며 급히 적은 질문이야. 아직 흐릿해.

        "\(q)"

        이 질문을 '답할 수 있는 질문' 3가지로 다시 써줘.
        각각 그 답을 알면 내가 무엇을 할 수 있게 되는지도 한 줄씩 붙여줘.
        지금은 답하지 말고, 다시 쓴 질문만 보여줘.
        """

    case .ask:
        return """
        [내 질문]
        \(q)
        \(contextSection(for: question))
        [원하는 답]
        1) 핵심 답 3~5줄
        2) 왜 그런지 근거 한 문단
        3) 내가 잘못 알고 있을 법한 지점 1~2개
        4) 직접 확인해볼 수 있는 가장 작은 예시나 실험 하나

        확실한 것과 추측을 구분해서 표시해줘. 모르는 건 모른다고 말해줘.
        """

    case .verify:
        return """
        방금 답에서 가장 틀리기 쉬운 부분은 어디야?

        - 이 답이 성립하려면 참이어야 하는 전제
        - 반대 입장이나, 이 답이 통하지 않는 예외 상황
        - 내가 1차 자료로 직접 확인하려면 무엇을 봐야 하는지 (공식 문서·스펙·원문 이름)

        버전·수치·이름처럼 구체적인 정보는 확신도를 함께 표시해줘.
        """

    case .followUps:
        return """
        지금까지 대화에서, 내가 아직 모르는데 알아야 할 것을 질문 3개로 뽑아줘.
        설명은 하지 말고 질문만. 짧고 구체적으로.

        (참고 — 내가 원래 물었던 질문: "\(q)")
        """

    case .grade:
        let mine = question.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        질문: "\(q)"

        이 질문에 대해 내가 이해한 걸 내 말로 적어봤어.

        "\(mine)"

        틀린 곳, 빠진 곳, 과장된 곳을 짚어줘.
        점수 대신, 고쳐 쓴 문장을 보여줘. 내가 놓친 핵심이 있으면 한 줄 덧붙여줘.
        """
    }
}

/// 앱에 이미 적혀 있는 맥락을 모은다 (비어 있으면 그 줄은 통째로 뺀다).
private func contextSection(for question: Question) -> String {
    var lines: [String] = []

    if let lecture = question.lecture {
        let title = lecture.title.trimmingCharacters(in: .whitespaces)
        if !title.isEmpty { lines.append("- 어디서 나왔나: \(title)") }

        if let note = blockNote(for: question, in: lecture) {
            lines.append("- 그 시점의 내 메모: \(note)")
        }
        if !lecture.currentState.isEmpty {
            lines.append("- 내가 지금 아는 수준: \(oneLine(lecture.currentState))")
        }
        if !lecture.goalState.isEmpty {
            lines.append("- 내가 도달하고 싶은 상태: \(oneLine(lecture.goalState))")
        }
    }

    // 이 질문이 다른 질문에서 파생된 꼬리질문이면, 원질문도 맥락이 된다.
    if let parent = question.linkedFrom.first {
        lines.append("- 이 질문이 나온 원질문: \(oneLine(parent.text))")
    }

    guard !lines.isEmpty else { return "\n" }
    return "\n[맥락]\n" + lines.joined(separator: "\n") + "\n"
}

/// 질문의 유효 시각이 들어가는 블록의 메모 (없거나 비어 있으면 nil)
private func blockNote(for question: Question, in lecture: Lecture) -> String? {
    let blocks = lecture.blocks.sorted { $0.startTime < $1.startTime }
    let hit = blocks.first { b in
        let d = questionTime(question, onDay: b.startTime)
        return d >= b.startTime && d <= b.endTime
    }
    guard let note = hit?.notes.trimmingCharacters(in: .whitespacesAndNewlines),
          !note.isEmpty else { return nil }
    return oneLine(note, limit: 500)
}

/// 여러 줄 메모를 프롬프트 한 줄에 넣기 좋게 정리한다.
private func oneLine(_ s: String, limit: Int = 200) -> String {
    let flat = s.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: " / ")
    return flat.count > limit ? String(flat.prefix(limit)) + "…" : flat
}
