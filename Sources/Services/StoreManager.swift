import Foundation
import StoreKit
import SwiftUI
import UserNotifications

enum FlatBillProductID {
    static let lifetime = "com.yanghe.flatbill.pro.lifetime"
    static let yearly = "com.yanghe.flatbill.pro.yearly"
    static let monthly = "com.yanghe.flatbill.pro.monthly"
    static let all: [String] = [lifetime, yearly, monthly]
}

@MainActor
final class StoreManager: ObservableObject {
    /// Plug free-tier leak: 2 lifetime free PDF exports total (unlimited drafts & live PDF preview).
    static let freeLifetimeExportLimit = 2
    static let freeMonthlyExportLimit = 2

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var statusMessage: String?

    @Published private(set) var totalSuccessfulExports: Int = 0

    private let totalKey = "flatbill.total.exports"
    private let proCacheKey = "flatbill.pro.cached"

    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: proCacheKey)
        totalSuccessfulExports = UserDefaults.standard.integer(forKey: totalKey)

        updatesTask = Task {
            await listenForTransactions()
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var remainingFreeExports: Int {
        max(0, Self.freeLifetimeExportLimit - totalSuccessfulExports)
    }

    var remainingFreeExportsThisMonth: Int {
        remainingFreeExports
    }

    var canExportFreePDF: Bool {
        isPro || remainingFreeExports > 0
    }

    func recordPDFExport() {
        totalSuccessfulExports += 1
        UserDefaults.standard.set(totalSuccessfulExports, forKey: totalKey)
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for id: String) -> String {
        if let p = product(for: id) {
            return p.displayPrice
        }
        switch id {
        case FlatBillProductID.lifetime: return L10n.t("$29.99", "¥98", "HK$148")
        case FlatBillProductID.yearly: return L10n.t("$19.99", "¥58", "HK$88")
        case FlatBillProductID.monthly: return L10n.t("$6.99", "¥18", "HK$28")
        default: return ""
        }
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: FlatBillProductID.all)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            // Fallback display prices stay visible offline
        }
    }

    func purchase(_ productId: String) async -> Bool {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        if products.isEmpty {
            await loadProducts()
        }
        guard let target = product(for: productId) else {
            statusMessage = L10n.t(
                "App Store products are syncing. Please check your connection and try again.",
                "苹果商店内购信息正在同步，请检查网络后重试。"
            )
            return false
        }

        do {
            let result = try await target.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    if productId == FlatBillProductID.yearly {
                        scheduleTrialReminder()
                    }
                    statusMessage = L10n.t("FlatBill Pro unlocked! Unlimited PDFs enabled.", "已解锁 FlatBill 永久/专业版！")
                    return true
                case .unverified:
                    statusMessage = L10n.t("Purchase verification failed. Please retry.", "交易校验未通过，请重试。")
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                statusMessage = L10n.t("Purchase is pending approval.", "交易等待审批中。")
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = L10n.t("Purchase failed: \(error.localizedDescription)", "购买未完成：\(error.localizedDescription)")
            return false
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = isPro
                ? L10n.t("FlatBill Pro restored successfully!", "已成功恢复 FlatBill Pro 权益！")
                : L10n.t("No active purchases found on this Apple Account.", "当前苹果账号下未找到已购记录。")
        } catch {
            statusMessage = L10n.t("Restore failed. Please try again shortly.", "恢复购买失败，请稍后再试。")
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               FlatBillProductID.all.contains(tx.productID),
               tx.revocationDate == nil {
                unlocked = true
                break
            }
        }
        isPro = unlocked
        UserDefaults.standard.set(unlocked, forKey: proCacheKey)
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let tx) = update {
                await tx.finish()
                await refreshEntitlements()
            }
        }
    }

    private func scheduleTrialReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = L10n.t("FlatBill · Free Trial Ends in 2 Days", "FlatBill · 7 天免费试用还剩 2 天", "FlatBill · 7 天免費試用還剩 2 天")
            content.body = L10n.t(
                "Your 7-day free trial ends in 48 hours. Cancel anytime in iOS Settings > Subscriptions if you don't wish to renew.",
                "您的 7 天免费试用将在 48 小时后到期，如暂不需要可在系统“订阅”中一键取消。",
                "您的 7 天免費試用將在 48 小時後到期，如暫不需要可在系統「訂閱項目」中一鍵取消。"
            )
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 24 * 3600, repeats: false)
            let req = UNNotificationRequest(identifier: "flatbill.trial.reminder", content: content, trigger: trigger)
            center.add(req)
        }
    }
}
