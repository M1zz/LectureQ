import SwiftUI

/// 숫자 · 날짜를 한 가지 모양으로 맞춘다.
/// 강의 시점(HH:mm)은 늘 0-9 로 적힌다. 아랍어 화면에서 다른 숫자(블록 시각 · 개수 · 날짜)가
/// 기기 지역을 따라 ١٢٣ 이나 히즈라력으로 나오면 한 화면에 두 가지가 섞인다.
/// 그래서 **아랍어일 때만** 0-9 · 양력으로 맞추고, 다른 언어는 기기 설정을 그대로 따른다(태국어의 불기 등).
enum AppLocale {
    static let isArabic = Bundle.main.preferredLocalizations.first == "ar"

    static let locale: Locale = {
        guard isArabic else { return .autoupdatingCurrent }
        var c = Locale.Components(locale: .current)
        c.numberingSystem = "latn"
        c.calendar = .gregorian
        return Locale(components: c)
    }()

    static let calendar: Calendar = {
        guard isArabic else { return .autoupdatingCurrent }
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        return cal
    }()

    static func dateStyle(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> Date.FormatStyle {
        Date.FormatStyle(date: date, time: time, locale: locale, calendar: calendar)
    }

    /// 아랍어 자판으로 친 숫자(٠-٩ · ۰-۹)를 0-9 로 — 강의 시점 칸이 그대로 읽히게 한다.
    static func latinDigits(_ s: String) -> String {
        String(s.unicodeScalars.map { u -> Character in
            switch u.value {
            case 0x0660...0x0669: return Character(UnicodeScalar(u.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: return Character(UnicodeScalar(u.value - 0x06F0 + 0x30)!)
            default: return Character(u)
            }
        })
    }
}

extension View {
    /// 화면 속 숫자 · 날짜 고르기(DatePicker)도 같은 모양으로 (→ AppLocale).
    /// Mac 의 시트 · 팝오버는 부모의 locale 을 물려받지 않으므로 그 안에도 단다.
    @ViewBuilder
    func appLocale() -> some View {
        if AppLocale.isArabic {
            environment(\.locale, AppLocale.locale)
                .environment(\.calendar, AppLocale.calendar)
        } else {
            self
        }
    }

    /// 강의 시점 칸 — 아랍어 자판의 숫자를 0-9 로 바꿔 둔다.
    func latinDigits(_ text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, new in
            let latin = AppLocale.latinDigits(new)
            if latin != new { text.wrappedValue = latin }
        }
    }
}
