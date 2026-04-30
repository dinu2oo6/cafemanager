import SwiftUI

struct InventoryListView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showingAdd = false
    @State private var selectedItem: InventoryItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                Group {
                    if dataService.isLoading {
                        LoadingView(message: "Loading inventory...")
                    } else if dataService.inventoryItems.isEmpty {
                        EmptyStateView(
                            icon: "shippingbox",
                            title: "No Inventory Items",
                            message: "Add your first inventory item to start tracking stock levels and get AI predictions.",
                            actionTitle: "Add Item"
                        ) { showingAdd = true }
                    } else {
                        inventoryList
                    }
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $viewModel.searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditInventoryView(item: nil)
            }
            .sheet(item: $selectedItem) { item in
                AddEditInventoryView(item: item)
            }
            .overlay(alignment: .top) {
                if let error = viewModel.errorMessage ?? dataService.errorMessage {
                    ErrorBannerView(message: error, dismissAction: {
                        viewModel.errorMessage = nil
                        dataService.errorMessage = nil
                    })
                    .padding(.horizontal)
                }
            }
        }
    }

    private var inventoryList: some View {
        List {
            // Low Stock Section
            let lowItems = viewModel.lowStockItems(dataService.inventoryItems)
            if !lowItems.isEmpty {
                Section {
                    ForEach(lowItems) { item in
                        inventoryRow(item, isLow: true)
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets, from: lowItems)
                    }
                } header: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.error)
                        Text("Low Stock (\(lowItems.count))")
                            .foregroundColor(AppTheme.error)
                            .bold()
                    }
                }
            }

            // All Items Section
            let normalItems = viewModel.normalStockItems(dataService.inventoryItems)
            if !normalItems.isEmpty {
                Section {
                    ForEach(normalItems) { item in
                        inventoryRow(item, isLow: false)
                    }
                    .onDelete { offsets in
                        deleteItems(at: offsets, from: normalItems)
                    }
                } header: {
                    Text("All Items (\(normalItems.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut, value: dataService.inventoryItems.count)
    }

    private func inventoryRow(_ item: InventoryItem, isLow: Bool) -> some View {
        Button { selectedItem = item } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Title row
                HStack {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(isLow ? AppTheme.error : AppTheme.textPrimary)

                    Spacer()

                    Text("\(item.quantity) \(item.unit)")
                        .font(.subheadline.bold())
                        .foregroundColor(isLow ? AppTheme.error : AppTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (isLow ? AppTheme.error : AppTheme.primary).opacity(0.1)
                        )
                        .cornerRadius(6)
                }

                // Price row
                HStack {
                    Label("Cost: \u{20B9}\(String(format: "%.0f", item.costPrice))", systemImage: "indianrupeesign.circle")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)

                    Spacer()

                    Label("Sell: \u{20B9}\(String(format: "%.0f", item.sellingPrice))", systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(AppTheme.success)
                }

                // Stock level bar + days info
                HStack {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(stockColor(for: item))
                                .frame(width: geo.size.width * item.stockLevelPercentage, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Spacer().frame(width: 12)

                    // Days until stockout
                    if item.averageDailyConsumption > 0 {
                        Text("\(item.daysUntilStockout)d left")
                            .font(.caption2.bold())
                            .foregroundColor(item.daysUntilStockout <= 3 ? AppTheme.error : AppTheme.secondary)
                    } else {
                        Text("No data")
                            .font(.caption2)
                            .foregroundColor(AppTheme.secondary.opacity(0.6))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func stockColor(for item: InventoryItem) -> Color {
        if item.stockLevelPercentage < 0.3 { return AppTheme.error }
        if item.stockLevelPercentage < 0.6 { return AppTheme.warning }
        return AppTheme.success
    }

    private func deleteItems(at offsets: IndexSet, from items: [InventoryItem]) {
        for offset in offsets {
            let item = items[offset]
            if let id = item.id {
                Task { await viewModel.deleteItem(id, service: dataService) }
            }
        }
    }
}
