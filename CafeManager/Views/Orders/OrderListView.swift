import SwiftUI

struct OrderListView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = OrderViewModel()
    @State private var showingAdd = false
    @State private var selectedOrder: Order?

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            Group {
                if dataService.isLoading {
                    LoadingView(message: "Loading orders...")
                } else if dataService.orders.isEmpty {
                    EmptyStateView(
                        icon: "cart",
                        title: "No Orders",
                        message: "Create orders to track purchases from your suppliers and manage deliveries.",
                        actionTitle: "Create Order"
                    ) { showingAdd = true }
                } else {
                    orderContent
                }
            }
        }
        .navigationTitle("Orders")
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
            AddEditOrderView(order: nil)
        }
        .sheet(item: $selectedOrder) { order in
            AddEditOrderView(order: order)
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

    private var orderContent: some View {
        VStack(spacing: 0) {
            // MARK: - Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip("All", isSelected: viewModel.filterStatus == nil) {
                        viewModel.filterStatus = nil
                    }
                    ForEach(OrderStatus.allCases) { status in
                        filterChip(status.rawValue, isSelected: viewModel.filterStatus == status) {
                            viewModel.filterStatus = status
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(AppTheme.accent)

            // MARK: - Order List
            List {
                ForEach(viewModel.filteredOrders(dataService.orders)) { order in
                    Button { selectedOrder = order } label: {
                        orderRow(order)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if let id = order.id {
                                Task { await viewModel.deleteOrder(id, service: dataService) }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if order.status == .pending || order.status == .ordered {
                            Button {
                                Task {
                                    await viewModel.updateStatus(order, to: .cancelled, service: dataService)
                                }
                            } label: {
                                Label("Cancel", systemImage: "xmark.circle")
                            }
                            .tint(AppTheme.error)
                        }

                        if order.status == .pending {
                            Button {
                                Task {
                                    await viewModel.updateStatus(order, to: .ordered, service: dataService)
                                }
                            } label: {
                                Label("Mark Ordered", systemImage: "checkmark.circle")
                            }
                            .tint(AppTheme.warning)
                        }

                        if order.status == .ordered {
                            Button {
                                Task {
                                    await viewModel.updateStatus(order, to: .delivered, service: dataService)
                                }
                            } label: {
                                Label("Mark Delivered", systemImage: "checkmark.circle.fill")
                            }
                            .tint(AppTheme.success)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .animation(.easeInOut, value: dataService.orders.count)
        }
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? AppTheme.primary : Color.white)
                .foregroundColor(isSelected ? .white : AppTheme.primary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.primary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
    }

    private func orderRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.itemName)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("from \(order.supplierName)")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                }

                Spacer()

                statusBadge(order.status)
            }

            HStack {
                Label("\(order.quantity) units", systemImage: "shippingbox")
                Spacer()
                Label("\u{20B9}\(String(format: "%.0f", order.totalCost))", systemImage: "indianrupeesign.circle")
            }
            .font(.caption)
            .foregroundColor(AppTheme.secondary)

            HStack {
                Label(formatDate(order.orderDate), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondary)
                Spacer()
                Label("ETA: \(formatDate(order.expectedDeliveryDate))", systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(order.expectedDeliveryDate < Date() && order.status != .delivered ? AppTheme.error : AppTheme.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: OrderStatus) -> some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(6)
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending: return AppTheme.warning
        case .ordered: return AppTheme.primary
        case .delivered: return AppTheme.success
        case .cancelled: return AppTheme.error
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
