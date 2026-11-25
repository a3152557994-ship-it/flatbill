import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var triggerMessage: String? = nil
    var invoiceAmountText: String? = nil
    var freeFallbackLabel: String? = nil
    var onFreeFallback: (() -> Void)? = nil

    @State private var selectedProductID: String = FlatBillProductID.lifetime
    @State private var showAbandonSheet: Bool = false

    private let style: RegionalPaywallStyle = L10n.paywallStyle
    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/terms.html")!
    private let abandonKey = "flatbill.paywall.abandonShownOnce"

    init(
        triggerMessage: String? = nil,
        invoiceAmountText: String? = nil,
        freeFallbackLabel: String? = nil,
        onFreeFallback: (() -> Void)? = nil
    ) {
        self.triggerMessage = triggerMessage
        self.invoiceAmountText = invoiceAmountText
        self.freeFallbackLabel = freeFallbackLabel
        self.onFreeFallback = onFreeFallback
        // Region-tailored default selection:
        // EU/DE/CH/UK strongly prefer transparent Lifetime one-time purchase;
        // US/CA/AU & East Asia see Lifetime highlighted right alongside 7-day zero-risk trial.
        let initialDefault: String = (L10n.paywallStyle == .angloROI)
            ? FlatBillProductID.yearly
            : FlatBillProductID.lifetime
        _selectedProductID = State(initialValue: initialDefault)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroHeader

                    if style == .eastAsiaDetail {
                        eastAsiaComparisonTable
                    } else {
                        benefitsChecklist
                    }

                    // 3 Plan Options (High monthly anchor + 7-day trial yearly + Lifetime only +$10 more)
                    VStack(spacing: 10) {
                        if style == .euPrivacyLifetime {
                            lifetimePlanCard
                            yearlyPlanCard
                            monthlyPlanCard
                        } else {
                            lifetimePlanCard
                            yearlyPlanCard
                            monthlyPlanCard
                        }
                    }

                    // Honest Blinkist 3-Step Timeline when Yearly 7-Day Free Trial is selected
                    if selectedProductID == FlatBillProductID.yearly {
                        trialTimelineCard
                    }

                    // Primary CTA
                    Button {
                        FunnelMetrics.record(.purchaseTapped)
                        Task {
                            let ok = await store.purchase(selectedProductID)
                            if ok {
                                FunnelMetrics.record(.purchaseSucceeded)
                                dismiss()
                            }
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

                    complianceFooter
                }
                .padding(16)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("FlatBill Pro", "升级 FlatBill Pro", "升級 FlatBill Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Close", "关闭", "關閉")) {
                        handleCloseTap()
                    }
                }
            }
            .onAppear {
                FunnelMetrics.record(.paywallViewed)
            }
            .sheet(isPresented: $showAbandonSheet) {
                abandonOfferSheet
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Regional Hero Variants

    @ViewBuilder
    private var heroHeader: some View {
        switch style {
        case .euPrivacyLifetime:
            // Calm, factual, GDPR-first, zero flashy red-strikethrough hype
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color(red: 0.48, green: 0.90, blue: 0.66))
                    Text(L10n.t("100% OFFLINE • GDPR PRIVATE • PAY ONCE", "100% 本地离线 • 隐私安全 • 一次买断", "100% 本機離線 • 隱私保護 • 一次買斷"))
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(Color(red: 0.48, green: 0.90, blue: 0.66))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.10))
                .clipShape(Capsule())

                Text(L10n.t(
                    "Own FlatBill Once.\nKeep All Invoice Data on Your Device.",
                    "一次买断 FlatBill 永久版\n所有账单仅存本地，绝不上传云端",
                    "一次買斷 FlatBill 永久版\n所有單據僅存本機，絕不上傳雲端"
                ))
                .font(.system(size: 22, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

                Text(triggerMessage ?? L10n.t(
                    "Unlimited A4 & Letter PDFs, VAT/GST fields, all 4 clean templates, zero ads, and optional one-time license with no recurring commitment.",
                    "支持 A4/Letter 无限导出、全 4 套干净模板、现场照片附页、零广告与一次性永久授权。",
                    "支援 A4/Letter 無限匯出、全 4 套專業範本、現場照片附頁、零廣告與一次性永久授權。"
                ))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.84))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(FlatTheme.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        case .eastAsiaDetail:
            // Clear, structured, transparent trust hero for JP/KR/TW/HK/SG
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(FlatTheme.accent)
                    Text(L10n.t("TRANSPARENT PRICING • DIRECT SUPPORT", "明码标价 • 无隐藏扣费 • 专属邮件支持", "透明定價 • 無隱藏扣款 • 專屬郵件支援"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FlatTheme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(FlatTheme.accent.opacity(0.16))
                .clipShape(Capsule())

                Text(L10n.t(
                    "Upgrade to FlatBill Pro\nClear Features, One-Time or Trial",
                    "升级 FlatBill Pro 专业版\n功能明细一目了然，买断或试用自由选",
                    "升級 FlatBill Pro 專業版\n功能明細一目了然，永久買斷或免費試用自由選"
                ))
                .font(.system(size: 21, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

                Text(triggerMessage ?? L10n.t(
                    "Full offline privacy, instant PDF/CSV exports, direct email support (\(ReviewPromptManager.supportEmail)), and easy 2-tap cancellation in iOS Settings.",
                    "100% 本地离线不建号、无限 PDF 与 CSV 导出、提供开发者邮件支持（\(ReviewPromptManager.supportEmail)），订阅随时在系统设置取消。",
                    "100% 本機離線免帳號、無限 PDF 與 CSV 匯出、提供開發者專屬郵件支援（\(ReviewPromptManager.supportEmail)），訂閱隨時可在 iOS 設定取消。"
                ))
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(FlatTheme.slateCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        case .angloROI:
            // Personal ROI Anchor (anchored to user's OWN real invoice amount!)
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .foregroundStyle(FlatTheme.accent)
                    Text(L10n.t("OWN IT ONCE • ZERO RENT-SEEKING", "买断用终身 • 告别高价年卡", "一次買斷終身用 • 告別高價年卡"))
                        .font(.caption.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(FlatTheme.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(FlatTheme.accent.opacity(0.16))
                .clipShape(Capsule())

                if let amount = invoiceAmountText {
                    Text(L10n.t(
                        "Your \(amount) Invoice Is Ready.\nUnlock Pro Once — Own It Forever.",
                        "这张 \(amount) 的单据已排好\n一次买断终身用，告别高价年费",
                        "這張 \(amount) 的單據已排好\n一次買斷終身用，告別高價年費"
                    ))
                    .font(.system(size: 23, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                } else {
                    Text(L10n.t(
                        "Stop Paying $240+/yr\nJust to Send PDF Invoices",
                        "别再为了发 PDF 单据\n每年交几百上千订阅费",
                        "別再為了發 PDF 單據\n每年交高額訂閱費"
                    ))
                    .font(.system(size: 25, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                }

                Text(triggerMessage ?? L10n.t(
                    "Unlimited PDFs, all 4 executive themes, job-site photo pages, A4 & US Letter, and 0% payment fees.",
                    "解锁无限导出 PDF、4 套专业模板、现场照片附页、A4/Letter 与税务 CSV 报表，零平台抽成。",
                    "解鎖無限匯出 PDF、4 套專業範本、現場照片附頁、A4/Letter 與稅務 CSV 報表，零平台抽成。"
                ))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.84))

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("Typical Invoice Apps", "常见订阅开单软件", "常見訂閱開單軟體"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.65))
                        Text(L10n.t("$200–$360 / yr", "¥268–¥598 / 年", "HK$1,500+ / 年"))
                            .font(.callout.weight(.bold).monospacedDigit())
                            .strikethrough(true, color: .red)
                            .foregroundStyle(Color.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("FlatBill Lifetime", "FlatBill 永久买断", "FlatBill 永久買斷"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(FlatTheme.accent)
                        Text(store.displayPrice(for: FlatBillProductID.lifetime) + L10n.t(" once", " 一次付清", " 一次付清"))
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
        }
    }

    // MARK: - Feature Breakdown

    private var benefitsChecklist: some View {
        VStack(alignment: .leading, spacing: 11) {
            benefitRow("doc.badge.plus", L10n.t("Unlimited PDF invoices, estimates & receipts (A4 & Letter)", "无限导出高清 PDF 报价单、发票与收据（支持 A4/Letter）", "無限匯出高畫質 PDF 報價單、發票與收據（支援 A4/Letter）"))
            benefitRow("paintpalette.fill", L10n.t("All 4 pro PDF themes & remove FlatBill footer", "全部 4 套专业单据模板，彻底去除底部标识", "全部 4 套專業單據範本，徹底移除底部標示"))
            benefitRow("photo.on.rectangle.angled", L10n.t("Unlimited job-site before/after photo addendum pages", "无限附加施工前后照片附页，绝不遮挡正文", "無限附加施工前後照片附頁，絕不遮擋正文"))
            benefitRow("tablecells.fill", L10n.t("1-tap CSV tax report, VAT/GST Tax ID & JSON backup", "一键导出年度税务 CSV、税号抬头与本地全量备份", "一鍵匯出年度稅務 CSV、統編稅號與本機完整備份"))
        }
        .flatCard(padding: 16)
    }

    private var eastAsiaComparisonTable: some View {
        VStack(spacing: 8) {
            HStack {
                Text(L10n.t("Feature Comparison", "功能对比明细", "功能對比明細"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(FlatTheme.ink)
                Spacer()
                Text(L10n.t("Free", "免费版", "免費版"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(FlatTheme.muted)
                    .frame(width: 58)
                Text("Pro")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(FlatTheme.accent)
                    .frame(width: 68)
            }
            Divider()
            compareRow(
                L10n.t("PDF Invoice Exports", "PDF 导出次数", "PDF 匯出次數"),
                free: L10n.t("2 total", "总计 2 次", "總計 2 次"),
                pro: L10n.t("Unlimited", "永久无限", "永久無限")
            )
            compareRow(
                L10n.t("Pro Themes & Clean Footer", "4 套专业模板去水印", "4 套專業範本去浮水印"),
                free: "—",
                pro: "✓"
            )
            compareRow(
                L10n.t("CSV Tax Export & Backup", "税务 CSV 报表导出", "稅務 CSV 報表匯出"),
                free: L10n.t("JSON only", "仅备份", "僅備份"),
                pro: L10n.t("CSV + JSON", "全套支持", "全套支援")
            )
            compareRow(
                L10n.t("A4 / Letter & VAT/GST ID", "A4 纸张与税号抬头", "A4 紙張與統編稅號"),
                free: "✓",
                pro: "✓"
            )
            compareRow(
                L10n.t("Direct Email Support", "开发者邮件支持", "開發者專屬郵件支援"),
                free: "✓",
                pro: L10n.t("Priority", "优先响应", "優先回覆")
            )
        }
        .flatCard(padding: 14)
    }

    private func compareRow(_ label: String, free: String, pro: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(FlatTheme.ink)
            Spacer()
            Text(free)
                .font(.caption2)
                .foregroundStyle(FlatTheme.muted)
                .frame(width: 58)
            Text(pro)
                .font(.caption2.weight(.bold))
                .foregroundStyle(FlatTheme.paidGreen)
                .frame(width: 68)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Plan Cards (Anchored Decoy Hierarchy)

    private var lifetimePlanCard: some View {
        planCard(
            id: FlatBillProductID.lifetime,
            title: L10n.t("Lifetime Pro (Pay Once)", "永久买断版（一次付清）", "永久買斷版（一次付清）"),
            subtitle: L10n.t("Only +$10 more than Annual • Own forever, zero renewals", "只比年卡贵一点，终身拥有永不续费", "只比年卡多一點，終身擁有永不續費"),
            price: store.displayPrice(for: FlatBillProductID.lifetime),
            period: L10n.t("one-time", "终身", "終身"),
            badge: style == .euPrivacyLifetime
                ? L10n.t("RECOMMENDED", "推荐买断", "推薦買斷")
                : L10n.t("BEST VALUE", "最划算", "最划算")
        )
    }

    private var yearlyPlanCard: some View {
        planCard(
            id: FlatBillProductID.yearly,
            title: L10n.t("Annual Pro (7-Day Free Trial)", "年度会员（含 7 天免费试用）", "年度會員（含 7 天免費試用）"),
            subtitle: L10n.t("Save 76% vs Monthly • Reminder sent on Day 5", "比月卡省 76% • 第 5 天主动发提醒", "比月卡省 76% • 第 5 天主動發提醒"),
            price: store.displayPrice(for: FlatBillProductID.yearly),
            period: L10n.t("/ year", "/ 年", "/ 年"),
            badge: L10n.t("7 DAYS FREE", "7天免费试", "7天免費試")
        )
    }

    private var monthlyPlanCard: some View {
        planCard(
            id: FlatBillProductID.monthly,
            title: L10n.t("Monthly Pro", "月度灵活版", "月度彈性版"),
            subtitle: L10n.t("Flexible monthly • Cancel anytime in Apple Settings", "按月付费 • 随时可在苹果订阅中取消", "按月付費 • 隨時可在系統訂閱中取消"),
            price: store.displayPrice(for: FlatBillProductID.monthly),
            period: L10n.t("/ month", "/ 月", "/ 月"),
            badge: nil
        )
    }

    // MARK: - Honest Blinkist 3-Step Trial Timeline

    private var trialTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("HOW YOUR 7-DAY FREE TRIAL WORKS", "7 天免费试用透明时间线", "7 天免費試用透明時間線"))
                .font(.caption2.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(FlatTheme.accent)

            timelineStep(
                icon: "lock.open.fill",
                tint: FlatTheme.paidGreen,
                title: L10n.t("Today — $0 Due", "今日 — ¥0 立即解锁全部功能", "今日 — NT$0 / HK$0 立即解鎖"),
                detail: L10n.t("Export unlimited clean PDFs & try all 4 templates risk-free.", "无限导出无水印单据、试用全部模板，今天不扣任何费用。", "無限匯出無浮水印單據、試用全部範本，今天不扣任何費用。")
            )
            timelineStep(
                icon: "bell.badge.fill",
                tint: FlatTheme.estimateBlue,
                title: L10n.t("Day 5 — Friendly Reminder", "第 5 天 — 扣费前 48 小时推送提醒", "第 5 天 — 扣款前 48 小時推播提醒"),
                detail: L10n.t("We notify you 2 days before the trial ends. No surprise bills.", "系统提前 2 天提醒，满意再留、不满意一键取消绝不偷扣。", "系統提前 2 天提醒，滿意再留、不滿意一鍵取消絕不偷扣。")
            )
            timelineStep(
                icon: "checkmark.circle.fill",
                tint: FlatTheme.accent,
                title: L10n.t("Day 7 — Annual Starts (\(store.displayPrice(for: FlatBillProductID.yearly))/yr)", "第 7 天 — 按 \(store.displayPrice(for: FlatBillProductID.yearly))/年续费", "第 7 天 — 按 \(store.displayPrice(for: FlatBillProductID.yearly))/年啟用"),
                detail: L10n.t("Cancel anytime in 2 taps in iOS Settings > Subscriptions.", "随时在 iPhone「设置 > 订阅」2 秒取消。", "隨時可在 iPhone「設定 > 訂閱」2 秒取消。")
            )
        }
        .flatCard(padding: 14)
    }

    private func timelineStep(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(FlatTheme.ink)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(FlatTheme.muted)
            }
            Spacer()
        }
    }

    // MARK: - 1-Time Non-Annoying Abandon Offer (Zero Fake Timers)

    private func handleCloseTap() {
        let alreadyShown = UserDefaults.standard.bool(forKey: abandonKey)
        if !store.isPro && !alreadyShown {
            UserDefaults.standard.set(true, forKey: abandonKey)
            FunnelMetrics.record(.abandonOfferShown)
            showAbandonSheet = true
        } else {
            dismiss()
        }
    }

    private var abandonOfferSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 34))
                .foregroundStyle(FlatTheme.accent)
                .padding(.top, 8)

            Text(L10n.t("Not Ready to Pay Upfront?", "不想现在就掏钱？先免费试 7 天", "不想現在就付錢？先免費試 7 天"))
                .font(.title3.weight(.heavy))
                .multilineTextAlignment(.center)

            Text(L10n.t(
                "Test unlimited clean PDFs on your real clients for 7 days at $0 today. We'll remind you on Day 5 before anything bills — or come back anytime for Lifetime Pro.",
                "今天 0 元开启 7 天全功能试用，发几张真单给客户看看效果；第 5 天提醒您，随时一键取消。",
                "今天 0 元開啟 7 天全功能試用，發幾張真單給客戶看看效果；第 5 天主動提醒您，隨時一鍵取消。"
            ))
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(FlatTheme.muted)

            Button {
                showAbandonSheet = false
                selectedProductID = FlatBillProductID.yearly
                FunnelMetrics.record(.purchaseTapped)
                Task {
                    let ok = await store.purchase(FlatBillProductID.yearly)
                    if ok {
                        FunnelMetrics.record(.purchaseSucceeded)
                        dismiss()
                    }
                }
            } label: {
                Text(L10n.t(
                    "Start 7-Day Free Trial ($0 Today)",
                    "0 元开启 7 天免费试用",
                    "0 元開啟 7 天免費試用"
                ))
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(FlatTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                showAbandonSheet = false
                dismiss()
            } label: {
                Text(L10n.t("No thanks, continue free", "不用了，继续使用免费版", "不用了，繼續使用免費版"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FlatTheme.muted)
            }
        }
        .padding(22)
    }

    // MARK: - Compliance Footer & Helpers

    private var complianceFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                Button(L10n.t("Restore Purchases", "恢复购买", "恢復購買")) {
                    Task { await store.restorePurchases() }
                }
                Link(L10n.t("Privacy Policy", "隐私政策", "隱私權政策"), destination: privacyURL)
                Link(L10n.t("Terms of Use", "使用条款", "使用條款"), destination: termsURL)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(FlatTheme.ink)

            Text(L10n.t(
                "Lifetime Pro is a one-time non-consumable purchase. Annual (\(store.displayPrice(for: FlatBillProductID.yearly))/year after 7-day free trial) and Monthly (\(store.displayPrice(for: FlatBillProductID.monthly))/month) plans auto-renew unless canceled at least 24 hours before the end of the current period in iOS Settings > Apple Account > Subscriptions.",
                "永久买断版为一次性买断内购。年度会员（含7天免费试用，到期按 \(store.displayPrice(for: FlatBillProductID.yearly))/年自动续订）与月度会员（\(store.displayPrice(for: FlatBillProductID.monthly))/月自动续订）可随时在 iPhone「设置 > Apple 账户 > 订阅」中提前 24 小时取消。",
                "永久買斷版為一次性買斷內購。年度會員（含7天免費試用，到期按 \(store.displayPrice(for: FlatBillProductID.yearly))/年自動續訂）與月度會員（\(store.displayPrice(for: FlatBillProductID.monthly))/月自動續訂）可隨時在 iPhone「設定 > Apple 帳號 > 訂閱項目」中提前 24 小時取消。"
            ))
            .font(.caption2)
            .foregroundStyle(FlatTheme.muted)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var ctaLabel: String {
        switch selectedProductID {
        case FlatBillProductID.lifetime:
            return L10n.t(
                "Unlock Lifetime Pro — \(store.displayPrice(for: FlatBillProductID.lifetime)) Once",
                "一次买断永久版 — \(store.displayPrice(for: FlatBillProductID.lifetime))",
                "一次買斷永久版 — \(store.displayPrice(for: FlatBillProductID.lifetime))"
            )
        case FlatBillProductID.yearly:
            return L10n.t(
                "Start 7-Day Free Trial (Then \(store.displayPrice(for: FlatBillProductID.yearly))/yr)",
                "0 元开启 7 天免费试用（后 \(store.displayPrice(for: FlatBillProductID.yearly))/年）",
                "0 元開啟 7 天免費試用（後 \(store.displayPrice(for: FlatBillProductID.yearly))/年）"
            )
        default:
            return L10n.t(
                "Subscribe Monthly — \(store.displayPrice(for: FlatBillProductID.monthly))/mo",
                "按月开通 — \(store.displayPrice(for: FlatBillProductID.monthly))/月",
                "按月開通 — \(store.displayPrice(for: FlatBillProductID.monthly))/月"
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
