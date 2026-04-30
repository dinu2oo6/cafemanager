import Foundation

@MainActor
class OrderViewModel: ObservableObject {
    @Published var filterStatus: OrderStatus?
    @Published var errorMessage: String?
    @Published var isProcessing = false

    func filteredOrders(_ orders: [Order]) -> [Order] {
        guard let status = filterStatus else { return orders }
        return orders.filter { $0.status == status }
    }

    func addOrder(_ order: Order, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.addOrder(order)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func updateOrder(_ order: Order, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.updateOrder(order)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func deleteOrder(_ orderId: String, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.deleteOrder(orderId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func updateStatus(_ order: Order, to newStatus: OrderStatus, service: FirebaseDataService) async {
        var updated = order
        updated.status = newStatus
        await updateOrder(updated, service: service)
    }

    func validate(itemId: String, supplierId: String, quantity: String, unitPrice: String) -> String? {
        if itemId.isEmpty { return "Please select an item" }
        if supplierId.isEmpty { return "Please select a supplier" }
        guard let qty = Int(quantity), qty > 0 else { return "Quantity must be greater than 0" }
        guard let price = Double(unitPrice), price > 0 else { return "Unit price must be greater than 0" }
        return nil
    }
}
