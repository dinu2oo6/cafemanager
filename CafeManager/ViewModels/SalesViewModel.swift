import Foundation

@MainActor
class SalesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedPaymentFilter: PaymentMethod?
    @Published var cartItems: [CartItem] = []
    @Published var selectedPaymentMethod: PaymentMethod = .cash
    @Published var customerName: String = ""
    @Published var discountPercentage: Double = 0
    @Published var notes: String = ""
    @Published var isProcessing = false
    @Published var showSuccess = false
    @Published var errorMessage: String?

    struct CartItem: Identifiable {
        let id = UUID()
        let inventoryItem: InventoryItem
        var quantity: Int
    }

    func filteredSales(from sales: [SaleTransaction]) -> [SaleTransaction] {
        var result = sales
        if let filter = selectedPaymentFilter {
            result = result.filter { $0.paymentMethod == filter }
        }
        if !searchText.isEmpty {
            result = result.filter { sale in
                sale.items.contains { $0.itemName.localizedCaseInsensitiveContains(searchText) }
                || (sale.customerName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        return result
    }

    func addToCart(_ item: InventoryItem) {
        if let index = cartItems.firstIndex(where: { $0.inventoryItem.id == item.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.append(CartItem(inventoryItem: item, quantity: 1))
        }
    }

    func removeFromCart(_ cartItem: CartItem) {
        cartItems.removeAll { $0.id == cartItem.id }
    }

    func updateQuantity(_ cartItem: CartItem, quantity: Int) {
        if let index = cartItems.firstIndex(where: { $0.id == cartItem.id }) {
            if quantity <= 0 {
                cartItems.remove(at: index)
            } else {
                cartItems[index].quantity = quantity
            }
        }
    }

    var subtotal: Double {
        cartItems.reduce(0) { $0 + ($1.inventoryItem.sellingPrice * Double($1.quantity)) }
    }

    var discountAmount: Double {
        subtotal * (discountPercentage / 100)
    }

    var totalAmount: Double {
        subtotal - discountAmount
    }

    var totalCost: Double {
        cartItems.reduce(0) { $0 + ($1.inventoryItem.costPrice * Double($1.quantity)) }
    }

    func processSale(dataService: FirebaseDataService) async {
        guard !cartItems.isEmpty else {
            errorMessage = "Cart is empty"
            return
        }

        isProcessing = true
        errorMessage = nil

        let saleItems = cartItems.map { cartItem in
            SaleItem(
                itemId: cartItem.inventoryItem.id ?? "",
                itemName: cartItem.inventoryItem.name,
                itemSKU: cartItem.inventoryItem.sku,
                itemBrand: cartItem.inventoryItem.brand,
                quantity: cartItem.quantity,
                unitPrice: cartItem.inventoryItem.sellingPrice,
                costPrice: cartItem.inventoryItem.costPrice
            )
        }

        let sale = SaleTransaction(
            items: saleItems,
            subtotal: subtotal,
            discount: discountAmount,
            totalAmount: totalAmount,
            paymentMethod: selectedPaymentMethod,
            customerName: customerName.isEmpty ? nil : customerName,
            notes: notes.isEmpty ? nil : notes,
            date: Date()
        )

        do {
            try await dataService.addSale(sale)

            for cartItem in cartItems {
                if let itemId = cartItem.inventoryItem.id {
                    try await dataService.logConsumption(
                        itemId: itemId,
                        amount: cartItem.quantity
                    )
                }
            }

            resetCart()
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    func resetCart() {
        cartItems = []
        customerName = ""
        discountPercentage = 0
        notes = ""
        selectedPaymentMethod = .cash
    }
}
