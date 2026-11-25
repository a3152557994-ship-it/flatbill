import PDFKit
import SwiftUI
import UIKit

struct DocumentPreviewView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    let documentId: UUID
    var onEdit: ((BillingDocument) -> Void)? = nil
    var onOpenConverted: ((BillingDocument) -> Void)? = nil

    @State private var showPaymentSheet = false
    @State private var paymentAmountText = ""
    @State private var paymentMethod = "Zelle"
    @State private var paymentNote = ""

    @State private var showSwapClientSheet = false
    @State private var showPaywall = false
    @State private var paywallMessage: String? = nil
    @State private var paywallFallbackLabel: String? = nil
    @State private var pendingFreeFallback: (() -> Void)? = nil

    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var toastText: String? = nil

    private var doc: BillingDocument? {
        ledger.documents.first { $0.id == documentId }
    }

    var body: some View {
        NavigationStack {
            if let doc {
                VStack(spacing: 0) {
                    // Top Quick Action Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PDFTheme.allCases) { theme in
                                let active = doc.theme == theme
                                Button {
                                    applyTheme(theme, to: doc)
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.swatchColor)
                                            .frame(width: 10, height: 10)
                                        Text(theme.title)
                                            .font(.caption.weight(.semibold))
                                        if theme.isPro && !store.isPro {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(active ? FlatTheme.slateCard : FlatTheme.card)
                                    .foregroundStyle(active ? .white : FlatTheme.ink)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(active ? FlatTheme.slateCard : FlatTheme.border, lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(FlatTheme.paper)

                    // Live Native Vector PDFKit Preview
                    let pdfData = PDFInvoiceRenderer.renderPDFData(
                        document: doc,
                        profile: ledger.profile,
                        includeBrandingFooter: !store.isPro
                    )
                    PDFKitRepresentable(data: pdfData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(white: 0.90))

                    // Bottom Action Deck
                    VStack(spacing: 10) {
                        if let toastText {
                            Text(toastText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FlatTheme.paidGreen)
                        }

                        HStack(spacing: 10) {
                            // Primary Export / Share PDF CTA
                            Button {
                                triggerExportPDF(doc: doc, pdfData: pdfData)
                            } label: {
                                Label(
                                    L10n.t("Send / Share PDF", "发送 / 导出 PDF"),
                                    systemImage: "square.and.arrow.up"
                                )
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FlatTheme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            if doc.kind == .estimate {
                                Button {
                                    let converted = ledger.convertEstimateToInvoice(doc)
                                    toastText = L10n.t("Converted to \(converted.number)!", "已一键转为发票 \(converted.number)！")
                                    onOpenConverted?(converted)
                                } label: {
                                    Label(L10n.t("To Invoice", "转为发票"), systemImage: "arrow.right.doc.on.clipboard")
                                        .font(.subheadline.weight(.bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .background(FlatTheme.slateCard)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            } else if doc.computedStatus != .paid {
                                Button {
                                    paymentAmountText = String(format: "%.2f", doc.balanceDue)
                                    paymentMethod = L10n.isChinese ? "WeChat / Alipay" : "Zelle"
                                    paymentNote = ""
                                    showPaymentSheet = true
                                } label: {
                                    Label(L10n.t("Record Paid", "记一笔收款"), systemImage: "checkmark.seal.fill")
                                        .font(.subheadline.weight(.bold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                        .background(FlatTheme.paidGreen)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        // Secondary Row: Clone & Swap Client + Print + Edit
                        HStack(spacing: 10) {
                            Button {
                                showSwapClientSheet = true
                            } label: {
                                Label(L10n.t("Clone & Swap Client", "复制并换客户"), systemImage: "doc.on.doc")
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(FlatTheme.paper)
                                    .foregroundStyle(FlatTheme.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(FlatTheme.border, lineWidth: 1))
                            }

                            Button {
                                printPDF(pdfData: pdfData, jobName: doc.number)
                            } label: {
                                Label(L10n.t("Print", "打印"), systemImage: "printer")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(FlatTheme.paper)
                                    .foregroundStyle(FlatTheme.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(FlatTheme.border, lineWidth: 1))
                            }

                            if let onEdit {
                                Button {
                                    dismiss()
                                    onEdit(doc)
                                } label: {
                                    Label(L10n.t("Edit", "编辑"), systemImage: "pencil")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(FlatTheme.paper)
                                        .foregroundStyle(FlatTheme.ink)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(FlatTheme.border, lineWidth: 1))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(FlatTheme.card)
                    .overlay(Rectangle().fill(FlatTheme.border).frame(height: 1), alignment: .top)
                }
                .navigationTitle("\(doc.number) • \(doc.computedStatus.label)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("Done", "完成")) { dismiss() }
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    if let shareURL {
                        ShareSheet(items: [shareURL])
                    }
                }
                .sheet(isPresented: $showPaymentSheet) {
                    recordPaymentSheet(for: doc)
                }
                .sheet(isPresented: $showSwapClientSheet) {
                    swapClientSheet(for: doc)
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(
                        triggerMessage: paywallMessage,
                        freeFallbackLabel: paywallFallbackLabel,
                        onFreeFallback: pendingFreeFallback
                    )
                }
            } else {
                Text(L10n.t("Document not found.", "未找到该单据。"))
            }
        }
    }

    private func applyTheme(_ theme: PDFTheme, to doc: BillingDocument) {
        var updated = doc
        updated.theme = theme
        ledger.upsertDocument(updated)
    }

    private func triggerExportPDF(doc: BillingDocument, pdfData: Data) {
        if doc.theme.isPro && !store.isPro {
            paywallMessage = L10n.t(
                "Your \(doc.theme.title) PDF is ready! Unlock Lifetime Pro once to export all 4 pro themes with zero footer branding.",
                "您的「\(doc.theme.title)」单据已排版就绪！一次买断即可无限导出全部 4 套专业模板并去除底部标识。"
            )
            paywallFallbackLabel = L10n.t("Continue free with Classic Slate theme →", "暂不升级，改用免费的「经典商务灰」导出 →")
            pendingFreeFallback = {
                var freeDoc = doc
                freeDoc.theme = .classicSlate
                ledger.upsertDocument(freeDoc)
                let freeData = PDFInvoiceRenderer.renderPDFData(document: freeDoc, profile: ledger.profile, includeBrandingFooter: true)
                performActualShare(doc: freeDoc, pdfData: freeData)
            }
            showPaywall = true
            return
        }

        if !store.canExportFreePDF {
            paywallMessage = L10n.t(
                "You've used all 3 free PDF exports this month. Unlock Lifetime Pro once (\(store.displayPrice(for: FlatBillProductID.lifetime))) for unlimited exports forever.",
                "本月 3 次免费 PDF 导出已用完。一次买断（\(store.displayPrice(for: FlatBillProductID.lifetime))）即可终身无限导出。"
            )
            paywallFallbackLabel = nil
            pendingFreeFallback = nil
            showPaywall = true
            return
        }

        performActualShare(doc: doc, pdfData: pdfData)
    }

    private func performActualShare(doc: BillingDocument, pdfData: Data) {
        let safeName = "\(doc.number)_\(doc.clientName.replacingOccurrences(of: " ", with: "_")).pdf"
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        try? pdfData.write(to: url, options: [.atomic])
        shareURL = url
        ledger.markAsSent(documentId: doc.id)
        if !store.isPro {
            store.recordPDFExport()
        }
        showShareSheet = true
    }

    private func printPDF(pdfData: Data, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        controller.printInfo = info
        controller.printingItem = pdfData
        controller.present(animated: true)
    }

    private func recordPaymentSheet(for doc: BillingDocument) -> some View {
        NavigationStack {
            Form {
                Section(L10n.t("Payment Details", "收款金额与方式")) {
                    HStack {
                        Text(CurrencyOption.symbol(for: doc.currencyCode))
                            .font(.headline.monospacedDigit())
                        TextField("0.00", text: $paymentAmountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.bold).monospacedDigit())
                    }
                    Picker(L10n.t("Method", "收款渠道"), selection: $paymentMethod) {
                        ForEach(PaymentRecord.commonMethods, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    TextField(L10n.t("Note (e.g., Deposit, Check #104)", "备注（如：开工定金、尾款已结）"), text: $paymentNote)
                }

                if !doc.payments.isEmpty {
                    Section(L10n.t("Previous Payments", "历史收款记录")) {
                        ForEach(doc.payments) { p in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(p.method).font(.subheadline.weight(.semibold))
                                    if !p.note.isEmpty {
                                        Text(p.note).font(.caption).foregroundStyle(FlatTheme.muted)
                                    }
                                }
                                Spacer()
                                Text(MoneyFormat.format(p.amount, currencyCode: doc.currencyCode))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(FlatTheme.paidGreen)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("Record Payment", "登记收款"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { showPaymentSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "确认入账")) {
                        if let val = Double(paymentAmountText.replacingOccurrences(of: ",", with: "")), val > 0 {
                            ledger.recordPayment(documentId: doc.id, amount: val, method: paymentMethod, note: paymentNote)
                            toastText = L10n.t("Payment recorded! PDF updated.", "收款已入账，PDF 已更新已结清印章！")
                            showPaymentSheet = false
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func swapClientSheet(for doc: BillingDocument) -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        let copy = ledger.cloneDocument(doc, swapClient: nil)
                        showSwapClientSheet = false
                        dismiss()
                        onEdit?(copy)
                    } label: {
                        Label(L10n.t("Duplicate with Same Client (\(doc.clientName))", "保留原客户直接复制新单"), systemImage: "doc.on.doc.fill")
                            .foregroundStyle(FlatTheme.accent)
                            .fontWeight(.semibold)
                    }
                }

                Section(L10n.t("Or Clone & Swap to Another Client", "或一键复制并切换为其他客户")) {
                    ForEach(ledger.clients) { client in
                        Button {
                            let copy = ledger.cloneDocument(doc, swapClient: client)
                            showSwapClientSheet = false
                            dismiss()
                            onEdit?(copy)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name).font(.subheadline.weight(.bold)).foregroundStyle(FlatTheme.ink)
                                if !client.company.isEmpty {
                                    Text(client.company).font(.caption).foregroundStyle(FlatTheme.muted)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.t("Clone & Swap Client", "复制并换客户"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { showSwapClientSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PDFKitRepresentable: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(white: 0.90, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
