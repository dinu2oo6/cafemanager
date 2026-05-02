import SwiftUI

struct AddEditInventoryView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = InventoryViewModel()
    @Environment(\.dismiss) private var dismiss

    let item: InventoryItem?
    var isEditing: Bool { item?.id != nil }

    private var currentItem: InventoryItem? {
        guard let itemId = item?.id else { return item }
        return dataService.inventoryItems.first(where: { $0.id == itemId }) ?? item
    }

    // Form fields
    @State private var name = ""
    @State private var brand = ""
    @State private var selectedCategory: ItemCategory = .other
    @State private var quantity = ""
    @State private var unit = "kg"
    @State private var reorderLevel = ""
    @State private var costPrice = ""
    @State private var sellingPrice = ""
    @State private var selectedSupplierId = ""
    @State private var expiryDate = Date()
    @State private var hasExpiry = false
    @State private var validationError: String?

    // Consumption logging
    @State private var consumptionAmount = ""
    @State private var consumptionDate = Date()
    @State private var showConsumptionSheet = false

    // Waste logging
    @State private var wasteAmount = ""
    @State private var wasteReason = ""
    @State private var wasteDate = Date()
    @State private var showWasteSheet = false

    // Delete
    @State private var showDeleteConfirmation = false

    let units = ["kg", "g", "L", "mL", "pcs", "dozen", "bags", "boxes", "packets"]

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

                    // MARK: - SKU Badge (edit mode)
                    if isEditing, let sku = currentItem?.sku, !sku.isEmpty {
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("SKU")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondary)
                                    Text(sku)
                                        .font(.title3.bold().monospaced())
                                        .foregroundColor(AppTheme.primary)
                                }
                                Spacer()
                                if let cat = currentItem?.category {
                                    Label(cat.rawValue, systemImage: cat.icon)
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppTheme.primary.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // MARK: - Basic Info
                    Section("Item Details") {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Item Name *", text: $name)
                        }

                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Brand (e.g. Amul, Nandini)", text: $brand)
                        }

                        Picker("Category", selection: $selectedCategory) {
                            ForEach(ItemCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .tint(AppTheme.primary)

                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Quantity", text: $quantity)
                                .keyboardType(.numberPad)
                        }

                        Picker("Unit", selection: $unit) {
                            ForEach(units, id: \.self) { u in
                                Text(u).tag(u)
                            }
                        }
                        .tint(AppTheme.primary)

                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AppTheme.warning)
                                .frame(width: 20)
                            TextField("Reorder Level", text: $reorderLevel)
                                .keyboardType(.numberPad)
                        }
                    }

                    // MARK: - Pricing
                    Section("Pricing") {
                        HStack {
                            Text("\u{20B9}")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Cost Price", text: $costPrice)
                                .keyboardType(.decimalPad)
                        }

                        HStack {
                            Text("\u{20B9}")
                                .foregroundColor(AppTheme.success)
                                .frame(width: 20)
                            TextField("Selling Price", text: $sellingPrice)
                                .keyboardType(.decimalPad)
                        }

                        if let cost = Double(costPrice), let sell = Double(sellingPrice), cost > 0, sell > 0 {
                            let margin = ((sell - cost) / sell) * 100
                            HStack {
                                Text("Margin")
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                Text("\(String(format: "%.1f", margin))%")
                                    .bold()
                                    .foregroundColor(margin > 0 ? AppTheme.success : AppTheme.error)
                            }
                        }
                    }

                    // MARK: - Supplier
                    Section("Supplier") {
                        Picker("Select Supplier", selection: $selectedSupplierId) {
                            Text("None").tag("")
                            ForEach(dataService.suppliers) { supplier in
                                Text(supplier.name).tag(supplier.id ?? "")
                            }
                        }
                        .tint(AppTheme.primary)
                    }

                    // MARK: - Expiry
                    Section("Expiry Date") {
                        Toggle("Has Expiry Date", isOn: $hasExpiry)
                            .tint(AppTheme.primary)

                        if hasExpiry {
                            DatePicker("Expires On", selection: $expiryDate, displayedComponents: .date)
                                .tint(AppTheme.primary)
                        }
                    }

                    // MARK: - Actions (Edit mode only)
                    if isEditing {
                        Section("Track Usage") {
                            Button {
                                consumptionDate = Date()
                                showConsumptionSheet = true
                            } label: {
                                Label("Log Daily Consumption", systemImage: "chart.line.downtrend.xyaxis")
                                    .foregroundColor(AppTheme.primary)
                            }

                            Button {
                                wasteDate = Date()
                                showWasteSheet = true
                            } label: {
                                Label("Log Waste / Spoilage", systemImage: "trash")
                                    .foregroundColor(AppTheme.warning)
                            }
                        }

                            Section {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Item", systemImage: "trash.fill")
                                    .foregroundColor(AppTheme.error)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }

                        // Stats
                        if let currentItem = currentItem {
                            Section("Statistics") {
                                HStack {
                                    Text("Daily Avg Consumption")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f %@/day", currentItem.averageDailyConsumption, currentItem.unit))
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.primary)
                                }
                                HStack {
                                    Text("Days Until Stockout")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondary)
                                    Spacer()
                                    Text(currentItem.averageDailyConsumption > 0 ? "\(currentItem.daysUntilStockout) days" : "N/A")
                                        .font(.caption.bold())
                                        .foregroundColor(currentItem.daysUntilStockout <= 3 ? AppTheme.error : AppTheme.primary)
                                }
                                HStack {
                                    Text("Profit Per Unit")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondary)
                                    Spacer()
                                    Text("\u{20B9}\(String(format: "%.2f", currentItem.profitPerUnit))")
                                        .font(.caption.bold())
                                        .foregroundColor(currentItem.profitPerUnit >= 0 ? AppTheme.success : AppTheme.error)
                                }
                                HStack {
                                    Text("Consumption Days")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.secondary)
                                    Spacer()
                                    Text("\(currentItem.dailyConsumption.count) days")
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.secondary)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") { saveItem() }
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
            .sheet(isPresented: $showConsumptionSheet) {
                NavigationStack {
                    Form {
                        TextField("Amount consumed", text: $consumptionAmount)
                            .keyboardType(.numberPad)
                        DatePicker("Consumption Date", selection: $consumptionDate, in: ...Date(), displayedComponents: .date)
                    }
                    .navigationTitle("Log Consumption")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                consumptionAmount = ""
                                showConsumptionSheet = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Log") { logConsumption() }
                                .bold()
                        }
                    }
                }
            }
            .sheet(isPresented: $showWasteSheet) {
                NavigationStack {
                    Form {
                        TextField("Wasted quantity", text: $wasteAmount)
                            .keyboardType(.numberPad)
                        TextField("Reason (e.g., expired, damaged)", text: $wasteReason)
                        DatePicker("Waste Date", selection: $wasteDate, in: ...Date(), displayedComponents: .date)
                    }
                    .navigationTitle("Log Waste")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                wasteAmount = ""
                                wasteReason = ""
                                showWasteSheet = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Log") { logWaste() }
                                .bold()
                        }
                    }
                }
            }
            .alert("Delete Item", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    guard let itemId = item?.id else { return }
                    Task {
                        await viewModel.deleteItem(itemId, service: dataService)
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(name)\"? This cannot be undone.")
            }
        }
    }

    private func populateFields() {
        guard let item else { return }
        name = item.name
        brand = item.brand ?? ""
        selectedCategory = item.category ?? .other
        quantity = String(item.quantity)
        unit = item.unit
        reorderLevel = String(item.reorderLevel)
        costPrice = String(format: "%.2f", item.costPrice)
        sellingPrice = String(format: "%.2f", item.sellingPrice)
        selectedSupplierId = item.supplierId
        if let expiry = item.expiryDate {
            hasExpiry = true
            expiryDate = expiry
        }
    }

    private func saveItem() {
        validationError = viewModel.validate(
            name: name, quantity: quantity, unit: unit,
            reorderLevel: reorderLevel, costPrice: costPrice, sellingPrice: sellingPrice
        )
        guard validationError == nil else { return }

        var newItem = item ?? InventoryItem.empty
        newItem.name = name.trimmingCharacters(in: .whitespaces)
        newItem.brand = brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces)
        newItem.category = selectedCategory
        newItem.quantity = Int(quantity) ?? 0
        newItem.unit = unit
        newItem.reorderLevel = Int(reorderLevel) ?? 10
        newItem.costPrice = Double(costPrice) ?? 0
        newItem.sellingPrice = Double(sellingPrice) ?? 0
        newItem.supplierId = selectedSupplierId
        newItem.expiryDate = hasExpiry ? expiryDate : nil

        Task {
            if isEditing {
                await viewModel.updateItem(newItem, service: dataService)
            } else {
                await viewModel.addItem(newItem, service: dataService)
            }
            if viewModel.errorMessage == nil { dismiss() }
        }
    }

    private func logConsumption() {
        guard let amount = Int(consumptionAmount), amount > 0,
              let itemId = item?.id else {
            consumptionAmount = ""
            return
        }
        Task {
            await viewModel.logConsumption(itemId: itemId, amount: amount, date: consumptionDate, service: dataService)
            consumptionAmount = ""
            showConsumptionSheet = false
        }
    }

    private func logWaste() {
        guard let amount = Int(wasteAmount), amount > 0,
              let itemId = item?.id else {
            wasteAmount = ""
            wasteReason = ""
            return
        }
        let entry = WasteEntry(quantity: amount, reason: wasteReason, date: wasteDate)
        Task {
            do {
                try await dataService.logWaste(itemId: itemId, entry: entry)
                showWasteSheet = false
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
            wasteAmount = ""
            wasteReason = ""
        }
    }
}
