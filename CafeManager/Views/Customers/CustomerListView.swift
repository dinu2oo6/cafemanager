import SwiftUI

struct CustomerListView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = CustomerViewModel()
    @State private var showAddCustomer = false
    @State private var selectedCustomer: Customer?

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            Group {
                if dataService.customers.isEmpty {
                    EmptyStateView(
                        icon: "person.crop.circle.badge.plus",
                        title: "No Customers Yet",
                        message: "Add customers to track loyalty tiers, purchase history, and identify churn risks."
                    )
                } else {
                    customerContent
                }
            }
        }
        .navigationTitle("Customers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCustomer = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddCustomer) {
            AddEditCustomerView(customer: nil)
        }
        .sheet(item: $selectedCustomer) { customer in
            AddEditCustomerView(customer: customer)
        }
    }

    private var customerContent: some View {
        VStack(spacing: 0) {
            statsHeader

            tierFilterBar
                .padding(.horizontal)
                .padding(.top, 8)

            List {
                ForEach(viewModel.filteredCustomers(from: dataService.customers)) { customer in
                    customerRow(customer)
                        .listRowBackground(Color.white)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedCustomer = customer
                        }
                }
                .onDelete { indexSet in
                    let filtered = viewModel.filteredCustomers(from: dataService.customers)
                    for index in indexSet {
                        if let customerId = filtered[index].id {
                            Task {
                                await viewModel.deleteCustomer(customerId, dataService: dataService)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchText, prompt: "Search customers...")
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        let stats = viewModel.customerStats(from: dataService.customers)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                customerStatPill(icon: "person.2.fill", value: "\(stats.totalCustomers)", label: "Total", color: .blue)
                customerStatPill(icon: "crown.fill", value: "\(stats.goldMembers)", label: "Gold", color: .yellow)
                customerStatPill(icon: "star.fill", value: "\(stats.silverMembers)", label: "Silver", color: .gray)
                customerStatPill(icon: "exclamationmark.triangle", value: "\(stats.churnRiskCount)", label: "At Risk", color: .red)
                customerStatPill(icon: "indianrupeesign.circle", value: currencyString(stats.averageCustomerValue), label: "Avg Value", color: .green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func customerStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Tier Filter

    private var tierFilterBar: some View {
        HStack(spacing: 8) {
            filterChip(label: "All", isSelected: viewModel.selectedTierFilter == nil && !viewModel.showChurnRiskOnly) {
                viewModel.selectedTierFilter = nil
                viewModel.showChurnRiskOnly = false
            }
            ForEach(LoyaltyTier.allCases) { tier in
                filterChip(label: tier.rawValue, isSelected: viewModel.selectedTierFilter == tier) {
                    viewModel.selectedTierFilter = tier
                    viewModel.showChurnRiskOnly = false
                }
            }
            filterChip(label: "Churn Risk", isSelected: viewModel.showChurnRiskOnly) {
                viewModel.showChurnRiskOnly.toggle()
                viewModel.selectedTierFilter = nil
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppTheme.primary : Color.white)
                .foregroundColor(isSelected ? .white : AppTheme.textPrimary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Customer Row

    private func customerRow(_ customer: Customer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tierColor(customer.loyaltyTier).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: customer.loyaltyTier.icon)
                    .foregroundColor(tierColor(customer.loyaltyTier))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(customer.name)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(customer.loyaltyTier.rawValue)
                        .font(.caption2.bold())
                        .foregroundColor(tierColor(customer.loyaltyTier))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tierColor(customer.loyaltyTier).opacity(0.1))
                        .cornerRadius(4)
                }
                HStack(spacing: 12) {
                    Text("\(customer.visitCount) visits")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                    Text("Spent: \(currencyString(customer.totalSpent))")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if customer.isChurnRisk {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("At Risk")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(AppTheme.error)
                }
                if let days = customer.daysSinceLastVisit {
                    Text("\(days)d ago")
                        .font(.caption)
                        .foregroundColor(days > 14 ? AppTheme.error : AppTheme.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func tierColor(_ tier: LoyaltyTier) -> Color {
        switch tier {
        case .gold: return Color(red: 1, green: 0.84, blue: 0)
        case .silver: return Color.gray
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}
