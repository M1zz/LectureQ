//
//  LectureQFlags.swift
//  LectureQ
//
//  원격 킬스위치 플래그 — LeeoKit(LeeoRemoteFlags)이 피드백 허브의 CloudKit RemoteFlags 레코드에서 읽는다.
//  심사 없이, 문제가 생긴 기능만 끈다.
//
//  ⚠️ rawValue = CloudKit 필드명 계약이다 — 다르면 아무리 꺼도 켜진 채로 도는 조용한 실패. 바꾸지 말 것.
//  ⚠️ 조회 실패 = 켬(가용성 우선), 갱신은 6시간 쓰로틀 → 즉시 전파되지 않는다(보통 다음 실행부터).
//
//  CloudKit Dashboard 설정(1회): 컨테이너 iCloud.com.Ysoup.FeedbackHub ▸ Public DB,
//  레코드 타입 RemoteFlags, recordName "flags_com.lectureq.LectureQ",
//  각 플래그를 Int64(1=켬/0=끔) 필드로 만들고 Production 배포. 필드가 없으면 켬으로 동작.
//

import Foundation
import LeeoKit

enum LectureQFlag: String, LeeoRemoteFlag, CaseIterable {
    /// 익명 사용 통계(사용현황 스냅샷 · 하루 한 번 app_open). 끄면 다음 실행부터 보내지 않는다.
    case usageReportingEnabled
    /// "질문 노트를 즐겁게 쓰고 계신가요?" 만족도 질문. 끄면 다음 실행부터 묻지 않는다.
    /// (설정의 '리뷰 남기기'는 사용자가 스스로 누르는 것이라 그대로 둔다.)
    case satisfactionPromptEnabled
}
