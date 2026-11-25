import Foundation
import StoreKit
import SwiftUI
import UIKit

/// Privacy-safe 100% local funnel diagnostics (ZERO network calls; preserves Apple "Data Not Collected").
enum FunnelMetrics {
    private static let prefix = "flatbill.funnel."

    enum Event: String {
        case onboardingCompleted = "onboarding_completed"
        case pdfExported = "pdf_exported"
        case paywallViewed = "paywall_viewed"
        case purchaseTapped = "purchase_tapped"
        case purchaseSucceeded = "purchase_succeeded"
        case abandonOfferShown = "abandon_offer_shown"
        case reviewHappyYes = "review_happy_yes"
        case reviewFeedbackNo = "review_feedback_no"
    }

    static func record(_ event: Event) {
        let key = prefix + event.rawValue
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
    }

    static func count(_ event: Event) -> Int {
        UserDefaults.standard.integer(forKey: prefix + event.rawValue)
    }
}

/// Happy-Path Review Gate: prompts happy users for native Apple rating; routes issues to support email.
enum ReviewPromptManager {
    private static let lastPromptKey = "flatbill.review.lastPromptEpoch"
    private static let cooldownSeconds: TimeInterval = 90 * 24 * 3600

    static let supportEmail = "a3152557994@gmail.com"

    static func shouldShowHappyGate(totalExports: Int) -> Bool {
        guard totalExports >= 1 else { return false }
        let last = UserDefaults.standard.double(forKey: lastPromptKey)
        if last > 0, Date().timeIntervalSince1970 - last < cooldownSeconds {
            return false
        }
        return true
    }

    static func markPromptShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
    }

    @MainActor
    static func triggerNativeAppleReview() {
        FunnelMetrics.record(.reviewHappyYes)
        markPromptShown()
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    @MainActor
    static func openSupportFeedbackEmail() {
        FunnelMetrics.record(.reviewFeedbackNo)
        markPromptShown()
        let subject = "FlatBill Feedback (v1.0.1)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "FlatBill"
        if let url = URL(string: "mailto:\(supportEmail)?subject=\(subject)") {
            UIApplication.shared.open(url)
        }
    }
}

struct PortfolioTool: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let appStoreURL: URL

    static var crossPromoTools: [PortfolioTool] {
        [
            PortfolioTool(
                id: "miledeck",
                icon: "car.fill",
                tint: Color(red: 0.08, green: 0.56, blue: 0.36),
                title: L10n.t("MileDeck — Auto Mileage Tax Log", "MileDeck 自动里程抵税记录", "MileDeck 自動里程報稅紀錄"),
                subtitle: L10n.t("Drive to job sites? Auto-log business miles offline for tax write-offs.", "开车跑工地必备：自动记录商务里程与 IRS/HMRC 抵税账本。", "開車跑案場必備：離線自動記錄商務里程與報稅帳本。"),
                appStoreURL: URL(string: "https://apps.apple.com/app/id6839022103")!
            ),
            PortfolioTool(
                id: "flatshift",
                icon: "clock.badge.checkmark.fill",
                tint: Color(red: 0.16, green: 0.36, blue: 0.78),
                title: L10n.t("FlatShift — Hours & Overtime Pay", "FlatShift 倒班排班与加班算薪", "FlatShift 排班日曆與加班試算"),
                subtitle: L10n.t("Zero-ad shift calendar, clock-in & exact overtime paycheck math.", "无广告离线倒班日历、打卡与加班费精算工具。", "無廣告離線排班日曆、打卡與加班費試算工具。"),
                appStoreURL: URL(string: "https://apps.apple.com/app/id6839022439")!
            ),
            PortfolioTool(
                id: "purescan",
                icon: "barcode.viewfinder",
                tint: Color(red: 0.14, green: 0.54, blue: 0.32),
                title: L10n.t("PureScan — Ingredient Scanner", "PureScan 配料照妖镜", "PureScan 配料照妖鏡"),
                subtitle: L10n.t("Snap any food or skincare label offline to spot additives fast.", "逛超市离线拍配料表，0.3秒识别食品添加剂与控糖避雷。", "逛超市離線拍成分表，0.3秒辨識食品添加劑與避雷。"),
                appStoreURL: URL(string: "https://apps.apple.com/app/id6837347918")!
            ),
            PortfolioTool(
                id: "cleanshield",
                icon: "shield.lefthalf.filled",
                tint: Color(red: 0.11, green: 0.42, blue: 0.72),
                title: L10n.t("CleanShield — AdBlock & Photo GPS", "净盾 Safari 去广告与抹除定位", "淨盾 Safari 去廣告與隱私保護"),
                subtitle: L10n.t("Block Safari popups and scrub home GPS before sharing photos.", "拦截 Safari 弹窗广告，发图前一键抹除家庭 GPS 定位。", "攔截 Safari 彈窗廣告，發圖前一鍵抹除家庭 GPS 定位。"),
                appStoreURL: URL(string: "https://apps.apple.com/app/id6836843272")!
            ),
        ]
    }
}
