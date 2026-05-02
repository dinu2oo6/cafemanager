import Foundation

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var isProcessing = false

    func filteredItems(_ items: [InventoryItem]) -> [InventoryItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.category?.rawValue.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func lowStockItems(_ items: [InventoryItem]) -> [InventoryItem] {
        filteredItems(items).filter { $0.isLow }
    }

    func normalStockItems(_ items: [InventoryItem]) -> [InventoryItem] {
        filteredItems(items).filter { !$0.isLow }
    }

    func addItem(_ item: InventoryItem, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.addInventoryItem(item)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func updateItem(_ item: InventoryItem, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.updateInventoryItem(item)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func deleteItem(_ itemId: String, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.deleteInventoryItem(itemId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func logConsumption(itemId: String, amount: Int, date: Date, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.logConsumption(itemId: itemId, amount: amount, date: date)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func validate(name: String, quantity: String, unit: String,
                  reorderLevel: String, costPrice: String, sellingPrice: String) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name is required" }
        guard let qty = Int(quantity), qty >= 0 else { return "Quantity must be a valid number (0 or more)" }
        if unit.trimmingCharacters(in: .whitespaces).isEmpty { return "Unit is required" }
        guard let reorder = Int(reorderLevel), reorder >= 0 else { return "Reorder level must be a valid number" }
        guard let cost = Double(costPrice), cost > 0 else { return "Cost price must be greater than 0" }
        guard let sell = Double(sellingPrice), sell > 0 else { return "Selling price must be greater than 0" }
        return nil
    }
}
