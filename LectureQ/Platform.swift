// Mac · iPhone · iPad 가 다른 자리를 한곳에 모은다.
import SwiftUI

extension View {
    /// Mac 시트 · 창의 크기. iPhone · iPad 는 시스템이 시트 크기를 정하므로 건드리지 않는다.
    @ViewBuilder
    func macFrame(width: CGFloat? = nil, height: CGFloat? = nil,
                  minWidth: CGFloat? = nil, minHeight: CGFloat? = nil) -> some View {
        #if os(macOS)
        if width != nil || height != nil {
            frame(width: width, height: height)
        } else {
            frame(minWidth: minWidth, minHeight: minHeight)
        }
        #else
        self
        #endif
    }
}

extension Color {
    /// 글 바탕색 — Mac 의 textBackgroundColor, iPhone · iPad 의 systemBackground.
    static var textBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

extension View {
    /// 글자만 있는 링크 모양 버튼 (Mac 의 .link, iPhone · iPad 는 테두리 없는 버튼).
    @ViewBuilder
    func linkButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.link)
        #else
        buttonStyle(.borderless)
        #endif
    }
}

extension View {
    /// 체크박스 (Mac). iPhone · iPad 는 켜지면 채워지는 버튼 — 긴 스위치보다 한 줄에 잘 들어간다.
    @ViewBuilder
    func checkboxToggleStyle() -> some View {
        #if os(macOS)
        toggleStyle(.checkbox)
        #else
        toggleStyle(.button)
        #endif
    }
}
