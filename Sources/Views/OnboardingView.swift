import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager

    var onFinish: (_ openPaywall: Bool, _ savingsHeadline: String?) -> Void

    @State private var selectedTradeIndex: Int = 0
    @State private var invoicesPerMonth: Double = 8
    @State private var selectedPaper: PaperSize = PaperSize.defaultForCurrentLocale()
    @State private var selectedCurrency: String = CurrencyOption.defaultCodeForCurrentLocale()

    private struct TradeOption {
        let icon: String
        let title: String
        let defaultTaxLabel: String
    }

    private var trades: [TradeOption] {
        [
            TradeOption(icon: "wrench.and.screwdriver.fill", title: L10n.t("Plumbing / HVAC / Electrical", "水电 / 暖通 / 维修", "水電 / 空調 / 維修"), defaultTaxLabel: L10n.t("Sales Tax", "税费", "稅額")),
            TradeOption(icon: "hammer.fill", title: L10n.t("Handyman / Remodeling", "装修 / 施工 / 工程", "裝修 / 工程 / 施工"), defaultTaxLabel: L10n.t("Sales Tax", "税费", "稅額")),
            TradeOption(icon: "sparkles", title: L10n.t("Cleaning / Landscaping", "保洁 / 园艺 / 上门服务", "清潔 / 園藝 / 到府服務"), defaultTaxLabel: L10n.t("Tax", "税费", "稅額")),
            TradeOption(icon: "laptopcomputer", title: L10n.t("Freelancer / Consulting", "自由职业 / 设计顾问", "自由接案 / 設計顧問"), defaultTaxLabel: L10n.t("VAT / GST", "税费", "營業稅")),
        ]
    }

    private var typicalCompetitorYearlyCost: Int {
        invoicesPerMonth >= 4 ? 264 : 108
    }

    private var estimatedAnnualSavings: Int {
        max(80, typicalCompetitorYearlyCost - 30)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(FlatTheme.accent)
                            .padding(14)
                            .background(FlatTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text(L10n.t(
                            "Send Pro PDF Invoices in 30 Seconds",
                            "30 秒离线开出专业 PDF 报价单与发票",
                            "30 秒離線開出專業 PDF 報價單與發票"
                        ))
                        .font(.title2.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(FlatTheme.ink)

                        Text(L10n.t(
                            "100% offline • No account required • 0% payment fees",
                            "100% 本地离线 • 免注册账号 • 0% 收款抽成",
                            "100% 本機離線 • 免註冊帳號 • 0% 收款抽成"
                        ))
                        .font(.subheadline)
                        .foregroundStyle(FlatTheme.muted)
                    }
                    .padding(.top, 8)

                    // Trade picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.t("1. What kind of work do you invoice?", "1. 您主要开哪种业务单据？", "1. 您主要開立哪類業務單據？"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(FlatTheme.ink)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(trades.indices, id: \.self) { idx in
                                let active = selectedTradeIndex == idx
                                Button {
                                    selectedTradeIndex = idx
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: trades[idx].icon)
                                            .font(.title3)
                                            .foregroundStyle(active ? .white : FlatTheme.accent)
                                        Text(trades[idx].title)
                                            .font(.caption.weight(.semibold))
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(active ? .white : FlatTheme.ink)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 74)
                                    .padding(8)
                                    .background(active ? FlatTheme.slateCard : FlatTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(active ? FlatTheme.accent : FlatTheme.border, lineWidth: active ? 2 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Format & Volume ROI Calculator
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("2. Your paper format & monthly volume", "2. 选择纸张规格与每月开单量", "2. 選擇紙張規格與每月開單量"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(FlatTheme.ink)

                        HStack(spacing: 10) {
                            Picker(L10n.t("Paper", "纸张", "紙張"), selection: $selectedPaper) {
                                ForEach(PaperSize.allCases) { size in
                                    Text(size.label).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)

                            Picker(L10n.t("Currency", "币种", "幣別"), selection: $selectedCurrency) {
                                ForEach(CurrencyOption.all) { c in
                                    Text(c.code).tag(c.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(FlatTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n.t("Invoices / estimates per month", "每月开单数量", "每月開單數量"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(FlatTheme.muted)
                                Spacer()
                                Text("\(Int(invoicesPerMonth)) / \(L10n.t("mo", "月", "月"))")
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(FlatTheme.accent)
                            }
                            Slider(value: $invoicesPerMonth, in: 2...30, step: 1)
                                .tint(FlatTheme.accent)
                        }
                    }
                    .flatCard(padding: 14)

                    // Personalized ROI Output Card
                    VStack(spacing: 6) {
                        Text(L10n.t("YOUR ESTIMATED SUBSCRIPTION SAVINGS", "为您预估省下的年卡订阅费", "為您預估省下的訂閱年費"))
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(Color.white.opacity(0.70))

                        Text(L10n.t(
                            "Save ~$\(estimatedAnnualSavings)+ every year",
                            "每年立省约 ¥\(estimatedAnnualSavings * 7)+ 订阅费",
                            "每年立省約 HK$\(estimatedAnnualSavings * 7)+ 訂閱費"
                        ))
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(FlatTheme.accent)

                        Text(L10n.t(
                            "Typical unlimited invoice apps charge $\(typicalCompetitorYearlyCost)/yr. FlatBill lets you start free or own it forever in one tap.",
                            "常见无限开单软件每年收费数百上千元，FlatBill 免费体验后再决定是否一次买断。",
                            "常見無限開單軟體每年收費高昂，FlatBill 先免費體驗，滿意再一次買斷用終身。"
                        ))
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.84))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(FlatTheme.slateCard)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // CTAs
                    VStack(spacing: 10) {
                        Button {
                            applySetupAndContinue(openPaywall: true)
                        } label: {
                            Text(L10n.t(
                                "Unlock Unlimited Pro (7-Day Free Trial / Lifetime)",
                                "查看买断与 7 天免费试用方案",
                                "查看永久買斷與 7 天免費試用"
                            ))
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(FlatTheme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Button {
                            applySetupAndContinue(openPaywall: false)
                        } label: {
                            Text(L10n.t(
                                "Start Free First (2 Free PDF Exports Included)",
                                "先免费体验（含 2 次完整免费 PDF 导出）",
                                "先免費體驗（含 2 次完整免費 PDF 匯出）"
                            ))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FlatTheme.muted)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(16)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("Skip", "跳过", "略過")) {
                        applySetupAndContinue(openPaywall: false)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private func applySetupAndContinue(openPaywall: Bool) {
        ledger.profile.paperSize = selectedPaper
        ledger.profile.defaultCurrencyCode = selectedCurrency
        if selectedPaper == .a4 && ledger.profile.defaultTaxLabel == "Sales Tax" {
            ledger.profile.defaultTaxLabel = selectedCurrency == "AUD" ? "GST" : "VAT"
        }
        ledger.save()
        UserDefaults.standard.set(true, forKey: "flatbill.onboarding.done")
        FunnelMetrics.record(.onboardingCompleted)
        let headline = L10n.t(
            "Save ~$\(estimatedAnnualSavings)+/yr on \(Int(invoicesPerMonth)) invoices/mo. Try 7 days free or pay once forever.",
            "按您每月 \(Int(invoicesPerMonth)) 单估算，一次买断立省高额年费。",
            "依您每月 \(Int(invoicesPerMonth)) 單估算，一次買斷立即省下高額年費。"
        )
        onFinish(openPaywall, headline)
    }
}
