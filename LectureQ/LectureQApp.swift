import SwiftUI
import SwiftData
import LeeoKit
import TipKit
import AppIntents

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
        // 사용 팁(→ FeatureTips.swift). 스크린샷 데모 모드에서는 팁이 찍히지 않게 켜지 않는다.
        if !DemoMode.isOn {
            try? Tips.configure([.displayFrequency(.daily)])
        }
        container = Self.makeContainer()
        // Siri · Spotlight 의 질문 찾기가 같은 저장소를 읽게 한다 (→ AppShortcuts.swift)
        let container = container
        AppDependencyManager.shared.add(dependency: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
                .storeFallbackNotice()
                .satisfactionCheckIfEnabled()
                .task { await LectureQTip.tipJar.startStandalone() }
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
            // 저장 파일을 절대 임의로 삭제하지 않는다. 파일은 그대로 두고 이번 실행만 메모리에서 열며,
            // 지금 적는 것이 남지 않는다는 걸 사용자에게 알린다 (예전에는 여기서 앱을 멈췄다).
            print("⚠️ 저장 파일을 열지 못함: \(storeURL.path)")
            return StoreFallback.memoryContainer(schema: schema, after: error)
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

// MARK: - 저장소를 못 연 날

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
    }
}
