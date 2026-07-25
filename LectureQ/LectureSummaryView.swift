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
    private var learned: [Question] { questions.filter { $0.isResolved } }
    private var followUps: Int { questions.filter { !$0.linkedFrom.isEmpty }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statRow
                    if !combinedNotes.isEmpty {
                        notesCard
                    }
                    toAskSection
                    learnedSection
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
                Label("강의 요약", systemImage: "doc.text.magnifyingglass")
                    .scaledFont(.headline)
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

    // MARK: Stats

    private var statRow: some View {
        HStack(spacing: 12) {
            stat("전체 질문", "\(questions.count)", "questionmark.bubble", .blue)
            stat("던질 질문", "\(toAsk.count)", "circle.dashed", .orange)
            stat("배운 점", "\(learned.count)", "checkmark.circle.fill", .green)
            stat("꼬리질문", "\(followUps)", "arrow.turn.down.right", .teal)
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .scaledFont(.title, weight: .bold, design: .rounded)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
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

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("강의 메모", systemImage: "note.text")
                .scaledFont(.subheadline, weight: .semibold)
                .foregroundStyle(.secondary)
            Text(combinedNotes)
                .scaledFont(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: To-ask (unresolved)

    private var toAskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("던질 질문", systemImage: "circle.dashed",
                         count: toAsk.count, color: .orange)
            if toAsk.isEmpty {
                emptyLine("아직 던질 질문이 없어요 — 모두 해결됐네요 🎉")
            } else {
                ForEach(toAsk) { q in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: q.linkedFrom.isEmpty ? "circle" : "arrow.turn.down.right")
                            .foregroundStyle(q.linkedFrom.isEmpty ? .orange : .teal)
                            .scaledFont(.body)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.text)
                                .textSelection(.enabled)
                            if !q.timeMark.isEmpty {
                                Label(q.timeMark, systemImage: "clock")
                                    .scaledFont(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: Learned (resolved)

    private var learnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("배운 점", systemImage: "checkmark.circle.fill",
                         count: learned.count, color: .green)
            if learned.isEmpty {
                emptyLine("아직 정리된 배운 점이 없어요. 질문을 해결로 표시하면 여기 모여요.")
            } else {
                ForEach(learned) { q in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(q.text)
                                .scaledFont(.callout, weight: .semibold)
                                .textSelection(.enabled)
                        }
                        let answer = q.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if answer.isEmpty {
                            Text("답 메모가 비어 있어요")
                                .scaledFont(.callout)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 24)
                        } else {
                            Text(answer)
                                .scaledFont(.callout)
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .padding(.leading, 24)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ title: String, systemImage: String,
                              count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .scaledFont(.title3, weight: .semibold)
            Text("\(count)")
                .scaledFont(.caption, weight: .bold)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(color.opacity(0.2), in: Capsule())
                .foregroundStyle(color)
        }
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.tertiary)
            .padding(.vertical, 4)
    }
}
