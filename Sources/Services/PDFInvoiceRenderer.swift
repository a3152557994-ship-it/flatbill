import Foundation
import UIKit

enum PDFInvoiceRenderer {
    struct Palette {
        let headerBg: UIColor
        let headerInk: UIColor
        let accent: UIColor
        let tableHeaderBg: UIColor
        let tableHeaderInk: UIColor
        let zebraBg: UIColor
        let darkHeader: Bool
    }

    private static func palette(for theme: PDFTheme) -> Palette {
        switch theme {
        case .classicSlate:
            return Palette(
                headerBg: UIColor(red: 0.11, green: 0.16, blue: 0.24, alpha: 1),
                headerInk: .white,
                accent: UIColor(red: 0.15, green: 0.36, blue: 0.65, alpha: 1),
                tableHeaderBg: UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1),
                tableHeaderInk: UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1),
                zebraBg: UIColor(red: 0.98, green: 0.985, blue: 0.99, alpha: 1),
                darkHeader: true
            )
        case .blueprintTrade:
            return Palette(
                headerBg: UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1),
                headerInk: .white,
                accent: UIColor(red: 0.85, green: 0.42, blue: 0.09, alpha: 1),
                tableHeaderBg: UIColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1),
                tableHeaderInk: .white,
                zebraBg: UIColor(red: 0.985, green: 0.975, blue: 0.96, alpha: 1),
                darkHeader: true
            )
        case .minimalStudio:
            return Palette(
                headerBg: .white,
                headerInk: UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1),
                accent: UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1),
                tableHeaderBg: UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1),
                tableHeaderInk: UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
                zebraBg: UIColor(red: 0.99, green: 0.99, blue: 0.99, alpha: 1),
                darkHeader: false
            )
        case .boldLedger:
            return Palette(
                headerBg: UIColor(red: 0.06, green: 0.07, blue: 0.08, alpha: 1),
                headerInk: .white,
                accent: UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1),
                tableHeaderBg: UIColor(red: 0.06, green: 0.07, blue: 0.08, alpha: 1),
                tableHeaderInk: .white,
                zebraBg: UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1),
                darkHeader: true
            )
        }
    }

    static func renderPDFData(
        document: BillingDocument,
        profile: BusinessProfile,
        includeBrandingFooter: Bool
    ) -> Data {
        let pageRect = profile.paperSize.pageRect
        let margin: CGFloat = 40
        let contentW = pageRect.width - margin * 2
        let pal = palette(for: document.theme)

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(document.number) - \(document.clientName)",
            kCGPDFContextCreator as String: "FlatBill",
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        return renderer.pdfData { ctx in
            var pageIndex = 1
            func beginNewPage() {
                ctx.beginPage()
                UIColor.white.setFill()
                ctx.fill(pageRect)
            }

            func drawFooter(pageNumber: Int) {
                let y = pageRect.height - 28
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin, y: y - 6))
                linePath.addLine(to: CGPoint(x: pageRect.width - margin, y: y - 6))
                UIColor(white: 0.88, alpha: 1).setStroke()
                linePath.lineWidth = 0.6
                linePath.stroke()

                let leftText = includeBrandingFooter
                    ? L10n.t("Created offline with FlatBill • Zero Monthly Fees (App Store)", "由 FlatBill 本地生成 • 零月费离线开单工具", "由 FlatBill 本機生成 • 零月費離線開單工具")
                    : "\(profile.businessName) • \(document.number)"
                drawText(leftText, in: CGRect(x: margin, y: y, width: contentW * 0.72, height: 14), font: .systemFont(ofSize: 8.5), color: UIColor(white: 0.50, alpha: 1))

                let rightText = L10n.t("Page \(pageNumber)", "第 \(pageNumber) 页")
                drawText(rightText, in: CGRect(x: margin + contentW * 0.72, y: y, width: contentW * 0.28, height: 14), font: .systemFont(ofSize: 8.5), color: UIColor(white: 0.50, alpha: 1), alignment: .right)
            }

            beginNewPage()
            var y: CGFloat = 0

            // MARK: - Top Header Banner
            let headerH: CGFloat = 114
            if pal.darkHeader {
                pal.headerBg.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: headerH))
                pal.accent.setFill()
                ctx.fill(CGRect(x: 0, y: headerH - 4, width: pageRect.width, height: 4))
            } else {
                pal.accent.setFill()
                ctx.fill(CGRect(x: margin, y: headerH - 2, width: contentW, height: 2))
            }

            // Business Logo + Name (Left)
            var leftX = margin
            if let logoData = profile.logoData, let logoImg = UIImage(data: logoData) {
                let logoBox = CGRect(x: margin, y: 24, width: 58, height: 58)
                let rounded = UIBezierPath(roundedRect: logoBox, cornerRadius: 8)
                ctx.cgContext.saveGState()
                rounded.addClip()
                logoImg.draw(in: logoBox)
                ctx.cgContext.restoreGState()
                leftX += 70
            }

            let bizTitle = profile.businessName.isEmpty ? "FlatBill Business" : profile.businessName
            drawText(bizTitle, in: CGRect(x: leftX, y: 24, width: 290, height: 24), font: .boldSystemFont(ofSize: 17), color: pal.headerInk)

            var subLines: [String] = []
            let idsLine = [profile.licenseNumber, profile.taxID].filter { !$0.isEmpty }.joined(separator: "  •  ")
            if !idsLine.isEmpty { subLines.append(idsLine) }
            let contactLine = [profile.phone, profile.email].filter { !$0.isEmpty }.joined(separator: "  •  ")
            if !contactLine.isEmpty { subLines.append(contactLine) }
            if !profile.address.isEmpty { subLines.append(profile.address) }
            let subColor = pal.darkHeader ? UIColor(white: 0.84, alpha: 1) : UIColor(white: 0.36, alpha: 1)
            drawText(subLines.joined(separator: "\n"), in: CGRect(x: leftX, y: 49, width: 310, height: 52), font: .systemFont(ofSize: 9.2), color: subColor, lineSpacing: 2.5)

            // Document Kind & Number (Right)
            drawText(document.kind.pdfHeading, in: CGRect(x: pageRect.width - margin - 210, y: 22, width: 210, height: 28), font: .systemFont(ofSize: 21, weight: .heavy), color: pal.darkHeader ? pal.accent : pal.headerInk, alignment: .right)
            drawText("#\(document.number)", in: CGRect(x: pageRect.width - margin - 210, y: 50, width: 210, height: 18), font: .monospacedDigitSystemFont(ofSize: 13, weight: .bold), color: pal.headerInk, alignment: .right)

            let dateMeta = "\(L10n.t("Issued", "开单日期")): \(df.string(from: document.issueDate))\n\(document.kind == .invoice ? L10n.t("Due Date", "到期日") : L10n.t("Valid Until", "有效期至")): \(df.string(from: document.dueDate))"
            drawText(dateMeta, in: CGRect(x: pageRect.width - margin - 210, y: 70, width: 210, height: 34), font: .systemFont(ofSize: 9.2), color: subColor, alignment: .right, lineSpacing: 2.5)

            y = headerH + 20

            // MARK: - Bill To + Summary Box
            let leftColW = contentW * 0.56
            let rightColW = contentW * 0.40
            let rightColX = margin + contentW - rightColW

            drawText(L10n.t("BILL TO", "客户信息"), in: CGRect(x: margin, y: y, width: leftColW, height: 13), font: .boldSystemFont(ofSize: 8.5), color: pal.accent)
            let clientDisplay = document.clientName.isEmpty ? L10n.t("Valued Customer", "客户") : document.clientName
            drawText(clientDisplay, in: CGRect(x: margin, y: y + 15, width: leftColW, height: 19), font: .boldSystemFont(ofSize: 13.5), color: .black)

            var cDetails: [String] = []
            if !document.clientCompany.isEmpty { cDetails.append(document.clientCompany) }
            if !document.clientAddress.isEmpty { cDetails.append(document.clientAddress) }
            let cContact = [document.clientPhone, document.clientEmail].filter { !$0.isEmpty }.joined(separator: "  •  ")
            if !cContact.isEmpty { cDetails.append(cContact) }
            if !document.jobTitle.isEmpty {
                cDetails.append("\(L10n.t("Job", "项目")): \(document.jobTitle)")
            }
            drawText(cDetails.joined(separator: "\n"), in: CGRect(x: margin, y: y + 35, width: leftColW, height: 58), font: .systemFont(ofSize: 9.5), color: UIColor(white: 0.28, alpha: 1), lineSpacing: 2.5)

            // Right Balance Callout Box
            let boxRect = CGRect(x: rightColX, y: y, width: rightColW, height: 76)
            let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 8)
            UIColor(red: 0.965, green: 0.965, blue: 0.96, alpha: 1).setFill()
            boxPath.fill()
            UIColor(white: 0.87, alpha: 1).setStroke()
            boxPath.lineWidth = 0.8
            boxPath.stroke()

            let amountLabel = document.kind == .estimate
                ? L10n.t("ESTIMATE TOTAL", "报价总额")
                : (document.computedStatus == .paid ? L10n.t("AMOUNT PAID", "已结清总额") : L10n.t("BALANCE DUE", "应付余额"))
            let amountNum = document.kind == .estimate
                ? document.total
                : (document.computedStatus == .paid ? document.total : document.balanceDue)

            drawText(amountLabel, in: CGRect(x: rightColX + 14, y: y + 12, width: rightColW - 28, height: 14), font: .boldSystemFont(ofSize: 8.5), color: UIColor(white: 0.42, alpha: 1), alignment: .right)
            drawText(
                MoneyFormat.format(amountNum, currencyCode: document.currencyCode),
                in: CGRect(x: rightColX + 14, y: y + 29, width: rightColW - 28, height: 28),
                font: .monospacedDigitSystemFont(ofSize: 22, weight: .heavy),
                color: document.computedStatus == .paid ? UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1) : pal.headerBg,
                alignment: .right
            )

            // PAID Rubber Stamp Overlay
            if document.computedStatus == .paid {
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: rightColX + 44, y: y + 38)
                ctx.cgContext.rotate(by: -0.22)
                let stampRect = CGRect(x: -36, y: -14, width: 72, height: 28)
                let stampPath = UIBezierPath(roundedRect: stampRect, cornerRadius: 5)
                let green = UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 0.9)
                green.setStroke()
                stampPath.lineWidth = 2.0
                stampPath.stroke()
                drawText(L10n.t("PAID", "已结清"), in: CGRect(x: -34, y: -9, width: 68, height: 18), font: .systemFont(ofSize: 13, weight: .black), color: green, alignment: .center)
                ctx.cgContext.restoreGState()
            }

            y += 102

            // MARK: - Line Items Table Header
            func drawTableHeader(at topY: CGFloat) -> CGFloat {
                let h: CGFloat = 26
                let rect = CGRect(x: margin, y: topY, width: contentW, height: h)
                let p = UIBezierPath(roundedRect: rect, cornerRadius: 5)
                pal.tableHeaderBg.setFill()
                p.fill()

                let f = UIFont.boldSystemFont(ofSize: 9)
                drawText(L10n.t("DESCRIPTION", "项目明细"), in: CGRect(x: margin + 10, y: topY + 7, width: contentW * 0.52, height: 14), font: f, color: pal.tableHeaderInk)
                drawText(L10n.t("QTY", "数量"), in: CGRect(x: margin + contentW * 0.53, y: topY + 7, width: contentW * 0.13, height: 14), font: f, color: pal.tableHeaderInk, alignment: .right)
                drawText(L10n.t("RATE", "单价"), in: CGRect(x: margin + contentW * 0.67, y: topY + 7, width: contentW * 0.15, height: 14), font: f, color: pal.tableHeaderInk, alignment: .right)
                drawText(L10n.t("AMOUNT", "小计"), in: CGRect(x: margin + contentW * 0.83, y: topY + 7, width: contentW * 0.17 - 10, height: 14), font: f, color: pal.tableHeaderInk, alignment: .right)
                return topY + h + 4
            }

            y = drawTableHeader(at: y)

            // MARK: - Line Items Rows (with automatic multi-page overflow)
            for (idx, item) in document.items.enumerated() {
                let descW = contentW * 0.50
                let nameText = item.name.isEmpty ? L10n.t("Line Item", "服务项目") : item.name
                let nameH = measureHeight(nameText, width: descW, font: .boldSystemFont(ofSize: 10.2))
                let detailH = item.details.isEmpty ? 0 : measureHeight(item.details, width: descW, font: .systemFont(ofSize: 8.8)) + 3
                let rowH = max(28, nameH + detailH + 12)

                if y + rowH > pageRect.height - 85 {
                    drawFooter(pageNumber: pageIndex)
                    pageIndex += 1
                    beginNewPage()
                    y = 40
                    y = drawTableHeader(at: y)
                }

                if idx % 2 == 1 {
                    pal.zebraBg.setFill()
                    ctx.fill(CGRect(x: margin, y: y, width: contentW, height: rowH))
                }

                drawText(nameText, in: CGRect(x: margin + 10, y: y + 6, width: descW, height: nameH + 2), font: .boldSystemFont(ofSize: 10.2), color: .black)
                if !item.details.isEmpty {
                    drawText(item.details, in: CGRect(x: margin + 10, y: y + 6 + nameH + 2, width: descW, height: detailH), font: .systemFont(ofSize: 8.8), color: UIColor(white: 0.42, alpha: 1))
                }

                let qtyStr = formatQty(item.quantity) + (item.unit.isEmpty ? "" : " \(item.unit)")
                drawText(qtyStr, in: CGRect(x: margin + contentW * 0.53, y: y + 7, width: contentW * 0.13, height: 16), font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular), color: UIColor(white: 0.20, alpha: 1), alignment: .right)
                drawText(MoneyFormat.format(item.unitPrice, currencyCode: document.currencyCode), in: CGRect(x: margin + contentW * 0.67, y: y + 7, width: contentW * 0.15, height: 16), font: .monospacedDigitSystemFont(ofSize: 9.5, weight: .regular), color: UIColor(white: 0.20, alpha: 1), alignment: .right)
                drawText(MoneyFormat.format(item.lineTotal, currencyCode: document.currencyCode), in: CGRect(x: margin + contentW * 0.83, y: y + 7, width: contentW * 0.17 - 10, height: 16), font: .monospacedDigitSystemFont(ofSize: 10, weight: .semibold), color: .black, alignment: .right)

                // Row separator
                let sep = UIBezierPath()
                sep.move(to: CGPoint(x: margin, y: y + rowH))
                sep.addLine(to: CGPoint(x: margin + contentW, y: y + rowH))
                UIColor(white: 0.91, alpha: 1).setStroke()
                sep.lineWidth = 0.5
                sep.stroke()

                y += rowH
            }

            y += 14

            // Ensure Totals + Payment Instructions + Signatures fit cleanly on page
            if y > pageRect.height - 235 {
                drawFooter(pageNumber: pageIndex)
                pageIndex += 1
                beginNewPage()
                y = 44
            }

            // MARK: - Totals Stack (Right) + Payment Instructions (Left)
            let totalsX = margin + contentW * 0.58
            let totalsW = contentW * 0.42
            let leftNotesW = contentW * 0.53
            let sectionStartY = y

            func drawTotalRow(_ label: String, _ value: String, bold: Bool = false, color: UIColor = .black, highlight: Bool = false) {
                let rowH: CGFloat = highlight ? 26 : 19
                if highlight {
                    let r = CGRect(x: totalsX - 8, y: y - 3, width: totalsW + 8, height: rowH)
                    let p = UIBezierPath(roundedRect: r, cornerRadius: 5)
                    pal.accent.withAlphaComponent(0.11).setFill()
                    p.fill()
                }
                let lf = bold ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 9.6)
                let vf = UIFont.monospacedDigitSystemFont(ofSize: bold ? 11.5 : 9.8, weight: bold ? .bold : .medium)
                drawText(label, in: CGRect(x: totalsX, y: y + (highlight ? 3 : 0), width: totalsW * 0.52, height: 18), font: lf, color: color)
                drawText(value, in: CGRect(x: totalsX + totalsW * 0.52, y: y + (highlight ? 3 : 0), width: totalsW * 0.48 - 4, height: 18), font: vf, color: color, alignment: .right)
                y += rowH
            }

            drawTotalRow(L10n.t("Subtotal", "小计"), MoneyFormat.format(document.subtotal, currencyCode: document.currencyCode))
            if document.discountValue > 0.009 {
                let dLabel = document.discountIsPercent
                    ? L10n.t("Discount (\(formatQty(document.discountAmount))%)", "折扣 (\(formatQty(document.discountAmount))%)")
                    : L10n.t("Discount", "优惠减免")
                drawTotalRow(dLabel, MoneyFormat.format(-document.discountValue, currencyCode: document.currencyCode), color: UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1))
            }
            if document.taxRate > 0.001 {
                let tLabel = "\(document.taxLabel.isEmpty ? L10n.t("Tax", "税费") : document.taxLabel) (\(formatQty(document.taxRate))%)"
                drawTotalRow(tLabel, MoneyFormat.format(document.taxAmount, currencyCode: document.currencyCode))
            }
            drawTotalRow(L10n.t("Total", "合计总额"), MoneyFormat.format(document.total, currencyCode: document.currencyCode), bold: true)

            if document.kind == .invoice && document.amountPaid > 0.009 {
                drawTotalRow(L10n.t("Amount Paid", "已收款"), MoneyFormat.format(-document.amountPaid, currencyCode: document.currencyCode), color: UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1))
            }
            if document.kind == .invoice {
                drawTotalRow(
                    L10n.t("Balance Due", "剩余应付"),
                    MoneyFormat.format(document.balanceDue, currencyCode: document.currencyCode),
                    bold: true,
                    color: document.computedStatus == .paid ? UIColor(red: 0.08, green: 0.50, blue: 0.24, alpha: 1) : pal.headerBg,
                    highlight: true
                )
            }

            // Left: Payment Instructions & Notes
            var leftY = sectionStartY
            if !document.paymentInstructions.isEmpty {
                let textH = measureHeight(document.paymentInstructions, width: leftNotesW - 20, font: .systemFont(ofSize: 8.8), lineSpacing: 2.0)
                let boxH = max(48, textH + 30)
                let pRect = CGRect(x: margin, y: leftY, width: leftNotesW, height: boxH)
                let pPath = UIBezierPath(roundedRect: pRect, cornerRadius: 6)
                UIColor(red: 0.99, green: 0.96, blue: 0.92, alpha: 1).setFill()
                pPath.fill()
                pal.accent.withAlphaComponent(0.35).setStroke()
                pPath.lineWidth = 0.8
                pPath.stroke()

                drawText(L10n.t("PAYMENT INSTRUCTIONS (0% FEE)", "收款方式说明"), in: CGRect(x: margin + 10, y: leftY + 7, width: leftNotesW - 20, height: 13), font: .boldSystemFont(ofSize: 8.2), color: pal.accent)
                drawText(document.paymentInstructions, in: CGRect(x: margin + 10, y: leftY + 21, width: leftNotesW - 20, height: textH + 6), font: .systemFont(ofSize: 8.8), color: UIColor(white: 0.20, alpha: 1), lineSpacing: 2.0)
                leftY += boxH + 10
            }
            if !document.notes.isEmpty {
                drawText(L10n.t("NOTES & WARRANTY", "备注与质保说明"), in: CGRect(x: margin, y: leftY, width: leftNotesW, height: 13), font: .boldSystemFont(ofSize: 8.2), color: UIColor(white: 0.45, alpha: 1))
                let nh = measureHeight(document.notes, width: leftNotesW, font: .systemFont(ofSize: 8.8), lineSpacing: 2.0) + 6
                drawText(document.notes, in: CGRect(x: margin, y: leftY + 14, width: leftNotesW, height: nh), font: .systemFont(ofSize: 8.8), color: UIColor(white: 0.30, alpha: 1), lineSpacing: 2.0)
                leftY += nh + 18
            }

            y = max(y, leftY) + 14

            // MARK: - Signatures Block (Contractor & Client)
            let hasContractorSig = profile.contractorSignatureData != nil
            let hasClientSig = document.clientSignatureData != nil
            if hasContractorSig || hasClientSig {
                if y > pageRect.height - 115 {
                    drawFooter(pageNumber: pageIndex)
                    pageIndex += 1
                    beginNewPage()
                    y = 48
                }
                let sigW = (contentW - 24) / 2
                drawSignatureBox(
                    title: L10n.t("Authorized Signature (\(profile.ownerName.isEmpty ? profile.businessName : profile.ownerName))", "服务方签名"),
                    imageData: profile.contractorSignatureData,
                    in: CGRect(x: margin, y: y, width: sigW, height: 68)
                )
                drawSignatureBox(
                    title: L10n.t("Client Approval (\(clientDisplay))", "客户验收/确认签名"),
                    imageData: document.clientSignatureData,
                    in: CGRect(x: margin + sigW + 24, y: y, width: sigW, height: 68)
                )
                y += 78
            }

            drawFooter(pageNumber: pageIndex)

            // MARK: - Dedicated Page 2+ Job Site Photos Addendum (Zero Text Overlap!)
            if !document.photos.isEmpty {
                let perPage = 4
                for chunkStart in stride(from: 0, to: document.photos.count, by: perPage) {
                    pageIndex += 1
                    beginNewPage()

                    drawText(
                        L10n.t("JOB SITE PHOTO ADDENDUM — #\(document.number)", "施工现场照片附页 — #\(document.number)"),
                        in: CGRect(x: margin, y: 36, width: contentW, height: 22),
                        font: .boldSystemFont(ofSize: 14),
                        color: pal.headerBg
                    )
                    drawText(
                        "\(clientDisplay) • \(document.jobTitle.isEmpty ? L10n.t("Before & After Documentation", "施工验收留档") : document.jobTitle)",
                        in: CGRect(x: margin, y: 58, width: contentW, height: 15),
                        font: .systemFont(ofSize: 9.5),
                        color: UIColor(white: 0.42, alpha: 1)
                    )
                    let accentBar = UIBezierPath(rect: CGRect(x: margin, y: 78, width: contentW, height: 2))
                    pal.accent.setFill()
                    accentBar.fill()

                    let slice = Array(document.photos[chunkStart..<min(chunkStart + perPage, document.photos.count)])
                    let gap: CGFloat = 18
                    let cellW = (contentW - gap) / 2
                    let cellH: CGFloat = 290
                    let startY: CGFloat = 98

                    for (i, photo) in slice.enumerated() {
                        let col = i % 2
                        let row = i / 2
                        let cx = margin + CGFloat(col) * (cellW + gap)
                        let cy = startY + CGFloat(row) * (cellH + gap)

                        let cardRect = CGRect(x: cx, y: cy, width: cellW, height: cellH)
                        let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
                        UIColor(white: 0.97, alpha: 1).setFill()
                        cardPath.fill()
                        UIColor(white: 0.88, alpha: 1).setStroke()
                        cardPath.lineWidth = 0.8
                        cardPath.stroke()

                        let imgRect = CGRect(x: cx + 8, y: cy + 8, width: cellW - 16, height: cellH - 52)
                        if let img = UIImage(data: photo.imageData) {
                            ctx.cgContext.saveGState()
                            UIBezierPath(roundedRect: imgRect, cornerRadius: 6).addClip()
                            drawAspectFill(img, in: imgRect)
                            ctx.cgContext.restoreGState()
                        }

                        let cap = photo.caption.isEmpty ? L10n.t("Job Photo #\(chunkStart + i + 1)", "现场照片 #\(chunkStart + i + 1)") : photo.caption
                        drawText(cap, in: CGRect(x: cx + 10, y: cy + cellH - 38, width: cellW - 20, height: 30), font: .boldSystemFont(ofSize: 9.5), color: UIColor(white: 0.18, alpha: 1))
                    }

                    drawFooter(pageNumber: pageIndex)
                }
            }
        }
    }

    private static func drawSignatureBox(title: String, imageData: Data?, in rect: CGRect) {
        if let data = imageData, let img = UIImage(data: data) {
            let imgBox = CGRect(x: rect.minX + 6, y: rect.minY, width: rect.width - 12, height: rect.height - 22)
            drawAspectFit(img, in: imgBox)
        }
        let line = UIBezierPath()
        line.move(to: CGPoint(x: rect.minX, y: rect.maxY - 18))
        line.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 18))
        UIColor(white: 0.72, alpha: 1).setStroke()
        line.lineWidth = 0.9
        line.stroke()

        drawText(title, in: CGRect(x: rect.minX, y: rect.maxY - 14, width: rect.width, height: 14), font: .systemFont(ofSize: 8.5), color: UIColor(white: 0.42, alpha: 1))
    }

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect) {
        let imgAspect = image.size.width / max(1, image.size.height)
        let boxAspect = rect.width / max(1, rect.height)
        var drawRect = rect
        if imgAspect > boxAspect {
            let w = rect.height * imgAspect
            drawRect = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height)
        } else {
            let h = rect.width / imgAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
        }
        image.draw(in: drawRect)
    }

    private static func drawAspectFit(_ image: UIImage, in rect: CGRect) {
        let imgAspect = image.size.width / max(1, image.size.height)
        let boxAspect = rect.width / max(1, rect.height)
        var drawRect = rect
        if imgAspect > boxAspect {
            let h = rect.width / imgAspect
            drawRect = CGRect(x: rect.minX, y: rect.midY - h / 2, width: rect.width, height: h)
        } else {
            let w = rect.height * imgAspect
            drawRect = CGRect(x: rect.midX - w / 2, y: rect.minY, width: w, height: rect.height)
        }
        image.draw(in: drawRect)
    }

    private static func formatQty(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.001 {
            return String(Int(value.rounded()))
        }
        var s = String(format: "%.2f", value)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            s.removeLast()
        }
        return s
    }

    private static func measureHeight(_ text: String, width: CGFloat, font: UIFont, lineSpacing: CGFloat = 1.5) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style],
            context: nil
        )
        return ceil(rect.height)
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 1.5
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
    }
}
