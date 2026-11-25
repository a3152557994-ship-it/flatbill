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
    static let freeMonthlyExportLimit = 3

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var statusMessage: String?

    @Published private(set) var exportsUsedThisMonth: Int = 0
    @Published private(set) var totalSuccessfulExports: Int = 0

    private let monthKey = "flatbill.quota.month"
    private let countKey = "flatbill.quota.count"
    private let totalKey = "flatbill.total.exports"
    private let proCacheKey = "flatbill.pro.cached"

    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: proCacheKey)
        totalSuccessfulExports = UserDefaults.standard.integer(forKey: totalKey)
        syncMonthlyQuotaIfNeeded()

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

    var remainingFreeExportsThisMonth: Int {
        max(0, Self.freeMonthlyExportLimit - exportsUsedThisMonth)
    }

    var canExportFreePDF: Bool {
        isPro || remainingFreeExportsThisMonth > 0
    }

    func recordPDFExport() {
        syncMonthlyQuotaIfNeeded()
        exportsUsedThisMonth += 1
        totalSuccessfulExports += 1
        UserDefaults.standard.set(exportsUsedThisMonth, forKey: countKey)
        UserDefaults.standard.set(totalSuccessfulExports, forKey: totalKey)
    }

    func syncMonthlyQuotaIfNeeded() {
        let stamp = Self.monthStamp()
        let saved = UserDefaults.standard.string(forKey: monthKey)
        if saved != stamp {
            UserDefaults.standard.set(stamp, forKey: monthKey)
            UserDefaults.standard.set(0, forKey: countKey)
            exportsUsedThisMonth = 0
        } else {
            exportsUsedThisMonth = UserDefaults.standard.integer(forKey: countKey)
        }
    }

    private static func monthStamp() -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: Date())
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func displayPrice(for id: String) -> String {
        if let p = product(for: id) {
            return p.displayPrice
        }
        switch id {
        case FlatBillProductID.lifetime: return L10n.t("$19.99", "¥68")
        case FlatBillProductID.yearly: return L10n.t("$9.99", "¥38")
        case FlatBillProductID.monthly: return L10n.t("$2.99", "¥12")
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
            content.title = L10n.t("FlatBill · Free Trial Ends Tomorrow", "FlatBill · 免费试用明天到期")
            content.body = L10n.t(
                "Your 3-day free trial ends in 24 hours. Cancel anytime in iOS Settings > Subscriptions if you don't wish to renew.",
                "您的 3 天免费试用还剩 24 小时，如暂不需要可在系统“订阅”中一键取消。"
            )
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
            let req = UNNotificationRequest(identifier: "flatbill.trial.reminder", content: content, trigger: trigger)
            center.add(req)
        }
    }
}
