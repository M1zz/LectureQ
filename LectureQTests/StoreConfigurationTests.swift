import XCTest
import SwiftData
@testable import LectureQ

/// 실제 저장소 설정이 CloudKit 을 타지 않고 열리는가.
/// 앱 엔타이틀먼트에 피드백 허브 iCloud 컨테이너가 있어, 기본값(.automatic)이면 그 컨테이너로 동기화를
/// 시도하다 저장소를 못 열고 실행 즉시 중단된다. 이 테스트는 앱을 호스트로 같은 엔타이틀먼트에서 돈다.
final class StoreConfigurationTests: XCTestCase {

    func testProductionStoreOpensWithoutCloudKit() throws {
        let schema = Schema([Lecture.self, Question.self, Block.self])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LectureQTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let config = LectureQApp.storeConfiguration(schema: schema, url: dir.appendingPathComponent("t.store"))
        XCTAssertNil(config.cloudKitContainerIdentifier)

        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.insert(Lecture(title: "저장 확인"))
        XCTAssertNoThrow(try context.save())
    }
}
