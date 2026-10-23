import Foundation

/// 웹 페이지(GitHub Pages, docs/) 주소 — 앱 화면 언어의 페이지로 연다.
/// 한국어는 루트(docs/*.html), 나머지 언어는 docs/<로케일>/*.html.
enum SiteURL {
    static let base = "https://m1zz.github.io/LectureQ/"

    /// docs/ 아래에 페이지 폴더가 있는 로케일 (deploy.env LOCALES 에서 ko 를 뺀 것).
    static let localizedFolders: Set<String> = [
        "en", "en-GB", "zh-Hans", "zh-Hant", "ja", "ru", "es", "de", "fr", "it", "pt-BR", "th",
        "vi", "cs", "da", "el", "fi", "id", "nb", "nl", "pl", "sv", "tr",
    ]

    static var folder: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "ko"
        return localizedFolders.contains(lang) ? lang + "/" : ""
    }

    /// 예: page("privacy.html"), page("") 는 소개 페이지.
    static func page(_ name: String) -> URL {
        URL(string: base + folder + name)!
    }
}
