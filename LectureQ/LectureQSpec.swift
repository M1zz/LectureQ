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
}
