import SwiftUI
import SwiftData

struct QuestionDetailView: View {
    @Bindable var question: Question
    @Environment(\.modelContext) private var context

    @State private var newFollowUp = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // Status + time mark
                HStack {
                    Button {
                        withAnimation { question.isResolved.toggle() }
                    } label: {
                        Label(question.isResolved ? "해결됨" : "미해결",
                              systemImage: question.isResolved ? "checkmark.circle.fill" : "circle.dashed")
                    }
                    .tint(question.isResolved ? .green : .orange)
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        TextField("시점", text: $question.timeMark)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    .foregroundStyle(.secondary)
                }

                // Question
                section("질문", systemImage: "questionmark.bubble") {
                    TextField("질문", text: $question.text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .scaledFont(22, weight: .medium)
                        .lineLimit(2...6)
                }

                // Answer
                section("답 / 찾은 내용", systemImage: "lightbulb") {
                    TextEditor(text: $question.answer)
                        .scaledFont(13)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .topLeading) {
                            if question.answer.isEmpty {
                                Text("답을 찾으면 여기에 기록하세요…")
                                    .foregroundStyle(.tertiary)
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                // Related questions — shown as a hierarchy:
                // 상위(출처) → 현재 질문 → 하위(파생)
                section("꼬리질문 위계", systemImage: "link") {
                    let parents = question.linkedFrom   // 이 질문이 파생된 출처(원 질문)
                    let children = question.related      // 여기서 파생된 꼬리질문

                    if parents.isEmpty && children.isEmpty {
                        Text("아직 연결된 꼬리질문이 없어요")
                            .foregroundStyle(.tertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            if !parents.isEmpty {
                                Text("원 질문 (이 질문의 출처)")
                                    .scaledFont(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            ForEach(parents) { p in
                                relatedRow(p, role: .parent)
                            }

                            currentRow

                            ForEach(children) { c in
                                relatedRow(c, role: .child)
                            }
                            if !children.isEmpty {
                                Text("꼬리질문 (여기서 파생됨)")
                                    .scaledFont(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 40)
                            }
                        }
                    }

                    followUpControls
                }

                Text("작성: \(question.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // Candidates: questions in the same lecture, not self, not already linked
    private var linkCandidates: [Question] {
        guard let lecture = question.lecture else { return [] }
        let linked = Set(question.allRelated.map(\.uuid))
        return lecture.questions
            .filter { $0.uuid != question.uuid && !linked.contains($0.uuid) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 새 꼬리질문 직접 만들기 + 기존 질문 연결
    private var followUpControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.teal)
                TextField("새 꼬리질문 입력…", text: $newFollowUp, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit(addFollowUp)
                Button("만들기", action: addFollowUp)
                    .buttonStyle(.borderedProminent)
                    .disabled(newFollowUp.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            linkMenu
        }
    }

    private var linkMenu: some View {
        Menu {
            if linkCandidates.isEmpty {
                Text("연결할 수 있는 질문이 없어요")
            } else {
                ForEach(linkCandidates) { candidate in
                    Button(candidate.text) {
                        question.related.append(candidate)
                    }
                }
            }
        } label: {
            Label("기존 질문을 꼬리질문으로 연결", systemImage: "link")
        }
        .fixedSize()
    }

    /// 입력한 텍스트로 새 질문을 만들어 현재 질문의 꼬리질문으로 연결한다.
    private func addFollowUp() {
        let text = newFollowUp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let child = Question(text: text, lecture: question.lecture)
        context.insert(child)
        question.related.append(child)
        newFollowUp = ""
    }

    private func unlink(_ other: Question) {
        question.related.removeAll { $0.uuid == other.uuid }
        question.linkedFrom.removeAll { $0.uuid == other.uuid }
    }

    // MARK: Hierarchy rows

    /// 상위(부모) / 하위(자식) 을 들여쓰기·아이콘·색으로 구분한다.
    enum RelationRole {
        case parent, child
        var indent: CGFloat { self == .parent ? 0 : 40 }
        var icon: String { self == .parent ? "arrow.up" : "arrow.turn.down.right" }
        var tag: String { self == .parent ? "원질문" : "꼬리" }
        var tint: Color { self == .parent ? .purple : .teal }
    }

    /// 현재 보고 있는 질문 (트리의 가운데, 파랑 강조)
    private var currentRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "smallcircle.filled.circle")
                .foregroundStyle(.blue)
            Circle()
                .fill(question.isResolved ? Color.green : .orange)
                .frame(width: 8, height: 8)
            Text(question.text)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text("현재")
                .scaledFont(.caption2, weight: .bold)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.blue.opacity(0.2), in: Capsule())
            Spacer()
        }
        .padding(8)
        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 20)
    }

    private func relatedRow(_ q: Question, role: RelationRole) -> some View {
        HStack(spacing: 6) {
            Image(systemName: role.icon)
                .scaledFont(.caption)
                .foregroundStyle(role.tint)
            Text(role.tag)
                .scaledFont(.caption2, weight: .bold)
                .foregroundStyle(role.tint)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(role.tint.opacity(0.18), in: Capsule())
            Circle()
                .fill(q.isResolved ? Color.green : .orange)
                .frame(width: 8, height: 8)
            Text(q.text)
                .lineLimit(1)
            Spacer()
            Button {
                unlink(q)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(role.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(role.tint.opacity(0.5))
                .frame(width: 3)
        }
        .padding(.leading, role.indent)
    }

    private func section(_ title: String, systemImage: String,
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .scaledFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
