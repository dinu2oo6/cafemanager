import SwiftUI

struct AddEditOrderView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = OrderViewModel()
    @Environment(\.dismiss) private var dismiss

    let order: Order?
    var isEditing: Bool { order?.id != nil }

    @State private var selectedItemId = ""
    @State private var selectedSupplierId = ""
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var status: OrderStatus = .pending
    @State private var orderDate = Date()
    @State private var validationError: String?

    var selectedItem: InventoryItem? {
        dataService.inventoryItems.first { $0.id == selectedItemId }
    }

    var selectedSupplier: Supplier? {
        dataService.suppliers.first { $0.id == selectedSupplierId }
    }

    var totalCost: Double {
        (Double(quantity) ?? 0) * (Double(unitPrice) ?? 0)
    }

    var expectedDeliveryDate: Date {
        let leadDays = selectedSupplier?.leadTimeInDays ?? 3
        return Calendar.current.date(byAdding: .day, value: leadDays, to: orderDate) ?? orderDate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                Form {
                    // MARK: - Validation Error
                    if let error = validationError ?? viewModel.errorMessage {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.error)
                            }
                        }
                    }

                    // MARK: - Item Selection
                    Section("Item") {
                        Picker("Select Item", selection: $selectedItemId) {
                            Text("Choose an item").tag("")
                            ForEach(dataService.inventoryItems) { item in
                                Text("\(item.name) (\(item.quantity) \(item.unit))").tag(item.id ?? "")
                            }
                        }
                        .tint(AppTheme.primary)

                        if let item = selectedItem {
                            HStack {
                                Text("Current Stock")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                Text("\(item.quantity) \(item.unit)")
                                    .font(.caption.bold())
                                    .foregroundColor(item.isLow ? AppTheme.error : AppTheme.success)
                            }
                        }
                    }

                    // MARK: - Supplier Selection
                    Section("Supplier") {
                        Picker("Select Supplier", selection: $selectedSupplierId) {
                            Text("Choose a supplier").tag("")
                            ForEach(dataService.suppliers) { supplier in
                                Text("\(supplier.name) (\(supplier.leadTimeInDays)d)").tag(supplier.id ?? "")
                            }
                        }
                        .tint(AppTheme.primary)

                        if let supplier = selectedSupplier {
                            HStack {
                                Text("Lead Time")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                Text("\(supplier.leadTimeInDays) days")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.primary)
                            }
                            HStack {
                                Text("Reliability")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Image(systemName: i < supplier.reliabilityStars ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.warning)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - Order Details
                    Section("Order Details") {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Quantity", text: $quantity)
                                .keyboardType(.numberPad)
                        }

                        HStack {
                            Text("\u{20B9}")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Unit Price", text: $unitPrice)
                                .keyboardType(.decimalPad)
                        }

                        HStack {
                            Text("Total Cost")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\u{20B9}\(String(format: "%.2f", totalCost))")
                                .font(.headline)
                                .foregroundColor(AppTheme.primary)
                        }

                        DatePicker("Order Date", selection: $orderDate, displayedComponents: .date)
                            .tint(AppTheme.primary)

                        HStack {
                            Text("Expected Delivery")
                                .foregroundColor(AppTheme.secondary)
                            Spacer()
                            Text(formatDate(expectedDeliveryDate))
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.primary)
                        }
                    }

                    // MARK: - Status (Edit mode only)
                    if isEditing {
                        Section("Status") {
                            Picker("Order Status", selection: $status) {
                                ForEach(OrderStatus.allCases) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Order" : "New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Create") { saveOrder() }
                        .foregroundColor(AppTheme.primary)
                        .bold()
                        .disabled(viewModel.isProcessing)
                }
            }
            .onAppear { populateFields() }
            .overlay {
                if viewModel.isProcessing {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .onChange(of: selectedItemId) { newId in
                if !isEditing, let item = dataService.inventoryItems.first(where: { $0.id == newId }) {
                    unitPrice = String(format: "%.2f", item.costPrice)
                    if item.supplierId.isEmpty == false {
                        selectedSupplierId = item.supplierId
                    }
                }
            }
        }
    }

    private func populateFields() {
        guard let order else { return }
        selectedItemId = order.itemId
        selectedSupplierId = order.supplierId
        quantity = String(order.quantity)
        unitPrice = String(format: "%.2f", order.unitPrice)
        status = order.status
        orderDate = order.orderDate
    }

    private func saveOrder() {
        validationError = viewModel.validate(
            itemId: selectedItemId, supplierId: selectedSupplierId,
            quantity: quantity, unitPrice: unitPrice
        )
        guard validationError == nil else { return }

        let itemName = selectedItem?.name ?? ""
        let supplierName = selectedSupplier?.name ?? ""

        var newOrder = order ?? Order.empty
        newOrder.itemId = selectedItemId
        newOrder.itemName = itemName
        newOrder.quantity = Int(quantity) ?? 0
        newOrder.supplierId = selectedSupplierId
        newOrder.supplierName = supplierName
        newOrder.orderDate = orderDate
        newOrder.expectedDeliveryDate = expectedDeliveryDate
        newOrder.status = isEditing ? status : .pending
        newOrder.unitPrice = Double(unitPrice) ?? 0
        newOrder.totalCost = totalCost

        Task {
            if isEditing {
                await viewModel.updateOrder(newOrder, service: dataService)
            } else {
                await viewModel.addOrder(newOrder, service: dataService)
            }
            if viewModel.errorMessage == nil { dismiss() }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
