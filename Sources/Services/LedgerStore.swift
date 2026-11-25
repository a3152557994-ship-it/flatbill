import Foundation
import SwiftUI

@MainActor
final class LedgerStore: ObservableObject {
    @Published var profile: BusinessProfile
    @Published var clients: [ClientRecord]
    @Published var priceBook: [PriceBookItem]
    @Published var documents: [BillingDocument]

    private let fileURL: URL

    init(customURL: URL? = nil, seedIfEmpty: Bool = true) {
        if let customURL {
            self.fileURL = customURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let dir = base.appendingPathComponent("FlatBill", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("ledger_v1.json")
        }

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.iso8601.decode(LedgerBackupBundle.self, from: data) {
            self.profile = decoded.profile
            self.clients = decoded.clients
            self.priceBook = decoded.priceBook
            self.documents = decoded.documents
        } else {
            self.profile = BusinessProfile.defaultLocalized()
            self.clients = []
            self.priceBook = []
            self.documents = []
            if seedIfEmpty {
                loadStarterSamples()
            }
        }
    }

    func save() {
        let bundle = LedgerBackupBundle(
            schemaVersion: 1,
            exportedAt: Date(),
            profile: profile,
            clients: clients,
            priceBook: priceBook,
            documents: documents
        )
        if let data = try? JSONEncoder.iso8601.encode(bundle) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    // MARK: - Revenue Metrics

    var totalCollected: Double {
        documents.filter { $0.kind == .invoice }.reduce(0) { $0 + $1.amountPaid }
    }

    var totalOutstanding: Double {
        documents.filter { $0.kind == .invoice }.reduce(0) { $0 + $1.balanceDue }
    }

    var totalOverdue: Double {
        documents.filter { $0.computedStatus == .overdue }.reduce(0) { $0 + $1.balanceDue }
    }

    var pendingEstimatesTotal: Double {
        documents.filter { $0.kind == .estimate }.reduce(0) { $0 + $1.total }
    }

    // MARK: - Document Lifecycle

    func nextNumber(for kind: DocumentKind) -> String {
        switch kind {
        case .invoice:
            let num = "\(profile.invoicePrefix)-\(profile.nextInvoiceNumber)"
            profile.nextInvoiceNumber += 1
            save()
            return num
        case .estimate:
            let num = "\(profile.estimatePrefix)-\(profile.nextEstimateNumber)"
            profile.nextEstimateNumber += 1
            save()
            return num
        }
    }

    func makeBlankDocument(kind: DocumentKind, client: ClientRecord? = nil) -> BillingDocument {
        let number = kind == .invoice
            ? "\(profile.invoicePrefix)-\(profile.nextInvoiceNumber)"
            : "\(profile.estimatePrefix)-\(profile.nextEstimateNumber)"
        let due = Calendar.current.date(byAdding: .day, value: max(0, profile.defaultDueDays), to: Date()) ?? Date()
        return BillingDocument(
            kind: kind,
            number: number,
            issueDate: Date(),
            dueDate: due,
            clientId: client?.id,
            clientName: client?.name ?? "",
            clientCompany: client?.company ?? "",
            clientEmail: client?.email ?? "",
            clientPhone: client?.phone ?? "",
            clientAddress: client?.address ?? "",
            jobTitle: "",
            currencyCode: profile.defaultCurrencyCode,
            items: [LineItem(name: "", details: "", quantity: 1, unit: L10n.t("job", "项"), unitPrice: 0, taxable: true)],
            taxRate: profile.defaultTaxRate,
            taxLabel: profile.defaultTaxLabel,
            notes: profile.defaultNotes,
            paymentInstructions: profile.paymentInstructions,
            theme: .classicSlate
        )
    }

    func upsertDocument(_ doc: BillingDocument) {
        var updated = doc
        updated.updatedAt = Date()
        if let idx = documents.firstIndex(where: { $0.id == updated.id }) {
            documents[idx] = updated
        } else {
            // Advance sequence counter if matching next number
            if updated.kind == .invoice && updated.number == "\(profile.invoicePrefix)-\(profile.nextInvoiceNumber)" {
                profile.nextInvoiceNumber += 1
            } else if updated.kind == .estimate && updated.number == "\(profile.estimatePrefix)-\(profile.nextEstimateNumber)" {
                profile.nextEstimateNumber += 1
            }
            documents.insert(updated, at: 0)
        }
        // Auto-save new client to directory if named and not yet stored
        let trimmedClient = updated.clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedClient.isEmpty && !clients.contains(where: { $0.name.caseInsensitiveCompare(trimmedClient) == .orderedSame }) {
            let newClient = ClientRecord(
                name: trimmedClient,
                company: updated.clientCompany,
                email: updated.clientEmail,
                phone: updated.clientPhone,
                address: updated.clientAddress
            )
            clients.insert(newClient, at: 0)
        }
        save()
    }

    func deleteDocument(_ id: UUID) {
        documents.removeAll { $0.id == id }
        save()
    }

    /// Signature competitor pain-killer: One-Tap Clone & Swap Client
    @discardableResult
    func cloneDocument(_ source: BillingDocument, swapClient: ClientRecord? = nil) -> BillingDocument {
        var copy = source
        copy.id = UUID()
        copy.number = nextNumber(for: source.kind)
        copy.issueDate = Date()
        copy.dueDate = Calendar.current.date(byAdding: .day, value: max(1, profile.defaultDueDays), to: Date()) ?? Date()
        copy.payments = []
        copy.clientSignatureData = nil
        copy.isSent = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.items = source.items.map { item in
            var c = item
            c.id = UUID()
            return c
        }
        if let client = swapClient {
            copy.clientId = client.id
            copy.clientName = client.name
            copy.clientCompany = client.company
            copy.clientEmail = client.email
            copy.clientPhone = client.phone
            copy.clientAddress = client.address
        }
        documents.insert(copy, at: 0)
        save()
        return copy
    }

    /// One-Tap Convert Estimate -> Invoice
    @discardableResult
    func convertEstimateToInvoice(_ estimate: BillingDocument) -> BillingDocument {
        var inv = estimate
        inv.id = UUID()
        inv.kind = .invoice
        inv.number = nextNumber(for: .invoice)
        inv.issueDate = Date()
        inv.dueDate = Calendar.current.date(byAdding: .day, value: max(1, profile.defaultDueDays), to: Date()) ?? Date()
        inv.payments = []
        inv.isSent = false
        inv.createdAt = Date()
        inv.updatedAt = Date()
        inv.items = estimate.items.map { item in
            var c = item
            c.id = UUID()
            return c
        }
        documents.insert(inv, at: 0)
        save()
        return inv
    }

    func recordPayment(documentId: UUID, amount: Double, method: String, note: String = "") {
        guard amount > 0, let idx = documents.firstIndex(where: { $0.id == documentId }) else { return }
        let rec = PaymentRecord(amount: amount, date: Date(), method: method, note: note)
        documents[idx].payments.append(rec)
        documents[idx].isSent = true
        documents[idx].updatedAt = Date()
        save()
    }

    func markAsSent(documentId: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == documentId }) else { return }
        documents[idx].isSent = true
        documents[idx].updatedAt = Date()
        save()
    }

    // MARK: - Clients & Price Book

    func upsertClient(_ client: ClientRecord) {
        if let idx = clients.firstIndex(where: { $0.id == client.id }) {
            clients[idx] = client
        } else {
            clients.insert(client, at: 0)
        }
        save()
    }

    func deleteClient(_ id: UUID) {
        clients.removeAll { $0.id == id }
        save()
    }

    func billedTotal(for client: ClientRecord) -> Double {
        documents.filter {
            $0.kind == .invoice &&
            ($0.clientId == client.id || $0.clientName.caseInsensitiveCompare(client.name) == .orderedSame)
        }.reduce(0) { $0 + $1.total }
    }

    func unpaidTotal(for client: ClientRecord) -> Double {
        documents.filter {
            $0.kind == .invoice &&
            ($0.clientId == client.id || $0.clientName.caseInsensitiveCompare(client.name) == .orderedSame)
        }.reduce(0) { $0 + $1.balanceDue }
    }

    func upsertPriceBookItem(_ item: PriceBookItem) {
        if let idx = priceBook.firstIndex(where: { $0.id == item.id }) {
            priceBook[idx] = item
        } else {
            priceBook.insert(item, at: 0)
        }
        save()
    }

    func deletePriceBookItem(_ id: UUID) {
        priceBook.removeAll { $0.id == id }
        save()
    }

    // MARK: - Backup & Tax CSV Export

    func exportJSONBackupData() -> Data? {
        let bundle = LedgerBackupBundle(
            schemaVersion: 1,
            exportedAt: Date(),
            profile: profile,
            clients: clients,
            priceBook: priceBook,
            documents: documents
        )
        return try? JSONEncoder.iso8601Pretty.encode(bundle)
    }

    func importJSONBackupData(_ data: Data) -> Bool {
        guard let decoded = try? JSONDecoder.iso8601.decode(LedgerBackupBundle.self, from: data) else {
            return false
        }
        self.profile = decoded.profile
        self.clients = decoded.clients
        self.priceBook = decoded.priceBook
        self.documents = decoded.documents
        save()
        return true
    }

    func exportTaxCSV() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var lines = ["Type,Number,Status,IssueDate,DueDate,Client,JobTitle,Currency,Subtotal,Discount,Tax,Total,Paid,BalanceDue"]
        for d in documents {
            let row = [
                d.kind.rawValue.uppercased(),
                csvEsc(d.number),
                d.computedStatus.rawValue.uppercased(),
                df.string(from: d.issueDate),
                df.string(from: d.dueDate),
                csvEsc(d.clientName),
                csvEsc(d.jobTitle),
                d.currencyCode,
                String(format: "%.2f", d.subtotal),
                String(format: "%.2f", d.discountValue),
                String(format: "%.2f", d.taxAmount),
                String(format: "%.2f", d.total),
                String(format: "%.2f", d.amountPaid),
                String(format: "%.2f", d.balanceDue),
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    private func csvEsc(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(cleaned)\""
    }

    // MARK: - Starter Realistic Sample Data

    func loadStarterSamples() {
        let now = Date()
        let cal = Calendar.current

        if L10n.isChinese {
            let c1 = ClientRecord(name: "林女士", company: "翠苑小区 6 栋 402", email: "lin@example.com", phone: "139-5555-0192", address: "杭州市西湖区翠苑三区 6 栋 402 室")
            let c2 = ClientRecord(name: "张总", company: "禾木咖啡馆", email: "zhang@example.com", phone: "137-5555-8820", address: "杭州市拱墅区大兜路 118 号")
            let c3 = ClientRecord(name: "周先生", company: "滨江朗诗熙华府", email: "zhou@example.com", phone: "135-5555-3310", address: "杭州市滨江区江南大道 588 号")
            self.clients = [c1, c2, c3]

            self.priceBook = [
                PriceBookItem(name: "上门检测与故障排查费", details: "含专业测漏仪器检测与维修方案报价", unit: "次", unitPrice: 120, taxable: false, category: "人工"),
                PriceBookItem(name: "厨房水槽下水改造与换阀", details: "304不锈钢角阀+防臭硅胶下水管全套更换", unit: "套", unitPrice: 480, taxable: true, category: "水电"),
                PriceBookItem(name: "墙面铲除补腻子与乳胶漆翻新", details: "立邦净味底漆1遍+面漆2遍，含现场成品保护", unit: "㎡", unitPrice: 68, taxable: true, category: "油漆"),
                PriceBookItem(name: "商用中央空调深度清洗保养", details: "风口拆洗+高温蒸汽杀菌+冷凝水疏通", unit: "台", unitPrice: 260, taxable: true, category: "维保"),
            ]

            let d1 = BillingDocument(
                kind: .invoice, number: "INV-1001",
                issueDate: cal.date(byAdding: .day, value: -4, to: now) ?? now,
                dueDate: cal.date(byAdding: .day, value: 3, to: now) ?? now,
                clientId: c1.id, clientName: c1.name, clientCompany: c1.company, clientEmail: c1.email, clientPhone: c1.phone, clientAddress: c1.address,
                jobTitle: "厨房水槽漏水维修与角阀更换",
                currencyCode: "CNY",
                items: [
                    LineItem(name: "304不锈钢冷热角阀更换（一对）", details: "拆除锈死旧阀并做打压防漏测试", quantity: 1, unit: "套", unitPrice: 320, taxable: true),
                    LineItem(name: "防臭硅胶下水套装安装", details: "含密封胶圈更换与橱柜底板除潮", quantity: 1, unit: "套", unitPrice: 180, taxable: true),
                    LineItem(name: "上门工时费", details: "含旧件清理带走", quantity: 1, unit: "次", unitPrice: 150, taxable: false),
                ],
                taxRate: 0, taxLabel: "税费",
                payments: [PaymentRecord(amount: 650, date: cal.date(byAdding: .day, value: -3, to: now) ?? now, method: "WeChat / Alipay", note: "现场微信已结清")],
                notes: profile.defaultNotes,
                paymentInstructions: profile.paymentInstructions,
                theme: .blueprintTrade,
                isSent: true
            )

            let d2 = BillingDocument(
                kind: .estimate, number: "EST-1002",
                issueDate: now,
                dueDate: cal.date(byAdding: .day, value: 14, to: now) ?? now,
                clientId: c2.id, clientName: c2.name, clientCompany: c2.company, clientEmail: c2.email, clientPhone: c2.phone, clientAddress: c2.address,
                jobTitle: "门店 4 台空调清洗及吧台电路增容报价",
                currencyCode: "CNY",
                items: [
                    LineItem(name: "商用嵌入式空调深度拆洗", details: "高温蒸汽杀菌 + 滤网及接水盘清理", quantity: 4, unit: "台", unitPrice: 260, taxable: true),
                    LineItem(name: "吧台 4 平方独立专线改造", details: "国标阻燃铜线 + 施耐德 32A 漏保空开", quantity: 1, unit: "项", unitPrice: 880, taxable: true),
                ],
                taxRate: 0, taxLabel: "税费",
                discountAmount: 100, discountIsPercent: false,
                notes: "本报价 14 天内有效；确认开工后预付 30% 材料定金，完工验收合格结清尾款。",
                paymentInstructions: profile.paymentInstructions,
                theme: .classicSlate,
                isSent: true
            )

            let d3 = BillingDocument(
                kind: .invoice, number: "INV-1003",
                issueDate: cal.date(byAdding: .day, value: -18, to: now) ?? now,
                dueDate: cal.date(byAdding: .day, value: -4, to: now) ?? now,
                clientId: c3.id, clientName: c3.name, clientCompany: c3.company, clientEmail: c3.email, clientPhone: c3.phone, clientAddress: c3.address,
                jobTitle: "客餐厅墙面翻新与防霉涂刷",
                currencyCode: "CNY",
                items: [
                    LineItem(name: "墙面局部铲除修补与乳胶漆翻新", details: "立邦抗碱底漆1遍 + 净味面漆2遍", quantity: 36, unit: "㎡", unitPrice: 68, taxable: true),
                    LineItem(name: "全屋家具地面成品保护与垃圾清运", details: "含施工后基础保洁", quantity: 1, unit: "项", unitPrice: 300, taxable: false),
                ],
                taxRate: 0, taxLabel: "税费",
                payments: [PaymentRecord(amount: 1000, date: cal.date(byAdding: .day, value: -18, to: now) ?? now, method: "WeChat / Alipay", note: "开工定金")],
                notes: profile.defaultNotes,
                paymentInstructions: profile.paymentInstructions,
                theme: .classicSlate,
                isSent: true
            )

            self.documents = [d2, d1, d3]
        } else {
            let c1 = ClientRecord(name: "Sarah Jenkins", company: "Oakwood Residence", email: "sarah.j@example.com", phone: "(512) 555-0192", address: "1420 Barton Hills Dr, Austin, TX 78704")
            let c2 = ClientRecord(name: "David Morales", company: "Redbird Coffee Co.", email: "david@redbird.example", phone: "(512) 555-0184", address: "802 South Congress Ave, Austin, TX 78704")
            let c3 = ClientRecord(name: "Rachel Lin", company: "Cedar Park Townhomes", email: "rachel.lin@example.com", phone: "(512) 555-0137", address: "215 Cypress Creek Rd, Cedar Park, TX 78613")
            self.clients = [c1, c2, c3]

            self.priceBook = [
                PriceBookItem(name: "Service Call & Diagnostics", details: "On-site troubleshooting and written repair scope", unit: "visit", unitPrice: 95, taxable: false, category: "Labor"),
                PriceBookItem(name: "Standard Skilled Labor", details: "Licensed technician labor rate", unit: "hr", unitPrice: 110, taxable: false, category: "Labor"),
                PriceBookItem(name: "Kitchen Shutoff Valve & Supply Line Kit", details: "Brass quarter-turn valves + braided steel lines", unit: "kit", unitPrice: 145, taxable: true, category: "Materials"),
                PriceBookItem(name: "Cedar Fence Picket Replacement", details: "Western red cedar pickets, galvanized nails & disposal", unit: "ft", unitPrice: 38, taxable: true, category: "Carpentry"),
                PriceBookItem(name: "Deep Move-Out Cleaning Package", details: "Kitchen appliances, baths, baseboards & windows", unit: "job", unitPrice: 340, taxable: false, category: "Cleaning"),
            ]

            let d1 = BillingDocument(
                kind: .invoice, number: "INV-1001",
                issueDate: cal.date(byAdding: .day, value: -5, to: now) ?? now,
                dueDate: cal.date(byAdding: .day, value: 9, to: now) ?? now,
                clientId: c1.id, clientName: c1.name, clientCompany: c1.company, clientEmail: c1.email, clientPhone: c1.phone, clientAddress: c1.address,
                jobTitle: "Kitchen Sink Valve & Disposal Replacement",
                currencyCode: "USD",
                items: [
                    LineItem(name: "1/2 HP Garbage Disposal Unit", details: "Stainless steel grind chamber with 5-yr factory warranty", quantity: 1, unit: "unit", unitPrice: 185, taxable: true),
                    LineItem(name: "Quarter-Turn Brass Shutoff Valve Kit", details: "Hot & cold supply replacement + pressure leak test", quantity: 1, unit: "kit", unitPrice: 145, taxable: true),
                    LineItem(name: "Installation Labor", details: "Remove old unit, install new flange, verify zero leaks", quantity: 2.5, unit: "hr", unitPrice: 110, taxable: false),
                ],
                taxRate: 8.25, taxLabel: "Sales Tax",
                payments: [PaymentRecord(amount: 632.23, date: cal.date(byAdding: .day, value: -4, to: now) ?? now, method: "Zelle", note: "Paid on-site via Zelle")],
                notes: profile.defaultNotes,
                paymentInstructions: profile.paymentInstructions,
                theme: .blueprintTrade,
                isSent: true
            )

            let d2 = BillingDocument(
                kind: .estimate, number: "EST-1002",
                issueDate: now,
                dueDate: cal.date(byAdding: .day, value: 14, to: now) ?? now,
                clientId: c2.id, clientName: c2.name, clientCompany: c2.company, clientEmail: c2.email, clientPhone: c2.phone, clientAddress: c2.address,
                jobTitle: "Patio Cedar Fence Repair & Gate Alignment",
                currencyCode: "USD",
                items: [
                    LineItem(name: "Cedar Fence Section Replacement", details: "Replace 24 linear ft of storm-damaged cedar pickets & rails", quantity: 24, unit: "ft", unitPrice: 38, taxable: true),
                    LineItem(name: "Heavy-Duty Self-Closing Gate Hinge Set", details: "Re-hang side gate with galvanized hardware", quantity: 1, unit: "set", unitPrice: 165, taxable: true),
                    LineItem(name: "Old Lumber Haul-Away & Disposal", details: "Clean sweep of patio and alley access", quantity: 1, unit: "job", unitPrice: 90, taxable: false),
                ],
                taxRate: 8.25, taxLabel: "Sales Tax",
                discountAmount: 50, discountIsPercent: false,
                notes: "Estimate valid for 14 days. 30% deposit schedules materials delivery; balance due upon walkthrough.",
                paymentInstructions: profile.paymentInstructions,
                theme: .classicSlate,
                isSent: true
            )

            let d3 = BillingDocument(
                kind: .invoice, number: "INV-1003",
                issueDate: cal.date(byAdding: .day, value: -20, to: now) ?? now,
                dueDate: cal.date(byAdding: .day, value: -6, to: now) ?? now,
                clientId: c3.id, clientName: c3.name, clientCompany: c3.company, clientEmail: c3.email, clientPhone: c3.phone, clientAddress: c3.address,
                jobTitle: "Drywall Patch, Texture Match & Interior Paint",
                currencyCode: "USD",
                items: [
                    LineItem(name: "Drywall Cutout, Tape & Orange-Peel Texture", details: "Hallway ceiling leak repair + primer coat", quantity: 1, unit: "job", unitPrice: 420, taxable: false),
                    LineItem(name: "Interior Paint & Materials", details: "2 gal low-VOC matte ceiling paint + drop cloths", quantity: 1, unit: "lot", unitPrice: 125, taxable: true),
                ],
                taxRate: 8.25, taxLabel: "Sales Tax",
                payments: [PaymentRecord(amount: 200, date: cal.date(byAdding: .day, value: -20, to: now) ?? now, method: "Venmo", note: "Initial deposit")],
                notes: profile.defaultNotes,
                paymentInstructions: profile.paymentInstructions,
                theme: .classicSlate,
                isSent: true
            )

            self.documents = [d2, d1, d3]
        }
        save()
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
    static var iso8601Pretty: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
