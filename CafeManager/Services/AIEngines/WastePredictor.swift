import Foundation

struct WastePredictor {
    static func predict(item: InventoryItem) -> WasteRisk? {
        guard let expiryDate = item.expiryDate else { return nil }

        let daysUntilExpiry = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0

        if daysUntilExpiry <= 0 {
            return WasteRisk(
                itemId: item.id ?? "", itemName: item.displayName, unit: item.unit,
                daysUntilExpiry: 0,
                predictedWasteQuantity: Double(item.quantity),
                wastePercentage: 100,
                recommendation: "EXPIRED — dispose of all \(item.quantity) \(item.unit) immediately."
            )
        }

        let canConsume = item.averageDailyConsumption * Double(daysUntilExpiry)
        let willWaste = max(0, Double(item.quantity) - canConsume)
        let wastePercentage = item.quantity > 0 ? (willWaste / Double(item.quantity)) * 100 : 0

        let recommendation: String
        if wastePercentage > 50 {
            recommendation = "High waste risk! \(Int(willWaste)) \(item.unit) will likely expire. Reduce next order significantly."
        } else if wastePercentage > 20 {
            recommendation = "Moderate waste risk. Consider reducing next order by \(Int(willWaste)) \(item.unit)."
        } else if wastePercentage > 0 {
            recommendation = "Low waste risk. ~\(Int(willWaste)) \(item.unit) may expire in \(daysUntilExpiry) days."
        } else {
            recommendation = "No waste expected. Stock will be consumed before expiry."
        }

        return WasteRisk(
            itemId: item.id ?? "", itemName: item.displayName, unit: item.unit,
            daysUntilExpiry: daysUntilExpiry,
            predictedWasteQuantity: willWaste,
            wastePercentage: wastePercentage,
            recommendation: recommendation
        )
    }

    static func predictAll(items: [InventoryItem]) -> [WasteRisk] {
        items.compactMap { predict(item: $0) }
            .sorted { $0.wastePercentage > $1.wastePercentage }
    }
}
