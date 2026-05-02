import Foundation
import FirebaseFirestore

// MARK: - Enums

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case ordered = "Ordered"
    case delivered = "Delivered"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

enum UrgencyLevel: String, Codable, CaseIterable {
    case critical = "Critical"
    case warning = "Warning"
    case normal = "Normal"
}

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case dairy = "Dairy"
    case beverages = "Beverages"
    case sweeteners = "Sweeteners"
    case dryGoods = "Dry Goods"
    case bakery = "Bakery"
    case produce = "Produce"
    case snacks = "Snacks"
    case packaging = "Packaging"
    case cleaning = "Cleaning"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dairy: return "drop.fill"
        case .beverages: return "cup.and.saucer.fill"
        case .sweeteners: return "cube.fill"
        case .dryGoods: return "leaf.fill"
        case .bakery: return "birthday.cake.fill"
        case .produce: return "carrot.fill"
        case .snacks: return "popcorn.fill"
        case .packaging: return "shippingbox.fill"
        case .cleaning: return "sparkles"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var skuPrefix: String {
        switch self {
        case .dairy: return "DRY"
        case .beverages: return "BEV"
        case .sweeteners: return "SWT"
        case .dryGoods: return "DRG"
        case .bakery: return "BAK"
        case .produce: return "PRD"
        case .snacks: return "SNK"
        case .packaging: return "PKG"
        case .cleaning: return "CLN"
        case .other: return "OTH"
        }
    }
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
    var sku: String?
    var name: String
    var brand: String?
    var category: ItemCategory?
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

    var displayName: String {
        if let brand, !brand.isEmpty {
            return "\(name) (\(brand))"
        }
        return name
    }

    var skuDisplay: String {
        sku ?? "—"
    }

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
            sku: nil, name: "", brand: nil, category: nil,
            quantity: 0, unit: "kg", reorderLevel: 10,
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

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case card = "Card"
    case upi = "UPI"
    case wallet = "Wallet"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cash: return "banknote"
        case .card: return "creditcard"
        case .upi: return "qrcode"
        case .wallet: return "wallet.pass"
        }
    }
}

// MARK: - Sale Item

struct SaleItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var itemId: String
    var itemName: String
    var itemSKU: String?
    var itemBrand: String?
    var quantity: Int
    var unitPrice: Double
    var costPrice: Double

    var totalPrice: Double { unitPrice * Double(quantity) }
    var totalCost: Double { costPrice * Double(quantity) }
    var profit: Double { totalPrice - totalCost }

    var displayName: String {
        if let itemBrand, !itemBrand.isEmpty {
            return "\(itemName) (\(itemBrand))"
        }
        return itemName
    }
}

// MARK: - Sale Transaction

struct SaleTransaction: Identifiable, Codable {
    @DocumentID var id: String?
    var items: [SaleItem]
    var subtotal: Double
    var discount: Double
    var totalAmount: Double
    var paymentMethod: PaymentMethod
    var customerName: String?
    var customerId: String?
    var notes: String?
    var date: Date
    @ServerTimestamp var createdAt: Date?

    var totalCOGS: Double {
        items.reduce(0) { $0 + $1.totalCost }
    }

    var grossProfit: Double {
        totalAmount - totalCOGS
    }

    var itemCount: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    static var empty: SaleTransaction {
        SaleTransaction(
            items: [], subtotal: 0, discount: 0,
            totalAmount: 0, paymentMethod: .cash,
            date: Date()
        )
    }
}

// MARK: - Loyalty Tier

enum LoyaltyTier: String, Codable, CaseIterable, Identifiable {
    case gold = "Gold"
    case silver = "Silver"
    case bronze = "Bronze"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gold: return "crown.fill"
        case .silver: return "star.fill"
        case .bronze: return "star.leadinghalf.filled"
        }
    }

    var color: String {
        switch self {
        case .gold: return "gold"
        case .silver: return "silver"
        case .bronze: return "bronze"
        }
    }

    var discountPercentage: Double {
        switch self {
        case .gold: return 15
        case .silver: return 10
        case .bronze: return 0
        }
    }
}

// MARK: - Customer

struct Customer: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var phone: String
    var totalSpent: Double
    var visitCount: Int
    var lastVisitDate: Date?
    var favoriteItems: [String]
    var notes: String?
    @ServerTimestamp var createdAt: Date?

    var loyaltyTier: LoyaltyTier {
        if visitCount > 50 && totalSpent > 5000 { return .gold }
        if visitCount > 20 && totalSpent > 1500 { return .silver }
        return .bronze
    }

    var averageOrderValue: Double {
        guard visitCount > 0 else { return 0 }
        return totalSpent / Double(visitCount)
    }

    var daysSinceLastVisit: Int? {
        guard let lastVisit = lastVisitDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastVisit, to: Date()).day
    }

    var isChurnRisk: Bool {
        guard let days = daysSinceLastVisit else { return false }
        return days > 14
    }

    static var empty: Customer {
        Customer(
            name: "", email: "", phone: "",
            totalSpent: 0, visitCount: 0,
            favoriteItems: []
        )
    }
}

// MARK: - Recipe Category

enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case hotBeverages = "Hot Beverages"
    case coldBeverages = "Cold Beverages"
    case snacks = "Snacks"
    case desserts = "Desserts"
    case meals = "Meals"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .hotBeverages: return "cup.and.saucer.fill"
        case .coldBeverages: return "mug.fill"
        case .snacks: return "popcorn.fill"
        case .desserts: return "birthday.cake.fill"
        case .meals: return "fork.knife"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Recipe Ingredient

struct RecipeIngredient: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var inventoryItemId: String
    var itemName: String
    var quantity: Double
    var unit: String
}

// MARK: - Recipe

struct Recipe: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: RecipeCategory
    var ingredients: [RecipeIngredient]
    var sellingPrice: Double
    var servingSize: String
    var preparationTime: Int
    var notes: String?
    @ServerTimestamp var createdAt: Date?

    static var empty: Recipe {
        Recipe(
            name: "", category: .hotBeverages,
            ingredients: [], sellingPrice: 0,
            servingSize: "1 cup", preparationTime: 5
        )
    }
}

// MARK: - Product Cost Analysis Types

struct ProductCostBreakdown: Identifiable {
    let id = UUID()
    let recipeName: String
    let ingredients: [IngredientCostDetail]
    let totalIngredientCost: Double
    let sellingPrice: Double
    let profitPerServing: Double
    let marginPercentage: Double
    let suggestions: [CostSuggestion]
    let wasteFactor: Double
    let trueProductionCost: Double
}

struct IngredientCostDetail: Identifiable {
    let id = UUID()
    let ingredientName: String
    let quantityNeeded: Double
    let unit: String
    let costPerUnit: Double
    let totalCost: Double
    let costPercentage: Double
    let stockAvailable: Int
    let servingsAvailable: Int
}

enum SuggestionType: String, Codable {
    case substitution = "Substitution"
    case portionOptimize = "Portion Optimize"
    case bulkBuying = "Bulk Buying"
    case marginAlert = "Margin Alert"
    case wasteReduction = "Waste Reduction"
    case priceAdjustment = "Price Adjustment"
    case seasonal = "Seasonal"

    var icon: String {
        switch self {
        case .substitution: return "arrow.triangle.2.circlepath"
        case .portionOptimize: return "slider.horizontal.3"
        case .bulkBuying: return "shippingbox.fill"
        case .marginAlert: return "exclamationmark.triangle.fill"
        case .wasteReduction: return "trash.slash.fill"
        case .priceAdjustment: return "tag.fill"
        case .seasonal: return "leaf.fill"
        }
    }

    var color: String {
        switch self {
        case .substitution: return "blue"
        case .portionOptimize: return "purple"
        case .bulkBuying: return "teal"
        case .marginAlert: return "red"
        case .wasteReduction: return "orange"
        case .priceAdjustment: return "green"
        case .seasonal: return "mint"
        }
    }
}

struct CostSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let detail: String
    let potentialSaving: Double
}

struct MenuProfitabilityItem: Identifiable {
    let id = UUID()
    let recipeName: String
    let category: String
    let totalCost: Double
    let sellingPrice: Double
    let margin: Double
    let monthlySales: Int
    let monthlyProfit: Double
    let rank: Int
}

struct WhatIfScenario: Identifiable {
    let id = UUID()
    let ingredientName: String
    let currentCost: Double
    let newCost: Double
    let priceChangePercent: Double
    let affectedRecipes: [WhatIfRecipeImpact]
}

struct WhatIfRecipeImpact: Identifiable {
    let id = UUID()
    let recipeName: String
    let oldCost: Double
    let newCost: Double
    let oldMargin: Double
    let newMargin: Double
    let monthlyProfitImpact: Double
}

// MARK: - Staff Role

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case manager = "Manager"
    case barista = "Barista"
    case cashier = "Cashier"
    case chef = "Chef"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .manager: return "person.badge.key"
        case .barista: return "cup.and.saucer.fill"
        case .cashier: return "banknote"
        case .chef: return "frying.pan"
        }
    }
}

// MARK: - Staff Member

struct StaffMember: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var role: StaffRole
    var email: String
    var phone: String
    var ordersCompleted: Int
    var revenueGenerated: Double
    var shiftStart: Date?
    var shiftEnd: Date?
    var isOnDuty: Bool
    @ServerTimestamp var createdAt: Date?

    var efficiency: Double {
        guard ordersCompleted > 0 else { return 0 }
        return revenueGenerated / Double(ordersCompleted)
    }

    static var empty: StaffMember {
        StaffMember(
            name: "", role: .barista, email: "", phone: "",
            ordersCompleted: 0, revenueGenerated: 0, isOnDuty: false
        )
    }
}
