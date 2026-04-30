import SwiftUI

struct SupplierListView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = SupplierViewModel()
    @State private var showingAdd = false
    @State private var selectedSupplier: Supplier?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                Group {
                    if dataService.isLoading {
                        LoadingView(message: "Loading suppliers...")
                    } else if dataService.suppliers.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "No Suppliers",
                            message: "Add your suppliers to link them with inventory items and track deliveries.",
                            actionTitle: "Add Supplier"
                        ) { showingAdd = true }
                    } else {
                        supplierList
                    }
                }
            }
            .navigationTitle("Suppliers")
            .searchable(text: $viewModel.searchText, prompt: "Search suppliers...")
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
                AddEditSupplierView(supplier: nil)
            }
            .sheet(item: $selectedSupplier) { supplier in
                AddEditSupplierView(supplier: supplier)
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

    private var supplierList: some View {
        List {
            ForEach(viewModel.filteredSuppliers(dataService.suppliers)) { supplier in
                Button { selectedSupplier = supplier } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(supplier.name)
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: i < supplier.reliabilityStars ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.warning)
                                }
                            }
                        }

                        HStack {
                            Label(supplier.email, systemImage: "envelope")
                            Spacer()
                            Label(supplier.phone, systemImage: "phone")
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                        .lineLimit(1)

                        HStack {
                            Label("\(supplier.leadTimeInDays) day lead time", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondary)
                            Spacer()
                            if supplier.totalAmountOwed > 0 {
                                Text("Owed: \u{20B9}\(String(format: "%.0f", supplier.totalAmountOwed))")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.error)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        if let id = supplier.id {
                            Task { await viewModel.deleteSupplier(id, service: dataService) }
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut, value: dataService.suppliers.count)
    }
}
