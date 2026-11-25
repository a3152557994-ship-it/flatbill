import PDFKit
import UIKit
import XCTest
@testable import FlatBill

@MainActor
final class FlatBillTests: XCTestCase {
    func testInvoiceTotalsTaxableDiscountAndPartialPayment() {
        let doc = BillingDocument(
            kind: .invoice,
            number: "INV-2001",
            clientName: "Alice Tester",
            currencyCode: "USD",
            items: [
                LineItem(name: "Materials", quantity: 2, unitPrice: 100, taxable: true),
                LineItem(name: "Labor", quantity: 1, unitPrice: 100, taxable: false),
            ],
            taxRate: 10.0,
            taxLabel: "Sales Tax",
            discountAmount: 30.0,
            discountIsPercent: false,
            payments: [PaymentRecord(amount: 100, method: "Zelle")],
            isSent: true
        )

        XCTAssertEqual(doc.subtotal, 300.0, accuracy: 0.01)
        XCTAssertEqual(doc.discountValue, 30.0, accuracy: 0.01)
        // Pro-rated taxable subtotal: 200 * (270/300) = 180 -> 10% tax = 18
        XCTAssertEqual(doc.taxAmount, 18.0, accuracy: 0.01)
        XCTAssertEqual(doc.total, 288.0, accuracy: 0.01)
        XCTAssertEqual(doc.balanceDue, 188.0, accuracy: 0.01)
        XCTAssertEqual(doc.computedStatus, .partial)
    }

    func testCloneSwapClientAndConvertEstimate() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("flatbill_test_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = LedgerStore(customURL: tmp, seedIfEmpty: true)

        let est = store.documents.first { $0.kind == .estimate }!
        let otherClient = store.clients.first { $0.name != est.clientName }!

        let cloned = store.cloneDocument(est, swapClient: otherClient)
        XCTAssertNotEqual(cloned.id, est.id)
        XCTAssertNotEqual(cloned.number, est.number)
        XCTAssertEqual(cloned.clientName, otherClient.name)
        XCTAssertEqual(cloned.items.count, est.items.count)
        XCTAssertTrue(cloned.payments.isEmpty)

        let inv = store.convertEstimateToInvoice(est)
        XCTAssertEqual(inv.kind, .invoice)
        XCTAssertTrue(inv.number.hasPrefix(store.profile.invoicePrefix))
        XCTAssertEqual(inv.total, est.total, accuracy: 0.01)
    }

    func testPDFRendererAllThemesAndPhotoAddendumPage() {
        let profile = BusinessProfile()
        // Create tiny valid sample JPEG
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 150))
        let img = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 150))
        }
        let jpeg = img.jpegData(compressionQuality: 0.8)!

        for theme in PDFTheme.allCases {
            let doc = BillingDocument(
                kind: .invoice,
                number: "INV-9999",
                clientName: "John Contractor",
                jobTitle: "Roof Patch & Gutter Cleaning",
                items: [
                    LineItem(name: "Shingle Repair", details: "Match charcoal architectural shingles", quantity: 1, unit: "job", unitPrice: 450, taxable: true),
                ],
                taxRate: 8.25,
                payments: [PaymentRecord(amount: 487.13, method: "Zelle")],
                photos: [JobPhoto(caption: "After repair completion", imageData: jpeg)],
                notes: "12-month leak warranty.",
                paymentInstructions: "Zelle: test@example.com",
                theme: theme,
                isSent: true
            )
            let pdfData = PDFInvoiceRenderer.renderPDFData(document: doc, profile: profile, includeBrandingFooter: false)
            XCTAssertGreaterThan(pdfData.count, 5_000, "PDF data should be substantial for theme \(theme)")
            let pdfDoc = PDFDocument(data: pdfData)
            XCTAssertNotNil(pdfDoc)
            XCTAssertEqual(pdfDoc?.pageCount, 2, "Should render Page 1 invoice + Page 2 clean job photo addendum")
        }
    }

    func testJSONBackupRestoreAndTaxCSV() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("flatbill_bak_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = LedgerStore(customURL: tmp, seedIfEmpty: true)

        let csv = store.exportTaxCSV()
        XCTAssertTrue(csv.contains("Type,Number,Status,IssueDate"))
        XCTAssertTrue(csv.contains("INV-1001"))

        let bak = store.exportJSONBackupData()
        XCTAssertNotNil(bak)

        let tmp2 = FileManager.default.temporaryDirectory.appendingPathComponent("flatbill_bak2_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp2) }
        let restored = LedgerStore(customURL: tmp2, seedIfEmpty: false)
        XCTAssertTrue(restored.documents.isEmpty)
        XCTAssertTrue(restored.importJSONBackupData(bak!))
        XCTAssertEqual(restored.documents.count, store.documents.count)
    }
}
