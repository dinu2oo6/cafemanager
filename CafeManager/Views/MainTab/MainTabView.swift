import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataService: FirebaseDataService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            SalesView()
                .tabItem {
                    Label("Sales", systemImage: "cart.fill")
                }
                .tag(1)

            InventoryListView()
                .tabItem {
                    Label("Inventory", systemImage: "shippingbox.fill")
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.primary)
    }
}

struct MoreTabView: View {
    @EnvironmentObject var dataService: FirebaseDataService

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                List {
                    Section("Intelligence") {
                        NavigationLink {
                            RecipeCostAnalysisView()
                        } label: {
                            moreRow(icon: "book.closed.fill", title: "Recipe Cost Analysis", subtitle: "\(dataService.recipes.count) recipes tracked", color: .brown)
                        }
                        NavigationLink {
                            PredictionDashboardView()
                        } label: {
                            moreRow(icon: "target", title: "Predictions", subtitle: "AI forecasts & waste alerts", color: .blue)
                        }
                        NavigationLink {
                            AnalyticsView()
                        } label: {
                            moreRow(icon: "chart.bar.xaxis", title: "Analytics", subtitle: "Revenue trends & reporting", color: .purple)
                        }
                        NavigationLink {
                            AIAssistantView()
                        } label: {
                            moreRow(icon: "sparkles", title: "AI Assistant", subtitle: "Chat with your cafe advisor", color: .orange)
                        }
                    }

                    Section("Hiring") {
                        NavigationLink {
                            JobImportView()
                        } label: {
                            moreRow(icon: "doc.text.magnifyingglass", title: "Job Import", subtitle: "Fetch & parse job listings", color: .cyan)
                        }
                    }

                    Section("Management") {
                        NavigationLink {
                            CustomerListView()
                        } label: {
                            moreRow(icon: "person.crop.circle", title: "Customers", subtitle: "\(dataService.customers.count) customers tracked", color: .green)
                        }
                        NavigationLink {
                            SupplierListView()
                        } label: {
                            moreRow(icon: "shippingbox.and.arrow.backward", title: "Suppliers", subtitle: "\(dataService.suppliers.count) suppliers", color: .teal)
                        }
                        NavigationLink {
                            OrderListView()
                        } label: {
                            moreRow(icon: "doc.text.fill", title: "Purchase Orders", subtitle: "\(dataService.orders.filter { $0.status == .pending }.count) pending", color: .indigo)
                        }
                    }

                    Section("Settings") {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            moreRow(icon: "gearshape.fill", title: "Settings", subtitle: "Account & preferences", color: .gray)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("More")
        }
    }

    private func moreRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
