import SwiftUI

struct ClientsView: View {
    @EnvironmentObject private var ledger: LedgerStore
    var onNewDocumentForClient: (DocumentKind, ClientRecord) -> Void

    @State private var searchText = ""
    @State private var editingClient: ClientRecord? = nil
    @State private var isCreatingNew = false

    private var filtered: [ClientRecord] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return ledger.clients }
        return ledger.clients.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.company.localizedCaseInsensitiveContains(q)
                || $0.phone.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { client in
                        clientCard(client)
                    }
                }
                .padding(16)
            }
            .background(FlatTheme.paper.ignoresSafeArea())
            .navigationTitle(L10n.t("Clients", "客户通讯录"))
            .searchable(text: $searchText, prompt: L10n.t("Search clients or addresses", "搜索客户姓名、地址或电话"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingNew = true
                        editingClient = ClientRecord(name: "")
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(FlatTheme.accent)
                    }
                }
            }
            .sheet(item: $editingClient) { client in
                ClientEditorSheet(client: client, isNew: isCreatingNew) { saved in
                    ledger.upsertClient(saved)
                } onDelete: { id in
                    ledger.deleteClient(id)
                }
            }
        }
    }

    private func clientCard(_ client: ClientRecord) -> some View {
        let billed = ledger.billedTotal(for: client)
        let unpaid = ledger.unpaidTotal(for: client)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(client.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FlatTheme.ink)
                    if !client.company.isEmpty {
                        Text(client.company)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(FlatTheme.muted)
                    }
                    if !client.address.isEmpty {
                        Text(client.address)
                            .font(.caption)
                            .foregroundStyle(FlatTheme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyFormat.format(billed, currencyCode: ledger.profile.defaultCurrencyCode))
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(FlatTheme.ink)
                    Text(L10n.t("Total Billed", "累计开单"))
                        .font(.caption2)
                        .foregroundStyle(FlatTheme.muted)
                    if unpaid > 0.01 {
                        Text(L10n.t("Unpaid \(MoneyFormat.format(unpaid, currencyCode: ledger.profile.defaultCurrencyCode))", "未结 \(MoneyFormat.format(unpaid, currencyCode: ledger.profile.defaultCurrencyCode))"))
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(FlatTheme.overdueRed)
                    }
                }
            }

            Divider().overlay(FlatTheme.border)

            HStack(spacing: 10) {
                Button {
                    onNewDocumentForClient(.invoice, client)
                } label: {
                    Label(L10n.t("+ Invoice", "+ 开发票"), systemImage: "doc.badge.plus")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FlatTheme.accentSoft)
                        .foregroundStyle(FlatTheme.accent)
                        .clipShape(Capsule())
                }

                Button {
                    onNewDocumentForClient(.estimate, client)
                } label: {
                    Label(L10n.t("+ Estimate", "+ 开报价"), systemImage: "doc.text")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(FlatTheme.estimateBlueSoft)
                        .foregroundStyle(FlatTheme.estimateBlue)
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    isCreatingNew = false
                    editingClient = client
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(FlatTheme.muted)
                }
            }
        }
        .flatCard(padding: 15)
    }
}

private struct ClientEditorSheet: View {
    @State var client: ClientRecord
    let isNew: Bool
    let onSave: (ClientRecord) -> Void
    let onDelete: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t("Client Details", "客户资料")) {
                    TextField(L10n.t("Full Name *", "姓名 *"), text: $client.name)
                    TextField(L10n.t("Company / Property", "公司 / 小区门牌"), text: $client.company)
                    TextField(L10n.t("Phone", "电话"), text: $client.phone).keyboardType(.phonePad)
                    TextField(L10n.t("Email", "邮箱"), text: $client.email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField(L10n.t("Address", "地址"), text: $client.address)
                    TextField(L10n.t("Notes (gate code, preferences)", "备注（门禁密码、偏好等）"), text: $client.notes)
                }
                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            onDelete(client.id)
                            dismiss()
                        } label: {
                            Label(L10n.t("Delete Client", "删除客户"), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? L10n.t("New Client", "新增客户") : L10n.t("Edit Client", "编辑客户"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("Save", "保存")) {
                        if !client.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(client)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
