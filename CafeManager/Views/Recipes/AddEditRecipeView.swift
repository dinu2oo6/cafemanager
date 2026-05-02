import SwiftUI

struct AddEditRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    @State var recipe: Recipe
    let dataService: FirebaseDataService

    @State private var showIngredientPicker = false
    @State private var newIngredientQty = ""
    @State private var selectedInventoryItem: InventoryItem?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { recipe.id != nil }

    var body: some View {
        Form {
            Section("Product Details") {
                TextField("Recipe Name (e.g., Masala Tea)", text: $recipe.name)
                Picker("Category", selection: $recipe.category) {
                    ForEach(RecipeCategory.allCases) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }
                TextField("Selling Price", value: $recipe.sellingPrice, format: .number)
                    .keyboardType(.decimalPad)
                TextField("Serving Size (e.g., 1 cup 200ml)", text: $recipe.servingSize)
                Stepper("Prep Time: \(recipe.preparationTime) min", value: $recipe.preparationTime, in: 1...120)
            }

            Section {
                if recipe.ingredients.isEmpty {
                    Text("No ingredients added yet")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ingredient.itemName)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("\(String(format: "%.2f", ingredient.quantity)) \(ingredient.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let item = dataService.inventoryItems.first(where: { $0.id == ingredient.inventoryItemId }) {
                                let qtyInBaseUnit = ProductCostAnalyzer.convertQuantity(ingredient.quantity, from: ingredient.unit, to: item.unit)
                                Text("\u{20B9}\(String(format: "%.2f", item.costPrice * qtyInBaseUnit))")
                                    .font(.caption.bold())
                                    .foregroundColor(AppTheme.primary)
                            }
                        }
                    }
                    .onDelete { indices in
                        recipe.ingredients.remove(atOffsets: indices)
                    }
                }

                Button {
                    showIngredientPicker = true
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                        .foregroundColor(AppTheme.primary)
                }
            } header: {
                Text("Ingredients")
            } footer: {
                if !recipe.ingredients.isEmpty {
                    let totalCost = recipe.ingredients.reduce(0.0) { sum, ing in
                        let item = dataService.inventoryItems.first { $0.id == ing.inventoryItemId }
                        let baseUnit = item?.unit ?? ing.unit
                        let qtyInBaseUnit = ProductCostAnalyzer.convertQuantity(ing.quantity, from: ing.unit, to: baseUnit)
                        return sum + (item?.costPrice ?? 0) * qtyInBaseUnit
                    }
                    Text("Total ingredient cost: \u{20B9}\(String(format: "%.2f", totalCost)) per serving")
                }
            }

            Section("Notes") {
                TextField("Optional notes...", text: Binding(
                    get: { recipe.notes ?? "" },
                    set: { recipe.notes = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(2...4)
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(AppTheme.error)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Recipe" : "New Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    saveRecipe()
                }
                .disabled(recipe.name.trimmingCharacters(in: .whitespaces).isEmpty || recipe.ingredients.isEmpty || isSaving)
                .bold()
            }
        }
        .sheet(isPresented: $showIngredientPicker) {
            NavigationStack {
                IngredientPickerView(
                    inventoryItems: dataService.inventoryItems,
                    onSelect: { item, quantity, unit in
                        let ingredient = RecipeIngredient(
                            inventoryItemId: item.id ?? "",
                            itemName: item.name,
                            quantity: quantity,
                            unit: unit
                        )
                        recipe.ingredients.append(ingredient)
                    }
                )
            }
        }
    }

    private func saveRecipe() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                if isEditing {
                    try await dataService.updateRecipe(recipe)
                } else {
                    try await dataService.addRecipe(recipe)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Ingredient Picker

private struct IngredientPickerView: View {
    let inventoryItems: [InventoryItem]
    let onSelect: (InventoryItem, Double, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedItem: InventoryItem?
    @State private var quantity = ""
    @State private var selectedUnit = "g"

    private let units = ["kg", "g", "L", "mL", "pcs", "dozen", "bags", "boxes", "packets", "tbsp", "tsp", "cups", "pinch"]

    private var filteredItems: [InventoryItem] {
        if searchText.isEmpty { return inventoryItems }
        return inventoryItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func smallUnitFor(_ inventoryUnit: String) -> String {
        switch inventoryUnit.lowercased() {
        case "kg": return "g"
        case "l": return "mL"
        default: return inventoryUnit
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let item = selectedItem {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: item.category?.icon ?? "square.grid.2x2.fill")
                            .foregroundColor(AppTheme.primary)
                        Text(item.displayName)
                            .font(.headline)
                        Spacer()
                        Text("\u{20B9}\(String(format: "%.2f", item.costPrice))/\(item.unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        TextField("Quantity per serving", text: $quantity)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }

                    HStack {
                        Button("Back") {
                            selectedItem = nil
                            quantity = ""
                        }
                        .foregroundColor(.secondary)

                        Spacer()

                        Button("Add Ingredient") {
                            guard let qty = Double(quantity), qty > 0 else { return }
                            onSelect(item, qty, selectedUnit)
                            dismiss()
                        }
                        .disabled(Double(quantity) == nil || (Double(quantity) ?? 0) <= 0)
                        .bold()
                    }
                }
                .padding()
            } else {
                List(filteredItems) { item in
                    Button {
                        selectedItem = item
                        selectedUnit = smallUnitFor(item.unit)
                    } label: {
                        HStack {
                            Image(systemName: item.category?.icon ?? "square.grid.2x2.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("\(item.quantity) \(item.unit) in stock \u{00B7} \u{20B9}\(String(format: "%.2f", item.costPrice))/\(item.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search ingredients...")
            }
        }
        .navigationTitle("Select Ingredient")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
