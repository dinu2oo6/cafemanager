import Foundation

struct ProductCostAnalyzer {

    static func analyzeProduct(recipe: Recipe, inventory: [InventoryItem], sales: [SaleTransaction], allRecipes: [Recipe]) -> ProductCostBreakdown {
        var ingredientDetails: [IngredientCostDetail] = []
        var totalCost: Double = 0

        for ingredient in recipe.ingredients {
            let inventoryItem = findInventoryItem(ingredient: ingredient, inventory: inventory)
            let costPerBaseUnit = inventoryItem?.costPrice ?? 0
            let inventoryUnit = inventoryItem?.unit ?? ingredient.unit
            let qtyInInventoryUnit = convertQuantity(ingredient.quantity, from: ingredient.unit, to: inventoryUnit)
            let itemCost = costPerBaseUnit * qtyInInventoryUnit
            totalCost += itemCost

            let stockAvailable = inventoryItem?.quantity ?? 0
            let servingsAvailable = qtyInInventoryUnit > 0 ? Int(Double(stockAvailable) / qtyInInventoryUnit) : 0

            ingredientDetails.append(IngredientCostDetail(
                ingredientName: ingredient.itemName,
                quantityNeeded: ingredient.quantity,
                unit: ingredient.unit,
                costPerUnit: costPerBaseUnit * convertQuantity(1, from: ingredient.unit, to: inventoryUnit),
                totalCost: itemCost,
                costPercentage: 0,
                stockAvailable: stockAvailable,
                servingsAvailable: servingsAvailable
            ))
        }

        ingredientDetails = ingredientDetails.map { detail in
            IngredientCostDetail(
                ingredientName: detail.ingredientName,
                quantityNeeded: detail.quantityNeeded,
                unit: detail.unit,
                costPerUnit: detail.costPerUnit,
                totalCost: detail.totalCost,
                costPercentage: totalCost > 0 ? (detail.totalCost / totalCost) * 100 : 0,
                stockAvailable: detail.stockAvailable,
                servingsAvailable: detail.servingsAvailable
            )
        }

        let wasteFactor = calculateWasteFactor(recipe: recipe, inventory: inventory)
        let trueProductionCost = totalCost + wasteFactor
        let profit = recipe.sellingPrice - trueProductionCost
        let margin = recipe.sellingPrice > 0 ? (profit / recipe.sellingPrice) * 100 : 0

        let suggestions = generateSuggestions(
            recipe: recipe, ingredientDetails: ingredientDetails,
            totalCost: totalCost, wasteFactor: wasteFactor,
            margin: margin, inventory: inventory, sales: sales
        )

        return ProductCostBreakdown(
            recipeName: recipe.name,
            ingredients: ingredientDetails,
            totalIngredientCost: totalCost,
            sellingPrice: recipe.sellingPrice,
            profitPerServing: profit,
            marginPercentage: margin,
            suggestions: suggestions,
            wasteFactor: wasteFactor,
            trueProductionCost: trueProductionCost
        )
    }

    // MARK: - Menu Profitability Ranking

    static func rankMenuProfitability(recipes: [Recipe], inventory: [InventoryItem], sales: [SaleTransaction]) -> [MenuProfitabilityItem] {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthlySaleItems = sales.filter { $0.date >= monthAgo }.flatMap { $0.items }

        var items: [MenuProfitabilityItem] = recipes.map { recipe in
            let breakdown = analyzeProduct(recipe: recipe, inventory: inventory, sales: sales, allRecipes: recipes)
            let monthlySalesQty = monthlySaleItems
                .filter { $0.itemName.localizedCaseInsensitiveContains(recipe.name) }
                .reduce(0) { $0 + $1.quantity }
            let monthlyProfit = breakdown.profitPerServing * Double(monthlySalesQty)

            return MenuProfitabilityItem(
                recipeName: recipe.name,
                category: recipe.category.rawValue,
                totalCost: breakdown.trueProductionCost,
                sellingPrice: recipe.sellingPrice,
                margin: breakdown.marginPercentage,
                monthlySales: monthlySalesQty,
                monthlyProfit: monthlyProfit,
                rank: 0
            )
        }

        items.sort { $0.monthlyProfit > $1.monthlyProfit }
        items = items.enumerated().map { idx, item in
            MenuProfitabilityItem(
                recipeName: item.recipeName, category: item.category,
                totalCost: item.totalCost, sellingPrice: item.sellingPrice,
                margin: item.margin, monthlySales: item.monthlySales,
                monthlyProfit: item.monthlyProfit, rank: idx + 1
            )
        }
        return items
    }

    // MARK: - What-If Scenario

    static func whatIfPriceChange(ingredientName: String, priceChangePercent: Double, recipes: [Recipe], inventory: [InventoryItem], sales: [SaleTransaction]) -> WhatIfScenario? {
        guard let item = inventory.first(where: { $0.name.localizedCaseInsensitiveContains(ingredientName) }) else { return nil }

        let newCost = item.costPrice * (1 + priceChangePercent / 100)

        let affectedRecipes = recipes.filter { recipe in
            recipe.ingredients.contains { $0.inventoryItemId == item.id || $0.itemName.localizedCaseInsensitiveContains(ingredientName) }
        }

        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let monthlySaleItems = sales.filter { $0.date >= monthAgo }.flatMap { $0.items }

        let impacts = affectedRecipes.map { recipe -> WhatIfRecipeImpact in
            let oldBreakdown = analyzeProduct(recipe: recipe, inventory: inventory, sales: sales, allRecipes: recipes)

            var newTotalCost: Double = 0
            for ingredient in recipe.ingredients {
                if ingredient.inventoryItemId == item.id || ingredient.itemName.localizedCaseInsensitiveContains(ingredientName) {
                    let qtyInBaseUnit = convertQuantity(ingredient.quantity, from: ingredient.unit, to: item.unit)
                    newTotalCost += newCost * qtyInBaseUnit
                } else {
                    let invItem = findInventoryItem(ingredient: ingredient, inventory: inventory)
                    let baseUnit = invItem?.unit ?? ingredient.unit
                    let qtyInBaseUnit = convertQuantity(ingredient.quantity, from: ingredient.unit, to: baseUnit)
                    newTotalCost += (invItem?.costPrice ?? 0) * qtyInBaseUnit
                }
            }

            let newMargin = recipe.sellingPrice > 0 ? ((recipe.sellingPrice - newTotalCost) / recipe.sellingPrice) * 100 : 0
            let monthlySalesQty = monthlySaleItems
                .filter { $0.itemName.localizedCaseInsensitiveContains(recipe.name) }
                .reduce(0) { $0 + $1.quantity }
            let monthlyImpact = (oldBreakdown.totalIngredientCost - newTotalCost) * Double(monthlySalesQty)

            return WhatIfRecipeImpact(
                recipeName: recipe.name,
                oldCost: oldBreakdown.totalIngredientCost,
                newCost: newTotalCost,
                oldMargin: oldBreakdown.marginPercentage,
                newMargin: newMargin,
                monthlyProfitImpact: monthlyImpact
            )
        }

        return WhatIfScenario(
            ingredientName: item.name,
            currentCost: item.costPrice,
            newCost: newCost,
            priceChangePercent: priceChangePercent,
            affectedRecipes: impacts
        )
    }

    // MARK: - Unit Conversion

    static func convertQuantity(_ amount: Double, from sourceUnit: String, to targetUnit: String) -> Double {
        let src = sourceUnit.lowercased().trimmingCharacters(in: .whitespaces)
        let tgt = targetUnit.lowercased().trimmingCharacters(in: .whitespaces)
        if src == tgt { return amount }

        let toGrams: [String: Double] = [
            "kg": 1000, "g": 1, "mg": 0.001,
            "pinch": 0.5
        ]
        let toMilliliters: [String: Double] = [
            "l": 1000, "ml": 1,
            "tbsp": 15, "tsp": 5, "cups": 240
        ]

        if let srcG = toGrams[src], let tgtG = toGrams[tgt] {
            return amount * srcG / tgtG
        }
        if let srcML = toMilliliters[src], let tgtML = toMilliliters[tgt] {
            return amount * srcML / tgtML
        }

        return amount
    }

    // MARK: - Private Helpers

    private static func findInventoryItem(ingredient: RecipeIngredient, inventory: [InventoryItem]) -> InventoryItem? {
        inventory.first { $0.id == ingredient.inventoryItemId }
            ?? inventory.first { $0.name.localizedCaseInsensitiveCompare(ingredient.itemName) == .orderedSame }
            ?? inventory.first { $0.name.localizedCaseInsensitiveContains(ingredient.itemName) }
    }

    private static func calculateWasteFactor(recipe: Recipe, inventory: [InventoryItem]) -> Double {
        var wasteCost: Double = 0
        for ingredient in recipe.ingredients {
            guard let item = findInventoryItem(ingredient: ingredient, inventory: inventory) else { continue }
            let totalWaste = item.wasteRecord.reduce(0) { $0 + $1.quantity }
            let totalConsumed = item.dailyConsumption.reduce(0, +)
            guard totalConsumed > 0 else { continue }
            let wasteRatio = Double(totalWaste) / Double(totalConsumed + totalWaste)
            let qtyInInventoryUnit = convertQuantity(ingredient.quantity, from: ingredient.unit, to: item.unit)
            wasteCost += qtyInInventoryUnit * item.costPrice * wasteRatio
        }
        return wasteCost
    }

    private static func generateSuggestions(
        recipe: Recipe, ingredientDetails: [IngredientCostDetail],
        totalCost: Double, wasteFactor: Double, margin: Double,
        inventory: [InventoryItem], sales: [SaleTransaction]
    ) -> [CostSuggestion] {
        var suggestions: [CostSuggestion] = []

        // Margin alerts
        if margin < 0 {
            suggestions.append(CostSuggestion(
                type: .marginAlert,
                title: "Selling at a Loss!",
                detail: "Costs \(cur(totalCost)) to make but sells for \(cur(recipe.sellingPrice)). Raise price to at least \(cur(totalCost * 1.3)) for a 30% margin.",
                potentialSaving: totalCost - recipe.sellingPrice
            ))
        } else if margin < 20 {
            let suggestedPrice = totalCost / 0.7
            suggestions.append(CostSuggestion(
                type: .marginAlert,
                title: "Low Profit Margin (\(String(format: "%.0f", margin))%)",
                detail: "Consider raising the price to \(cur(suggestedPrice)) for a healthier 30% margin.",
                potentialSaving: suggestedPrice - recipe.sellingPrice
            ))
        }

        // Portion optimization — most expensive ingredient
        if let mostExpensive = ingredientDetails.max(by: { $0.totalCost < $1.totalCost }),
           mostExpensive.costPercentage > 40 {
            let reducedQty = mostExpensive.quantityNeeded * 0.85
            let saving = (mostExpensive.quantityNeeded - reducedQty) * mostExpensive.costPerUnit
            suggestions.append(CostSuggestion(
                type: .portionOptimize,
                title: "Optimize \(mostExpensive.ingredientName) Portion",
                detail: "Reducing by 15% (from \(f(mostExpensive.quantityNeeded)) to \(f(reducedQty)) \(mostExpensive.unit)) saves \(cur(saving))/serving.",
                potentialSaving: saving
            ))
        }

        // Waste reduction
        if wasteFactor > 0.01 {
            suggestions.append(CostSuggestion(
                type: .wasteReduction,
                title: "Waste Adds \(cur(wasteFactor)) Per Serving",
                detail: "Ingredient waste costs \(cur(wasteFactor)) extra per \(recipe.name). Better storage could save \(cur(wasteFactor * 30))/month.",
                potentialSaving: wasteFactor * 30
            ))
        }

        // Ingredient substitution
        for detail in ingredientDetails {
            guard let currentItem = inventory.first(where: { $0.name.localizedCaseInsensitiveContains(detail.ingredientName) }) else { continue }
            let alternatives = inventory.filter { alt in
                alt.id != currentItem.id &&
                alt.category == currentItem.category &&
                alt.costPrice < currentItem.costPrice &&
                alt.costPrice > 0
            }
            if let cheapest = alternatives.min(by: { $0.costPrice < $1.costPrice }) {
                let qtyInBaseUnit = convertQuantity(detail.quantityNeeded, from: detail.unit, to: currentItem.unit)
                let saving = (currentItem.costPrice - cheapest.costPrice) * qtyInBaseUnit
                suggestions.append(CostSuggestion(
                    type: .substitution,
                    title: "Switch to \(cheapest.displayName)",
                    detail: "Replace \(currentItem.displayName) (\(cur(currentItem.costPrice))/\(currentItem.unit)) with \(cheapest.displayName) (\(cur(cheapest.costPrice))/\(cheapest.unit)) to save \(cur(saving))/serving.",
                    potentialSaving: saving
                ))
            }
        }

        // Bulk buying
        for detail in ingredientDetails {
            guard let item = inventory.first(where: { $0.name.localizedCaseInsensitiveContains(detail.ingredientName) }) else { continue }
            let monthlyUsage = item.averageDailyConsumption * 30
            if monthlyUsage > 0 {
                let estimatedBulkSaving = item.costPrice * 0.12
                let monthlySaving = estimatedBulkSaving * monthlyUsage
                if monthlySaving > 100 {
                    suggestions.append(CostSuggestion(
                        type: .bulkBuying,
                        title: "Buy \(item.name) in Bulk",
                        detail: "You use ~\(Int(monthlyUsage)) \(item.unit)/month. Bulk ordering could save ~12% (\(cur(monthlySaving))/month).",
                        potentialSaving: monthlySaving
                    ))
                }
            }
        }

        // Seasonal suggestions
        let month = Calendar.current.component(.month, from: Date())
        if (4...6).contains(month) {
            if recipe.category == .hotBeverages {
                suggestions.append(CostSuggestion(
                    type: .seasonal,
                    title: "Summer — Promote Cold Alternatives",
                    detail: "Hot beverage demand typically drops 20-30% in summer. Consider promoting iced versions to maintain revenue.",
                    potentialSaving: 0
                ))
            }
            if recipe.category == .coldBeverages {
                suggestions.append(CostSuggestion(
                    type: .seasonal,
                    title: "Peak Season — Maximize Cold Beverage Sales",
                    detail: "Cold beverages are in peak demand. A 5-10% price increase or bundle deals can boost profit.",
                    potentialSaving: recipe.sellingPrice * 0.07
                ))
            }
        } else if (11...12).contains(month) || month == 1 {
            if recipe.category == .hotBeverages {
                suggestions.append(CostSuggestion(
                    type: .seasonal,
                    title: "Peak Season for Hot Beverages",
                    detail: "Winter drives higher demand for hot drinks. Stock up on ingredients and consider premium pricing.",
                    potentialSaving: recipe.sellingPrice * 0.05
                ))
            }
        }

        // Rainy season (Jul-Sep) for hot beverages
        if (7...9).contains(month) && recipe.category == .hotBeverages {
            suggestions.append(CostSuggestion(
                type: .seasonal,
                title: "Monsoon Boost for Hot Drinks",
                detail: "Rainy season increases hot beverage demand. Consider combo deals with snacks to increase average order value.",
                potentialSaving: recipe.sellingPrice * 0.1
            ))
        }

        return suggestions
    }

    private static func cur(_ value: Double) -> String {
        "\u{20B9}\(String(format: "%.2f", value))"
    }

    private static func f(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
