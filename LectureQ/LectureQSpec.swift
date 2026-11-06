//
//  LectureQSpec.swift
//  LectureQ
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//
//  피드백 허브(iCloud.com.Ysoup.FeedbackHub) 컨테이너와 샌드박스 네트워크 권한은
//  project.yml 의 entitlements 에 있다 (→ LectureQ/LectureQ.entitlements 로 생성된다).
//

import Foundation
import LeeoKit

enum LectureQSpec: LeeoAppSpec {
    static let appName = "질문 노트"
    static let developerEmail = "leeo@kakao.com"

    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.lectureq.LectureQ"
    )

    /// 익명 사용 통계 — 설치 수·실행 일수·버전 분포를 피드백 허브로 보낸다.
    /// 기본값(LeeoNoopAnalytics)이면 부트스트랩이 아무것도 안 보낸다. 무엇을 보내는지는 docs/privacy.html.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: LectureQSpec.self)

    /// 지원·개인정보 페이지 (README.md, docs/).
    static let legal = LeeoLegalConfig(
        privacyURL: SiteURL.page("privacy.html"),
        supportURL: SiteURL.page("support.html"),
        // 계정을 만들지 않는다 — 데이터는 이 맥에만 있다.
        createsAccounts: false,
        marketingURL: SiteURL.page("")
    )

    /// **무료 · Plus · Pro 세 칸** (→ Purchases.swift). 칸마다 주 · 월 · 연 구독과 평생을 둔다.
    ///
    /// ⚠️ 팁 상품은 `productIDs` · 권한 목록에 넣지 않는다. 넣으면 팁을 낸 사람이 Plus 가 된다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: saleProductIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            entitlementIDs: plusEntitlementIDs.union(proEntitlementIDs),
            // 실제 판정은 `PurchaseManager.allows` 가 한다. 여기는 매니페스트 · 점검용 선언이다.
            gate: LeeoGatePolicy(
                freeLimits: [ProFeature.unlimitedLectures.rawValue: freeLectureLimit],
                proOnly: Set(ProFeature.allCases.filter { $0 != .unlimitedLectures }.map(\.rawValue))),
            tipJar: LeeoTipJarConfig(productIDs: tipProductIDs)
        )
    )

    /// 무료로 만들 수 있는 강의 수.
    static let freeLectureLimit = 10

    // MARK: 상품 ID
    //
    // ⚠️ App Store Connect · LectureQ.storekit 과 **글자 하나까지 같아야** 한다.
    // 자동 갱신 구독 여섯 개는 한 구독 그룹에 두고 Pro 를 위 등급으로 둔다(갈아탈 때 남은 기간을 정산한다).

    static let plusWeeklyID = "com.lectureq.LectureQ.plus.weekly"
    static let plusMonthlyID = "com.lectureq.LectureQ.plus.monthly"
    static let plusYearlyID = "com.lectureq.LectureQ.plus.yearly"
    static let plusLifetimeID = "com.lectureq.LectureQ.plus"
    static let proWeeklyID = "com.lectureq.LectureQ.pro.weekly"
    static let proMonthlyID = "com.lectureq.LectureQ.pro.monthly"
    static let proYearlyID = "com.lectureq.LectureQ.pro.yearly"
    static let proLifetimeID = "com.lectureq.LectureQ.pro"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let proUpgradeID = "com.lectureq.LectureQ.pro.upgrade"
    /// 구독 졸업: 구독 중인 사람에게만 보이는 Pro 평생.
    static let proGraduateID = "com.lectureq.LectureQ.pro.graduate"

    static let tipProductIDs = ["com.lectureq.LectureQ.tip.small",
                                "com.lectureq.LectureQ.tip.medium",
                                "com.lectureq.LectureQ.tip.large"]

    /// 불러올 상품.
    static let saleProductIDs = [plusWeeklyID, plusMonthlyID, plusYearlyID, plusLifetimeID,
                                 proWeeklyID, proMonthlyID, proYearlyID, proLifetimeID,
                                 proUpgradeID, proGraduateID]

    static let plusEntitlementIDs: Set<String> = [plusWeeklyID, plusMonthlyID, plusYearlyID, plusLifetimeID]
    static let proEntitlementIDs: Set<String> = [proWeeklyID, proMonthlyID, proYearlyID, proLifetimeID,
                                                 proUpgradeID, proGraduateID]
    /// 자동 갱신 구독 (졸업 제안의 대상).
    static let subscriptionIDs: Set<String> = [plusWeeklyID, plusMonthlyID, plusYearlyID,
                                               proWeeklyID, proMonthlyID, proYearlyID]
    /// 끝이 없는 Pro.
    static let proLifetimeIDs: Set<String> = [proLifetimeID, proUpgradeID, proGraduateID]

    /// 가진 상품이 여는 칸.
    static func tier(owned: Set<String>) -> LectureQTier {
        if !owned.isDisjoint(with: proEntitlementIDs) { return .pro }
        if !owned.isDisjoint(with: plusEntitlementIDs) { return .plus }
        return .free
    }

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6794597095" }
}

/// 팁을 부탁할 만한 순간 — 지금까지 강의에서 남긴 질문 수. 큰 것부터.
enum LectureQTipMoments {
    static let questions = [500, 150, 50]

    static func reached(questionCount n: Int) -> [LeeoTipMoment] {
        questions.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "questions.\(threshold)",
                          message: String(localized: "지금까지 강의에서 질문 \(n)개를 남겼어요",
                                          comment: "Tip ask card: how many lecture questions the person has written so far"))
        }
    }
}
