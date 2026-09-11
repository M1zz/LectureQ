import SwiftUI
import SwiftData
import AppKit

struct QuestionDetailView: View {
    @Bindable var question: Question
    @Environment(\.modelContext) private var context

    @State private var newFollowUp = ""
    @State private var copiedPrompt: AIPrompt?   // 방금 복사한 단계 (확인 표시용)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statusRow

                VStack(alignment: .leading, spacing: 6) {
                    // 이 질문이 파생된 원질문 (있을 때만)
                    ForEach(question.linkedFrom, id: \.uuid) { parent in
                        HStack(spacing: 6) {
                            Text("원질문")
                                .foregroundStyle(.tertiary)
                            Text(parent.text)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            unlinkButton(parent)
                        }
                        .scaledFont(.callout)
                    }

                    TextField("질문", text: $question.text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .scaledFont(22, weight: .medium)
                        .lineLimit(1...6)
                }

                answerSection
                followUpSection

                Text("작성 \(question.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .scaledFont(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    // MARK: 상태 · 시점

    private var statusRow: some View {
        HStack(spacing: 16) {
            Toggle("해결됨", isOn: $question.isResolved)
            // 요약의 "배운 점"은 해결됨 + 이 토글이 켜진 것만 모은다. 해결 전에는 의미가 없어 숨긴다.
            if question.isResolved {
                Toggle("배운 점에 포함", isOn: $question.isLearned)
                    .help("요약의 ‘배운 점’ 목록에 넣을지 선택")
            }
            Spacer()
            // 강의 시점 — 타임블록에서 이 질문의 위치를 정한다.
            HStack(spacing: 6) {
                Text("시점")
                    .foregroundStyle(.secondary)
                TextField("HH:mm", text: $question.timeMark)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .help("강의 시점 (24시간 HH:mm)")
                Button("지금") { question.timeMark = timeMarkString() }
                    .buttonStyle(.link)
            }
        }
        .toggleStyle(.checkbox)
    }

    // MARK: 답 + AI 프롬프트

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("답")
                Spacer()
                if let copied = copiedPrompt {
                    Text("\(copied.title) 복사됨")
                        .scaledFont(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
                aiMenu
            }

            TextEditor(text: $question.answer)
                .scaledFont(13)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if question.answer.isEmpty {
                        Text("내 말로 정리해 적어보세요")
                            .scaledFont(13)
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 13)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    /// 앱에 이미 적힌 맥락(강의·그 시점 메모·학습 상태·원질문)을 채운 프롬프트를 복사한다.
    /// 단계 순서는 docs/ai-guide.html 의 5단계와 같다.
    private var aiMenu: some View {
        Menu("AI 프롬프트 복사") {
            ForEach(AIPrompt.allCases) { p in
                Button(p.title) { copy(p) }
                    .disabled(p.unavailableReason(for: question) != nil)
            }
            Divider()
            if let guide = URL(string: "https://m1zz.github.io/LectureQ/ai-guide.html") {
                Link("가이드 열기", destination: guide)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("강의 맥락을 채운 프롬프트를 클립보드에 복사합니다")
    }

    /// 프롬프트를 클립보드에 넣고, 어떤 단계를 복사했는지 잠깐 보여준다.
    private func copy(_ p: AIPrompt) {
        guard p.unavailableReason(for: question) == nil else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(makePrompt(p, for: question), forType: .string)
        withAnimation { copiedPrompt = p }
    }

    // MARK: 꼬리질문

    private var followUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("꼬리질문")

            ForEach(question.related, id: \.uuid) { child in
                HStack {
                    Text(child.text)
                        .foregroundStyle(child.isResolved ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    unlinkButton(child)
                }
            }

            TextField("새 꼬리질문 — Return으로 추가", text: $newFollowUp)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addFollowUp)

            linkMenu
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

    private var linkMenu: some View {
        Menu("기존 질문을 꼬리질문으로 연결") {
            ForEach(linkCandidates, id: \.uuid) { candidate in
                Button(candidate.text) {
                    question.related.append(candidate)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(linkCandidates.isEmpty)
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

    private func unlinkButton(_ other: Question) -> some View {
        Button("해제") { unlink(other) }
            .buttonStyle(.borderless)
            .scaledFont(.caption)
            .foregroundStyle(.secondary)
            .help("연결 해제 (질문은 지워지지 않아요)")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .scaledFont(.caption, weight: .semibold)
            .foregroundStyle(.secondary)
    }
}
