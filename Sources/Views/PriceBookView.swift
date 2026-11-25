import SwiftUI

struct PriceBookView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @State private var searchText = ""
    @State private var editingItem: PriceBookItem? = nil
    @State private var isCreatingNew = false

    private var filtered: [PriceBookItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ledger.priceBook }
        return ledger.priceBook.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.details.localizedCaseInsensitiveContains(q)
                || $0.category.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { item in
                        Button {
                            isCreatingNew = false
                            editingItem = item
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(item.category.uppercased())
                                            .font(.system(size: 10, weight: .heavy))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(FlatTheme.accentSoft)
                                            .foregroundStyle(FlatTheme.accent)
                                            .clipShape(Capsule())
                                        if item.taxable {
                                            Text(L10n.t("TAXABLE", "含税项"))
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(FlatTheme.muted)
                                        }
                                    }
                                    Text(item.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(FlatTheme.ink)
                                    if !item.details.isEmpty {
                                        Text(item.details)
                                            .font(.caption)
                                            .foregroundStyle(FlatTheme.muted)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(MoneyFormat.format(item.unitPrice, currencyCode: ledger.profile.defaultCurrencyCode))
                                        .font(.headline.weight(.heavy).monospacedDigit())
                                        .foregroundStyle(FlatTheme.ink)
                                    Text("/ \(item.unit)")
                                        .font(.caption2)
                                        .foregroundStyle(FlatTheme.muted)
                                }
                            }
                            .flatCard(padding: 15)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("Price Book", "常用价目库"))
            .searchable(text: $searchText, prompt: L10n.t("Search labor rates or materials", "搜索人工费、材料或标准报价项"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingNew = true
                        editingItem = PriceBookItem(name: "", unit: L10n.t("job", "项"), unitPrice: 95, category: L10n.t("Labor", "人工"))
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(FlatTheme.accent)
                    }
                }
            }
            .sheet(item: $editingItem) { item in
                PriceBookEditorSheet(item: item, isNew: isCreatingNew) { saved in
                    ledger.upsertPriceBookItem(saved)
                } onDelete: { id in
                    ledger.deletePriceBookItem(id)
                }
            }
        }
    }
}

private struct PriceBookEditorSheet: View {
    @State var item: PriceBookItem
    let isNew: Bool
    let onSave: (PriceBookItem) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Saved Service or Material", "标准服务 / 材料项")) {
                    TextField(L10n.t("Item Name *", "项目名称 *"), text: $item.name)
                    TextField(L10n.t("Default Description", "默认施工说明"), text: $item.details)
                    TextField(L10n.t("Category (Labor, Materials...)", "分类（人工、材料、维保…）"), text: $item.category)
                    HStack {
                        Text(L10n.t("Unit Price", "单价"))
                        Spacer()
                        TextField("0.00", value: $item.unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(L10n.t("Unit", "计价单位"))
                        Spacer()
                        TextField(L10n.t("hr / ft / job", "项 / ㎡ / 小时"), text: $item.unit)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle(L10n.t("Taxable by default", "默认计税"), isOn: $item.taxable)
                }
                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            onDelete(item.id)
                            dismiss()
                        } label: {
                            Label(L10n.t("Delete Item", "删除价目项"), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? L10n.t("New Price Book Item", "新增价目项") : L10n.t("Edit Item", "编辑价目项"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存")) {
                        if !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(item)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
