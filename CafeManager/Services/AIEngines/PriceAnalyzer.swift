import Foundation

struct PriceAnalyzer {
    static func analyze(items: [InventoryItem], suppliers: [Supplier]) -> [PriceInsight] {
        items.compactMap { item -> PriceInsight? in
            guard item.costPrice > 0 else { return nil }

            let margin = item.marginPercentage
            let monthlyQty = item.averageDailyConsumption * 30

            let suggestion: String
            if margin < 0 {
                suggestion = "Selling at a loss! Increase price by at least \(formatCurrency(abs(item.profitPerUnit))) per \(item.unit)."
            } else if margin < 20 {
                let targetCost = item.sellingPrice * 0.6
                let savings = (item.costPrice - targetCost) * monthlyQty * 12
                suggestion = "Low margin (\(String(format: "%.0f", margin))%). Find a supplier under \(formatCurrency(targetCost))/\(item.unit) to save \(formatCurrency(savings))/year."
            } else if margin < 40 {
                suggestion = "Moderate margin (\(String(format: "%.0f", margin))%). Monthly revenue: \(formatCurrency(item.sellingPrice * monthlyQty))."
            } else {
                suggestion = "Strong margin (\(String(format: "%.0f", margin))%). Annual profit potential: \(formatCurrency(item.profitPerUnit * monthlyQty * 12))."
            }

            return PriceInsight(
                itemName: item.displayName, currentCost: item.costPrice,
                sellingPrice: item.sellingPrice, margin: margin,
                monthlyQuantity: monthlyQty, suggestion: suggestion
            )
        }
    }

    static func calculateAnnualSavings(currentCost: Double, alternativeCost: Double, monthlyQuantity: Double) -> Double {
        (currentCost - alternativeCost) * monthlyQuantity * 12
    }

    private static func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "\u{20B9}"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\u{20B9}\(Int(value))"
    }
}
