import Foundation
import FirebaseFirestore

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "User not authenticated. Please sign in."
        case .documentNotFound: return "Document not found."
        case .encodingFailed: return "Failed to encode data."
        }
    }
}

@MainActor
class FirebaseDataService: ObservableObject {
    @Published var inventoryItems: [InventoryItem] = []
    @Published var suppliers: [Supplier] = []
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private(set) var userId: String?

    func configure(userId: String) {
        self.userId = userId
        removeAllListeners()
        isLoading = true
        startListening()
    }

    func reset() {
        removeAllListeners()
        userId = nil
        inventoryItems = []
        suppliers = []
        orders = []
    }

    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    private func startListening() {
        listenToInventory()
        listenToSuppliers()
        listenToOrders()
    }

    private var basePath: String? {
        guard let userId else { return nil }
        return "users/\(userId)"
    }

    // MARK: - Inventory

    private func listenToInventory() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/inventory")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.inventoryItems = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: InventoryItem.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addInventoryItem(_ item: InventoryItem) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/inventory").addDocument(from: item)
    }

    func updateInventoryItem(_ item: InventoryItem) async throws {
        guard let path = basePath, let id = item.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/inventory").document(id).setData(from: item, merge: true)
    }

    func deleteInventoryItem(_ itemId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/inventory").document(itemId).delete()
    }

    func logConsumption(itemId: String, amount: Int) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        guard var item = inventoryItems.first(where: { $0.id == itemId }) else {
            throw FirebaseError.documentNotFound
        }
        var consumption = item.dailyConsumption
        consumption.append(amount)
        if consumption.count > 30 { consumption = Array(consumption.suffix(30)) }
        item.dailyConsumption = consumption
        item.quantity = max(0, item.quantity - amount)
        try db.collection("\(path)/inventory").document(itemId).setData(from: item, merge: true)
    }

    func logWaste(itemId: String, entry: WasteEntry) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        guard var item = inventoryItems.first(where: { $0.id == itemId }) else {
            throw FirebaseError.documentNotFound
        }
        item.wasteRecord.append(entry)
        item.quantity = max(0, item.quantity - entry.quantity)
        try db.collection("\(path)/inventory").document(itemId).setData(from: item, merge: true)
    }

    // MARK: - Suppliers

    private func listenToSuppliers() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/suppliers")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.suppliers = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Supplier.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addSupplier(_ supplier: Supplier) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/suppliers").addDocument(from: supplier)
    }

    func updateSupplier(_ supplier: Supplier) async throws {
        guard let path = basePath, let id = supplier.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/suppliers").document(id).setData(from: supplier, merge: true)
    }

    func deleteSupplier(_ supplierId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/suppliers").document(supplierId).delete()
    }

    // MARK: - Orders

    private func listenToOrders() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/orders")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.orders = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Order.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addOrder(_ order: Order) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/orders").addDocument(from: order)
    }

    func updateOrder(_ order: Order) async throws {
        guard let path = basePath, let id = order.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/orders").document(id).setData(from: order, merge: true)
    }

    func deleteOrder(_ orderId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/orders").document(orderId).delete()
    }
}
