import SwiftUI
import SwiftData
import LeeoKit

@main
struct LectureQApp: App {
    let container: ModelContainer

    init() {
        // 단위 테스트(LectureQTests)가 이 앱을 호스트로 띄울 때: 사용자의 실제 저장 파일을 열지 않고,
        // 통계·플래그 네트워크도 타지 않는다. 테스트는 메모리 저장소만 쓴다.
        if Self.isRunningUnitTests {
            container = try! ModelContainer(
                for: Lecture.self, Question.self, Block.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            return
        }
        // LeeoKit 계약을 켜는 한 줄 (→ LectureQSpec.swift). 실행 횟수 기록 · 익명 사용 통계 · 원격 킬스위치 갱신
        // · DEBUG 프리플라이트. 통계·플래그는 피드백 허브(CloudKit)로 간다.
        // 크래시 진단(MetricKit)은 macOS 에선 LeeoKit 안에서 no-op.
        // 통계는 원격 플래그(→ LectureQFlags.swift)로 끌 수 있다 — 지난 실행에서 받아 둔 값을 읽는다.
        LeeoKit.bootstrap(
            LectureQSpec.self,
            flags: LectureQFlag.self,
            usageReporting: LeeoRemoteFlags.isEnabled(LectureQFlag.usageReportingEnabled)
        )
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
                .satisfactionCheckIfEnabled()
        }
        .modelContainer(container)

        // 앱 메뉴 ▸ 설정… (⌘,) — 피드백 · 리뷰 · 문의 · 정책 링크
        Settings {
            SettingsView()
        }
    }

    /// XCTest 가 앱을 호스트로 실행 중인가.
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 데이터가 사라지지 않도록, 눈에 보이는 실제 파일에 SwiftData 저장소를 만든다.
    /// 경로: ~/Library/Application Support/LectureQ/LectureQ.store
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Lecture.self, Question.self, Block.self])
        #if DEBUG
        if DemoMode.isOn { return DemoMode.makeContainer(schema: schema) }
        #endif
        let storeURL = storeFileURL()
        let config = storeConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ LectureQ 저장 파일: \(storeURL.path)")
            return container
        } catch {
            // 저장 파일을 절대 임의로 삭제하지 않는다. 문제를 그대로 드러내 데이터 유실을 막는다.
            fatalError("""
            SwiftData 저장소를 열 수 없습니다. 데이터 유실을 막기 위해 중단합니다.
            파일: \(storeURL.path)
            원인: \(error)
            """)
        }
    }

    /// 저장소 설정. **CloudKit 동기화를 명시적으로 끈다(.none).**
    /// 기본값(.automatic)은 엔타이틀먼트의 첫 iCloud 컨테이너로 동기화를 시도하는데, 이 앱의 컨테이너
    /// (iCloud.com.Ysoup.FeedbackHub)는 익명 통계·피드백용이다. 모델이 CloudKit 규칙(모든 속성 기본값)을
    /// 만족하지 않아 저장소가 열리지 않고 실행 즉시 중단되며, 열린다 해도 공책 내용이 남의 컨테이너로 올라간다.
    /// 데이터는 이 Mac 에만 둔다(개인정보 처리방침과 같다).
    static func storeConfiguration(schema: Schema, url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: schema, url: url, allowsSave: true, cloudKitDatabase: .none)
    }

    /// 저장 폴더가 없으면 만들고, 저장 파일의 전체 경로를 돌려준다.
    static func storeFileURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("LectureQ", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("LectureQ.store")
    }
}

private extension View {
    /// 만족도 질문("즐겁게 쓰고 계신가요?") — 조건(실행 횟수·설치 일수·질문 해결 같은 긍정 행동)이 맞을 때만
    /// LeeoKit 이 스스로 묻는다. 원격 플래그로 끌 수 있고, 스크린샷 데모 모드에서는 묻지 않는다.
    @ViewBuilder
    func satisfactionCheckIfEnabled() -> some View {
        if !DemoMode.isOn, LeeoRemoteFlags.isEnabled(LectureQFlag.satisfactionPromptEnabled) {
            self.leeoSatisfactionCheck(LectureQSpec.self)
        } else {
            self
        }
    }
}
