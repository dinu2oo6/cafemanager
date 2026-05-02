import SwiftUI

struct RecipeCostAnalysisView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var vm = RecipeViewModel()

    @State private var showAddRecipe = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("View", selection: $selectedTab) {
                    Text("Recipes").tag(0)
                    Text("Profitability").tag(1)
                    Text("What-If").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.padding)
                .padding(.top, 8)

                switch selectedTab {
                case 0: recipeListTab
                case 1: profitabilityTab
                case 2: whatIfTab
                default: EmptyView()
                }
            }
        }
        .navigationTitle("Recipe Cost Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddRecipe = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            NavigationStack {
                AddEditRecipeView(recipe: .empty, dataService: dataService)
            }
        }
        .onAppear {
            vm.refreshMenuRanking(dataService: dataService)
        }
    }

    // MARK: - Recipes Tab

    private var recipeListTab: some View {
        Group {
            if dataService.recipes.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.secondary.opacity(0.4))
                    Text("No Recipes Yet")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Add your first recipe to see ingredient costs, profit margins, and smart suggestions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button {
                        showAddRecipe = true
                    } label: {
                        Label("Add Recipe", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dataService.recipes) { recipe in
                            NavigationLink {
                                ProductCostDetailView(recipe: recipe)
                                    .environmentObject(dataService)
                            } label: {
                                RecipeCardView(recipe: recipe, dataService: dataService)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(AppTheme.padding)
                }
            }
        }
    }

    // MARK: - Profitability Tab

    private var profitabilityTab: some View {
        Group {
            if vm.menuRanking.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Add recipes to see profitability ranking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.menuRanking) { item in
                            ProfitabilityRowView(item: item)
                        }
                    }
                    .padding(AppTheme.padding)
                }
            }
        }
        .onAppear {
            vm.refreshMenuRanking(dataService: dataService)
        }
    }

    // MARK: - What-If Tab

    private var whatIfTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Price Change Simulator")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("See how an ingredient price change affects all your recipes.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Ingredient name (e.g., Milk)", text: $vm.whatIfIngredient)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Price change:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(vm.whatIfPercentage > 0 ? "+" : "")\(String(format: "%.0f", vm.whatIfPercentage))%")
                            .font(.subheadline.bold())
                            .foregroundColor(vm.whatIfPercentage > 0 ? AppTheme.error : AppTheme.success)
                    }
                    Slider(value: $vm.whatIfPercentage, in: -50...100, step: 5)
                        .tint(vm.whatIfPercentage > 0 ? AppTheme.error : AppTheme.success)

                    Button {
                        vm.runWhatIf(dataService: dataService)
                    } label: {
                        Text("Simulate")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

                if let scenario = vm.whatIfResult {
                    WhatIfResultView(scenario: scenario)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppTheme.error)
                        .padding()
                }
            }
            .padding(AppTheme.padding)
        }
    }
}

// MARK: - Recipe Card

private struct RecipeCardView: View {
    let recipe: Recipe
    let dataService: FirebaseDataService

    private var breakdown: ProductCostBreakdown {
        ProductCostAnalyzer.analyzeProduct(
            recipe: recipe,
            inventory: dataService.inventoryItems,
            sales: dataService.sales,
            allRecipes: dataService.recipes
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: recipe.category.icon)
                    .font(.title3)
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.name)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("\(recipe.category.rawValue) \u{00B7} \(recipe.servingSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\u{20B9}\(String(format: "%.0f", recipe.sellingPrice))")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text("selling price")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                costPill(label: "Cost", value: breakdown.trueProductionCost, color: AppTheme.warning)
                costPill(label: "Profit", value: breakdown.profitPerServing, color: breakdown.profitPerServing >= 0 ? AppTheme.success : AppTheme.error)
                marginPill(margin: breakdown.marginPercentage)

                Spacer()

                if !breakdown.suggestions.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                        Text("\(breakdown.suggestions.count)")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func costPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\u{20B9}\(String(format: "%.2f", value))")
                .font(.caption.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func marginPill(margin: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(String(format: "%.0f", margin))%")
                .font(.caption.bold())
                .foregroundColor(margin >= 30 ? AppTheme.success : margin >= 15 ? AppTheme.warning : AppTheme.error)
            Text("Margin")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Profitability Row

private struct ProfitabilityRowView: View {
    let item: MenuProfitabilityItem

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(item.rank)")
                .font(.headline.bold())
                .foregroundColor(rankColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.recipeName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(String(format: "%.0f", item.margin))% margin")
                    .font(.caption.bold())
                    .foregroundColor(item.margin >= 30 ? AppTheme.success : item.margin >= 15 ? AppTheme.warning : AppTheme.error)
                if item.monthlySales > 0 {
                    Text("\(item.monthlySales) sold/mo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("\u{20B9}\(String(format: "%.0f", item.monthlyProfit))/mo profit")
                    .font(.caption)
                    .foregroundColor(item.monthlyProfit >= 0 ? AppTheme.success : AppTheme.error)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var rankColor: Color {
        switch item.rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return AppTheme.secondary
        }
    }
}

// MARK: - What-If Result

private struct WhatIfResultView: View {
    let scenario: WhatIfScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.purple)
                Text("Scenario Results")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }

            HStack {
                Text(scenario.ingredientName)
                    .font(.subheadline.bold())
                Spacer()
                Text("\u{20B9}\(String(format: "%.2f", scenario.currentCost))")
                    .strikethrough()
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\u{20B9}\(String(format: "%.2f", scenario.newCost))")
                    .font(.subheadline.bold())
                    .foregroundColor(scenario.priceChangePercent > 0 ? AppTheme.error : AppTheme.success)
            }

            if scenario.affectedRecipes.isEmpty {
                Text("No recipes use this ingredient.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(scenario.affectedRecipes) { impact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(impact.recipeName)
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)
                        HStack {
                            Text("Cost: \u{20B9}\(String(format: "%.2f", impact.oldCost)) \u{2192} \u{20B9}\(String(format: "%.2f", impact.newCost))")
                                .font(.caption)
                            Spacer()
                            Text("Margin: \(String(format: "%.0f", impact.oldMargin))% \u{2192} \(String(format: "%.0f", impact.newMargin))%")
                                .font(.caption)
                                .foregroundColor(impact.newMargin < impact.oldMargin ? AppTheme.error : AppTheme.success)
                        }
                        if impact.monthlyProfitImpact != 0 {
                            Text("Monthly profit impact: \u{20B9}\(String(format: "%.0f", impact.monthlyProfitImpact))")
                                .font(.caption)
                                .foregroundColor(impact.monthlyProfitImpact >= 0 ? AppTheme.success : AppTheme.error)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
