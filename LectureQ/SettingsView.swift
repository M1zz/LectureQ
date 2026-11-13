import SwiftUI
import LeeoKit

/// 앱 메뉴 ▸ 설정… (⌘,) 창.
/// 피드백 보내기 · 보낸 피드백 · 리뷰 남기기 · 개인정보/지원 링크 · 버전은 LeeoSupportSection 이,
/// 메일 문의와 인스타그램은 이 화면이 직접 둔다.
struct SettingsView: View {
    private static let instagramURL = URL(string: "https://instagram.com/lee25_ios")!
    private static let subscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    // 요금제 (→ Purchases.swift, PaywallView.swift)
    @State private var purchases = PurchaseManager.shared
    @State private var showingPaywall = false
    /// 페이월을 평생으로 골라 둔 채 여는가 ('평생으로 바꾸기').
    @State private var paywallTerm: PlanTerm = .yearly
    /// 구독을 평생으로 바꾸는 시트 (→ LeeoGraduationOfferView).
    @State private var showingGraduation = false
    @State private var restoreMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                planSection

                Section("지원") {
                    LeeoSupportSection<LectureQSpec>()
                }

                Section {
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<LectureQSpec>()
                    LeeoTipJarLink<LectureQSpec>(tipJar: PurchaseManager.shared.tipJar)
                }

                Section {
                    if let mail = Self.mailURL {
                        Link(destination: mail) {
                            Label("메일로 문의하기", systemImage: "envelope")
                        }
                        .help(LectureQSpec.developerEmail)
                    }
                    Link(destination: Self.instagramURL) {
                        Label("인스타그램에서 소식 보기", systemImage: "camera")
                    }
                } header: {
                    Text("연락하기")
                } footer: {
                    #if os(macOS)
                    Text("문의하실 때 macOS 버전과 어떤 동작에서 문제가 생겼는지 적어 주시면 빠르게 확인할 수 있어요.")
                        .foregroundStyle(.secondary)
                    #else
                    Text("문의하실 때 iOS 버전과 어떤 동작에서 문제가 생겼는지 적어 주시면 빠르게 확인할 수 있어요.")
                        .foregroundStyle(.secondary)
                    #endif
                }
            }
            .formStyle(.grouped)
            #if !os(macOS)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            #endif
        }
        .macFrame(width: 480, height: 600)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(initialTerm: paywallTerm)
        }
        .sheet(isPresented: $showingGraduation) {
            LeeoGraduationOfferView(graduate: purchases.graduateProduct) {
                await purchases.refresh()
            }
        }
    }

    /// 지금 쓰는 칸 · 요금제 보기 · 구독 관리 · 평생으로 바꾸기 · 구매 복원.
    private var planSection: some View {
        Section {
            LabeledContent("지금 쓰는 칸", value: purchases.tier.title)
            if purchases.isEarlyUser {
                Text("처음부터 함께해 주셔서 Pro를 그대로 드려요.")
                    .foregroundStyle(.secondary)
            }
            if purchases.tier < .pro {
                Button("요금제 보기") { openPaywall(.yearly) }
            }
            if purchases.subscription != nil {
                Link(LeeoLadderText.manageSubscription, destination: Self.subscriptionsURL)
            }
            // 평생이 아닌 사람에게 늘 선다. 구독 중이면 졸업가로, 아니면 평생을 골라 둔 요금제로.
            if !purchases.ownsLifetimePro, !purchases.ownsPlusLifetime {
                Button(LeeoLadderText.switchToLifetimeEntry) {
                    if purchases.subscription != nil, purchases.graduateProduct != nil {
                        showingGraduation = true
                    } else {
                        openPaywall(.lifetime)
                    }
                }
            }
            Button("구매 복원") {
                Task {
                    restoreMessage = nil
                    await purchases.restore()
                    if purchases.tier == .free { restoreMessage = purchases.failureMessage }
                }
            }
            .disabled(purchases.isWorking)
            if let restoreMessage {
                Text(restoreMessage)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("요금제")
        }
    }

    private func openPaywall(_ term: PlanTerm) {
        paywallTerm = term
        showingPaywall = true
    }

    /// 받는 사람 · 제목 · 앱/OS 버전이 채워진 메일 초안.
    private static var mailURL: URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #if os(macOS)
        let body = String(localized: "\n\n\n—\n앱 버전: \(version) (\(build))\nmacOS: \(os)")
        #else
        let body = String(localized: "\n\n\n—\n앱 버전: \(version) (\(build))\niOS: \(os)")
        #endif
        var c = URLComponents(string: "mailto:\(LectureQSpec.developerEmail)")
        c?.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "[\(LectureQSpec.appName)] 문의")),
            URLQueryItem(name: "body", value: body)
        ]
        return c?.url
    }
}
