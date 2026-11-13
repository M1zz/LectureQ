import SwiftUI

/// 질문 추가 심볼 — ? 가 뚫린 말풍선의 오른쪽 아래 모서리에 + 배지를 얹는다.
/// SF Symbols 의 배지 기호처럼 배지 둘레를 비워 두 모양이 겹치지 않고 한 덩어리로 읽힌다.
/// 글꼴 크기를 따라 커지고 줄며, 색은 둘러싼 foregroundStyle 을 따른다.
struct AddQuestionSymbol: View {
    private let badgeRatio: CGFloat = 0.42   // 배지 지름 (말풍선 너비 대비)
    private let gapRatio: CGFloat = 0.07     // 배지 둘레 빈틈
    private let outset = CGSize(width: 0.12, height: 0.08)   // 배지가 모서리 밖으로 나가는 정도

    var body: some View {
        Image(systemName: "questionmark.bubble.fill")
            .hidden()   // 크기는 말풍선 기호 그대로 — 글꼴 · 툴바 크기를 따른다
            .overlay {
                GeometryReader { g in
                    let s = g.size.width
                    let d = s * badgeRatio
                    let center = CGPoint(x: s - d / 2 + s * outset.width,
                                         y: g.size.height - d / 2 + s * outset.height)
                    // 배지가 나간 만큼 절반을 되돌려 전체가 자리 가운데에 오게 한다
                    let shift = CGSize(width: -s * outset.width / 2, height: -s * outset.height / 2)

                    Image(systemName: "questionmark.bubble.fill")
                        .mask {
                            Rectangle()
                                .overlay {
                                    Circle()
                                        .frame(width: d + s * gapRatio * 2, height: d + s * gapRatio * 2)
                                        .position(center)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                        }
                        .offset(shift)
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: d, height: d)
                        .position(center)
                        .offset(shift)
                }
            }
            .accessibilityHidden(true)
    }
}
