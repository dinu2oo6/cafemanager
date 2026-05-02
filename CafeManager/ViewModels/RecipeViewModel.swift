import Foundation

@MainActor
final class RecipeViewModel: ObservableObject {

    @Published var selectedRecipe: Recipe?
    @Published var costBreakdown: ProductCostBreakdown?
    @Published var menuRanking: [MenuProfitabilityItem] = []
    @Published var whatIfResult: WhatIfScenario?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // What-if inputs
    @Published var whatIfIngredient = ""
    @Published var whatIfPercentage: Double = 10

    func analyzeRecipe(_ recipe: Recipe, dataService: FirebaseDataService) {
        selectedRecipe = recipe
        costBreakdown = ProductCostAnalyzer.analyzeProduct(
            recipe: recipe,
            inventory: dataService.inventoryItems,
            sales: dataService.sales,
            allRecipes: dataService.recipes
        )
    }

    func refreshMenuRanking(dataService: FirebaseDataService) {
        menuRanking = ProductCostAnalyzer.rankMenuProfitability(
            recipes: dataService.recipes,
            inventory: dataService.inventoryItems,
            sales: dataService.sales
        )
    }

    func runWhatIf(dataService: FirebaseDataService) {
        guard !whatIfIngredient.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Enter an ingredient name."
            return
        }
        whatIfResult = ProductCostAnalyzer.whatIfPriceChange(
            ingredientName: whatIfIngredient,
            priceChangePercent: whatIfPercentage,
            recipes: dataService.recipes,
            inventory: dataService.inventoryItems,
            sales: dataService.sales
        )
        if whatIfResult == nil {
            errorMessage = "Ingredient '\(whatIfIngredient)' not found in inventory."
        }
    }

    func addRecipe(_ recipe: Recipe, dataService: FirebaseDataService) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await dataService.addRecipe(recipe)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func updateRecipe(_ recipe: Recipe, dataService: FirebaseDataService) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await dataService.updateRecipe(recipe)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func deleteRecipe(_ recipeId: String, dataService: FirebaseDataService) {
        isLoading = true
        Task {
            do {
                try await dataService.deleteRecipe(recipeId)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
