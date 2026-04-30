import Foundation
import FirebaseFirestore

// MARK: - Enums

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case ordered = "Ordered"
    case delivered = "Delivered"

    var id: String { rawValue }
}

enum UrgencyLevel: String, Codable, CaseIterable {
    case critical = "Critical"
    case warning = "Warning"
    case normal = "Normal"
}

// MARK: - Consumption Entry

struct ConsumptionEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var quantity: Int
    var date: Date
}

// MARK: - Waste Entry

struct WasteEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var quantity: Int
    var reason: String
    var date: Date
}

// MARK: - Inventory Item

struct InventoryItem: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var quantity: Int
    var unit: String
    var reorderLevel: Int
    var costPrice: Double
    var sellingPrice: Double
    var supplierId: String
    var dailyConsumption: [Int]
    var consumptionLog: [ConsumptionEntry]?
    var wasteRecord: [WasteEntry]
    var expiryDate: Date?
    @ServerTimestamp var createdAt: Date?

    var isLow: Bool { quantity <= reorderLevel }

    var averageDailyConsumption: Double {
        guard !dailyConsumption.isEmpty else { return 0 }
        return Double(dailyConsumption.reduce(0, +)) / Double(dailyConsumption.count)
    }

    var daysUntilStockout: Int {
        guard averageDailyConsumption > 0 else { return 999 }
        return Int(Double(quantity) / averageDailyConsumption)
    }

    var profitPerUnit: Double { sellingPrice - costPrice }

    var marginPercentage: Double {
        guard sellingPrice > 0 else { return 0 }
        return (profitPerUnit / sellingPrice) * 100
    }

    var stockLevelPercentage: Double {
        guard reorderLevel > 0 else { return 1.0 }
        let ratio = Double(quantity) / (Double(reorderLevel) * 3.0)
        return min(max(ratio, 0), 1.0)
    }

    static var empty: InventoryItem {
        InventoryItem(
            name: "", quantity: 0, unit: "kg", reorderLevel: 10,
            costPrice: 0, sellingPrice: 0, supplierId: "",
            dailyConsumption: [], wasteRecord: [], expiryDate: nil
        )
    }
}

// MARK: - Supplier

struct Supplier: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var address: String
    var leadTimeInDays: Int
    var paymentTerms: String
    var onTimeDeliveryRate: Double
    var totalAmountOwed: Double
    @ServerTimestamp var createdAt: Date?

    var reliabilityStars: Int {
        Int(round(onTimeDeliveryRate / 20.0))
    }

    static var empty: Supplier {
        Supplier(
            name: "", email: "", phone: "", address: "",
            leadTimeInDays: 3, paymentTerms: "Net 30",
            onTimeDeliveryRate: 80, totalAmountOwed: 0
        )
    }
}

// MARK: - Order

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var itemId: String
    var itemName: String
    var quantity: Int
    var supplierId: String
    var supplierName: String
    var orderDate: Date
    var expectedDeliveryDate: Date
    var status: OrderStatus
    var unitPrice: Double
    var totalCost: Double
    @ServerTimestamp var createdAt: Date?

    static var empty: Order {
        Order(
            itemId: "", itemName: "", quantity: 0,
            supplierId: "", supplierName: "",
            orderDate: Date(), expectedDeliveryDate: Date(),
            status: .pending, unitPrice: 0, totalCost: 0
        )
    }
}

// MARK: - AI Prediction Types

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String
    let predictedQuantity: Double
    let confidence: Int
}

struct StockRecommendation: Identifiable {
    let id = UUID()
    let itemId: String
    let itemName: String
    let currentQuantity: Int
    let unit: String
    let daysUntilStockout: Int
    let recommendedOrderDate: Date
    let recommendedQuantity: Int
    let urgencyLevel: UrgencyLevel
    let message: String
}

struct PriceInsight: Identifiable {
    let id = UUID()
    let itemName: String
    let currentCost: Double
    let sellingPrice: Double
    let margin: Double
    let monthlyQuantity: Double
    let suggestion: String
}

struct WasteRisk: Identifiable {
    let id = UUID()
    let itemId: String
    let itemName: String
    let unit: String
    let daysUntilExpiry: Int
    let predictedWasteQuantity: Double
    let wastePercentage: Double
    let recommendation: String
}

struct ConsumptionInsight: Identifiable {
    let id = UUID()
    let itemId: String
    let itemName: String
    let dailyAverage: Double
    let weekdayAverage: Double
    let weekendAverage: Double
    let trendPercentage: Double
    let isAnomalous: Bool
}
