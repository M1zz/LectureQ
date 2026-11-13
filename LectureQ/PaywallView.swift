//
//  PaywallView.swift
//  LectureQ
//
//  **무료 · Plus · Pro 세 칸과 비교표를 한 장에** (→ Purchases.swift).
//
//  무료 칸을 먼저 세운다. 강의 10개까지는 질문을 남기고 답을 찾아 배운 점으로 정리하는 데
//  값을 받지 않는다. 사는 사람도 안 사는 사람도 이 화면을 닫고 나서 앱을 계속 쓴다.
//
//  유료 칸마다 연 구독(기본) · 평생을 고르고, 주 · 월 구독은 펼쳐서 고른다.
//  ⚠️ App Store 에서 불러온 상품만 단추로 선다. 아직 없는 상품은 자리를 비운다.
//  ⚠️ 구독을 파는 화면이라 심사가 보는 것: 가격과 기간, 첫 해 할인 뒤 값, 자동 갱신과 해지,
//     이용약관 · 개인정보 처리방침, 구매 복원. 하나라도 빠지면 돌아온다.
//

import SwiftUI
import StoreKit
import LeeoKit

/// 유료 칸을 사는 길.
enum PlanTerm: CaseIterable {
    case weekly, monthly, yearly, lifetime
}

struct PaywallView: View {
    /// 어느 문 앞에서 열렸는가. 그 기능이 든 칸과 비교표의 줄을 강조한다.
    var highlight: ProFeature?
    /// 처음 고를 길. 설정의 '평생으로 바꾸기' 는 평생으로 연다.
    var initialTerm: PlanTerm = .yearly

    @State private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 이 페이월이 떠 있는 창에 띄운다.
    @Environment(\.purchase) private var purchaseAction

    @State private var plusTerm: PlanTerm = .yearly
    @State private var proTerm: PlanTerm = .yearly
    /// 주 · 월 구독을 펼쳤는가.
    @State private var showsShortTerms = false
    /// 첫 해 할인을 받을 수 있는 구독. 이미 한 번 받은 사람에게 할인가를 말하면 거짓말이다.
    @State private var introEligible: Set<String> = []
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let highlight { reasonBanner(highlight) }
                    plansStatus
                    HStack(alignment: .top, spacing: 12) {
                        freeCard
                        paidCard(.plus)
                        paidCard(.pro)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    ComparisonTable(highlight: highlight)
                    if let message = purchases.failureMessage, purchases.isSelling {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .scaledFont(.body)
                            .foregroundStyle(.orange)
                    }
                    legal
                }
                .padding(24)
            }
            Divider()
            HStack {
                Button(LeeoLadderText.later) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("구매 복원") { Task { await purchases.restore() } }
                    .disabled(purchases.isWorking)
            }
            .padding(16)
        }
        .macFrame(width: 820, height: 680)
        .task {
            LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
            plusTerm = initialTerm
            proTerm = initialTerm
            if initialTerm == .weekly || initialTerm == .monthly { showsShortTerms = true }
            await loadPlans()
        }
        .onChange(of: purchases.products.map(\.id)) { _, _ in
            Task { await loadIntroEligibility() }
        }
        // 사거나 되찾아서 칸이 올라갔으면 이 화면은 할 일을 다 했다.
        .onChange(of: purchases.tier) { old, new in
            if new > old, new >= (highlight?.tier ?? .plus) { dismiss() }
        }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("질문 노트 Plus · Pro")
                .scaledFont(.title, weight: .bold)
                .accessibilityAddTraits(.isHeader)
            Text("궁금증을 끝까지 배운 점으로. 연 구독이나 평생 중에 고르세요.")
                .scaledFont(.title3)
                .foregroundStyle(.secondary)
        }
    }

    /// 방금 부딪힌 자리를 한 줄로.
    private func reasonBanner(_ feature: ProFeature) -> some View {
        Label {
            Text(verbatim: "\(feature.reasonTitle) · \(String(localized: "\(feature.tier.title)에서 열려요", comment: "Paywall: the feature opens with this plan. %@ = plan name"))")
                .scaledFont(.body, weight: .semibold)
        } icon: {
            Image(systemName: "lock.open")
                .accessibilityHidden(true)
        }
        .foregroundStyle(.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: 칸

    private var freeCard: some View {
        card(.free, tagline: "강의 10개까지, 질문을 남기고 답을 찾아 배운 점으로 정리해 보세요.") {
            EmptyView()
        }
    }

    private func paidCard(_ tier: LectureQTier) -> some View {
        let tagline: LocalizedStringKey = tier == .plus
            ? "강의 수 걱정 없이, AI 프롬프트 다섯 단계 전부."
            : "생각이 뻗어 간 지도와, 대화 기록을 바로 가져오기까지."
        return card(tier, tagline: tagline) {
            purchaseArea(tier)
        }
    }

    private func card<Footer: View>(_ tier: LectureQTier, tagline: LocalizedStringKey,
                                    @ViewBuilder footer: () -> Footer) -> some View {
        let current = purchases.tier == tier
        let included = purchases.tier > tier && tier != .free
        let emphasized = highlight.map { $0.tier == tier } ?? (tier == .pro)
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(tier.title)
                    .scaledFont(.title2, weight: .bold)
                    .accessibilityAddTraits(.isHeader)
                if tier == .pro, !current {
                    Text("추천")
                        .scaledFont(.body, weight: .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .background(Color.accentColor, in: Capsule())
                }
            }
            Text(tagline)
                .scaledFont(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if current {
                Label("지금 쓰는 중", systemImage: "checkmark.seal.fill")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(.tint)
            } else if included {
                Label("Pro에 포함", systemImage: "checkmark")
                    .scaledFont(.body)
                    .foregroundStyle(.secondary)
            } else {
                footer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            shape.fill(emphasized ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.03))
            shape.strokeBorder(emphasized || current ? Color.accentColor : Color.primary.opacity(0.08),
                               lineWidth: emphasized || current ? 1.5 : 1)
        }
    }

    // MARK: 고르고 사기

    private func term(_ tier: LectureQTier) -> Binding<PlanTerm> {
        tier == .plus ? $plusTerm : $proTerm
    }

    /// 그 칸의 그 길. 불러오지 못했으면 nil.
    /// **Plus 평생을 가진 사람에게는 Pro 평생 자리에 올리기 상품을 세운다** — 같은 것을 두 번 다 내고 사게 두지 않는다.
    private func product(_ tier: LectureQTier, _ term: PlanTerm) -> Product? {
        let id: String = switch (tier, term) {
        case (.plus, .weekly):   LectureQSpec.plusWeeklyID
        case (.plus, .monthly):  LectureQSpec.plusMonthlyID
        case (.plus, .yearly):   LectureQSpec.plusYearlyID
        case (.plus, .lifetime): LectureQSpec.plusLifetimeID
        case (_, .weekly):       LectureQSpec.proWeeklyID
        case (_, .monthly):      LectureQSpec.proMonthlyID
        case (_, .yearly):       LectureQSpec.proYearlyID
        case (_, .lifetime):     purchases.ownsPlusLifetime ? LectureQSpec.proUpgradeID : LectureQSpec.proLifetimeID
        }
        return purchases.product(id)
    }

    @ViewBuilder
    private func purchaseArea(_ tier: LectureQTier) -> some View {
        let shown: [PlanTerm] = showsShortTerms ? PlanTerm.allCases : [.yearly, .lifetime]
        let available = shown.filter { product(tier, $0) != nil }
        if !available.isEmpty {
            let chosenTerm = available.contains(term(tier).wrappedValue) ? term(tier).wrappedValue : available[0]
            let chosen = product(tier, chosenTerm)
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(available, id: \.self) { option in
                        termButton(tier, option, selected: option == chosenTerm)
                    }
                }
                if let note = note(tier, chosenTerm) {
                    Text(note)
                        .scaledFont(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !showsShortTerms, product(tier, .weekly) != nil || product(tier, .monthly) != nil {
                    Button("주 · 월 구독도 보기") { showsShortTerms = true }
                        .linkButtonStyle()
                        .scaledFont(.body)
                }
                Button {
                    guard let chosen else { return }
                    Task { await purchases.purchase(chosen, using: purchaseAction) }
                } label: {
                    Group {
                        if purchases.isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(buyTitle(chosen))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(purchases.isWorking || chosen == nil)
            }
        }
    }

    private func termButton(_ tier: LectureQTier, _ option: PlanTerm, selected: Bool) -> some View {
        let price = product(tier, option)?.displayPrice ?? ""
        let (title, priceText): (String, String) = switch option {
        case .weekly:   (String(localized: "주 구독", comment: "Plan term: weekly subscription"),
                         String(localized: "\(price) / 주", comment: "Weekly price. %@ = price"))
        case .monthly:  (String(localized: "월 구독", comment: "Plan term: monthly subscription"),
                         String(localized: "\(price) / 월", comment: "Monthly price. %@ = price"))
        case .yearly:   (LeeoLadderText.yearly, String(format: LeeoLadderText.perYearFormat, price))
        case .lifetime: (LeeoLadderText.lifetime, price)
        }
        return Button {
            term(tier).wrappedValue = option
        } label: {
            VStack(spacing: 2) {
                Text(title).scaledFont(.body, weight: .semibold)
                Text(priceText).scaledFont(.body, monospacedDigit: true)
            }
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(title), \(priceText)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// 고른 길 아래 한 줄: 첫 해 할인, 평생이 연 구독 몇 년치인지, 올리기 값.
    private func note(_ tier: LectureQTier, _ term: PlanTerm) -> String? {
        switch term {
        case .yearly:
            guard let product = product(tier, .yearly), introEligible.contains(product.id),
                  let offer = product.subscription?.introductoryOffer else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            if tier == .pro, purchases.ownsPlusLifetime {
                return String(localized: "Plus 평생을 가지고 계셔서 올리는 값만 받아요.",
                              comment: "Paywall: Plus lifetime owners pay only the upgrade price for Pro lifetime")
            }
            guard let yearly = product(tier, .yearly)?.price, let lifetime = product(tier, .lifetime)?.price,
                  yearly > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime / yearly).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        case .weekly, .monthly:
            return nil
        }
    }

    /// "₩8,800 결제". 첫 해 할인을 받을 수 있으면 실제로 나갈 할인가를 적는다.
    private func buyTitle(_ product: Product?) -> String {
        guard let product else { return "" }
        var price = product.displayPrice
        if introEligible.contains(product.id), let offer = product.subscription?.introductoryOffer {
            price = offer.displayPrice
        }
        return String(localized: "\(price) 결제", comment: "Paywall buy button. %@ = price")
    }

    // MARK: 불러오기

    @ViewBuilder
    private var plansStatus: some View {
        if !purchases.isSelling {
            if loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("요금제를 불러오는 중…")
                        .scaledFont(.body)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Text("요금제를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 불러와 주세요.")
                        .scaledFont(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        Task { await loadPlans() }
                    } label: {
                        Label("다시 불러오기", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    /// 요금제를 불러온다. 샌드박스는 첫 조회가 빈손으로 돌아오는 일이 잦아 한 번 더 청한다.
    private func loadPlans() async {
        loading = true
        await purchases.loadProducts()
        if !purchases.isSelling {
            try? await Task.sleep(for: .seconds(1.5))
            await purchases.loadProducts()
        }
        await loadIntroEligibility()
        loading = false
    }

    private func loadIntroEligibility() async {
        var eligible: Set<String> = []
        for product in purchases.products {
            if let sub = product.subscription, sub.introductoryOffer != nil, await sub.isEligibleForIntroOffer {
                eligible.insert(product.id)
            }
        }
        introEligible = eligible
    }

    // MARK: 약관

    private var legal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 값으로 자동 갱신되며, Apple 계정으로 결제됩니다. 처음 구독하는 분께는 연 구독 첫 해 할인이 한 번 적용되고, 그 뒤에는 정가로 갱신됩니다. 해지와 관리는 App Store 계정 설정에서 합니다. 평생은 한 번만 결제하고 갱신되지 않습니다.")
                .scaledFont(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                if let terms = LectureQSpec.monetization.subscriptionTermsURL {
                    Button("이용약관") { openURL(terms) }
                }
                Button("개인정보 처리방침") { openURL(LectureQSpec.legal.privacyURL) }
            }
            .linkButtonStyle()
            .scaledFont(.body)
        }
    }
}

// MARK: - 비교표

/// 칸마다 무엇이 열리는지. 방금 부딪힌 기능의 줄을 강조한다.
private struct ComparisonTable: View {
    let highlight: ProFeature?

    private enum Cell {
        case text(String), included, excluded
    }

    private struct Row: Identifiable {
        let title: String
        let cells: [Cell]   // 무료 · Plus · Pro
        var feature: ProFeature?
        var id: String { title }
    }

    private var rows: [Row] {
        let unlimited = String(localized: "무제한", comment: "Comparison table: no limit")
        return [
            Row(title: String(localized: "강의"),
                cells: [.text(String(localized: "\(LectureQSpec.freeLectureLimit)개", comment: "Comparison table: count of lectures")),
                        .text(unlimited), .text(unlimited)],
                feature: .unlimitedLectures),
            Row(title: String(localized: "질문 · 꼬리질문"), cells: [.text(unlimited), .text(unlimited), .text(unlimited)]),
            Row(title: String(localized: "타임블록 메모 · 강의 요약"), cells: [.included, .included, .included]),
            Row(title: String(localized: "AI 프롬프트"),
                cells: [.text(String(localized: "\(2)단계", comment: "Comparison table: number of AI prompt steps")),
                        .text(String(localized: "\(5)단계", comment: "Comparison table: number of AI prompt steps")),
                        .text(String(localized: "\(5)단계", comment: "Comparison table: number of AI prompt steps"))],
                feature: .allPrompts),
            Row(title: String(localized: "학습 상태"), cells: [.excluded, .included, .included], feature: .learningState),
            Row(title: ProFeature.graph.reasonTitle, cells: [.excluded, .excluded, .included], feature: .graph),
            Row(title: ProFeature.timeline.reasonTitle, cells: [.excluded, .excluded, .included], feature: .timeline),
            Row(title: ProFeature.markdownImport.reasonTitle, cells: [.excluded, .excluded, .included], feature: .markdownImport),
            Row(title: ProFeature.shortcuts.reasonTitle, cells: [.excluded, .excluded, .included], feature: .shortcuts),
        ]
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
            GridRow {
                Text("기능")
                ForEach(LectureQTier.allCases, id: \.self) { tier in
                    Text(tier.title).gridColumnAlignment(.center)
                }
            }
            .scaledFont(.body, weight: .semibold)
            .padding(.vertical, 6)
            Divider()
            ForEach(rows) { row in
                let lit = row.feature != nil && row.feature == highlight
                GridRow {
                    // 방금 부딪힌 기능의 줄은 이름을 강조색 · 굵게.
                    Text(row.title)
                        .fontWeight(lit ? .semibold : .regular)
                        .foregroundStyle(lit ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    ForEach(row.cells.indices, id: \.self) { i in
                        cell(row.cells[i])
                            .frame(maxWidth: .infinity)
                    }
                }
                .scaledFont(.body)
                .padding(.vertical, 6)
                Divider()
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func cell(_ cell: Cell) -> some View {
        switch cell {
        case .text(let s):
            Text(s)
        case .included:
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .accessibilityLabel(String(localized: "포함", comment: "Comparison table: included"))
        case .excluded:
            Text(verbatim: "–")
                .foregroundStyle(.tertiary)
                .accessibilityLabel(String(localized: "없음", comment: "Comparison table: not included"))
        }
    }
}

// MARK: - 기능 이름

extension ProFeature {
    /// 페이월 머리의 한 줄과 비교표의 줄 이름.
    var reasonTitle: String {
        switch self {
        case .unlimitedLectures:
            String(localized: "강의 \(LectureQSpec.freeLectureLimit)개를 기록했어요",
                   comment: "Paywall reason: the free lecture limit is reached")
        case .allPrompts:
            [AIPrompt.verify, .followUps, .grade].map(\.title).joined(separator: " · ")
        case .learningState:
            String(localized: "학습 상태")
        case .graph:
            String(localized: "질문 그래프", comment: "Feature: graph of questions and follow-ups")
        case .timeline:
            String(localized: "타임블록 모아보기", comment: "Feature: every lecture's time blocks in one timeline")
        case .markdownImport:
            String(localized: "마크다운 가져오기", comment: "Feature: import a conversation from Markdown")
        case .shortcuts:
            String(localized: "단축어 · Siri 질문 추가", comment: "Feature: add a question with Shortcuts or Siri")
        }
    }
}
