import XCTest
import SwiftData
@testable import LectureQ

/// 실제 저장소 설정이 앱 자신의 iCloud 컨테이너로 열리는가.
/// 앱 엔타이틀먼트에는 피드백 허브 iCloud 컨테이너도 있어, 컨테이너를 정하지 않으면(.automatic) 그쪽으로
/// 동기화를 시도하다 저장소를 못 열고 실행 즉시 중단된다. 공책은 앱 자신의 컨테이너로만 기기 사이를 오간다.
/// 이 테스트는 앱을 호스트로 같은 엔타이틀먼트에서 돈다.
final class StoreConfigurationTests: XCTestCase {

    func testProductionStoreOpensWithAppICloudContainer() throws {
        let schema = Schema([Lecture.self, Question.self, Block.self])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LectureQTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = LectureQApp.storeConfiguration(schema: schema, url: dir.appendingPathComponent("t.store"))
        XCTAssertEqual(config.cloudKitContainerIdentifier, LectureQApp.cloudContainer)
        XCTAssertNotEqual(config.cloudKitContainerIdentifier, "iCloud.com.Ysoup.FeedbackHub")

        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.insert(Lecture(title: "저장 확인"))
        XCTAssertNoThrow(try context.save())
    }
}
