//
//  Purchases.swift
//  LectureQ
//
//  **무료 · Plus · Pro 세 칸** (→ LectureQSpec.monetization, 상품 ID 도 거기 있다).
//
//   · 무료: 강의 10개, 질문 · 꼬리질문 · 타임블록 메모 · 요약, AI 프롬프트 두 단계(다듬기 · 답 찾기)
//   · Plus: 강의 무제한, AI 프롬프트 다섯 단계 전부, 학습 상태
//   · Pro: Plus 전부 + 질문 그래프 · 타임블록 모아보기 · 마크다운 가져오기 · 단축어/Siri 로 질문 추가
//
//  ⚠️ 영수증을 읽고 사고 되찾는 일은 전부 LeeoKit(`LeeoStore`)이 한다. 여기 남은 것은 **정책**뿐이다.
//  ⚠️ 절대 잠그지 않는 것: 이미 만든 강의 · 질문을 보고 고치고 지우는 일, 손쉬운 사용.
//     한도는 **새 강의를 만들 때만** 본다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import LeeoKit

/// 세 칸. 위 칸은 아래 칸을 전부 연다.
enum LectureQTier: Int, Comparable, CaseIterable {
    case free, plus, pro

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .free: String(localized: "무료", comment: "Plan name: free tier")
        case .plus: "Plus"
        case .pro:  "Pro"
        }
    }
}

/// 값을 받는 자리. 막히면 그 기능이 든 칸을 앞세운 페이월이 뜬다.
enum ProFeature: String, Identifiable, CaseIterable {
    /// 11번째 강의부터 (무료는 `LectureQSpec.freeLectureLimit` 개).
    case unlimitedLectures
    /// AI 프롬프트 ③ 답 되묻기 · ④ 꼬리질문 뽑기 · ⑤ 내 답 채점받기.
    case allPrompts
    /// 강의별 학습 상태 (지금 나의 상태 · 마쳤을 때 상태 · 배우고 싶은 것).
    case learningState
    /// 질문 그래프.
    case graph
    /// 타임블록 모아보기 (모든 강의의 블록을 시간순으로).
    case timeline
    /// 대화 마크다운 가져오기.
    case markdownImport
    /// 단축어 · Siri 로 질문 추가.
    case shortcuts

    var id: String { rawValue }

    var tier: LectureQTier {
        switch self {
        case .unlimitedLectures, .allPrompts, .learningState: .plus
        case .graph, .timeline, .markdownImport, .shortcuts:  .pro
        }
    }
}

extension AIPrompt {
    /// 무료로 쓰는 두 단계(다듬기 · 답 찾기) 밖의 단계는 Plus 다.
    var feature: ProFeature? {
        switch self {
        case .refine, .ask: nil
        case .verify, .followUps, .grade: .allPrompts
        }
    }
}

// MARK: - 먼저 쓰던 사람

enum EarlyUser {
    /// 페이월이 생기기 전 마지막으로 낸 버전(1.0.3 빌드 11). 그때까지 받은 사람은 Pro 를 그대로 쓴다.
    /// ⚠️ 페이월이 든 버전은 이보다 높아야 한다.
    static let lastVersionBeforePaywall = "1.0.3"

    /// macOS 의 `originalAppVersion` 은 처음 받은 판의 CFBundleShortVersionString 이다.
    /// 샌드박스 · Xcode 는 실제 판을 돌려주지 않으므로 App Store 에서 받은 것만 본다.
    static func isEarly() async -> Bool {
        guard case .verified(let app)? = try? await AppTransaction.shared,
              app.environment == .production else { return false }
        return isEarly(originalAppVersion: app.originalAppVersion)
    }

    static func isEarly(originalAppVersion: String) -> Bool {
        originalAppVersion.compare(lastVersionBeforePaywall, options: .numeric) != .orderedDescending
    }
}

// MARK: - 사고 되찾기

/// 화면은 `tier` 와 `allows(_:)` 만 본다.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    @ObservationIgnored let store: LeeoStore
    /// 개발자 응원하기(팁). 기능을 열지 않는다 — 결제 갱신은 `store` 의 리스너가 이리로 넘긴다.
    @ObservationIgnored let tipJar: LeeoTipJar

    /// 지금 쓰는 칸.
    private(set) var tier: LectureQTier = .free
    /// 페이월에 설 상품. App Store 에서 불러온 것만 있다.
    private(set) var products: [Product] = []
    /// 이 Apple 계정이 가진 상품.
    private(set) var ownedIDs: Set<String> = []
    /// 페이월 전부터 쓰던 사람이라 Pro 인가.
    private(set) var isEarlyUser = false
    /// 지금 살아 있는 구독. 있으면 졸업가를 권할 수 있다.
    private(set) var subscription: LeeoGraduation.Subscription?
    private(set) var isWorking = false
    /// 사다가 막혔을 때 그대로 보여 줄 말.
    private(set) var failureMessage: String?

    @ObservationIgnored private var observation: AnyCancellable?

    private init() {
        guard let config = LectureQSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. LectureQSpec.monetization 을 확인할 것")
        }
        let store = LeeoStore(config: config, grandfather: { await EarlyUser.isEarly() })
        guard let tipJar = store.tipJar else {
            preconditionFailure("계약에 팁이 없다. LectureQSpec.monetization 을 확인할 것")
        }
        self.store = store
        self.tipJar = tipJar
        // objectWillChange 는 값이 바뀌기 **직전**에 온다. 다음 차례에 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
        pull()
    }

    /// **팔고 있는가.** 스토어에서 상품을 하나도 못 불러왔으면 살 길이 없으니 아무것도 막지 않는다.
    var isSelling: Bool { !products.isEmpty }

    /// 이 기능을 지금 써도 되는가.
    func allows(_ feature: ProFeature) -> Bool {
        DemoMode.isOn || !isSelling || tier >= feature.tier
    }

    /// 새 강의를 하나 더 만들어도 되는가. 이미 만든 강의는 몇 개든 그대로 보고 고치고 지운다.
    func allowsNewLecture(existing count: Int) -> Bool {
        count < LectureQSpec.freeLectureLimit || allows(.unlimitedLectures)
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    /// Plus 평생을 가졌는가. 그러면 Pro 평생 자리에 올리기 상품이 선다.
    var ownsPlusLifetime: Bool { ownedIDs.contains(LectureQSpec.plusLifetimeID) }
    /// 끝이 없는 Pro 를 가졌는가. 졸업 · 평생으로 바꾸기를 권하지 않는다.
    var ownsLifetimePro: Bool { isEarlyUser || !ownedIDs.isDisjoint(with: LectureQSpec.proLifetimeIDs) }

    // MARK: 상태 맞추기

    /// 영수증을 다시 읽고 상품을 불러온다. 앱을 열 때 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        await store.loadProducts()
        subscription = await LeeoGraduation.currentSubscription(among: LectureQSpec.subscriptionIDs)
        pull()
    }

    /// 페이월이 상품을 못 불러왔을 때 다시 청한다.
    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    // MARK: 사기 / 되찾기

    /// ⚠️ `action` 은 화면의 `@Environment(\.purchase)` 다. 결제 시트가 그 창에 뜬다.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        subscription = await LeeoGraduation.currentSubscription(among: LectureQSpec.subscriptionIDs)
        pull()
    }

    func restore() async {
        await store.restore()
        subscription = await LeeoGraduation.currentSubscription(among: LectureQSpec.subscriptionIDs)
        pull()
        if tier == .free, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 구매한 기록을 찾지 못했어요.",
                                    comment: "Restore purchases: nothing found")
        }
    }

    // MARK: 구독 졸업

    var graduateProduct: Product? { product(LectureQSpec.proGraduateID) }

    /// 지금 졸업가를 한 번 보일 때인가 (구독 6개월째 · 갱신 7일 전). 보이기로 했으면 표시를 남긴다.
    func takeGraduationOffer(now: Date = Date()) -> Bool {
        guard let subscription, graduateProduct != nil, !ownsLifetimePro,
              LeeoGraduation.isDue(subscription, now: now, lastOffered: LeeoGraduation.lastOffered())
        else { return false }
        LeeoGraduation.markOffered(now)
        return true
    }

    // MARK: -

    private func pull() {
        isEarlyUser = store.isGrandfathered
        tier = isEarlyUser ? .pro : LectureQSpec.tier(owned: store.purchasedProductIDs)
        ownedIDs = store.purchasedProductIDs
        products = store.products
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError
    }
}
