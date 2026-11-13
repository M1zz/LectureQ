import AppIntents
import Combine
import CoreSpotlight
import SwiftData

/// 단축어·Spotlight·Siri 에서 들어온 요청을 화면(ContentView)에 넘기는 다리.
/// 앱이 꺼져 있다가 단축어로 켜져도, ContentView 가 구독하는 순간 현재 값을 받아 처리한다.
@MainActor
final class CaptureRequest: ObservableObject {
    static let shared = CaptureRequest()
    /// "질문 추가" — 입력창을 연다.
    @Published var isPending = false
    /// Spotlight · Siri 에서 고른 질문 — 그 강의와 질문을 연다.
    @Published var openQuestionID: UUID?
}

/// 질문 입력창을 바로 연다 — 앱에서 ⌘⇧N 을 누른 것과 같다.
struct AddQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "질문 추가"
    static let description = IntentDescription("질문 노트를 열고 지금 보고 있는 강의에 질문을 적는 창을 띄웁니다.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRequest.shared.isPending = true
        return .result()
    }
}

// MARK: - 질문을 Siri · Spotlight 가 찾게

/// 적어 둔 질문 하나. 질문 · 답 · 강의 이름으로 찾고, Spotlight 에 싣는다(macOS 15+). 누르면 그 질문이 열린다.
struct QuestionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("질문", comment: "Siri/Spotlight: one question noted during a lecture")
    )
    static let defaultQuery = QuestionQuery()

    let id: UUID
    let text: String
    let answer: String
    let lectureTitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(String(text.prefix(80)))", subtitle: "\(lectureTitle)")
    }

    init(_ question: Question) {
        id = question.uuid
        text = question.text
        answer = question.answer
        lectureTitle = question.lecture?.title ?? ""
    }
}

@available(macOS 15.0, iOS 18.0, *)
extension QuestionEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.textContent = [text, answer].filter { !$0.isEmpty }.joined(separator: "\n")
        set.keywords = lectureTitle.isEmpty ? [] : [lectureTitle]
        return set
    }
}

struct QuestionQuery: EntityStringQuery {
    @Dependency private var container: ModelContainer

    func entities(for identifiers: [UUID]) async throws -> [QuestionEntity] {
        let wanted = Set(identifiers)
        return QuestionLibrary.questions(in: container).filter { wanted.contains($0.uuid) }.map(QuestionEntity.init)
    }

    func entities(matching string: String) async throws -> [QuestionEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return QuestionLibrary.questions(in: container).map(QuestionEntity.init).filter {
            [$0.text, $0.answer, $0.lectureTitle].contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    /// 최근에 적은 질문부터.
    func suggestedEntities() async throws -> [QuestionEntity] {
        QuestionLibrary.questions(in: container).prefix(20).map(QuestionEntity.init)
    }
}

/// 질문을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenQuestionIntent: OpenIntent {
    static let title = LocalizedStringResource("질문 열기", comment: "Siri/Spotlight: open a saved question")
    static let description = IntentDescription(
        LocalizedStringResource("고른 질문을 그 강의와 함께 앱에서 엽니다.", comment: "Siri: open question description")
    )

    @Parameter(title: LocalizedStringResource("질문", comment: "Siri: question parameter"),
               description: LocalizedStringResource("열 질문. 질문이나 답, 강의 이름으로 찾습니다.", comment: "Siri: question parameter description"))
    var target: QuestionEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRequest.shared.openQuestionID = target.id
        return .result()
    }
}

enum QuestionLibrary {
    /// 적어 둔 질문, 최근 것부터. 빈 질문은 뺀다.
    static func questions(in container: ModelContainer) -> [Question] {
        let descriptor = FetchDescriptor<Question>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? ModelContext(container).fetch(descriptor)) ?? []).filter { !$0.text.isEmpty }
    }

    /// Spotlight 에 싣는 질문을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: QuestionEntity.self)
        try? await index.indexAppEntities(questions(in: container).map(QuestionEntity.init))
    }
}

// MARK: - Siri 문구

struct LectureQShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuestionIntent(),
            phrases: [
                "\(.applicationName)에 질문 추가",
                "\(.applicationName)에서 질문 적기",
                "\(.applicationName) 질문 추가"
            ],
            shortTitle: "질문 추가",
            systemImageName: "questionmark.bubble"
        )
    }
}
