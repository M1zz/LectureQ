import SwiftUI
import LeeoKit

/// 앱 메뉴 ▸ 설정… (⌘,) 창.
/// 피드백 보내기 · 보낸 피드백 · 리뷰 남기기 · 개인정보/지원 링크 · 버전은 LeeoSupportSection 이,
/// 메일 문의와 인스타그램은 이 화면이 직접 둔다.
struct SettingsView: View {
    private static let instagramURL = URL(string: "https://instagram.com/lee25_ios")!

    var body: some View {
        NavigationStack {
            Form {
                Section("지원") {
                    LeeoSupportSection<LectureQSpec>()
                }

                Section {
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                }

                Section {
                    if let mail = Self.mailURL {
                        Link(destination: mail) {
                            Label("메일로 문의하기", systemImage: "envelope")
                        }
                        .help(LectureQSpec.developerEmail)
                    }
                    Link(destination: Self.instagramURL) {
                        Label("인스타그램에서 소식 보기", systemImage: "camera")
                    }
                } header: {
                    Text("연락하기")
                } footer: {
                    Text("문의하실 때 macOS 버전과 어떤 동작에서 문제가 생겼는지 적어 주시면 빠르게 확인할 수 있어요.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 520)
    }

    /// 받는 사람 · 제목 · 앱/OS 버전이 채워진 메일 초안.
    private static var mailURL: URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var c = URLComponents(string: "mailto:\(LectureQSpec.developerEmail)")
        c?.queryItems = [
            URLQueryItem(name: "subject", value: "[\(LectureQSpec.appName)] 문의"),
            URLQueryItem(name: "body", value: "\n\n\n—\n앱 버전: \(version) (\(build))\nmacOS: \(os)")
        ]
        return c?.url
    }
}
