import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var ledger: LedgerStore
    @EnvironmentObject private var store: StoreManager

    @State private var selectedTab: Int = 0
    @State private var previewDocId: UUID? = nil
    @State private var editingDoc: EditingTarget? = nil
    @State private var showPaywall: Bool = false
    @State private var didApplyLaunchDemo = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DocumentsHomeView(
                previewDocId: $previewDocId,
                editingDoc: $editingDoc,
                showPaywall: $showPaywall
            )
            .tabItem {
                Label(L10n.t("Documents", "单据"), systemImage: "doc.text.fill")
            }
            .tag(0)

            ClientsView { kind, client in
                let blank = ledger.makeBlankDocument(kind: kind, client: client)
                editingDoc = EditingTarget(document: blank, isNew: true)
            }
            .tabItem {
                Label(L10n.t("Clients", "客户"), systemImage: "person.2.fill")
            }
            .tag(1)

            PriceBookView()
                .tabItem {
                    Label(L10n.t("Price Book", "价目库"), systemImage: "list.bullet.rectangle.fill")
                }
                .tag(2)

            SettingsView(showPaywall: $showPaywall)
                .tabItem {
                    Label(L10n.t("Business", "商号"), systemImage: "building.2.fill")
                }
                .tag(3)
        }
        .tint(FlatTheme.accent)
        .sheet(item: $editingDoc) { target in
            DocumentEditorView(document: target.document, isNew: target.isNew) { saved in
                previewDocId = saved.id
            }
        }
        .sheet(isPresented: Binding(get: { previewDocId != nil }, set: { if !$0 { previewDocId = nil } })) {
            if let docId = previewDocId {
                DocumentPreviewView(
                    documentId: docId,
                    onEdit: { doc in
                        editingDoc = EditingTarget(document: doc, isNew: false)
                    },
                    onOpenConverted: { converted in
                        previewDocId = converted.id
                    }
                )
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear {
            applyDemoScreenIfNeeded()
        }
    }

    private func applyDemoScreenIfNeeded() {
        guard !didApplyLaunchDemo else { return }
        didApplyLaunchDemo = true
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-ui_demo_screen"), idx + 1 < args.count else { return }
        let screen = args[idx + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch screen {
            case "home":
                selectedTab = 0
            case "preview":
                selectedTab = 0
                // Open the paid Blueprint Trade sample invoice for sharp PDF preview showcase
                if let inv = ledger.documents.first(where: { $0.kind == .invoice && $0.computedStatus == .paid }) ?? ledger.documents.first {
                    previewDocId = inv.id
                }
            case "editor":
                selectedTab = 0
                if let est = ledger.documents.first(where: { $0.kind == .estimate }) ?? ledger.documents.first {
                    editingDoc = EditingTarget(document: est, isNew: false)
                }
            case "clients":
                selectedTab = 1
            case "pricebook":
                selectedTab = 2
            case "paywall":
                selectedTab = 0
                showPaywall = true
            default:
                break
            }
        }
    }
}
