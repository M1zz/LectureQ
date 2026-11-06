import XCTest
@testable import LectureQ

/// 무료 · Plus · Pro 의 정책 (→ Purchases.swift, LectureQSpec).
final class PlanTests: XCTestCase {

    func testProductsOpenTheirTier() {
        XCTAssertEqual(LectureQSpec.tier(owned: []), .free)
        XCTAssertEqual(LectureQSpec.tier(owned: ["com.lectureq.LectureQ.tip.small"]), .free)
        for id in LectureQSpec.plusEntitlementIDs {
            XCTAssertEqual(LectureQSpec.tier(owned: [id]), .plus, id)
        }
        for id in LectureQSpec.proEntitlementIDs {
            XCTAssertEqual(LectureQSpec.tier(owned: [id]), .pro, id)
        }
        XCTAssertEqual(LectureQSpec.tier(owned: [LectureQSpec.plusLifetimeID, LectureQSpec.proUpgradeID]), .pro)
    }

    /// 팁은 아무것도 열지 않는다. 팔 상품 · 권한 목록에 섞이면 팁을 낸 사람이 Plus 가 된다.
    func testTipsAreNotEntitlements() {
        let paywall = try! XCTUnwrap(LectureQSpec.paywall)
        for tip in LectureQSpec.tipProductIDs {
            XCTAssertFalse(paywall.productIDs.contains(tip))
            XCTAssertFalse(paywall.entitlementIDs.contains(tip))
        }
        XCTAssertEqual(paywall.tipJar?.productIDs, LectureQSpec.tipProductIDs)
    }

    /// 판매 상품은 모두 권한 상품이고, 구독은 모두 판매 상품이다.
    func testProductListsAgree() {
        let sale = Set(LectureQSpec.saleProductIDs)
        XCTAssertEqual(sale, LectureQSpec.plusEntitlementIDs.union(LectureQSpec.proEntitlementIDs))
        XCTAssertTrue(LectureQSpec.subscriptionIDs.isSubset(of: sale))
        XCTAssertTrue(LectureQSpec.proLifetimeIDs.isDisjoint(with: LectureQSpec.subscriptionIDs))
    }

    func testFreePromptSteps() {
        XCTAssertNil(AIPrompt.refine.feature)
        XCTAssertNil(AIPrompt.ask.feature)
        XCTAssertEqual(AIPrompt.verify.feature, .allPrompts)
        XCTAssertEqual(AIPrompt.followUps.feature, .allPrompts)
        XCTAssertEqual(AIPrompt.grade.feature, .allPrompts)
    }

    func testFeatureTiers() {
        XCTAssertEqual(ProFeature.unlimitedLectures.tier, .plus)
        XCTAssertEqual(ProFeature.learningState.tier, .plus)
        XCTAssertEqual(ProFeature.graph.tier, .pro)
        XCTAssertEqual(ProFeature.timeline.tier, .pro)
        XCTAssertEqual(ProFeature.markdownImport.tier, .pro)
        XCTAssertEqual(ProFeature.shortcuts.tier, .pro)
    }

    /// 1.0.3 까지 받은 사람은 Pro 를 그대로 쓴다 (macOS 의 originalAppVersion 은 CFBundleShortVersionString).
    func testEarlyUserCutoff() {
        XCTAssertTrue(EarlyUser.isEarly(originalAppVersion: "1.0"))
        XCTAssertTrue(EarlyUser.isEarly(originalAppVersion: "1.0.1"))
        XCTAssertTrue(EarlyUser.isEarly(originalAppVersion: "1.0.3"))
        XCTAssertFalse(EarlyUser.isEarly(originalAppVersion: "1.0.4"))
        XCTAssertFalse(EarlyUser.isEarly(originalAppVersion: "1.1.0"))
        XCTAssertFalse(EarlyUser.isEarly(originalAppVersion: "1.0.10"))
    }
}
