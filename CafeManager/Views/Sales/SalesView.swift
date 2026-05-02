import SwiftUI

struct SalesView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = SalesViewModel()
    @State private var showNewSale = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                Group {
                    if dataService.sales.isEmpty {
                        EmptyStateView(
                            icon: "cart.badge.plus",
                            title: "No Sales Yet",
                            message: "Start recording sales to track revenue, monitor performance, and get AI-powered insights."
                        )
                    } else {
                        salesContent
                    }
                }
            }
            .navigationTitle("Sales")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewSale = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewSale) {
                NewSaleView()
            }
        }
    }

    private var salesContent: some View {
        VStack(spacing: 0) {
            todaySummaryCard
                .padding()

            paymentFilterBar
                .padding(.horizontal)

            if !viewModel.searchText.isEmpty || viewModel.selectedPaymentFilter != nil {
                HStack {
                    Text("\(viewModel.filteredSales(from: dataService.sales).count) results")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                    Spacer()
                    if viewModel.selectedPaymentFilter != nil {
                        Button("Clear Filter") {
                            viewModel.selectedPaymentFilter = nil
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            List {
                ForEach(viewModel.filteredSales(from: dataService.sales)) { sale in
                    saleRow(sale)
                        .listRowBackground(Color.white)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .onDelete { indexSet in
                    let filtered = viewModel.filteredSales(from: dataService.sales)
                    for index in indexSet {
                        if let saleId = filtered[index].id {
                            Task {
                                try? await dataService.deleteSale(saleId)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchText, prompt: "Search sales...")
        }
    }

    // MARK: - Today Summary

    private var todaySummaryCard: some View {
        HStack(spacing: 16) {
            summaryPill(
                icon: "indianrupeesign.circle.fill",
                label: "Revenue",
                value: currencyString(dataService.todayRevenue),
                color: AppTheme.primary
            )
            summaryPill(
                icon: "cart.fill",
                label: "Orders",
                value: "\(dataService.todayOrderCount)",
                color: .blue
            )
            summaryPill(
                icon: "chart.line.uptrend.xyaxis",
                label: "Profit",
                value: currencyString(dataService.todayProfit),
                color: AppTheme.success
            )
        }
    }

    private func summaryPill(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Payment Filter

    private var paymentFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        if viewModel.selectedPaymentFilter == method {
                            viewModel.selectedPaymentFilter = nil
                        } else {
                            viewModel.selectedPaymentFilter = method
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: method.icon)
                                .font(.caption2)
                            Text(method.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(viewModel.selectedPaymentFilter == method ? AppTheme.primary : Color.white)
                        .foregroundColor(viewModel.selectedPaymentFilter == method ? .white : AppTheme.textPrimary)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Sale Row

    private func saleRow(_ sale: SaleTransaction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sale.paymentMethod.icon)
                    .font(.caption)
                    .foregroundColor(AppTheme.primary)
                    .padding(6)
                    .background(AppTheme.primary.opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sale.itemCount) item\(sale.itemCount == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(sale.date, style: .time)
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(currencyString(sale.totalAmount))
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.primary)
                    if sale.discount > 0 {
                        Text("-\(currencyString(sale.discount))")
                            .font(.caption)
                            .foregroundColor(AppTheme.success)
                    }
                }
            }

            if sale.items.count <= 3 {
                Text(sale.items.map { "\($0.displayName) x\($0.quantity)" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .lineLimit(1)
            } else {
                Text(sale.items.prefix(2).map { "\($0.displayName) x\($0.quantity)" }.joined(separator: ", ") + " +\(sale.items.count - 2) more")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .lineLimit(1)
            }

            if let customer = sale.customerName {
                HStack(spacing: 4) {
                    Image(systemName: "person.circle")
                        .font(.caption2)
                    Text(customer)
                        .font(.caption)
                }
                .foregroundColor(AppTheme.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}
