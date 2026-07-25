import SwiftUI
import SwiftData

@main
struct LectureQApp: App {
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
        }
        .modelContainer(container)
    }

    /// 데이터가 사라지지 않도록, 눈에 보이는 실제 파일에 SwiftData 저장소를 만든다.
    /// 경로: ~/Library/Application Support/LectureQ/LectureQ.store
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Lecture.self, Question.self, Block.self])
        let storeURL = storeFileURL()

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

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
