import PhotosUI
import SwiftUI
import UIKit

struct DocumentEditorView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var draft: BillingDocument
    let isNew: Bool
    var onSavedAndPreview: ((BillingDocument) -> Void)? = nil

    @State private var showClientPicker = false
    @State private var showPriceBookPicker = false
    @State private var showSignaturePad = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showDiscardAlert = false
    @State private var hasUnsavedChanges = false

    init(document: BillingDocument, isNew: Bool, onSavedAndPreview: ((BillingDocument) -> Void)? = nil) {
        _draft = State(initialValue: document)
        self.isNew = isNew
        self.onSavedAndPreview = onSavedAndPreview
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. Document Type & Number
                Section(L10n.t("Document Info", "单据基础信息")) {
                    Picker(L10n.t("Type", "单据类型"), selection: $draft.kind) {
                        ForEach(DocumentKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(L10n.t("Number", "单据编号"))
                        Spacer()
                        TextField("INV-1001", text: $draft.number)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.semibold).monospacedDigit())
                    }

                    TextField(L10n.t("Job Title (e.g., Fence Repair)", "工程/项目名称（如：厨房水电改造）"), text: $draft.jobTitle)

                    DatePicker(L10n.t("Issue Date", "开单日期"), selection: $draft.issueDate, displayedComponents: .date)
                    DatePicker(
                        draft.kind == .invoice ? L10n.t("Due Date", "应付截止日") : L10n.t("Valid Until", "报价有效期至"),
                        selection: $draft.dueDate,
                        displayedComponents: .date
                    )

                    Picker(L10n.t("Currency", "结算币种"), selection: $draft.currencyCode) {
                        ForEach(CurrencyOption.all) { c in
                            Text(c.name).tag(c.code)
                        }
                    }
                }

                // 2. Client Info (with 1-tap directory pick)
                Section {
                    Button {
                        showClientPicker = true
                    } label: {
                        Label(L10n.t("Pick from Saved Clients", "从老客户通讯录一键填入"), systemImage: "person.crop.circle.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FlatTheme.accent)
                    }

                    TextField(L10n.t("Client Name *", "客户姓名 *"), text: $draft.clientName)
                    TextField(L10n.t("Company / Property (optional)", "公司 / 小区门牌（选填）"), text: $draft.clientCompany)
                    TextField(L10n.t("Phone", "联系电话"), text: $draft.clientPhone)
                        .keyboardType(.phonePad)
                    TextField(L10n.t("Email", "电子邮箱"), text: $draft.clientEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField(L10n.t("Job Site Address", "施工/客户地址"), text: $draft.clientAddress)
                } header: {
                    Text(L10n.t("Bill To", "客户信息"))
                }

                // 3. Line Items + Quick Price Book Insert
                Section {
                    ForEach($draft.items) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(L10n.t("Item or Service Name", "项目 / 材料 / 服务名称"), text: $item.name)
                                .font(.subheadline.weight(.bold))
                            TextField(L10n.t("Description / Scope (optional)", "规格说明 / 施工细节（选填）"), text: $item.details)
                                .font(.caption)
                                .foregroundStyle(FlatTheme.muted)

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("Qty", "数量")).font(.caption2).foregroundStyle(FlatTheme.muted)
                                    TextField("1", value: $item.quantity, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .frame(width: 64)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("Unit", "单位")).font(.caption2).foregroundStyle(FlatTheme.muted)
                                    TextField(L10n.t("hr/job", "项/㎡"), text: $item.unit)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .frame(width: 68)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("Unit Price", "单价")).font(.caption2).foregroundStyle(FlatTheme.muted)
                                    TextField("0.00", value: $item.unitPrice, format: .number)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(L10n.t("Total", "小计")).font(.caption2).foregroundStyle(FlatTheme.muted)
                                    Text(MoneyFormat.format(item.lineTotal, currencyCode: draft.currencyCode))
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(FlatTheme.ink)
                                }
                            }

                            Toggle(L10n.t("Taxable", "计入税费"), isOn: $item.taxable)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        draft.items.remove(atOffsets: offsets)
                        if draft.items.isEmpty {
                            draft.items.append(LineItem(name: "", unitPrice: 0))
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            draft.items.append(LineItem(name: "", quantity: 1, unit: L10n.t("job", "项"), unitPrice: 0))
                        } label: {
                            Label(L10n.t("Add Blank Line", "加一行明细"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FlatTheme.ink)
                        }
                        Spacer()
                        Button {
                            showPriceBookPicker = true
                        } label: {
                            Label(L10n.t("From Price Book", "从价目库秒加"), systemImage: "bolt.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(FlatTheme.accent)
                        }
                    }
                } header: {
                    Text(L10n.t("Line Items", "费用明细"))
                }

                // 4. Tax, Discount & Live Total Summary
                Section(L10n.t("Tax, Discount & Total", "税费、折扣与合计")) {
                    HStack {
                        Text(L10n.t("Tax Label", "税项名称"))
                        Spacer()
                        TextField("Sales Tax", text: $draft.taxLabel)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.t("Tax Rate (%)", "税率 (%)"))
                        Spacer()
                        TextField("0", value: $draft.taxRate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text(L10n.t("Discount", "优惠减免"))
                        Spacer()
                        Picker("", selection: $draft.discountIsPercent) {
                            Text(CurrencyOption.symbol(for: draft.currencyCode)).tag(false)
                            Text("%").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 86)

                        TextField("0", value: $draft.discountAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                    }

                    summaryRow(L10n.t("Subtotal", "小计"), MoneyFormat.format(draft.subtotal, currencyCode: draft.currencyCode), bold: false)
                    if draft.discountValue > 0.009 {
                        summaryRow(L10n.t("Discount", "折扣减免"), MoneyFormat.format(-draft.discountValue, currencyCode: draft.currencyCode), bold: false)
                    }
                    if draft.taxRate > 0.001 {
                        summaryRow(draft.taxLabel, MoneyFormat.format(draft.taxAmount, currencyCode: draft.currencyCode), bold: false)
                    }
                    summaryRow(L10n.t("Total", "最终合计"), MoneyFormat.format(draft.total, currencyCode: draft.currencyCode), bold: true)
                }

                // 5. Job Site Photos (Dedicated Page 2 — Zero Overlap Guarantee!)
                Section {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            L10n.t("Attach Before / After Job Photo", "添加施工前后现场照片"),
                            systemImage: "camera.badge.ellipsis"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlatTheme.accent)
                    }

                    ForEach($draft.photos) { $photo in
                        HStack(spacing: 12) {
                            if let uiImg = UIImage(data: photo.imageData) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            TextField(L10n.t("Photo caption (e.g., Before repair)", "照片说明（如：更换新阀门完工照）"), text: $photo.caption)
                                .font(.subheadline)
                        }
                    }
                    .onDelete { offsets in
                        draft.photos.remove(atOffsets: offsets)
                    }
                } header: {
                    Text(L10n.t("Job Site Photos (Clean Page-2 Addendum)", "现场照片（自动排在附页，绝不挡字）"))
                }

                // 6. Client Approval Signature + Payment Instructions + Notes
                Section(L10n.t("Signature & Payment Instructions", "签字与收款说明")) {
                    Button {
                        showSignaturePad = true
                    } label: {
                        HStack {
                            Label(
                                draft.clientSignatureData == nil
                                    ? L10n.t("Capture Client Approval Signature", "让客户当场手写验收签名")
                                    : L10n.t("Client Signature Saved (Tap to Update)", "已保存客户签名（点击重签）"),
                                systemImage: draft.clientSignatureData == nil ? "signature" : "checkmark.circle.fill"
                            )
                            .foregroundStyle(draft.clientSignatureData == nil ? FlatTheme.ink : FlatTheme.paidGreen)
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Payment Instructions (0% Platform Fee)", "收款方式说明（零抽成）"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlatTheme.muted)
                        TextEditor(text: $draft.paymentInstructions)
                            .frame(minHeight: 56)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Notes & Warranty", "备注与质保条款"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlatTheme.muted)
                        TextEditor(text: $draft.notes)
                            .frame(minHeight: 56)
                    }
                }
            }
            .onChange(of: draft) { _, _ in
                hasUnsavedChanges = true
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let raw = try? await newItem.loadTransferable(type: Data.self),
                       let uiImg = UIImage(data: raw),
                       let jpeg = uiImg.resizedForPDF().jpegData(compressionQuality: 0.72) {
                        draft.photos.append(JobPhoto(caption: "", imageData: jpeg))
                    }
                    selectedPhotoItem = nil
                }
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .navigationTitle(isNew ? L10n.t("New \(draft.kind.label)", "新建\(draft.kind.label)") : draft.number)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) {
                        if hasUnsavedChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save & PDF", "保存并预览PDF")) {
                        saveDraft()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert(L10n.t("Keep Your Work Safe", "防止误滑丢失单据"), isPresented: $showDiscardAlert) {
                Button(L10n.t("Save Draft & Close", "保存草稿并退出")) {
                    saveDraft(openPreview: false)
                }
                Button(L10n.t("Discard Changes", "放弃修改"), role: .destructive) {
                    dismiss()
                }
                Button(L10n.t("Keep Editing", "继续编辑"), role: .cancel) {}
            } message: {
                Text(L10n.t("You have unsaved line items. Save as draft before leaving?", "您有尚未保存的费用明细，是否存为草稿防丢失？"))
            }
            .sheet(isPresented: $showClientPicker) {
                NavigationStack {
                    List(ledger.clients) { c in
                        Button {
                            draft.clientId = c.id
                            draft.clientName = c.name
                            draft.clientCompany = c.company
                            draft.clientEmail = c.email
                            draft.clientPhone = c.phone
                            draft.clientAddress = c.address
                            showClientPicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name).font(.subheadline.weight(.bold)).foregroundStyle(FlatTheme.ink)
                                if !c.company.isEmpty {
                                    Text(c.company).font(.caption).foregroundStyle(FlatTheme.muted)
                                }
                            }
                        }
                    }
                    .navigationTitle(L10n.t("Select Client", "选择客户"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.t("Close", "关闭")) { showClientPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showPriceBookPicker) {
                NavigationStack {
                    List(ledger.priceBook) { pb in
                        Button {
                            let newLine = LineItem(
                                name: pb.name,
                                details: pb.details,
                                quantity: 1,
                                unit: pb.unit,
                                unitPrice: pb.unitPrice,
                                taxable: pb.taxable
                            )
                            if draft.items.count == 1 && draft.items[0].name.isEmpty && draft.items[0].unitPrice == 0 {
                                draft.items[0] = newLine
                            } else {
                                draft.items.append(newLine)
                            }
                            showPriceBookPicker = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pb.name).font(.subheadline.weight(.bold)).foregroundStyle(FlatTheme.ink)
                                    if !pb.details.isEmpty {
                                        Text(pb.details).font(.caption).foregroundStyle(FlatTheme.muted).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(MoneyFormat.format(pb.unitPrice, currencyCode: draft.currencyCode))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(FlatTheme.accent)
                            }
                        }
                    }
                    .navigationTitle(L10n.t("Insert from Price Book", "从价目库一键插入"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.t("Close", "关闭")) { showPriceBookPicker = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSignaturePad) {
                SignaturePadView(
                    title: L10n.t("Client Approval Signature", "客户验收签名"),
                    existingData: draft.clientSignatureData
                ) { pngData in
                    draft.clientSignatureData = pngData
                }
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, bold: Bool) -> some View {
        HStack {
            Text(label).font(bold ? .headline.weight(.bold) : .subheadline)
            Spacer()
            Text(value)
                .font((bold ? Font.headline.weight(.heavy) : Font.subheadline.weight(.semibold)).monospacedDigit())
                .foregroundStyle(bold ? FlatTheme.ink : FlatTheme.muted)
        }
    }

    private func saveDraft(openPreview: Bool = true) {
        if draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.clientName = L10n.t("Walk-in Client", "现场客户")
        }
        ledger.upsertDocument(draft)
        hasUnsavedChanges = false
        dismiss()
        if openPreview {
            onSavedAndPreview?(draft)
        }
    }
}

private extension UIImage {
    func resizedForPDF(maxDimension: CGFloat = 1280) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
