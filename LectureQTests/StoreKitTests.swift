import XCTest
import StoreKit
import StoreKitTest
import LeeoKit
@testable import LectureQ

/// LectureQ.storekit(가짜 스토어)로 상품과 구매 흐름을 시험한다.
/// 상품 ID 가 계약(LectureQSpec)과 글자 하나라도 다르면 페이월은 그 자리를 비운다 — 여기서 먼저 잡는다.
@MainActor
final class StoreKitTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "LectureQ")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
    }

    func testEveryProductLoads() async throws {
        let ids = LectureQSpec.saleProductIDs + LectureQSpec.tipProductIDs
        let products = try await Product.products(for: ids)
        XCTAssertEqual(Set(products.map(\.id)), Set(ids))
        // 구독 여섯 개는 한 그룹이고, 연 구독에는 첫 해 할인이 있다.
        let subs = products.filter { $0.subscription != nil }
        XCTAssertEqual(Set(subs.map(\.id)), LectureQSpec.subscriptionIDs)
        XCTAssertEqual(Set(subs.compactMap { $0.subscription?.subscriptionGroupID }).count, 1)
        for id in [LectureQSpec.plusYearlyID, LectureQSpec.proYearlyID] {
            XCTAssertNotNil(products.first { $0.id == id }?.subscription?.introductoryOffer, id)
        }
    }

    /// Plus 연 구독 → Plus, Plus 평생 + 올리기 → Pro. 팁은 아무것도 열지 않는다.
    func testPurchasesOpenTiers() async throws {
        let config = try XCTUnwrap(LectureQSpec.paywall)
        let store = LeeoStore(config: config)

        try await session.buyProduct(identifier: LectureQSpec.tipProductIDs[0])
        await store.refreshEntitlements()
        XCTAssertEqual(LectureQSpec.tier(owned: store.purchasedProductIDs), .free)

        try await session.buyProduct(identifier: LectureQSpec.plusYearlyID)
        await refresh(store, until: LectureQSpec.plusYearlyID)
        XCTAssertEqual(LectureQSpec.tier(owned: store.purchasedProductIDs), .plus)

        session.clearTransactions()
        try await session.buyProduct(identifier: LectureQSpec.plusLifetimeID)
        try await session.buyProduct(identifier: LectureQSpec.proUpgradeID)
        await refresh(store, until: LectureQSpec.proUpgradeID)
        XCTAssertEqual(LectureQSpec.tier(owned: store.purchasedProductIDs), .pro)
    }

    /// 가짜 스토어는 산 직후 그 거래가 보유 목록(currentEntitlements)에 오르기까지 잠깐 걸릴 때가 있다.
    /// 바로 읽으면 테스트가 시점에 따라 갈리므로, 산 상품이 보일 때까지(최대 2초) 다시 읽는다.
    private func refresh(_ store: LeeoStore, until productID: String) async {
        for _ in 0..<20 {
            await store.refreshEntitlements()
            if store.purchasedProductIDs.contains(productID) { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }
}
