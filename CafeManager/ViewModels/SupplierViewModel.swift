import Foundation

@MainActor
class SupplierViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var isProcessing = false

    func filteredSuppliers(_ suppliers: [Supplier]) -> [Supplier] {
        guard !searchText.isEmpty else { return suppliers }
        return suppliers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    func addSupplier(_ supplier: Supplier, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.addSupplier(supplier)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func updateSupplier(_ supplier: Supplier, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.updateSupplier(supplier)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func deleteSupplier(_ supplierId: String, service: FirebaseDataService) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await service.deleteSupplier(supplierId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    func supplierName(for id: String, suppliers: [Supplier]) -> String {
        suppliers.first { $0.id == id }?.name ?? "Unknown"
    }

    func validate(name: String, email: String, phone: String, leadTime: String) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Name is required" }
        if email.trimmingCharacters(in: .whitespaces).isEmpty { return "Email is required" }
        if !email.contains("@") || !email.contains(".") { return "Please enter a valid email address" }
        if phone.trimmingCharacters(in: .whitespaces).isEmpty { return "Phone number is required" }
        guard let lt = Int(leadTime), lt > 0 else { return "Lead time must be greater than 0 days" }
        return nil
    }
}
