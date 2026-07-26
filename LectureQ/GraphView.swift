import SwiftUI
import SwiftData

// MARK: - Graph container (fetches data, hosts the simulation)

struct GraphContainerView: View {
    @Environment(\.dismiss) private var dismiss

    /// 그래프는 이 강의 하나만(그 강의의 질문들) 보여준다.
    let lecture: Lecture

    /// 노드에서 "이동"을 누르면 해당 질문 uuid 를 상위(ContentView)로 전달한다.
    var onSelectQuestion: (UUID) -> Void = { _ in }

    @StateObject private var model = GraphModel()
    @State private var magnifyBase: CGFloat = 1   // 핀치 줌 기준 배율

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("질문 그래프", systemImage: "point.3.connected.trianglepath.dotted")
                    .scaledFont(.headline)
                Text(lecture.title)
                    .scaledFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                legend
                zoomControls
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)

            Divider()

            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    GraphCanvas(model: model, viewport: geo.size,
                                onSelect: { id in
                                    onSelectQuestion(id)
                                    dismiss()
                                })
                }
                .background(Color(nsColor: .textBackgroundColor))
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            model.setScale(magnifyBase * value.magnification)
                        }
                        .onEnded { _ in magnifyBase = model.scale }
                )
                .onAppear {
                    model.canvasSize = geo.size
                    model.sync(lectures: [lecture], questions: lecture.questions)
                    model.fitToScreen()
                    magnifyBase = model.scale
                }
                .onChange(of: geo.size) { _, newSize in
                    model.canvasSize = newSize   // fit 계산·가운데 정렬 기준 갱신
                }
                .onDisappear { model.stop() }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button { model.zoom(by: 1 / 1.2) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("축소")

            Button {
                model.fitToScreen()
                magnifyBase = model.scale
            } label: {
                Text("\(Int((model.scale * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 42)
            }
            .help("화면에 맞추기")

            Button { model.zoom(by: 1.2) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("확대")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .scaledFont(.caption)
        .padding(.trailing, 8)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendDot(.blue, "강의")
            legendDot(.orange, "미해결")
            legendDot(.green, "해결")
            // 꽉 찬 원 = 답 내용 있음 / 빈 원 = 질문만
            HStack(spacing: 4) {
                Circle().fill(Color.secondary).frame(width: 9, height: 9)
                Text("답 있음").foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle().strokeBorder(Color.secondary, lineWidth: 2).frame(width: 9, height: 9)
                Text("질문만").foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .foregroundStyle(.teal)
                Text("꼬리질문").foregroundStyle(.secondary)
            }
        }
        .scaledFont(.caption)
        .padding(.trailing, 8)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Node / edge data

struct GraphNode: Identifiable {
    enum Kind {
        case lecture
        case question(resolved: Bool, hasContent: Bool)
    }
    let id: UUID
    var label: String
    var kind: Kind

    var color: Color {
        switch kind {
        case .lecture: return .blue
        case .question(let resolved, _): return resolved ? .green : .orange
        }
    }

    var isQuestion: Bool {
        if case .question = kind { return true }
        return false
    }

    /// 답 내용이 있으면 꽉 찬 원, 없으면(질문만) 빈 원(테두리)으로 그린다.
    var isFilled: Bool {
        switch kind {
        case .lecture: return true
        case .question(_, let hasContent): return hasContent
        }
    }

    var radius: CGFloat {
        switch kind {
        case .lecture: return 26
        case .question: return 16
        }
    }
}

// MARK: - Tree layout model

struct GraphEdge {
    let from: UUID
    let to: UUID
    var directed: Bool   // true면 from(원질문) → to(꼬리질문) 방향 화살표를 그린다
}

@MainActor
final class GraphModel: ObservableObject {
    @Published var positions: [UUID: CGPoint] = [:]
    @Published var contentSize: CGSize = .zero   // 그래프 전체(줌 1.0 기준) 크기
    @Published var scale: CGFloat = 1            // 화면 배율 (fit/줌)
    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []
    var canvasSize: CGSize = CGSize(width: 800, height: 600)

    private let minScale: CGFloat = 0.2
    private let maxScale: CGFloat = 2.5

    // 트리 자식 관계: 강의 → 최상위 질문, 질문 → 꼬리질문
    private var childMap: [UUID: [UUID]] = [:]
    private var rootOrder: [UUID] = []   // 강의(루트) 순서

    // 레이아웃 상수
    private let levelHeight: CGFloat = 130
    private let leafSpacing: CGFloat = 110
    private let topMargin: CGFloat = 70

    func sync(lectures: [Lecture], questions: [Question]) {
        nodes = []
        edges = []
        childMap = [:]
        rootOrder = lectures.map(\.uuid)

        for lecture in lectures {
            nodes.append(GraphNode(id: lecture.uuid, label: lecture.title, kind: .lecture))
            // 강의의 자식 = 부모 질문이 없는(최상위) 질문
            let tops = lecture.questions
                .filter { $0.linkedFrom.isEmpty }
                .sorted { $0.createdAt < $1.createdAt }
            childMap[lecture.uuid] = tops.map(\.uuid)
        }
        for q in questions {
            let hasContent = !q.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            nodes.append(GraphNode(id: q.uuid,
                                   label: q.text,
                                   kind: .question(resolved: q.isResolved,
                                                   hasContent: hasContent)))
            // 강의에는 최상위(부모 없는) 질문만 직접 연결한다.
            // 꼬리질문은 강의와의 직접 관계를 끊고 원질문(부모)에만 이어진다.
            if let lecture = q.lecture, q.linkedFrom.isEmpty {
                edges.append(GraphEdge(from: lecture.uuid, to: q.uuid, directed: false))
            }
            // 질문의 자식 = 꼬리질문
            let kids = q.related.sorted { $0.createdAt < $1.createdAt }
            childMap[q.uuid] = kids.map(\.uuid)
            for rel in kids {
                edges.append(GraphEdge(from: q.uuid, to: rel.uuid, directed: true))
            }
        }

        layoutTree()
        fitToScreen()
    }

    func relayout() { layoutTree() }
    func start() { layoutTree() }   // 시뮬레이션 없음 — 진입 시 한 번 배치
    func stop() {}

    /// 그래프 전체가 캔버스에 들어오도록 배율을 맞춘다(작으면 확대하진 않음).
    func fitToScreen() {
        guard contentSize.width > 0, contentSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else { return }
        let s = min(canvasSize.width / contentSize.width,
                    canvasSize.height / contentSize.height)
        scale = min(1, max(minScale, s))
    }

    func zoom(by factor: CGFloat) { setScale(scale * factor) }
    func setScale(_ s: CGFloat) { scale = min(maxScale, max(minScale, s)) }

    /// 위에서 아래로 내려가는 트리 배치. 강의가 맨 위 루트.
    func layoutTree() {
        guard !nodes.isEmpty else { return }

        var placed = Set<UUID>()
        var xPos: [UUID: CGFloat] = [:]
        var yPos: [UUID: CGFloat] = [:]
        var nextLeafX: CGFloat = 0

        func place(_ id: UUID, _ depth: Int) -> CGFloat {
            if placed.contains(id) { return xPos[id] ?? 0 }   // 순환/공유 자식 방지
            placed.insert(id)
            yPos[id] = topMargin + CGFloat(depth) * levelHeight

            let kids = (childMap[id] ?? []).filter { !placed.contains($0) }
            let x: CGFloat
            if kids.isEmpty {
                x = nextLeafX
                nextLeafX += leafSpacing
            } else {
                let childXs = kids.map { place($0, depth + 1) }
                x = (childXs.min()! + childXs.max()!) / 2
            }
            xPos[id] = x
            return x
        }

        // 강의(루트)부터 배치 → 여러 강의는 나란히 놓인 숲(forest) 형태
        for root in rootOrder { _ = place(root, 0) }
        // 강의에 속하지 않은 고아 질문 등은 루트로 취급해 마저 배치
        for node in nodes where !placed.contains(node.id) { _ = place(node.id, 0) }

        // 자연 좌표로 정규화(왼쪽 여백 확보) + 전체 콘텐츠 크기 계산.
        // 캔버스에 억지로 맞추지 않고, 실제 크기를 재서 fit/줌/스크롤이 처리하게 한다.
        let xs = xPos.values
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let maxY = yPos.values.max() ?? topMargin
        let sideMargin: CGFloat = 90
        let offsetX = sideMargin - minX

        var newPositions: [UUID: CGPoint] = [:]
        for node in nodes {
            let x = (xPos[node.id] ?? 0) + offsetX
            let y = yPos[node.id] ?? topMargin
            newPositions[node.id] = CGPoint(x: x, y: y)
        }
        positions = newPositions
        contentSize = CGSize(width: (maxX - minX) + sideMargin * 2,
                             height: maxY + 130)
    }

    func beginDrag(_ id: UUID, to point: CGPoint) {
        positions[id] = point
    }

    func endDrag(_ id: UUID) {}
}

// MARK: - Canvas rendering + drag

struct GraphCanvas: View {
    @ObservedObject var model: GraphModel
    var viewport: CGSize = .zero
    var onSelect: (UUID) -> Void = { _ in }
    @State private var hoveredID: UUID?
    @State private var tappedID: UUID?      // 이동 팝오버를 띄운 질문 노드

    var body: some View {
        let content = model.contentSize
        let scale = model.scale
        graph
            .frame(width: max(content.width, 1),
                   height: max(content.height, 1),
                   alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
            // 스크롤뷰가 배율 적용된 실제 크기를 알도록 다시 프레임을 준다.
            .frame(width: max(content.width * scale, 1),
                   height: max(content.height * scale, 1),
                   alignment: .topLeading)
            // 콘텐츠가 뷰포트보다 작으면 가운데 정렬(스크롤 없이 중앙에), 크면 스크롤.
            .frame(minWidth: viewport.width, minHeight: viewport.height,
                   alignment: .center)
    }

    private var graph: some View {
        ZStack(alignment: .topLeading) {
            // Edges
            Canvas { ctx, _ in
                for edge in model.edges {
                    guard let pa = model.positions[edge.from],
                          let pb = model.positions[edge.to] else { continue }

                    if edge.directed {
                        // 원질문 → 꼬리질문: 색이 있는 화살표
                        let color = Color.teal.opacity(0.7)
                        // 자식 노드 테두리 앞에서 화살표가 끝나도록 약간 당긴다
                        let dx = pb.x - pa.x, dy = pb.y - pa.y
                        let len = max(sqrt(dx * dx + dy * dy), 1)
                        let ux = dx / len, uy = dy / len
                        let tip = CGPoint(x: pb.x - ux * 18, y: pb.y - uy * 18)

                        var line = Path()
                        line.move(to: pa)
                        line.addLine(to: tip)
                        ctx.stroke(line, with: .color(color), lineWidth: 1.6)

                        // 화살촉
                        let head: CGFloat = 8
                        let left = CGPoint(x: tip.x - ux * head - uy * head * 0.6,
                                           y: tip.y - uy * head + ux * head * 0.6)
                        let right = CGPoint(x: tip.x - ux * head + uy * head * 0.6,
                                            y: tip.y - uy * head - ux * head * 0.6)
                        var arrow = Path()
                        arrow.move(to: tip)
                        arrow.addLine(to: left)
                        arrow.addLine(to: right)
                        arrow.closeSubpath()
                        ctx.fill(arrow, with: .color(color))
                    } else {
                        // 강의 — 질문: 방향 없는 옅은 선
                        var path = Path()
                        path.move(to: pa)
                        path.addLine(to: pb)
                        ctx.stroke(path, with: .color(.secondary.opacity(0.35)), lineWidth: 1.2)
                    }
                }
            }
            .allowsHitTesting(false)

            // Nodes
            ForEach(model.nodes) { node in
                if let pos = model.positions[node.id] {
                    nodeView(node)
                        .popover(isPresented: Binding(
                            get: { tappedID == node.id },
                            set: { if !$0 { tappedID = nil } }
                        ), arrowEdge: .top) {
                            nodeActionPopover(node)
                        }
                        .position(pos)
                        .gesture(
                            // minimumDistance 0 으로 탭도 받되, 이동량이 작으면 탭으로 처리
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if dragDistance(value) > 6 {
                                        model.beginDrag(node.id, to: value.location)
                                    }
                                }
                                .onEnded { value in
                                    if dragDistance(value) <= 6 {
                                        // 탭: 질문 노드면 이동 팝오버, 강의 노드는 무시
                                        tappedID = node.isQuestion ? node.id : nil
                                    }
                                    model.endDrag(node.id)
                                }
                        )
                        .onHover { hovering in
                            hoveredID = hovering ? node.id : (hoveredID == node.id ? nil : hoveredID)
                        }
                }
            }
        }
    }

    private func dragDistance(_ value: DragGesture.Value) -> CGFloat {
        hypot(value.translation.width, value.translation.height)
    }

    /// 노드를 탭했을 때 뜨는 "이 질문으로 이동" 팝오버.
    private func nodeActionPopover(_ node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(node.label)
                .scaledFont(.callout, weight: .semibold)
                .lineLimit(4)
                .frame(maxWidth: 260, alignment: .leading)

            HStack {
                Button("닫기") { tappedID = nil }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    let id = node.id
                    tappedID = nil
                    onSelect(id)
                } label: {
                    Label("이 질문으로 이동", systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func nodeView(_ node: GraphNode) -> some View {
        let isHovered = hoveredID == node.id
        return VStack(spacing: 3) {
            Group {
                if node.isFilled {
                    // 답 내용 있음: 꽉 찬 원
                    Circle()
                        .fill(node.color.gradient)
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                } else {
                    // 질문만(답 없음): 빈 원 — 옅게 채우고 색 테두리만
                    Circle()
                        .fill(node.color.opacity(0.12))
                        .overlay(Circle().strokeBorder(node.color, lineWidth: 2.5))
                }
            }
            .frame(width: node.radius * 2, height: node.radius * 2)
            .shadow(color: node.color.opacity(isHovered ? 0.6 : 0.25),
                    radius: isHovered ? 10 : 4)

            Text(node.label)
                .scaledFont(.caption2)
                .lineLimit(isHovered ? 4 : 1)
                .frame(maxWidth: isHovered ? 220 : 110)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
        }
        .scaleEffect(isHovered ? 1.08 : 1)
        .animation(.snappy(duration: 0.15), value: isHovered)
    }
}
