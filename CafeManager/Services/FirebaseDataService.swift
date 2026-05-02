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
    @Published var sales: [SaleTransaction] = []
    @Published var customers: [Customer] = []
    @Published var staffMembers: [StaffMember] = []
    @Published var recipes: [Recipe] = []
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
        sales = []
        customers = []
        staffMembers = []
        recipes = []
    }

    private func removeAllListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    private func startListening() {
        listenToInventory()
        listenToSuppliers()
        listenToOrders()
        listenToSales()
        listenToCustomers()
        listenToStaff()
        listenToRecipes()
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

    func generateSKU(for item: InventoryItem) -> String {
        let prefix = item.category?.skuPrefix ?? {
            let name = item.name.uppercased().filter { $0.isLetter }
            return String(name.prefix(3)).padding(toLength: 3, withPad: "X", startingAt: 0)
        }()

        let existingCount = inventoryItems.filter { existing in
            if let cat = item.category, let existingCat = existing.category {
                return cat == existingCat
            }
            return existing.sku?.hasPrefix(prefix) ?? false
        }.count

        return "\(prefix)-\(String(format: "%03d", existingCount + 1))"
    }

    func addInventoryItem(_ item: InventoryItem) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        var newItem = item
        if newItem.sku == nil || newItem.sku?.isEmpty == true {
            newItem.sku = generateSKU(for: newItem)
        }
        _ = try db.collection("\(path)/inventory").addDocument(from: newItem)
    }

    func updateInventoryItem(_ item: InventoryItem) async throws {
        guard let path = basePath, let id = item.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/inventory").document(id).setData(from: item, merge: true)
    }

    func deleteInventoryItem(_ itemId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/inventory").document(itemId).delete()
    }

    func logConsumption(itemId: String, amount: Int, date: Date = Date()) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        guard var item = inventoryItems.first(where: { $0.id == itemId }) else {
            throw FirebaseError.documentNotFound
        }

        var logs = item.consumptionLog ?? []
        logs.append(ConsumptionEntry(quantity: amount, date: date))
        logs.sort { $0.date < $1.date }
        item.consumptionLog = logs

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: logs) {
            calendar.startOfDay(for: $0.date)
        }
        let daily = grouped.keys.sorted().map { day in
            grouped[day]?.reduce(0) { $0 + $1.quantity } ?? 0
        }
        item.dailyConsumption = Array(daily.suffix(30))

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

    // MARK: - Sales

    private func listenToSales() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/sales")
            .order(by: "date", descending: true)
            .limit(to: 500)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.sales = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: SaleTransaction.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addSale(_ sale: SaleTransaction) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/sales").addDocument(from: sale)
    }

    func deleteSale(_ saleId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/sales").document(saleId).delete()
    }

    var todaySales: [SaleTransaction] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return sales.filter { $0.date >= startOfDay }
    }

    var todayRevenue: Double {
        todaySales.reduce(0) { $0 + $1.totalAmount }
    }

    var todayProfit: Double {
        todaySales.reduce(0) { $0 + $1.grossProfit }
    }

    var todayOrderCount: Int {
        todaySales.count
    }

    // MARK: - Customers

    private func listenToCustomers() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/customers")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.customers = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Customer.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addCustomer(_ customer: Customer) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/customers").addDocument(from: customer)
    }

    func updateCustomer(_ customer: Customer) async throws {
        guard let path = basePath, let id = customer.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/customers").document(id).setData(from: customer, merge: true)
    }

    func deleteCustomer(_ customerId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/customers").document(customerId).delete()
    }

    // MARK: - Staff

    private func listenToStaff() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/staff")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.staffMembers = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: StaffMember.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addStaffMember(_ member: StaffMember) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/staff").addDocument(from: member)
    }

    func updateStaffMember(_ member: StaffMember) async throws {
        guard let path = basePath, let id = member.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/staff").document(id).setData(from: member, merge: true)
    }

    func deleteStaffMember(_ memberId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/staff").document(memberId).delete()
    }

    // MARK: - Recipes

    private func listenToRecipes() {
        guard let path = basePath else { return }
        let listener = db.collection("\(path)/recipes")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.recipes = snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Recipe.self)
                    } ?? []
                }
            }
        listeners.append(listener)
    }

    func addRecipe(_ recipe: Recipe) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        _ = try db.collection("\(path)/recipes").addDocument(from: recipe)
    }

    func updateRecipe(_ recipe: Recipe) async throws {
        guard let path = basePath, let id = recipe.id else { throw FirebaseError.notAuthenticated }
        try db.collection("\(path)/recipes").document(id).setData(from: recipe, merge: true)
    }

    func deleteRecipe(_ recipeId: String) async throws {
        guard let path = basePath else { throw FirebaseError.notAuthenticated }
        try await db.collection("\(path)/recipes").document(recipeId).delete()
    }
}
