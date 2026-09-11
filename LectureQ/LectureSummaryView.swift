import SwiftUI
import SwiftData

/// 한 강의를 한눈에: 던질 질문(미해결) + 배운 점(해결됨) + 메모를 요약해 보여준다.
struct LectureSummaryView: View {
    let lecture: Lecture
    @Environment(\.dismiss) private var dismiss

    private var questions: [Question] {
        lecture.questions.sorted { $0.createdAt < $1.createdAt }
    }
    private var toAsk: [Question] { questions.filter { !$0.isResolved } }
    // 배운 점 = 해결됐고 + 배운 점으로 포함(isLearned) 한 것
    private var learned: [Question] { questions.filter { $0.isResolved && $0.isLearned } }
    // 답은 있지만 "배운 점"에서 뺀 것
    private var excluded: [Question] { questions.filter { $0.isResolved && !$0.isLearned } }
    private var followUps: Int { questions.filter { !$0.linkedFrom.isEmpty }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("질문 \(questions.count) · 던질 질문 \(toAsk.count) · 배운 점 \(learned.count) · 꼬리질문 \(followUps)")
                        .scaledFont(.callout)
                        .foregroundStyle(.secondary)
                    if !combinedNotes.isEmpty {
                        notesSection
                    }
                    toAskSection
                    learnedSection
                    if !excluded.isEmpty {
                        excludedSection
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lecture.title)
                    .scaledFont(.title2, weight: .bold)
                Text(lecture.createdAt.formatted(date: .long, time: .omitted))
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("닫기") { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(16)
    }

    // MARK: Notes

    /// 블록들의 메모(+레거시 강의 메모)를 시간순으로 합친다.
    private var combinedNotes: String {
        var parts = lecture.blocks
            .sorted { $0.startTime < $1.startTime }
            .map { $0.notes.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let legacy = lecture.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !legacy.isEmpty && !parts.contains(legacy) { parts.insert(legacy, at: 0) }
        return parts.joined(separator: "\n\n")
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("메모")
            Text(combinedNotes)
                .scaledFont(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: To-ask (unresolved)

    private var toAskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("던질 질문", count: toAsk.count)
            if toAsk.isEmpty {
                emptyLine("모두 해결했어요")
            } else {
                ForEach(toAsk, id: \.uuid) { q in
                    HStack(alignment: .firstTextBaseline) {
                        Text(q.text)
                            .textSelection(.enabled)
                            // 꼬리질문은 들여써서 구분
                            .padding(.leading, q.linkedFrom.isEmpty ? 0 : 16)
                        Spacer()
                        if !q.timeMark.isEmpty {
                            Text(q.timeMark)
                                .scaledFont(.caption, monospacedDigit: true)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Learned (resolved)

    private var learnedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("배운 점", count: learned.count)
            if learned.isEmpty {
                emptyLine("질문을 해결로 표시하면 여기 모여요")
            } else {
                ForEach(learned, id: \.uuid) { q in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(q.text)
                                .scaledFont(.callout, weight: .semibold)
                                .textSelection(.enabled)
                            Spacer()
                            Button("제외") {
                                withAnimation { q.isLearned = false }
                            }
                            .buttonStyle(.borderless)
                            .scaledFont(.caption)
                            .foregroundStyle(.secondary)
                            .help("배운 점에서 제외 (답은 그대로 남아요)")
                        }
                        let answer = q.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(answer.isEmpty ? "답 메모가 비어 있어요" : answer)
                            .scaledFont(.callout)
                            .foregroundStyle(answer.isEmpty ? .tertiary : .primary)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: Excluded (답은 있지만 배운 점 아님)

    private var excludedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("제외한 답", count: excluded.count)
            ForEach(excluded, id: \.uuid) { q in
                HStack(alignment: .firstTextBaseline) {
                    Text(q.text)
                        .scaledFont(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button("다시 넣기") {
                        withAnimation { q.isLearned = true }
                    }
                    .buttonStyle(.borderless)
                    .scaledFont(.caption)
                    .help("다시 배운 점으로")
                }
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, count: Int? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .scaledFont(.title3, weight: .semibold)
            if let count {
                Text("\(count)")
                    .scaledFont(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.tertiary)
    }
}
