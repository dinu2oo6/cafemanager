import SwiftUI

struct NewSaleView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = SalesViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                VStack(spacing: 0) {
                    if !viewModel.cartItems.isEmpty {
                        cartSummaryBar
                    }

                    ScrollView {
                        VStack(spacing: AppTheme.sectionSpacing) {
                            if !viewModel.cartItems.isEmpty {
                                cartSection
                            }

                            menuSection

                            if !viewModel.cartItems.isEmpty {
                                paymentSection
                                checkoutSection
                            }

                            Spacer().frame(height: 20)
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationTitle("New Sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Sale Complete!", isPresented: $viewModel.showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Transaction recorded successfully.")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Cart Summary Bar

    private var cartSummaryBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "cart.fill")
                    .font(.caption)
                Text("\(viewModel.cartItems.reduce(0) { $0 + $1.quantity }) items")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            Spacer()
            Text(currencyString(viewModel.totalAmount))
                .font(.headline.bold())
                .foregroundColor(.white)
        }
        .padding()
        .background(AppTheme.primary)
    }

    // MARK: - Cart Section

    private var cartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundColor(AppTheme.primary)
                Text("Cart")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button("Clear") { viewModel.resetCart() }
                    .font(.caption)
                    .foregroundColor(AppTheme.error)
            }
            .padding(.horizontal)

            ForEach(viewModel.cartItems) { cartItem in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cartItem.inventoryItem.displayName)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 4) {
                            if let sku = cartItem.inventoryItem.sku {
                                Text(sku)
                                    .font(.caption2.monospaced())
                                    .foregroundColor(AppTheme.primary)
                            }
                            Text(currencyString(cartItem.inventoryItem.sellingPrice) + " each")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            viewModel.updateQuantity(cartItem, quantity: cartItem.quantity - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(AppTheme.secondary)
                        }

                        Text("\(cartItem.quantity)")
                            .font(.subheadline.bold())
                            .frame(width: 24)

                        Button {
                            viewModel.updateQuantity(cartItem, quantity: cartItem.quantity + 1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(AppTheme.primary)
                        }
                    }

                    Text(currencyString(cartItem.inventoryItem.sellingPrice * Double(cartItem.quantity)))
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider().padding(.horizontal)

            HStack {
                Text("Subtotal")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondary)
                Spacer()
                Text(currencyString(viewModel.subtotal))
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            if viewModel.discountAmount > 0 {
                HStack {
                    Text("Discount (\(Int(viewModel.discountPercentage))%)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.success)
                    Spacer()
                    Text("-\(currencyString(viewModel.discountAmount))")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.success)
                }
                .padding(.horizontal)
            }

            HStack {
                Text("Total")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(currencyString(viewModel.totalAmount))
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.primary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .padding(.horizontal)
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "menucard.fill")
                    .foregroundColor(.blue)
                Text("Menu Items")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            TextField("Search items...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            let filtered = filteredItems
            if filtered.isEmpty {
                Text("No items found")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(filtered) { item in
                        menuItemCard(item)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var filteredItems: [InventoryItem] {
        let items = dataService.inventoryItems.filter { $0.sellingPrice > 0 && $0.quantity > 0 }
        if searchText.isEmpty { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || ($0.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            || ($0.sku?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func menuItemCard(_ item: InventoryItem) -> some View {
        Button {
            viewModel.addToCart(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                if let sku = item.sku, !sku.isEmpty {
                    Text(sku)
                        .font(.caption2.monospaced())
                        .foregroundColor(AppTheme.secondary)
                }
                HStack {
                    Text(currencyString(item.sellingPrice))
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primary)
                    Spacer()
                    Text("\(item.quantity) \(item.unit)")
                        .font(.caption2)
                        .foregroundColor(item.isLow ? AppTheme.warning : AppTheme.secondary)
                }
                let inCart = viewModel.cartItems.first(where: { $0.inventoryItem.id == item.id })?.quantity ?? 0
                if inCart > 0 {
                    Text("\(inCart) in cart")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.success)
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(
                        viewModel.cartItems.contains(where: { $0.inventoryItem.id == item.id })
                        ? AppTheme.primary.opacity(0.5)
                        : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }

    // MARK: - Payment Section

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.purple)
                Text("Payment")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            HStack(spacing: 8) {
                ForEach(PaymentMethod.allCases) { method in
                    Button {
                        viewModel.selectedPaymentMethod = method
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: method.icon)
                                .font(.title3)
                            Text(method.rawValue)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(viewModel.selectedPaymentMethod == method ? AppTheme.primary : Color.white)
                        .foregroundColor(viewModel.selectedPaymentMethod == method ? .white : AppTheme.textPrimary)
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.primary.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                TextField("Customer name (optional)", text: $viewModel.customerName)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Discount %")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondary)
                    Slider(value: $viewModel.discountPercentage, in: 0...50, step: 5)
                        .tint(AppTheme.primary)
                    Text("\(Int(viewModel.discountPercentage))%")
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 40)
                }

                TextField("Notes (optional)", text: $viewModel.notes)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Checkout

    private var checkoutSection: some View {
        Button {
            Task {
                await viewModel.processSale(dataService: dataService)
            }
        } label: {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete Sale — \(currencyString(viewModel.totalAmount))")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.cartItems.isEmpty ? Color.gray : AppTheme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.cartItems.isEmpty || viewModel.isProcessing)
        .padding(.horizontal)
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}
