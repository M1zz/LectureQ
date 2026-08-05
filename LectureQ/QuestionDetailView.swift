import SwiftUI
import SwiftData
import AppKit

struct QuestionDetailView: View {
    @Bindable var question: Question
    @Environment(\.modelContext) private var context

    @State private var newFollowUp = ""
    @State private var selectedPrompt: AIPrompt = .ask   // 지금 고른 단계 (라벨에 남는다)
    @State private var copiedPrompt: AIPrompt?           // 방금 복사한 단계 (확인 표시용)
    @State private var previewPrompt: AIPrompt?          // 복사 전에 내용을 펼쳐 보는 단계

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

                    // 배운 점으로 포함할지 — 요약의 "배운 점"은 해결됨 + 이 토글이 켜진 것만 모은다.
                    Button {
                        withAnimation { question.isLearned.toggle() }
                    } label: {
                        Label(question.isLearned ? "배운 점" : "배운 점 아님",
                              systemImage: question.isLearned ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                    .buttonStyle(.bordered)
                    .help("요약의 ‘배운 점’ 목록에 넣을지 선택")

                    Spacer()

                    // 강의 시점 — 언제든 고쳐 쓸 수 있고, "지금"으로 현재 시각을 찍을 수 있다.
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        TextField("HH:mm", text: $question.timeMark)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 76)
                            .help("강의 시점 (24시간 HH:mm). 타임블록의 Q 위치를 정해요")
                        Button("지금") { question.timeMark = timeMarkString() }
                            .buttonStyle(.link)
                            .help("지금 시각으로 맞추기")
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

                // 답을 찾으러 가는 자리 — 앱에 적힌 맥락을 채운 프롬프트를 복사해 AI로 가져간다.
                aiSection

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
                                // 그냥 "기록하세요"가 아니라, 무엇을 어떻게 적어야 남는지 알려준다.
                                Text("AI 답을 그대로 붙여넣기보다 내 말로 정리해 적어보세요 — 그래야 ★배운 점이 됩니다")
                                    .foregroundStyle(.tertiary)
                                    .padding(12)
                                    .allowsHitTesting(false)
                            }
                        }

                    if !question.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // 적어 둔 답이 있으면 채점 단계를 바로 권한다.
                        promptButton(.grade)
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
                            ForEach(parents, id: \.uuid) { p in
                                relatedRow(p, role: .parent)
                            }

                            currentRow

                            ForEach(children, id: \.uuid) { c in
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

    // MARK: AI로 답 찾기

    /// 답을 찾으러 갈 때 쓰는 자리. 앱에 이미 적힌 맥락(강의·그 시점 메모·학습 상태·원질문)을
    /// 프롬프트에 채워 복사한다. 단계는 docs/ai-guide.html 의 5단계와 같다.
    private var aiSection: some View {
        section("AI로 답 찾기", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // 고른 단계가 라벨에 그대로 남는다 (무엇을 복사하려는지 항상 보이게)
                    Menu {
                        ForEach(AIPrompt.allCases) { p in
                            Button {
                                select(p)
                            } label: {
                                Label {
                                    Text("\(p.badge) \(p.title) — \(p.subtitle)")
                                } icon: {
                                    Image(systemName: p == selectedPrompt ? "checkmark" : p.systemImage)
                                }
                            }
                            .disabled(p.unavailableReason(for: question) != nil)
                        }
                        Divider()
                        if let guide = URL(string: "https://m1zz.github.io/LectureQ/ai-guide.html") {
                            Link(destination: guide) {
                                Label("AI로 답 찾기 가이드 열기", systemImage: "book")
                            }
                        }
                    } label: {
                        Label("\(selectedPrompt.badge) \(selectedPrompt.title)",
                              systemImage: selectedPrompt.systemImage)
                    }
                    .fixedSize()
                    .help("어떤 단계의 프롬프트를 만들지 고릅니다")

                    Button {
                        copy(selectedPrompt)
                    } label: {
                        Label("프롬프트 복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedPrompt.unavailableReason(for: question) != nil)
                    .help(selectedPrompt.unavailableReason(for: question)
                          ?? "\(selectedPrompt.title) 프롬프트를 클립보드에 복사합니다")

                    Button {
                        previewPrompt = selectedPrompt
                    } label: {
                        Label("미리 보기", systemImage: "eye")
                    }
                    .help("복사될 내용을 먼저 확인합니다")

                    Spacer()

                    if let copied = copiedPrompt {
                        Label("\(copied.title) 복사됨 — AI 대화창에 붙여넣으세요",
                              systemImage: "checkmark.circle.fill")
                            .scaledFont(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }

                // 고른 단계가 무엇을 하는 단계인지 아래에 한 줄로 남긴다.
                Text(stepHint)
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
            }
            .popover(item: $previewPrompt) { p in
                VStack(alignment: .leading, spacing: 10) {
                    Text(p.title).scaledFont(.headline)
                    ScrollView {
                        Text(makePrompt(p, for: question))
                            .scaledFont(12, design: .monospaced)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 280)
                    HStack {
                        Spacer()
                        Button("복사") {
                            copy(p)
                            previewPrompt = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
                .frame(width: 460)
            }
        }
    }

    /// 고른 단계 아래에 보여줄 안내 — 지금 단계가 무엇이고 다음은 무엇인지.
    private var stepHint: String {
        if let blocked = selectedPrompt.unavailableReason(for: question) { return blocked }
        switch selectedPrompt {
        case .refine:    return "\(selectedPrompt.subtitle) · 마음에 드는 버전이 나오면 위 질문 문장을 그걸로 고치세요."
        case .ask:       return "\(selectedPrompt.subtitle) · 강의·그 시점 메모·학습 상태가 자동으로 실립니다."
        case .verify:    return "\(selectedPrompt.subtitle) · 답을 받은 바로 그 대화창에 이어서 붙여넣으세요."
        case .followUps: return "\(selectedPrompt.subtitle) · 나온 질문은 아래 ‘새 꼬리질문 입력’에 붙여넣으세요."
        case .grade:     return "\(selectedPrompt.subtitle) · 여기까지 통과한 것만 ★배운 점으로 남기세요."
        }
    }

    /// 단계를 고르면 그 단계로 바꾸고 바로 복사까지 한다 (한 번 더 누르게 하지 않기 위해).
    private func select(_ p: AIPrompt) {
        withAnimation { selectedPrompt = p }
        copy(p)
    }

    /// 답 칸 아래에서 쓰는 단계 바로가기 버튼 (선택 상태도 함께 바뀐다).
    private func promptButton(_ p: AIPrompt) -> some View {
        Button {
            select(p)
        } label: {
            Label("\(p.badge) \(p.title)", systemImage: p.systemImage)
        }
        .buttonStyle(.bordered)
        .disabled(p.unavailableReason(for: question) != nil)
        .help(p.unavailableReason(for: question)
              ?? "\(p.subtitle) — 프롬프트를 클립보드에 복사합니다")
    }

    /// 프롬프트를 클립보드에 넣고, 어떤 단계를 복사했는지 잠깐 보여준다.
    private func copy(_ p: AIPrompt) {
        guard p.unavailableReason(for: question) == nil else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(makePrompt(p, for: question), forType: .string)
        withAnimation { copiedPrompt = p }
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
                ForEach(linkCandidates, id: \.uuid) { candidate in
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
        // 꼬리질문도 만든 시점(지금)을 찍어 타임블록에 바로 자리를 잡게 한다.
        let child = Question(text: text, timeMark: timeMarkString(), lecture: question.lecture)
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
