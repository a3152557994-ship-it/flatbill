import SwiftUI

@main
struct FlatBillApp: App {
    @StateObject private var ledger = LedgerStore()
    @StateObject private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(ledger)
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
