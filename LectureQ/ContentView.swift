import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 앱 글씨 크기 배율 (macOS는 dynamicTypeSize가 안 먹혀서 직접 배율 적용)

struct FontScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1.0 }
extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScaleKey.self] }
        set { self[FontScaleKey.self] = newValue }
    }
}

struct ScaledFont: ViewModifier {
    @Environment(\.fontScale) private var scale
    var base: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    func body(content: Content) -> some View {
        content.font(.system(size: base * scale, weight: weight, design: design))
    }
}

struct ScaledStyleFont: ViewModifier {
    @Environment(\.fontScale) private var scale
    var style: Font.TextStyle
    var weight: Font.Weight?
    var design: Font.Design = .default
    var mono: Bool = false

    static func base(_ s: Font.TextStyle) -> CGFloat {
        switch s {
        case .largeTitle: return 26
        case .title:      return 22
        case .title2:     return 17
        case .title3:     return 15
        case .headline:   return 13
        case .body:       return 13
        case .callout:    return 12
        case .subheadline:return 11
        case .footnote:   return 10
        case .caption:    return 10
        case .caption2:   return 10
        @unknown default: return 13
        }
    }

    func body(content: Content) -> some View {
        let w = weight ?? (style == .headline ? .semibold : .regular)
        var f = Font.system(size: Self.base(style) * scale, weight: w, design: design)
        if mono { f = f.monospacedDigit() }
        return content.font(f)
    }
}

extension View {
    /// 앱 글씨 크기 배율이 적용되는 폰트. base는 배율 1.0일 때 pt.
    func scaledFont(_ base: CGFloat, weight: Font.Weight = .regular,
                    design: Font.Design = .default) -> some View {
        modifier(ScaledFont(base: base, weight: weight, design: design))
    }

    /// 텍스트 스타일 기반 배율 폰트 (.body/.caption/.headline 등).
    func scaledFont(_ style: Font.TextStyle, weight: Font.Weight? = nil,
                    design: Font.Design = .default, monospacedDigit: Bool = false) -> some View {
        modifier(ScaledStyleFont(style: style, weight: weight, design: design, mono: monospacedDigit))
    }

    /// 앱 글씨 배율을 이 하위 트리에 적용한다.
    /// - fontScale: scaledFont(...)가 읽는 배율
    /// - 기본 폰트: 명시적 폰트가 없는 Text 도 배율에 맞게 커지도록 환경 기본 폰트를 배율만큼 키운다.
    func appFontScale(_ scale: CGFloat) -> some View {
        self.environment(\.fontScale, scale)
            .environment(\.font, .system(size: 13 * scale))
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query private var allQuestions: [Question]   // 그래프에서 uuid 로 질문을 찾기 위함

    @State private var selectedLecture: Lecture?
    @State private var selectedQuestion: Question?
    @State private var showQuickCapture = false
    @State private var showGraph = false
    @State private var showSummary = false
    @State private var showTimeline = false
    @State private var showState = false
    @State private var showUnresolvedOnly = false
    @State private var showImporter = false
    @State private var importError: String?

    // 마지막으로 보던 강의를 기억했다가 다음 실행 때 복원한다.
    @AppStorage("lastLectureUUID") private var lastLectureUUID = ""

    // 앱 내 글씨 크기 배율 (− aA + 로 조절, 기본 index 1 = 1.0배)
    @AppStorage("fontScaleIndex") private var fontScaleIndex = 1
    private let fontScales: [CGFloat] = [0.85, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0]
    private var fontScale: CGFloat {
        fontScales[min(max(fontScaleIndex, 0), fontScales.count - 1)]
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .appFontScale(fontScale)
        } content: {
            memoColumn
                .appFontScale(fontScale)
        } detail: {
            Group {
                if let q = selectedQuestion {
                    QuestionDetailView(question: q)
                        .id(q.uuid)
                } else {
                    ContentUnavailableView("질문을 선택하세요",
                                           systemImage: "questionmark.bubble",
                                           description: Text("⌘⇧N 으로 언제든 질문을 빠르게 남길 수 있어요"))
                }
            }
            .appFontScale(fontScale)
        }
        .appFontScale(fontScale)
        .sheet(isPresented: $showQuickCapture) {
            QuickCaptureView(lecture: selectedLecture ?? lectures.first)
                .appFontScale(fontScale)
        }
        .sheet(isPresented: $showGraph) {
            if let lecture = selectedLecture {
                GraphContainerView(lecture: lecture, onSelectQuestion: navigateToQuestion)
                    .frame(minWidth: 900, minHeight: 640)
                    .appFontScale(fontScale)
            }
        }
        .sheet(isPresented: $showSummary) {
            if let lecture = selectedLecture {
                LectureSummaryView(lecture: lecture)
                    .appFontScale(fontScale)
            }
        }
        .sheet(isPresented: $showTimeline) {
            TimelineView()
                .appFontScale(fontScale)
        }
        .sheet(isPresented: $showState) {
            if let lecture = selectedLecture {
                LectureStateView(lecture: lecture)
                    .appFontScale(fontScale)
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importContentTypes) { result in
            switch result {
            case .success(let url):
                do {
                    let lecture = try LectureMarkdownImporter.importFile(at: url, in: context)
                    selectedQuestion = nil
                    selectedLecture = lecture
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("가져오기 실패", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("확인", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .onAppear(perform: restoreSelection)
        .onChange(of: selectedLecture) { _, newValue in
            // 강의를 바꿀 때마다 기억해 둔다. (nil이면 지우지 않고 유지)
            if let lecture = newValue {
                lastLectureUUID = lecture.uuid.uuidString
                selectedQuestion = nil
                ensureBlocks(lecture)
                ensureCoverage(lecture)
            }
        }
        .onChange(of: coverageSignature) { _, _ in
            // 블록 밖(시점 초과) 질문이 생기면 블록을 자동 추가
            ensureCoverage(selectedLecture)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                lectureMenu
            }

            // 아이콘만 늘어놓으면 뭐가 뭔지 알기 어려워, 자주 쓰는 것만 남기고 나머지는 "보기" 메뉴로 묶는다.
            // (메뉴 안에서는 글자와 단축키가 함께 보인다)
            ToolbarItemGroup {
                Toggle(isOn: $showUnresolvedOnly) {
                    Label("미해결만", systemImage: "circle.dashed")
                }
                .help("미해결 질문만 보기")

                viewMenu

                Button {
                    showQuickCapture = true
                } label: {
                    Label("빠른 질문", systemImage: "plus.bubble")
                }
                .labelStyle(.titleAndIcon)   // 가장 자주 쓰는 동작이라 글자까지 노출
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .help("빠른 질문 입력 (⌘⇧N)")
            }
        }
    }

    /// 강의를 다르게 보는 화면들 + 글씨 크기를 한 곳에 모은 메뉴.
    private var viewMenu: some View {
        Menu {
            Button {
                showSummary = true
            } label: {
                Label("요약 — 질문·배운 점 한눈에", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(selectedLecture == nil)
            .keyboardShortcut("1", modifiers: .command)

            Button {
                showGraph = true
            } label: {
                Label("그래프 — 질문 관계도", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .disabled(selectedLecture == nil)
            .keyboardShortcut("2", modifiers: .command)

            Button {
                showTimeline = true
            } label: {
                Label("타임블록 — 시간순 블록 모아보기", systemImage: "calendar.day.timeline.left")
            }
            .keyboardShortcut("3", modifiers: .command)

            Button {
                showState = true
            } label: {
                Label("학습 상태 — 지금·목표·배우고 싶은 것", systemImage: "list.bullet.clipboard")
            }
            .disabled(selectedLecture == nil)
            .keyboardShortcut("4", modifiers: .command)

            Divider()

            Menu {
                Button {
                    fontScaleIndex = min(fontScales.count - 1, fontScaleIndex + 1)
                } label: {
                    Label("글씨 크게", systemImage: "plus.magnifyingglass")
                }
                .disabled(fontScaleIndex == fontScales.count - 1)
                .keyboardShortcut("+", modifiers: .command)

                Button {
                    fontScaleIndex = max(0, fontScaleIndex - 1)
                } label: {
                    Label("글씨 작게", systemImage: "minus.magnifyingglass")
                }
                .disabled(fontScaleIndex == 0)
                .keyboardShortcut("-", modifiers: .command)

                Button {
                    fontScaleIndex = 1
                } label: {
                    Label("기본 크기로", systemImage: "textformat.size")
                }
                .disabled(fontScaleIndex == 1)
                .keyboardShortcut("0", modifiers: .command)
            } label: {
                Label("글씨 크기 (\(Int(fontScale * 100))%)", systemImage: "textformat.size")
            }

            Divider()

            // 답을 찾으러 갈 때(= AI에게 물으러 갈 때) 바로 꺼내 볼 수 있게 메뉴에 둔다.
            if let guide = URL(string: "https://m1zz.github.io/LectureQ/ai-guide.html") {
                Link(destination: guide) {
                    Label("AI로 답 찾기 가이드", systemImage: "sparkles")
                }
            }
        } label: {
            Label("보기", systemImage: "square.grid.2x2")
        }
        .help("요약·그래프·타임블록·학습 상태·글씨 크기")
    }

    /// 가져오기 파일 선택창에서 허용할 타입 (.md, 일반 텍스트).
    private var importContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let md = UTType(filenameExtension: "md") { types.append(md) }
        if let markdown = UTType("net.daringfireball.markdown") { types.append(markdown) }
        return types
    }

    // MARK: Sidebar — 질문 리스트만 (강의 선택은 툴바 메뉴로 숨김)

    private var sidebar: some View {
        questionsPane
            .navigationSplitViewColumnWidth(min: 240, ideal: 300)
    }

    /// 툴바에 들어가는 강의 전환·추가·삭제 메뉴 (사이드바에서 숨긴 강의 선택 UI)
    private var lectureMenu: some View {
        Menu {
            // 선택 기준을 SwiftData 모델 객체가 아니라 안정적인 uuid 로 둔다.
            // (@Model 객체를 Picker 선택/태그로 쓰면 insert 직후 영구 ID 부여 시
            //  hash 가 바뀌어 SwiftUI Picker 내부 캐시가 깨지며 크래시가 남)
            Picker("강의 선택", selection: Binding<UUID?>(
                get: { selectedLecture?.uuid },
                set: { id in selectedLecture = lectures.first { $0.uuid == id } }
            )) {
                ForEach(lectures, id: \.uuid) { lecture in
                    Text(lecture.title).tag(lecture.uuid as UUID?)
                }
            }
            .pickerStyle(.inline)

            Divider()
            Button {
                addLectureQuick()
            } label: {
                Label("강의 추가", systemImage: "plus")
            }
            // 가져오기도 결국 "강의를 하나 만드는" 동작이라 이 메뉴에 둔다.
            Button {
                showImporter = true
            } label: {
                Label("마크다운에서 가져오기…", systemImage: "square.and.arrow.down")
            }
            if selectedLecture != nil {
                Button(role: .destructive) {
                    deleteCurrentLecture()
                } label: {
                    Label("현재 강의 삭제", systemImage: "trash")
                }
            }
        } label: {
            Label(selectedLecture?.title ?? "강의 선택", systemImage: "book")
        }
    }

    // MARK: 질문 리스트 (사이드바)

    @ViewBuilder
    private var questionsPane: some View {
        if let lecture = selectedLecture {
            let rows = orderedHierarchy(lecture)
                .filter { showUnresolvedOnly ? !$0.question.isResolved : true }

            // 선택·행 식별을 @Model(Question) 객체가 아니라 안정적인 uuid 로 둔다.
            // (@Model 객체를 List selection/tag/ForEach id 로 쓰면 insert·save 시점에 영구 ID가 부여되며
            //  hash 가 바뀌어 SwiftUI 내부 Dictionary 가 깨진다 — "Duplicate keys of type 'Question'" 크래시)
            List(selection: Binding<UUID?>(
                get: { selectedQuestion?.uuid },
                set: { id in
                    selectedQuestion = id.flatMap { uid in
                        lecture.questions.first { $0.uuid == uid }
                    }
                }
            )) {
                Section("질문") {
                    ForEach(rows, id: \.question.uuid) { row in
                        QuestionRow(question: row.question, depth: row.depth)
                            .tag(row.question.uuid as UUID?)
                            .contextMenu {
                                Button("삭제", role: .destructive) {
                                    if selectedQuestion?.uuid == row.question.uuid { selectedQuestion = nil }
                                    context.delete(row.question)
                                }
                            }
                    }

                    // 마지막 질문 아래에 질문 추가 버튼
                    Button {
                        showQuickCapture = true
                    } label: {
                        Label("질문 추가", systemImage: "plus.bubble.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .listRowSeparator(.hidden)
                }
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView("질문이 없어요",
                                           systemImage: "plus.bubble",
                                           description: Text("아래 ‘질문 추가’ 또는 ⌘⇧N 으로 남겨보세요"))
                }
            }
        } else {
            ContentUnavailableView("강의를 선택하세요", systemImage: "book")
        }
    }

    /// 그래프에서 "이동"한 질문으로 이동한다.
    /// 다른 강의의 질문이면 강의를 먼저 바꾼다. (강의 변경 onChange 가 selectedQuestion 을 nil 로
    /// 만들기 때문에, 질문 선택은 그 다음 런루프로 미뤄 클로버되지 않게 한다.)
    private func navigateToQuestion(_ id: UUID) {
        guard let q = allQuestions.first(where: { $0.uuid == id }) else { return }
        if let lecture = q.lecture, lecture.uuid != selectedLecture?.uuid {
            selectedLecture = lecture
        }
        DispatchQueue.main.async { selectedQuestion = q }
    }

    /// 앱을 켤 때: 마지막으로 보던 강의가 있으면 복원하고, 없으면 가장 상단(최신) 강의를 선택한다.
    private func restoreSelection() {
        guard selectedLecture == nil else { return }
        if !lastLectureUUID.isEmpty,
           let remembered = lectures.first(where: { $0.uuid.uuidString == lastLectureUUID }) {
            selectedLecture = remembered
        } else {
            selectedLecture = lectures.first   // 최신순 정렬이므로 first = 가장 상단
        }
    }

    /// 새 강의를 만들고(초기 블록 1개 포함) 바로 선택해 메인에 표시한다.
    private func addLectureQuick() {
        let lecture = Lecture(title: "새 강의")
        context.insert(lecture)
        let block = Block(startTime: .now)
        block.lecture = lecture
        context.insert(block)
        selectedLecture = lecture
        selectedQuestion = nil
    }

    private func deleteCurrentLecture() {
        guard let lecture = selectedLecture else { return }
        selectedLecture = nil
        context.delete(lecture)
    }

    /// 현재 강의에 새 블록을 지금 시각으로 추가한다.
    /// 직전(가장 최근 시작) 블록의 기간을 "지금까지"로 맞춰, 블록이 다음 블록 생성 전까지 이어지게 한다.
    private func addBlockToCurrent() {
        guard let lecture = selectedLecture else { return }
        let now = Date.now
        if let prev = lecture.blocks
            .filter({ $0.startTime <= now })
            .max(by: { $0.startTime < $1.startTime }) {
            let mins = Int((now.timeIntervalSince(prev.startTime) / 60).rounded())
            if mins >= 1 { prev.durationMinutes = mins }
        }
        let block = Block(startTime: now)
        block.lecture = lecture
        context.insert(block)
    }

    /// 블록을 지운다. 역관계를 먼저 끊어 강의의 blocks 배열에서 즉시 사라지게 하고,
    /// 그 강의의 자동 블록 생성을 꺼서 지운 블록이 커버리지 보정으로 되살아나지 않게 한다.
    private func deleteBlock(_ block: Block) {
        let lecture = block.lecture
        lecture?.autoBlockCoverage = false
        block.lecture = nil
        context.delete(block)
        try? context.save()
    }

    /// 강의에 블록이 하나도 없으면(신규/레거시) 레거시 메모·시간으로 초기 블록을 만든다.
    /// 단, 사용자가 블록을 직접 지운 강의(autoBlockCoverage == false)는 건드리지 않는다.
    private func ensureBlocks(_ lecture: Lecture?) {
        guard let lecture, lecture.blocks.isEmpty, lecture.autoBlockCoverage else { return }
        let block = Block(startTime: lecture.startTime,
                          durationMinutes: lecture.durationMinutes,
                          notes: lecture.notes)
        block.lecture = lecture
        context.insert(block)
    }

    /// 유효 시각(timeMark 또는 작성시각)이 어느 블록에도 안 드는 질문이 있으면,
    /// 그 시각을 담는 작은 블록을(이웃 블록과 겹치지 않게) 만든다. 한 번에 하나씩.
    /// 사용자가 블록을 직접 지운 강의에서는 동작하지 않는다(지운 블록이 되살아나는 것을 막는다).
    private func ensureCoverage(_ lecture: Lecture?) {
        guard let lecture, lecture.autoBlockCoverage else { return }
        let blocks = lecture.blocks.sorted { $0.startTime < $1.startTime }
        guard let first = blocks.first else { return }

        func covered(_ q: Question) -> Bool {
            blocks.contains { b in
                let d = questionTime(q, onDay: b.startTime)
                return d >= b.startTime && d <= b.endTime
            }
        }

        for q in lecture.questions where !covered(q) {
            let qd = questionTime(q, onDay: first.startTime)

            // qd 주변에 기본 ±30분 창을 잡되, 이웃 블록과 겹치지 않게 자른다.
            let prevEnd = blocks.filter { $0.endTime <= qd }.map(\.endTime).max()
            let nextStart = blocks.filter { $0.startTime >= qd }.map(\.startTime).min()

            var start = qd.addingTimeInterval(-30 * 60)
            var end = qd.addingTimeInterval(30 * 60)
            if let p = prevEnd, start < p { start = p }
            if let n = nextStart, end > n { end = n }
            if start > qd { start = qd }
            if end < qd.addingTimeInterval(60) { end = qd.addingTimeInterval(60) }

            let minutes = max(5, Int(ceil(end.timeIntervalSince(start) / 60.0)))
            let block = Block(startTime: start, durationMinutes: minutes)
            block.lecture = lecture
            context.insert(block)
            return   // 하나만 추가하고 종료 (서명 변화로 재호출됨)
        }
    }

    /// 블록 커버리지 재계산 트리거용 서명 (질문·timeMark·블록 구성이 바뀌면 갱신)
    private var coverageSignature: String {
        guard let l = selectedLecture else { return "" }
        let marks = l.questions.map(\.timeMark).joined(separator: ",")
        let blockSig = l.blocks
            .sorted { $0.startTime < $1.startTime }
            .map { "\(Int($0.startTime.timeIntervalSince1970))-\($0.durationMinutes)" }
            .joined(separator: ";")
        return "\(l.uuid.uuidString)|\(l.questions.count)|\(marks)|\(blockSig)"
    }

    // MARK: 가운데 열 — 강의 제목 + 블록들(타임블록/메모)

    @ViewBuilder
    private var memoColumn: some View {
        if let lecture = selectedLecture {
            let blocks = lecture.blocks.sorted { $0.startTime < $1.startTime }
            let markers = computeBlockMarkers(for: lecture)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("강의 이름", text: Bindable(lecture).title)
                        .textFieldStyle(.plain)
                        .scaledFont(22, weight: .bold)
                        .padding(.leading, 4)

                    ForEach(blocks, id: \.uuid) { block in
                        BlockView(block: block,
                                  markers: markers[block.uuid] ?? [],
                                  onSelectQuestion: { selectedQuestion = $0 },
                                  onDelete: { deleteBlock(block) })
                            .contextMenu {
                                Button("블록 삭제", role: .destructive) {
                                    deleteBlock(block)
                                }
                            }
                    }

                    // 마지막 블록 아래에서 새 블록 추가
                    Button(action: addBlockToCurrent) {
                        Label("블록 추가", systemImage: "plus")
                            .scaledFont(.callout, weight: .medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(.tertiary)
                    )
                    .padding(.leading, 66)
                }
                .padding(16)
            }
            .navigationTitle(lecture.title)
            .navigationSplitViewColumnWidth(min: 340, ideal: 440)
        } else {
            ContentUnavailableView("강의를 선택하세요", systemImage: "book")
        }
    }

    /// 강의의 질문을 원질문 → 꼬리질문 순서로 펼쳐, 각 행의 들여쓰기 깊이와 함께 돌려준다.
    private func orderedHierarchy(_ lecture: Lecture) -> [(question: Question, depth: Int)] {
        let all = lecture.questions
        var result: [(question: Question, depth: Int)] = []
        var visited = Set<UUID>()

        func dfs(_ q: Question, _ depth: Int) {
            guard visited.insert(q.uuid).inserted else { return }
            result.append((q, depth))
            for child in q.related.sorted(by: { $0.createdAt < $1.createdAt }) {
                dfs(child, depth + 1)
            }
        }

        // 부모가 없는 질문을 루트로 시작
        let roots = all.filter { $0.linkedFrom.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
        for root in roots { dfs(root, 0) }

        // 순환 등으로 아직 안 들른 질문은 루트로 취급해 마저 표시
        for q in all.sorted(by: { $0.createdAt < $1.createdAt }) where !visited.contains(q.uuid) {
            dfs(q, 0)
        }
        return result
    }
}

struct QuestionRow: View {
    @Bindable var question: Question
    var depth: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .scaledFont(.caption)
                    .foregroundStyle(.teal)
            }

            Button {
                question.isResolved.toggle()
            } label: {
                Image(systemName: question.isResolved ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(question.isResolved ? .green : .orange)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    if depth > 0 {
                        Text("꼬리")
                            .scaledFont(.caption2, weight: .bold)
                            .foregroundStyle(.teal)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.teal.opacity(0.18), in: Capsule())
                    }
                    Text(question.text)
                        .scaledFont(13)
                        .lineLimit(2)
                        .strikethrough(question.isResolved, color: .secondary)
                }
                HStack(spacing: 6) {
                    Label(question.createdAt.formatted(date: .numeric, time: .shortened),
                          systemImage: "calendar")
                    if !question.timeMark.isEmpty {
                        Label(question.timeMark, systemImage: "clock")
                    }
                    if !question.allRelated.isEmpty {
                        Label("\(question.allRelated.count)", systemImage: "link")
                    }
                }
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .padding(.leading, CGFloat(depth) * 18)
    }
}
