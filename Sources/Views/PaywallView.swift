import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var triggerMessage: String? = nil
    var freeFallbackLabel: String? = nil
    var onFreeFallback: (() -> Void)? = nil

    @State private var selectedProductID: String = FlatBillProductID.lifetime

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/terms.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Hero Banner
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "seal.fill")
                                .foregroundStyle(FlatTheme.accent)
                            Text(L10n.t("OWN IT ONCE • ZERO RENT-SEEKING", "买断用终身 • 告别高价年卡"))
                                .font(.caption.weight(.bold))
                                .tracking(0.6)
                                .foregroundStyle(FlatTheme.accent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(FlatTheme.accent.opacity(0.16))
                        .clipShape(Capsule())

                        Text(L10n.t("Stop Paying $200+/yr\nJust to Send PDF Invoices", "别再为了发 PDF 单据\n每年交几百块订阅费"))
                            .font(.system(size: 26, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        if let triggerMessage {
                            Text(triggerMessage)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.84))
                                .padding(.top, 2)
                        } else {
                            Text(L10n.t("Unlimited PDFs, all 4 executive themes, job-site photo pages, and 0% payment fees.", "解锁无限导出 PDF、4 套专业模板、现场附图附页与税务报表，零平台抽成。"))
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.82))
                        }

                        // Side-by-side price comparison anchor (no third-party trademarks)
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t("Typical Invoice Apps", "常见订阅制开单软件"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                Text(L10n.t("$200–$360 / yr", "¥268–¥598 / 年"))
                                    .font(.callout.weight(.bold).monospacedDigit())
                                    .strikethrough(true, color: .red)
                                    .foregroundStyle(Color.white.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t("FlatBill Lifetime", "FlatBill 永久买断"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(FlatTheme.accent)
                                Text(store.displayPrice(for: FlatBillProductID.lifetime) + L10n.t(" once", " 一次付清"))
                                    .font(.callout.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(FlatTheme.accent.opacity(0.24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(FlatTheme.accent, lineWidth: 1.2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(FlatTheme.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Benefits Checklist
                    VStack(alignment: .leading, spacing: 11) {
                        benefitRow("doc.badge.plus", L10n.t("Unlimited PDF invoices, estimates & receipts", "无限导出高清 PDF 报价单、发票与收据"))
                        benefitRow("paintpalette.fill", L10n.t("All 4 pro PDF themes & remove FlatBill footer", "全部 4 套专业单据模板，彻底去除底部标识"))
                        benefitRow("photo.on.rectangle.angled", L10n.t("Unlimited job-site before/after photo pages", "无限附加施工前后照片附页，绝不遮挡正文"))
                        benefitRow("tablecells.fill", L10n.t("1-tap CSV tax report & full JSON backup", "一键导出年度税务 CSV 报表与本地全量备份"))
                    }
                    .flatCard(padding: 16)

                    // 3 Plan Options
                    VStack(spacing: 10) {
                        planCard(
                            id: FlatBillProductID.lifetime,
                            title: L10n.t("Lifetime Pro (Pay Once)", "永久买断版（一次付清）"),
                            subtitle: L10n.t("Own forever • No recurring bills • Best Value", "终身拥有 • 永不续费 • 最划算"),
                            price: store.displayPrice(for: FlatBillProductID.lifetime),
                            period: L10n.t("one-time", "终身"),
                            badge: L10n.t("MOST POPULAR", "老板首选")
                        )

                        planCard(
                            id: FlatBillProductID.yearly,
                            title: L10n.t("Annual Pro (3-Day Free Trial)", "年度会员（含 3 天免费试用）"),
                            subtitle: L10n.t("Try free for 3 days • Reminder sent 24h before renewal", "先免费试 3 天 • 扣费前 24 小时主动提醒"),
                            price: store.displayPrice(for: FlatBillProductID.yearly),
                            period: L10n.t("/ year", "/ 年"),
                            badge: L10n.t("FREE TRIAL", "3天试用")
                        )

                        planCard(
                            id: FlatBillProductID.monthly,
                            title: L10n.t("Monthly Pro", "月度灵活版"),
                            subtitle: L10n.t("Cancel anytime in Apple ID settings", "按月付、随时可在苹果订阅中取消"),
                            price: store.displayPrice(for: FlatBillProductID.monthly),
                            period: L10n.t("/ month", "/ 月"),
                            badge: nil
                        )
                    }

                    // Primary CTA
                    Button {
                        Task {
                            let ok = await store.purchase(selectedProductID)
                            if ok { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isPurchasing {
                                ProgressView().tint(.white)
                            }
                            Text(ctaLabel)
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(FlatTheme.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(store.isPurchasing)

                    if let status = store.statusMessage {
                        Text(status)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(FlatTheme.accent)
                            .multilineTextAlignment(.center)
                    }

                    // Non-hostile Free Exit
                    if let freeFallbackLabel, let onFreeFallback {
                        Button {
                            dismiss()
                            onFreeFallback()
                        } label: {
                            Text(freeFallbackLabel)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(FlatTheme.muted)
                        }
                        .padding(.top, 2)
                    }

                    // Apple 3.1.2 Compliance Disclosure + Restore + Privacy + Terms
                    VStack(spacing: 8) {
                        HStack(spacing: 18) {
                            Button(L10n.t("Restore Purchases", "恢复购买")) {
                                Task { await store.restorePurchases() }
                            }
                            Link(L10n.t("Privacy Policy", "隐私政策"), destination: privacyURL)
                            Link(L10n.t("Terms of Use", "使用条款"), destination: termsURL)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(FlatTheme.ink)

                        Text(L10n.t(
                            "Lifetime Pro is a one-time non-consumable purchase. Annual (\(store.displayPrice(for: FlatBillProductID.yearly))/year after 3-day free trial) and Monthly (\(store.displayPrice(for: FlatBillProductID.monthly))/month) plans auto-renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple Account > Subscriptions.",
                            "永久买断版为一次性买断内购。年度会员（含3天免费试用，到期按 \(store.displayPrice(for: FlatBillProductID.yearly))/年自动续订）与月度会员（\(store.displayPrice(for: FlatBillProductID.monthly))/月自动续订）可随时在 iPhone「设置 > Apple 账户 > 订阅」中提前 24 小时取消。"
                        ))
                        .font(.caption2)
                        .foregroundStyle(FlatTheme.muted)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("FlatBill Pro", "升级 FlatBill Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Close", "关闭")) { dismiss() }
                }
            }
        }
    }

    private var ctaLabel: String {
        switch selectedProductID {
        case FlatBillProductID.lifetime:
            return L10n.t(
                "Unlock Lifetime Pro — \(store.displayPrice(for: FlatBillProductID.lifetime)) Once",
                "一次买断永久版 — \(store.displayPrice(for: FlatBillProductID.lifetime))"
            )
        case FlatBillProductID.yearly:
            return L10n.t(
                "Start 3-Day Free Trial (Then \(store.displayPrice(for: FlatBillProductID.yearly))/yr)",
                "开启 3 天免费试用（随后 \(store.displayPrice(for: FlatBillProductID.yearly))/年）"
            )
        default:
            return L10n.t(
                "Subscribe Monthly — \(store.displayPrice(for: FlatBillProductID.monthly))/mo",
                "按月开通 — \(store.displayPrice(for: FlatBillProductID.monthly))/月"
            )
        }
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FlatTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(FlatTheme.ink)
            Spacer()
        }
    }

    private func planCard(
        id: String,
        title: String,
        subtitle: String,
        price: String,
        period: String,
        badge: String?
    ) -> some View {
        let selected = selectedProductID == id
        return Button {
            selectedProductID = id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? FlatTheme.accent : FlatTheme.border)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(FlatTheme.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(id == FlatBillProductID.lifetime ? FlatTheme.accent : FlatTheme.estimateBlue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(FlatTheme.muted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(price)
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(FlatTheme.ink)
                    Text(period)
                        .font(.caption2)
                        .foregroundStyle(FlatTheme.muted)
                }
            }
            .padding(14)
            .background(selected ? FlatTheme.accentSoft : FlatTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? FlatTheme.accent : FlatTheme.border, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
