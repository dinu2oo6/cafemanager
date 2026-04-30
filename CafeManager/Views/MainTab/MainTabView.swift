import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataService: FirebaseDataService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            InventoryListView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
                .tag(0)

            SupplierListView()
                .tabItem {
                    Label("Suppliers", systemImage: "person.2.fill")
                }
                .tag(1)

            OrderListView()
                .tabItem {
                    Label("Orders", systemImage: "cart.fill")
                }
                .tag(2)

            PredictionDashboardView()
                .tabItem {
                    Label("Predictions", systemImage: "target")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(AppTheme.primary)
    }
}
