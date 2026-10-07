//
//  LectureQSpec.swift
//  LectureQ
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//
//  ⚠️ 피드백 허브(iCloud.com.Ysoup.FeedbackHub)는 아직 이 앱의 entitlements 에 없다.
//     (샌드박스에 네트워크 권한도 없다.) 피드백 화면을 켜기 전에 둘 다 먼저 추가해야 한다.
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

    /// 지원·개인정보 페이지 (README.md, docs/).
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/LectureQ/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/LectureQ/support.html")!,
        // 계정을 만들지 않는다 — 데이터는 이 맥에만 있다.
        createsAccounts: false,
        marketingURL: URL(string: "https://m1zz.github.io/LectureQ/")
    )

    /// 인앱 결제 없음.
    static let monetization = LeeoMonetization.free
}
