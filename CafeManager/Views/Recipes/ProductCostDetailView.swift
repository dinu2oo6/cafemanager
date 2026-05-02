import SwiftUI

struct ProductCostDetailView: View {
    let recipe: Recipe
    @EnvironmentObject var dataService: FirebaseDataService
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    private var breakdown: ProductCostBreakdown {
        ProductCostAnalyzer.analyzeProduct(
            recipe: recipe,
            inventory: dataService.inventoryItems,
            sales: dataService.sales,
            allRecipes: dataService.recipes
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                costSummaryCard
                ingredientBreakdownCard
                if !breakdown.suggestions.isEmpty {
                    suggestionsCard
                }
                stockAvailabilityCard
            }
            .padding(AppTheme.padding)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showEditSheet = true } label: {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                AddEditRecipeView(recipe: recipe, dataService: dataService)
            }
        }
        .alert("Delete Recipe", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = recipe.id {
                    Task {
                        try? await dataService.deleteRecipe(id)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(recipe.name)?")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: recipe.category.icon)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(AppTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.textPrimary)
                HStack(spacing: 8) {
                    Label(recipe.category.rawValue, systemImage: recipe.category.icon)
                    Text("\u{00B7}")
                    Label(recipe.servingSize, systemImage: "cup.and.saucer")
                    Text("\u{00B7}")
                    Label("\(recipe.preparationTime) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Cost Summary

    private var costSummaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "indianrupeesign.circle.fill")
                    .foregroundColor(AppTheme.primary)
                Text("Cost Summary")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 0) {
                costSummaryTile(
                    title: "Ingredient Cost",
                    value: "\u{20B9}\(String(format: "%.2f", breakdown.totalIngredientCost))",
                    color: .blue
                )
                costSummaryTile(
                    title: "Waste Factor",
                    value: "+\u{20B9}\(String(format: "%.2f", breakdown.wasteFactor))",
                    color: .orange
                )
                costSummaryTile(
                    title: "True Cost",
                    value: "\u{20B9}\(String(format: "%.2f", breakdown.trueProductionCost))",
                    color: AppTheme.warning
                )
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selling Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\u{20B9}\(String(format: "%.2f", breakdown.sellingPrice))")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("Profit/Serving")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\u{20B9}\(String(format: "%.2f", breakdown.profitPerServing))")
                        .font(.title3.bold())
                        .foregroundColor(breakdown.profitPerServing >= 0 ? AppTheme.success : AppTheme.error)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Margin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", breakdown.marginPercentage))%")
                        .font(.title3.bold())
                        .foregroundColor(marginColor)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private func costSummaryTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ingredient Breakdown

    private var ingredientBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(AppTheme.primary)
                Text("Ingredient Breakdown")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            ForEach(breakdown.ingredients) { detail in
                VStack(spacing: 6) {
                    HStack {
                        Text(detail.ingredientName)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\u{20B9}\(String(format: "%.2f", detail.totalCost))")
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.primary)
                    }
                    HStack {
                        Text("\(String(format: "%.2f", detail.quantityNeeded)) \(detail.unit) @ \u{20B9}\(String(format: "%.2f", detail.costPerUnit))/\(detail.unit)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.0f", detail.costPercentage))% of cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.primary.opacity(0.15))
                            .frame(height: 4)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(AppTheme.primary)
                                    .frame(width: geo.size.width * min(detail.costPercentage / 100, 1), height: 4)
                            }
                    }
                    .frame(height: 4)
                }
                .padding(.vertical, 4)
                if detail.id != breakdown.ingredients.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Suggestions

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Smart Suggestions")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(breakdown.suggestions.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }

            ForEach(breakdown.suggestions) { suggestion in
                SuggestionRowView(suggestion: suggestion)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: - Stock Availability

    private var stockAvailabilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(.teal)
                Text("Stock Availability")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            let minServings = breakdown.ingredients.map(\.servingsAvailable).min() ?? 0

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You can make")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(minServings)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(minServings > 20 ? AppTheme.success : minServings > 5 ? AppTheme.warning : AppTheme.error)
                        Text("servings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text("with current stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            ForEach(breakdown.ingredients) { detail in
                HStack {
                    Text(detail.ingredientName)
                        .font(.caption)
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Text("\(detail.stockAvailable) \(detail.unit) in stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("(\(detail.servingsAvailable) servings)")
                        .font(.caption.bold())
                        .foregroundColor(detail.servingsAvailable > 20 ? AppTheme.success : detail.servingsAvailable > 5 ? AppTheme.warning : AppTheme.error)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var marginColor: Color {
        if breakdown.marginPercentage >= 30 { return AppTheme.success }
        if breakdown.marginPercentage >= 15 { return AppTheme.warning }
        return AppTheme.error
    }
}

// MARK: - Suggestion Row

private struct SuggestionRowView: View {
    let suggestion: CostSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: suggestion.type.icon)
                .font(.body)
                .foregroundColor(suggestionColor)
                .frame(width: 32, height: 32)
                .background(suggestionColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(suggestion.title)
                        .font(.subheadline.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if suggestion.potentialSaving > 0 {
                        Text("Save \u{20B9}\(String(format: "%.0f", suggestion.potentialSaving))")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppTheme.success.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(suggestion.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(suggestionColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(suggestionColor.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var suggestionColor: Color {
        switch suggestion.type {
        case .substitution: return .blue
        case .portionOptimize: return .purple
        case .bulkBuying: return .teal
        case .marginAlert: return .red
        case .wasteReduction: return .orange
        case .priceAdjustment: return .green
        case .seasonal: return .mint
        }
    }
}
