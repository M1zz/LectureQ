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

    /// 인앱 결제 없음.
    static let monetization = LeeoMonetization.free

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6794597095" }
}

// MARK: - 팁 (개발자 응원하기)

/// 무료 앱이라 LeeoStore 가 없다. 팁 엔진을 여기 하나 두고, 앱을 열 때 `startStandalone()` 을 부른다.
@MainActor
enum LectureQTip {
    static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.lectureq.LectureQ.tip.small",
        "com.lectureq.LectureQ.tip.medium",
        "com.lectureq.LectureQ.tip.large",
    ]))
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
