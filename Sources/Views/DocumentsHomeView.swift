import SwiftUI

struct DocumentsHomeView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager

    @Binding var previewDocId: UUID?
    @Binding var editingDoc: EditingTarget?
    @Binding var showPaywall: Bool

    @State private var searchText = ""
    @State private var selectedFilter: FilterChip = .all

    enum FilterChip: String, CaseIterable, Identifiable {
        case all, invoices, estimates, unpaid, paid
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return L10n.t("All", "全部")
            case .invoices: return L10n.t("Invoices", "发票")
            case .estimates: return L10n.t("Estimates", "报价单")
            case .unpaid: return L10n.t("Unpaid", "待收款")
            case .paid: return L10n.t("Paid", "已收清")
            }
        }
    }

    private var filteredDocuments: [BillingDocument] {
        ledger.documents.filter { doc in
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all: return true
                case .invoices: return doc.kind == .invoice
                case .estimates: return doc.kind == .estimate
                case .unpaid: return doc.kind == .invoice && doc.computedStatus != .paid
                case .paid: return doc.computedStatus == .paid
                }
            }()
            guard matchesFilter else { return false }
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return true }
            return doc.clientName.localizedCaseInsensitiveContains(q)
                || doc.number.localizedCaseInsensitiveContains(q)
                || doc.jobTitle.localizedCaseInsensitiveContains(q)
                || doc.clientCompany.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    revenueHeroCard
                    quickActionRow
                    filterBar

                    if filteredDocuments.isEmpty {
                        emptyStateCard
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredDocuments) { doc in
                                documentCard(doc)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("FlatBill", "FlatBill 报价单"))
            .searchable(text: $searchText, prompt: L10n.t("Search client, job, or #number", "搜索客户名、项目或单号"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !store.isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "seal.fill")
                                Text(L10n.t("Lifetime", "买断版"))
                            }
                            .font(.caption.weight(.heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(FlatTheme.accentSoft)
                            .foregroundStyle(FlatTheme.accent)
                            .clipShape(Capsule())
                        }
                    } else {
                        Label("PRO", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(FlatTheme.paidGreen)
                    }
                }
            }
        }
    }

    private var revenueHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("COLLECTED REVENUE", "累计已收款"))
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text(MoneyFormat.format(ledger.totalCollected, currencyCode: ledger.profile.defaultCurrencyCode))
                        .font(.system(size: 32, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(store.isPro
                         ? L10n.t("UNLIMITED PRO", "永久买断已解锁", "永久買斷已解鎖")
                         : L10n.t("\(store.remainingFreeExports)/\(StoreManager.freeLifetimeExportLimit) Free PDFs Left", "余 \(store.remainingFreeExports)/\(StoreManager.freeLifetimeExportLimit) 次免费导出", "餘 \(store.remainingFreeExports)/\(StoreManager.freeLifetimeExportLimit) 次免費匯出"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(store.isPro ? FlatTheme.paidGreen.opacity(0.28) : Color.white.opacity(0.12))
                        .foregroundStyle(store.isPro ? Color(red: 0.55, green: 0.96, blue: 0.68) : Color.white.opacity(0.92))
                        .clipShape(Capsule())
                    Text(L10n.t("Offline • 0% Card Fees", "离线秒开 • 零平台抽成"))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }

            Divider().overlay(Color.white.opacity(0.14))

            HStack(spacing: 12) {
                metricPill(
                    title: L10n.t("Outstanding", "待收尾款"),
                    amount: ledger.totalOutstanding,
                    color: Color(red: 0.99, green: 0.72, blue: 0.35)
                )
                metricPill(
                    title: L10n.t("Overdue", "逾期未付"),
                    amount: ledger.totalOverdue,
                    color: Color(red: 0.98, green: 0.52, blue: 0.52)
                )
                metricPill(
                    title: L10n.t("Open Quotes", "待确认报价"),
                    amount: ledger.pendingEstimatesTotal,
                    color: Color(red: 0.56, green: 0.80, blue: 1.0)
                )
            }
        }
        .padding(18)
        .background(FlatTheme.slateCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metricPill(title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.65))
            Text(MoneyFormat.format(amount, currencyCode: ledger.profile.defaultCurrencyCode))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quickActionRow: some View {
        HStack(spacing: 10) {
            Button {
                let doc = ledger.makeBlankDocument(kind: .invoice)
                editingDoc = EditingTarget(document: doc, isNew: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                    Text(L10n.t("New Invoice", "新建发票/收款单"))
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FlatTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                let doc = ledger.makeBlankDocument(kind: .estimate)
                editingDoc = EditingTarget(document: doc, isNew: true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.headline)
                    Text(L10n.t("New Estimate", "新建报价单"))
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FlatTheme.card)
                .foregroundStyle(FlatTheme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(FlatTheme.border, lineWidth: 1.2))
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterChip.allCases) { chip in
                    let active = selectedFilter == chip
                    Button {
                        selectedFilter = chip
                    } label: {
                        Text(chip.title)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(active ? FlatTheme.ink : FlatTheme.card)
                            .foregroundStyle(active ? .white : FlatTheme.muted)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(active ? FlatTheme.ink : FlatTheme.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    private func documentCard(_ doc: BillingDocument) -> some View {
        let status = doc.computedStatus
        return Button {
            previewDocId = doc.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(doc.number)
                                .font(.caption.weight(.heavy).monospacedDigit())
                                .foregroundStyle(doc.kind == .estimate ? FlatTheme.estimateBlue : FlatTheme.accent)
                            Text(status.label)
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(status.bg)
                                .foregroundStyle(status.tint)
                                .clipShape(Capsule())
                            if !doc.photos.isEmpty {
                                Label("\(doc.photos.count)", systemImage: "photo")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(FlatTheme.muted)
                            }
                        }

                        Text(doc.clientName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(FlatTheme.ink)

                        if !doc.jobTitle.isEmpty {
                            Text(doc.jobTitle)
                                .font(.caption)
                                .foregroundStyle(FlatTheme.muted)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(MoneyFormat.format(doc.total, currencyCode: doc.currencyCode))
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(FlatTheme.ink)

                        if doc.kind == .invoice && doc.amountPaid > 0 && doc.balanceDue > 0.01 {
                            Text(L10n.t("Due \(MoneyFormat.format(doc.balanceDue, currencyCode: doc.currencyCode))", "余 \(MoneyFormat.format(doc.balanceDue, currencyCode: doc.currencyCode))"))
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(FlatTheme.overdueRed)
                        } else {
                            Text(doc.dueDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(FlatTheme.muted)
                        }
                    }
                }

                Divider().overlay(FlatTheme.border)

                HStack(spacing: 14) {
                    Button {
                        let copy = ledger.cloneDocument(doc)
                        editingDoc = EditingTarget(document: copy, isNew: false)
                    } label: {
                        Label(L10n.t("Clone", "秒复制"), systemImage: "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlatTheme.ink)
                    }

                    if doc.kind == .estimate {
                        Button {
                            let inv = ledger.convertEstimateToInvoice(doc)
                            previewDocId = inv.id
                        } label: {
                            Label(L10n.t("Convert to Invoice", "一键转发票"), systemImage: "arrow.right.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(FlatTheme.accent)
                        }
                    } else if status != .paid {
                        Button {
                            ledger.recordPayment(documentId: doc.id, amount: doc.balanceDue, method: L10n.isChinese ? "WeChat / Alipay" : "Zelle")
                        } label: {
                            Label(L10n.t("Mark Paid", "标为已结清"), systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(FlatTheme.paidGreen)
                        }
                    }

                    Spacer()

                    Label(L10n.t("PDF", "预览PDF"), systemImage: "doc.richtext")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FlatTheme.muted)
                }
            }
            .flatCard(padding: 15)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                previewDocId = doc.id
            } label: {
                Label(L10n.t("Preview & Share PDF", "预览并发送 PDF"), systemImage: "doc.richtext")
            }
            Button {
                editingDoc = EditingTarget(document: doc, isNew: false)
            } label: {
                Label(L10n.t("Edit Document", "编辑单据"), systemImage: "pencil")
            }
            Button {
                let copy = ledger.cloneDocument(doc)
                editingDoc = EditingTarget(document: copy, isNew: false)
            } label: {
                Label(L10n.t("Clone Document", "复制该单据"), systemImage: "doc.on.doc")
            }
            if doc.kind == .estimate {
                Button {
                    let inv = ledger.convertEstimateToInvoice(doc)
                    previewDocId = inv.id
                } label: {
                    Label(L10n.t("Convert to Invoice", "转为发票"), systemImage: "arrow.right.doc.on.clipboard")
                }
            }
            Divider()
            Button(role: .destructive) {
                ledger.deleteDocument(doc.id)
            } label: {
                Label(L10n.t("Delete", "删除"), systemImage: "trash")
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(FlatTheme.muted)
            Text(L10n.t("No matching documents yet", "还没有符合条件的单据"))
                .font(.headline)
            Text(L10n.t("Tap New Invoice or New Estimate above to create a crisp PDF in under 30 seconds.", "点击上方按钮，30 秒离线生成带 Logo 与收款码说明的高清 PDF 单据。"))
                .font(.caption)
                .foregroundStyle(FlatTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .flatCard()
    }
}

struct EditingTarget: Identifiable {
    let id = UUID()
    let document: BillingDocument
    let isNew: Bool
}
