import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager
    @Binding var showPaywall: Bool

    @State private var logoPickerItem: PhotosPickerItem? = nil
    @State private var showSignaturePad = false
    @State private var shareFileURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showImporter = false
    @State private var alertMessage: String? = nil

    private let privacyURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/privacy.html")!
    private let termsURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/terms.html")!
    private let supportURL = URL(string: "https://a3152557994-ship-it.github.io/flatbill/support.html")!

    var body: some View {
        NavigationStack {
            Form {
                // Pro Banner
                Section {
                    if store.isPro {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(FlatTheme.paidGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("FlatBill Pro Active", "FlatBill Pro 已永久解锁"))
                                    .font(.headline)
                                Text(L10n.t("Unlimited PDFs, all 4 themes & CSV tax exports enabled.", "已开启无限导出 PDF、全 4 套模板与税务 CSV 报表。"))
                                    .font(.caption)
                                    .foregroundStyle(FlatTheme.muted)
                            }
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "seal.fill")
                                    .font(.title2)
                                    .foregroundStyle(FlatTheme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.t("Upgrade to Lifetime Pro (\(store.displayPrice(for: FlatBillProductID.lifetime)) Once)", "买断 FlatBill Pro（一次 \(store.displayPrice(for: FlatBillProductID.lifetime))）"))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(FlatTheme.ink)
                                    Text(L10n.t("Ditch $200+/yr invoice subscriptions forever.", "告别动辄几百上千的年卡订阅，一次买断用终身。"))
                                        .font(.caption)
                                        .foregroundStyle(FlatTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(FlatTheme.muted)
                            }
                        }
                    }

                    Button(L10n.t("Restore Purchases", "恢复购买")) {
                        Task {
                            await store.restorePurchases()
                            alertMessage = store.statusMessage
                        }
                    }
                }

                // Business Identity
                Section(L10n.t("Business Profile & Logo", "商家抬头与 Logo")) {
                    HStack(spacing: 14) {
                        if let data = ledger.profile.logoData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(FlatTheme.accentSoft)
                                .frame(width: 54, height: 54)
                                .overlay(Image(systemName: "building.2.fill").foregroundStyle(FlatTheme.accent))
                        }

                        PhotosPicker(selection: $logoPickerItem, matching: .images) {
                            Text(ledger.profile.logoData == nil
                                 ? L10n.t("Upload Business Logo", "上传公司/工作室 Logo")
                                 : L10n.t("Change Logo", "更换 Logo"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FlatTheme.accent)
                        }

                        Spacer()
                        if ledger.profile.logoData != nil {
                            Button(role: .destructive) {
                                ledger.profile.logoData = nil
                                ledger.save()
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    TextField(L10n.t("Business Name", "公司 / 商号名称", "公司 / 商號名稱"), text: $ledger.profile.businessName)
                    TextField(L10n.t("Your Name", "负责人 / 师傅姓名", "負責人 / 師傅姓名"), text: $ledger.profile.ownerName)
                    TextField(L10n.t("License Number (optional)", "资质编号 / 工号（选填）", "證照編號 / 工號（選填）"), text: $ledger.profile.licenseNumber)
                    TextField(L10n.t("VAT / GST / ABN / Tax ID (optional)", "税号 / 统一编号 VAT·GST·ABN（选填）", "統一編號 / VAT / GST / ABN（選填）"), text: $ledger.profile.taxID)
                    TextField(L10n.t("Phone", "联系电话", "聯絡電話"), text: $ledger.profile.phone)
                    TextField(L10n.t("Email", "电子邮箱"), text: $ledger.profile.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField(L10n.t("Business Address", "办公/门店地址"), text: $ledger.profile.address)

                    Button {
                        showSignaturePad = true
                    } label: {
                        HStack {
                            Label(
                                ledger.profile.contractorSignatureData == nil
                                    ? L10n.t("Add Your Default Signature", "录制您的默认手写签名")
                                    : L10n.t("Default Signature Saved (Tap to Update)", "已保存默认签名（点击更新）"),
                                systemImage: "signature"
                            )
                            Spacer()
                            if ledger.profile.contractorSignatureData != nil {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(FlatTheme.paidGreen)
                            }
                        }
                    }
                }

                // Billing Defaults & 0% Fee Payment Instructions
                Section(L10n.t("Defaults & Direct Payment Instructions", "默认计税与 0% 抽成收款说明")) {
                    Picker(L10n.t("PDF Paper Size", "PDF 纸张规格", "PDF 紙張規格"), selection: $ledger.profile.paperSize) {
                        ForEach(PaperSize.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    Picker(L10n.t("Default Currency", "默认币种", "預設幣別"), selection: $ledger.profile.defaultCurrencyCode) {
                        ForEach(CurrencyOption.all) { c in
                            Text(c.name).tag(c.code)
                        }
                    }
                    TextField(L10n.t("Tax Label (Sales Tax / VAT / GST)", "税费名称（如税费 / VAT / GST）", "稅目名稱（如營業稅 / VAT / GST）"), text: $ledger.profile.defaultTaxLabel)
                    HStack {
                        Text(L10n.t("Default Tax Rate (%)", "默认税率 (%)"))
                        Spacer()
                        TextField("0", value: $ledger.profile.defaultTaxRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    Stepper(
                        L10n.t("Payment Due: Net \(ledger.profile.defaultDueDays) days", "默认账期：\(ledger.profile.defaultDueDays) 天"),
                        value: $ledger.profile.defaultDueDays,
                        in: 0...90
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Direct Payment Instructions (Zelle / Venmo / Check)", "直接收款方式说明（无中间商抽成）"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlatTheme.muted)
                        TextEditor(text: $ledger.profile.paymentInstructions)
                            .frame(minHeight: 68)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Default Warranty / Footer Note", "默认备注与质保说明"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlatTheme.muted)
                        TextEditor(text: $ledger.profile.defaultNotes)
                            .frame(minHeight: 58)
                    }
                }

                // Data Sovereignty: CSV Tax Export & JSON Backup
                Section(L10n.t("Tax Reports & Offline Backup", "税务报表与离线数据主权")) {
                    Button {
                        if !store.isPro {
                            showPaywall = true
                            return
                        }
                        let csv = ledger.exportTaxCSV()
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FlatBill_Tax_Report.csv")
                        try? csv.write(to: url, atomically: true, encoding: .utf8)
                        shareFileURL = url
                        showShareSheet = true
                    } label: {
                        HStack {
                            Label(L10n.t("Export Tax Summary (CSV)", "导出年度报税明细 (CSV)"), systemImage: "tablecells")
                            Spacer()
                            if !store.isPro {
                                Image(systemName: "lock.fill").font(.caption).foregroundStyle(FlatTheme.muted)
                            }
                        }
                    }

                    Button {
                        if let data = ledger.exportJSONBackupData() {
                            let url = FileManager.default.temporaryDirectory.appendingPathComponent("FlatBill_Backup.json")
                            try? data.write(to: url, options: [.atomic])
                            shareFileURL = url
                            showShareSheet = true
                        }
                    } label: {
                        Label(L10n.t("Export Full Local Backup (JSON)", "导出全量本地备份 (JSON)"), systemImage: "square.and.arrow.up.on.square")
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label(L10n.t("Restore from JSON Backup", "从 JSON 备份恢复数据"), systemImage: "square.and.arrow.down.on.square")
                    }
                }

                // Cross-Promotion: More Zero-Subscription Offline Tools
                Section(L10n.t("More Offline No-Subscription Tools", "更多零订阅离线小工具", "更多免訂閱離線小工具")) {
                    ForEach(PortfolioTool.crossPromoTools) { tool in
                        Link(destination: tool.appStoreURL) {
                            HStack(spacing: 12) {
                                Image(systemName: tool.icon)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(tool.tint)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tool.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FlatTheme.ink)
                                    Text(tool.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(FlatTheme.muted)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(FlatTheme.muted)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Legal & Support
                Section(L10n.t("Privacy & Support", "隐私与支持", "隱私與支援")) {
                    Link(L10n.t("Privacy Policy (100% Offline Data)", "隐私政策（100% 本地离线）", "隱私權政策（100% 本機離線）"), destination: privacyURL)
                    Link(L10n.t("Terms of Use (EULA)", "使用条款 (EULA)", "使用條款 (EULA)"), destination: termsURL)
                    Link(L10n.t("Help & Support", "帮助与联系支持", "說明與聯絡支援"), destination: supportURL)
                    Button(L10n.t("Send Feedback / Report Issue", "意见反馈 / 问题直达开发者", "意見回饋 / 回報問題")) {
                        ReviewPromptManager.openSupportFeedbackEmail()
                    }
                    HStack {
                        Text(L10n.t("Version", "版本号", "版本號"))
                        Spacer()
                        Text("1.0.1").foregroundStyle(FlatTheme.muted)
                    }
                }
            }
            .onChange(of: ledger.profile) { _, _ in
                ledger.save()
            }
            .onChange(of: logoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let img = UIImage(data: data),
                       let jpeg = img.jpegData(compressionQuality: 0.78) {
                        ledger.profile.logoData = jpeg
                        ledger.save()
                    }
                    logoPickerItem = nil
                }
            }
            .navigationTitle(L10n.t("Business & Settings", "商号与设置"))
            .sheet(isPresented: $showSignaturePad) {
                SignaturePadView(
                    title: L10n.t("Your Default Signature", "服务方默认签名"),
                    existingData: ledger.profile.contractorSignatureData
                ) { pngData in
                    ledger.profile.contractorSignatureData = pngData
                    ledger.save()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareFileURL {
                    ShareSheet(items: [shareFileURL])
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url), ledger.importJSONBackupData(data) {
                        alertMessage = L10n.t("Backup restored successfully!", "本地备份已成功恢复！")
                    } else {
                        alertMessage = L10n.t("Could not read backup file.", "无法识别该备份文件。")
                    }
                case .failure(let err):
                    alertMessage = err.localizedDescription
                }
            }
            .alert(L10n.t("FlatBill", "FlatBill 提示"), isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
}
