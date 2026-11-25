import Foundation
import SwiftUI

enum DocumentKind: String, Codable, CaseIterable, Identifiable {
    case invoice
    case estimate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .invoice: return L10n.t("Invoice", "发票/收款单")
        case .estimate: return L10n.t("Estimate", "报价单")
        }
    }

    var shortLabel: String {
        switch self {
        case .invoice: return L10n.t("INV", "发票")
        case .estimate: return L10n.t("EST", "报价")
        }
    }

    var pdfHeading: String {
        switch self {
        case .invoice: return L10n.t("INVOICE", "收款发票 / INVOICE")
        case .estimate: return L10n.t("ESTIMATE", "项目报价单 / ESTIMATE")
        }
    }
}

enum DocumentStatus: String, Codable, CaseIterable {
    case draft
    case sent
    case partial
    case paid
    case overdue

    var label: String {
        switch self {
        case .draft: return L10n.t("Draft", "草稿")
        case .sent: return L10n.t("Sent", "已发送")
        case .partial: return L10n.t("Partial", "部分收款")
        case .paid: return L10n.t("Paid", "已收清")
        case .overdue: return L10n.t("Overdue", "已逾期")
        }
    }

    var tint: Color {
        switch self {
        case .draft: return FlatTheme.muted
        case .sent: return FlatTheme.estimateBlue
        case .partial: return FlatTheme.accent
        case .paid: return FlatTheme.paidGreen
        case .overdue: return FlatTheme.overdueRed
        }
    }

    var bg: Color {
        switch self {
        case .draft: return Color.gray.opacity(0.12)
        case .sent: return FlatTheme.estimateBlueSoft
        case .partial: return FlatTheme.accentSoft
        case .paid: return FlatTheme.paidGreenSoft
        case .overdue: return FlatTheme.overdueRedSoft
        }
    }
}

enum PDFTheme: String, Codable, CaseIterable, Identifiable {
    case classicSlate
    case blueprintTrade
    case minimalStudio
    case boldLedger

    var id: String { rawValue }

    var isPro: Bool {
        self != .classicSlate
    }

    var title: String {
        switch self {
        case .classicSlate: return L10n.t("Classic Slate", "经典商务灰")
        case .blueprintTrade: return L10n.t("Blueprint Trade", "工程蓝图橙")
        case .minimalStudio: return L10n.t("Minimal Studio", "极简设计白")
        case .boldLedger: return L10n.t("Bold Ledger", "硬核账单黑")
        }
    }

    var swatchColor: Color {
        switch self {
        case .classicSlate: return Color(red: 0.14, green: 0.22, blue: 0.34)
        case .blueprintTrade: return FlatTheme.accent
        case .minimalStudio: return Color(red: 0.24, green: 0.24, blue: 0.26)
        case .boldLedger: return Color(red: 0.08, green: 0.09, blue: 0.10)
        }
    }
}

struct CurrencyOption: Hashable, Identifiable {
    let code: String
    let symbol: String
    let name: String
    var id: String { code }

    static let all: [CurrencyOption] = [
        CurrencyOption(code: "USD", symbol: "$", name: "USD ($)"),
        CurrencyOption(code: "CAD", symbol: "CA$", name: "CAD (CA$)"),
        CurrencyOption(code: "GBP", symbol: "£", name: "GBP (£)"),
        CurrencyOption(code: "EUR", symbol: "€", name: "EUR (€)"),
        CurrencyOption(code: "AUD", symbol: "A$", name: "AUD (A$)"),
        CurrencyOption(code: "CNY", symbol: "¥", name: "CNY (¥)"),
        CurrencyOption(code: "HKD", symbol: "HK$", name: "HKD (HK$)"),
        CurrencyOption(code: "TWD", symbol: "NT$", name: "TWD (NT$)"),
    ]

    static func symbol(for code: String) -> String {
        all.first(where: { $0.code == code })?.symbol ?? "$"
    }
}

enum MoneyFormat {
    static func format(_ amount: Double, currencyCode: String) -> String {
        let sym = CurrencyOption.symbol(for: currencyCode)
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        let str = nf.string(from: NSNumber(value: abs(amount))) ?? String(format: "%.2f", abs(amount))
        return amount < 0 ? "-\(sym)\(str)" : "\(sym)\(str)"
    }
}

struct LineItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var details: String = ""
    var quantity: Double = 1
    var unit: String = ""
    var unitPrice: Double
    var taxable: Bool = true

    var lineTotal: Double {
        max(0, quantity) * max(0, unitPrice)
    }
}

struct JobPhoto: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var caption: String
    var imageData: Data
    var capturedAt: Date = Date()
}

struct PaymentRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var amount: Double
    var date: Date = Date()
    var method: String
    var note: String = ""

    static let commonMethods: [String] = [
        "Zelle", "Venmo", "Cash", "Check", "Bank Transfer", "Cash App", "Card", "WeChat / Alipay"
    ]
}

struct ClientRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var company: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var notes: String = ""
}

struct PriceBookItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var details: String = ""
    var unit: String = "job"
    var unitPrice: Double
    var taxable: Bool = true
    var category: String = "Labor"
}

struct BusinessProfile: Codable, Equatable {
    var businessName: String = "Ridgeway Home Services LLC"
    var ownerName: String = "Mike Carter"
    var licenseNumber: String = "LIC #CA-884921"
    var email: String = "mike@ridgewayservices.example"
    var phone: String = "(512) 555-0148"
    var address: String = "410 Oakridge Blvd, Austin, TX 78704"
    var defaultTaxRate: Double = 8.25
    var defaultTaxLabel: String = "Sales Tax"
    var defaultDueDays: Int = 14
    var defaultCurrencyCode: String = "USD"
    var paymentInstructions: String = "Pay with $0 fees via Zelle: mike@ridgewayservices.example  •  Venmo: @RidgewayHome  •  Check payable to Ridgeway Home Services LLC."
    var defaultNotes: String = "Thank you for your business! All workmanship carries a 12-month warranty. Please reply to approve or confirm receipt."
    var logoData: Data? = nil
    var contractorSignatureData: Data? = nil
    var invoicePrefix: String = "INV"
    var estimatePrefix: String = "EST"
    var nextInvoiceNumber: Int = 1004
    var nextEstimateNumber: Int = 1003

    static func defaultLocalized() -> BusinessProfile {
        if L10n.isChinese {
            return BusinessProfile(
                businessName: "匠心居家维修工程部",
                ownerName: "陈师傅",
                licenseNumber: "工号 #ZJ-202608",
                email: "chen@example.com",
                phone: "138-0000-5148",
                address: "杭州市西湖区文三路 288 号",
                defaultTaxRate: 0.0,
                defaultTaxLabel: "税费",
                defaultDueDays: 7,
                defaultCurrencyCode: "CNY",
                paymentInstructions: "支持微信 / 支付宝 / 对公转账，完工验收满意后结清尾款，无平台抽成手续费。",
                defaultNotes: "感谢您的信任！本次施工享 12 个月免费质保，如有任何问题欢迎随时联系。",
                logoData: nil,
                contractorSignatureData: nil,
                invoicePrefix: "INV",
                estimatePrefix: "EST",
                nextInvoiceNumber: 1004,
                nextEstimateNumber: 1003
            )
        }
        return BusinessProfile()
    }
}

struct BillingDocument: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: DocumentKind
    var number: String
    var issueDate: Date = Date()
    var dueDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    var clientId: UUID? = nil
    var clientName: String
    var clientCompany: String = ""
    var clientEmail: String = ""
    var clientPhone: String = ""
    var clientAddress: String = ""
    var jobTitle: String = ""
    var currencyCode: String = "USD"
    var items: [LineItem]
    var taxRate: Double = 0
    var taxLabel: String = "Tax"
    var discountAmount: Double = 0
    var discountIsPercent: Bool = false
    var payments: [PaymentRecord] = []
    var photos: [JobPhoto] = []
    var notes: String = ""
    var paymentInstructions: String = ""
    var theme: PDFTheme = .classicSlate
    var clientSignatureData: Data? = nil
    var isSent: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var subtotal: Double {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    var discountValue: Double {
        let raw = discountIsPercent ? subtotal * (max(0, min(100, discountAmount)) / 100.0) : max(0, discountAmount)
        return min(subtotal, raw)
    }

    var taxableSubtotal: Double {
        let taxableRaw = items.filter(\.taxable).reduce(0) { $0 + $1.lineTotal }
        guard subtotal > 0 else { return 0 }
        let ratio = (subtotal - discountValue) / subtotal
        return max(0, taxableRaw * ratio)
    }

    var taxAmount: Double {
        let raw = taxableSubtotal * (max(0, taxRate) / 100.0)
        return (raw * 100.0).rounded() / 100.0
    }

    var total: Double {
        max(0, subtotal - discountValue + taxAmount)
    }

    var amountPaid: Double {
        payments.reduce(0) { $0 + max(0, $1.amount) }
    }

    var balanceDue: Double {
        max(0, total - amountPaid)
    }

    var computedStatus: DocumentStatus {
        if kind == .estimate {
            return isSent ? .sent : .draft
        }
        if total > 0 && balanceDue <= 0.009 {
            return .paid
        }
        if amountPaid > 0.009 && balanceDue > 0.009 {
            return .partial
        }
        if isSent && dueDate < Calendar.current.startOfDay(for: Date()) {
            return .overdue
        }
        return isSent ? .sent : .draft
    }
}

struct LedgerBackupBundle: Codable {
    var schemaVersion: Int = 1
    var exportedAt: Date = Date()
    var profile: BusinessProfile
    var clients: [ClientRecord]
    var priceBook: [PriceBookItem]
    var documents: [BillingDocument]
}
