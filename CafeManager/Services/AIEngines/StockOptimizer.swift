import Foundation

struct StockOptimizer {
    static func analyze(item: InventoryItem, supplier: Supplier?) -> StockRecommendation {
        let avgConsumption = item.averageDailyConsumption
        let daysLeft = item.daysUntilStockout
        let leadTime = supplier?.leadTimeInDays ?? 3

        let orderByDay = max(0, daysLeft - leadTime)
        let orderDate = Calendar.current.date(byAdding: .day, value: orderByDay, to: Date()) ?? Date()

        let suggestedQty = Int(avgConsumption * 14) + (item.reorderLevel * 2)

        let urgency: UrgencyLevel
        let message: String

        if avgConsumption == 0 {
            return StockRecommendation(
                itemId: item.id ?? "", itemName: item.displayName,
                currentQuantity: item.quantity, unit: item.unit,
                daysUntilStockout: 999, recommendedOrderDate: orderDate,
                recommendedQuantity: item.reorderLevel,
                urgencyLevel: .normal,
                message: "No consumption data yet. Start logging daily usage for predictions."
            )
        }

        if daysLeft <= leadTime {
            urgency = .critical
            message = "CRITICAL: Order immediately! Only \(daysLeft) day(s) of stock left. Supplier needs \(leadTime) days to deliver."
        } else if daysLeft <= leadTime + 2 {
            urgency = .warning
            message = "Order soon — \(daysLeft) days of stock remaining. Supplier lead time is \(leadTime) days."
        } else {
            urgency = .normal
            message = "Stock healthy. \(daysLeft) days of supply remaining."
        }

        return StockRecommendation(
            itemId: item.id ?? "", itemName: item.displayName,
            currentQuantity: item.quantity, unit: item.unit,
            daysUntilStockout: daysLeft, recommendedOrderDate: orderDate,
            recommendedQuantity: max(suggestedQty, item.reorderLevel),
            urgencyLevel: urgency, message: message
        )
    }

    static func analyzeAll(items: [InventoryItem], suppliers: [Supplier]) -> [StockRecommendation] {
        items.map { item in
            let supplier = suppliers.first { $0.id == item.supplierId }
            return analyze(item: item, supplier: supplier)
        }
    }
}
