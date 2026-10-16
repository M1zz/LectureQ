import SwiftUI
import TipKit

/// 질문이 몇 개 쌓인 사람에게 "보기 메뉴에서 한눈에 돌아볼 수 있다"를 알려 준다.
/// 요약·그래프는 이 앱에서 정리의 핵심인데, 툴바의 '보기' 메뉴 안에 있어 열어 보지 않으면 모른다.
/// - 질문을 3개 이상 저장한 뒤에만 뜬다 (첫 화면에서 쏟아내지 않는다).
/// - 요약이나 그래프를 한 번이라도 열면 다시 뜨지 않는다.
struct ReviewViewsTip: Tip {
    /// 질문을 저장한 순간
    static let questionSaved = Event(id: "featureTip.questionSaved")

    /// 요약·그래프를 한 번이라도 열었는가
    @Parameter static var hasOpenedReview: Bool = false

    var title: Text { Text("질문이 쌓였다면 돌아보세요") }
    var message: Text? {
        Text("보기 메뉴의 요약(⌘1)에서 던질 질문과 배운 점을, 그래프(⌘2)에서 질문 사이의 연결을 한눈에 볼 수 있어요.")
    }
    var image: Image? { Image(systemName: "rectangle.3.group") }

    var rules: [Rule] {
        #Rule(Self.$hasOpenedReview) { $0 == false }
        #Rule(Self.questionSaved) { $0.donations.count >= 3 }
    }
}

enum FeatureTips {
    /// 질문을 하나 저장했다.
    static func donateQuestionSaved() {
        Task { await ReviewViewsTip.questionSaved.donate() }
    }

    /// 요약이나 그래프를 열었다 — 팁을 더는 띄우지 않는다.
    static func markReviewOpened() {
        ReviewViewsTip.hasOpenedReview = true
    }
}
