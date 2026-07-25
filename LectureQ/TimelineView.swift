import SwiftUI
import SwiftData
import AppKit

// MARK: - 질문 마커 계산 (여러 블록에 걸쳐 강의 질문을 시점순으로 배치)

struct QMarker: Identifiable {
    let q: Question
    let frac: CGFloat      // 해당 블록 안에서의 세로 위치 0~1
    var id: UUID { q.uuid }
}

/// 강의의 질문들을 각 블록의 실제 시각 범위[start,end]에 매핑해 블록별 마커 목록을 만든다.
/// timeMark 는 벽시계 시각(예 "12:00")으로 해석한다.
func computeBlockMarkers(for lecture: Lecture) -> [UUID: [QMarker]] {
    let blocks = lecture.blocks.sorted { $0.startTime < $1.startTime }
    guard !blocks.isEmpty else { return [:] }

    var result: [UUID: [QMarker]] = [:]
    for b in blocks { result[b.uuid] = [] }

    let qs = lecture.questions.sorted { $0.createdAt < $1.createdAt }
    for q in qs {
        var placed = false
        for b in blocks {
            let span = b.endTime.timeIntervalSince(b.startTime)
            guard span > 0 else { continue }
            let d = questionTime(q, onDay: b.startTime)
            if d >= b.startTime, d <= b.endTime {
                let frac = CGFloat(d.timeIntervalSince(b.startTime) / span)
                result[b.uuid, default: []].append(QMarker(q: q, frac: min(1, max(0, frac))))
                placed = true
                break
            }
        }
        if !placed, let last = blocks.last {
            // 어느 블록에도 안 들면 마지막 블록 끝자락에 (커버리지 자동추가 전 임시)
            result[last.uuid, default: []].append(QMarker(q: q, frac: 1))
        }
    }
    return result
}

/// 질문의 유효 시각: timeMark(시:분)이 파싱되면 그 날(day)의 시각, 아니면 작성 시각(createdAt).
func questionTime(_ q: Question, onDay day: Date) -> Date {
    clockDate(on: day, timeMark: q.timeMark) ?? q.createdAt
}

/// "HH:MM" 또는 "HH:MM:SS" → (시, 분, 초). 실패 시 nil.
func parseClock(_ s: String) -> (h: Int, m: Int, s: Int)? {
    let parts = s.split(separator: ":").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count >= 2, parts.allSatisfy({ Int($0) != nil }) else { return nil }
    let n = parts.compactMap { Int($0) }
    if n.count == 2 { return (n[0], n[1], 0) }
    if n.count == 3 { return (n[0], n[1], n[2]) }
    return nil
}

/// 기준 날짜(day)의 연·월·일에 timeMark 의 시:분:초를 합쳐 Date 를 만든다.
func clockDate(on day: Date, timeMark: String) -> Date? {
    guard let t = parseClock(timeMark) else { return nil }
    let cal = Calendar.current
    var dc = cal.dateComponents([.year, .month, .day], from: day)
    dc.hour = t.h; dc.minute = t.m; dc.second = t.s
    return cal.date(from: dc)
}

// MARK: - 전체 타임라인 (모든 강의의 블록을 시간순으로)

struct TimelineView: View {
    @Query(sort: \Block.startTime) private var blocks: [Block]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("타임블록", systemImage: "calendar.day.timeline.left")
                    .scaledFont(.headline)
                Spacer()
                Button("닫기") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)
            Divider()

            if blocks.isEmpty {
                ContentUnavailableView("블록이 없어요",
                                       systemImage: "calendar.badge.plus",
                                       description: Text("메인 화면에서 ‘블록 추가’로 만들면 여기 모여요"))
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(blocks) { block in
                            VStack(alignment: .leading, spacing: 4) {
                                if let title = block.lecture?.title, !title.isEmpty {
                                    Text(title)
                                        .scaledFont(.caption, weight: .semibold)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 66)
                                }
                                BlockView(block: block, markers: markers(for: block))
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
    }

    private func markers(for block: Block) -> [QMarker] {
        guard let lecture = block.lecture else { return [] }
        return computeBlockMarkers(for: lecture)[block.uuid] ?? []
    }
}

// MARK: - 단일 블록 뷰: 왼쪽 시간 게이지(질문 점) + 오른쪽 카드(시간·메모)

struct BlockView: View {
    @Bindable var block: Block
    var markers: [QMarker] = []
    /// true면 소요시간 비례 고정 높이 대신 주어진 공간을 가득 채운다.
    var fillsHeight: Bool = false
    /// 질문 점을 눌렀을 때 호출 (질문 상세로 이동). nil이면 점은 표시만 됨.
    var onSelectQuestion: ((Question) -> Void)? = nil

    @State private var showSettings = false
    private let durationOptions = [15, 30, 45, 60, 75, 90, 120, 150, 180]

    private var blockHeight: CGFloat {
        max(260, min(460, CGFloat(block.durationMinutes) * 1.6))
    }

    private var hue: Double {
        if block.colorHue >= 0 { return block.colorHue }
        let bytes = withUnsafeBytes(of: block.uuid.uuid) { Array($0) }
        return Double(bytes.first ?? 0) / 255.0
    }

    private var accent: Color {
        Color(hue: hue, saturation: 0.62, brightness: 0.9)
    }

    /// ColorPicker 바인딩: 고른 색의 hue만 저장(채도·명도는 앱 톤으로 통일).
    private var colorBinding: Binding<Color> {
        Binding(
            get: { accent },
            set: { newColor in
                let ns = NSColor(newColor).usingColorSpace(.deviceRGB) ?? NSColor(newColor)
                block.colorHue = Double(ns.hueComponent)
            }
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            timeGutter
            card
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("블록 설정").scaledFont(.headline)

            HStack {
                Label("색상", systemImage: "paintpalette")
                Spacer()
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            HStack {
                Label("시작", systemImage: "clock")
                Spacer()
                DatePicker("", selection: $block.startTime,
                           displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            HStack {
                Label("기간", systemImage: "timer")
                Spacer()
                Menu("\(block.durationMinutes)분") {
                    ForEach(durationOptions, id: \.self) { m in
                        Button("\(m)분") { block.durationMinutes = m }
                    }
                }
                .fixedSize()
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var timeGutter: some View {
        VStack(spacing: 2) {
            Text(block.startTime.formatted(date: .omitted, time: .shortened))
                .scaledFont(.caption, weight: .semibold, monospacedDigit: true)

            GeometryReader { geo in
                ZStack {
                    Rectangle()
                        .fill(accent.opacity(0.5))
                        .frame(width: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ForEach(laidOut(markers, height: geo.size.height)) { item in
                        Button {
                            onSelectQuestion?(item.q)
                        } label: {
                            questionDot(item.q)
                        }
                        .buttonStyle(QDotButtonStyle())
                        .disabled(onSelectQuestion == nil)
                        .position(x: geo.size.width / 2, y: item.y)
                        .help(item.q.timeMark.isEmpty
                              ? item.q.text
                              : "\(item.q.timeMark) · \(item.q.text)")
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Text(block.endTime.formatted(date: .omitted, time: .shortened))
                .scaledFont(.caption2, monospacedDigit: true)
                .foregroundStyle(.secondary)
        }
        .frame(width: 56)
        .frame(height: fillsHeight ? nil : blockHeight)
        .frame(maxHeight: fillsHeight ? .infinity : nil)
    }

    struct LaidOutMarker: Identifiable {
        let q: Question
        let y: CGFloat
        var id: UUID { q.uuid }
    }

    /// 시각 위치가 너무 가까워 겹치는 Q 버튼들을 최소 간격만큼 밀어내 모두 보이게 배치한다.
    private func laidOut(_ markers: [QMarker], height: CGFloat) -> [LaidOutMarker] {
        guard height > 0, !markers.isEmpty else { return [] }
        let gap: CGFloat = 27          // 버튼(24) + 여유
        let margin: CGFloat = 13       // 버튼 반지름
        let minY = margin, maxY = max(margin, height - margin)

        let sorted = markers.sorted { $0.frac < $1.frac }
        var ys = sorted.map { min(maxY, max(minY, $0.frac * height)) }

        // 아래 방향으로 최소 간격 확보
        for i in 1..<ys.count where ys[i] < ys[i - 1] + gap {
            ys[i] = ys[i - 1] + gap
        }
        // 아래로 넘치면 위로 되밀기
        if let last = ys.last, last > maxY {
            ys[ys.count - 1] = maxY
            for i in stride(from: ys.count - 2, through: 0, by: -1) where ys[i] > ys[i + 1] - gap {
                ys[i] = ys[i + 1] - gap
            }
            // 위로 넘치면 다시 아래로 (간격은 좁아질 수 있음 — 어쩔 수 없음)
            if ys[0] < minY {
                ys[0] = minY
                for i in 1..<ys.count where ys[i] < ys[i - 1] + gap {
                    ys[i] = ys[i - 1] + gap
                }
            }
        }
        return zip(sorted, ys).map { LaidOutMarker(q: $0.q, y: $1) }
    }

    /// 질문 버튼(Q): 색=해결여부(초록/주황), 채움=답 유무. 눌러서 질문으로 이동.
    private func questionDot(_ q: Question) -> some View {
        let color: Color = q.isResolved ? .green : .orange
        let hasAnswer = !q.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Text("Q")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(hasAnswer ? .white : color)
            .frame(width: 24, height: 24)
            .background(
                Circle().fill(hasAnswer
                              ? AnyShapeStyle(color.gradient)
                              : AnyShapeStyle(Color(nsColor: .textBackgroundColor)))
            )
            .overlay(Circle().strokeBorder(color, lineWidth: hasAnswer ? 1 : 2))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            // "..." 설정 버튼 (색상·시작·기간)
            HStack {
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "ellipsis")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("블록 설정 (색상·시작·기간)")
                .popover(isPresented: $showSettings, arrowEdge: .top) {
                    settingsPopover
                }
            }

            Divider()

            ZStack(alignment: .topLeading) {
                TextEditor(text: $block.notes)
                    .scaledFont(13)
                    .scrollContentBackground(.hidden)
                if block.notes.isEmpty {
                    // TextEditor(NSTextView)의 텍스트 시작 위치(lineFragmentPadding=5)에 맞춰 정렬
                    Text("이 시간에 배운 내용·기억할 점을 메모하세요…")
                        .scaledFont(13)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 150, maxHeight: .infinity)
        }
        .padding(12)
        .frame(height: fillsHeight ? nil : blockHeight, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .top)
        .background(accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accent)
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 눌리는 느낌을 주는 Q 버튼 스타일 (호버 시 살짝 커지고, 누르면 작아짐)
struct QDotButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : (hovering ? 1.12 : 1))
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .animation(.snappy(duration: 0.12), value: hovering)
            .onHover { hovering = $0 }
    }
}
