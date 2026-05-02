import Foundation

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var todayRevenue: Double = 0
    @Published var todayProfit: Double = 0
    @Published var todayOrderCount: Int = 0
    @Published var todayCustomerCount: Int = 0
    @Published var revenueTarget: Double = 15000
    @Published var profitMargin: Double = 0
    @Published var averageOrderValue: Double = 0

    @Published var lowStockItems: [InventoryItem] = []
    @Published var expiringItems: [InventoryItem] = []
    @Published var criticalAlerts: [DashboardAlert] = []
    @Published var recentSales: [SaleTransaction] = []

    @Published var hourlyRevenue: [HourlyData] = []
    @Published var topSellingItems: [TopItem] = []
    @Published var paymentBreakdown: [PaymentBreakdownItem] = []

    func refresh(sales: [SaleTransaction], inventory: [InventoryItem], customers: [Customer]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let todaySales = sales.filter { $0.date >= startOfDay }

        todayRevenue = todaySales.reduce(0) { $0 + $1.totalAmount }
        todayProfit = todaySales.reduce(0) { $0 + $1.grossProfit }
        todayOrderCount = todaySales.count
        averageOrderValue = todayOrderCount > 0 ? todayRevenue / Double(todayOrderCount) : 0
        profitMargin = todayRevenue > 0 ? (todayProfit / todayRevenue) * 100 : 0

        let uniqueCustomerIds = Set(todaySales.compactMap { $0.customerId })
        todayCustomerCount = max(uniqueCustomerIds.count, todayOrderCount)

        lowStockItems = inventory.filter { $0.isLow }.sorted { $0.quantity < $1.quantity }
        expiringItems = inventory.filter { item in
            guard let expiry = item.expiryDate else { return false }
            let hoursUntilExpiry = calendar.dateComponents([.hour], from: Date(), to: expiry).hour ?? 999
            return hoursUntilExpiry <= 24 && hoursUntilExpiry > 0
        }

        recentSales = Array(todaySales.prefix(5))

        buildAlerts(inventory: inventory)
        buildHourlyRevenue(sales: todaySales)
        buildTopItems(sales: todaySales)
        buildPaymentBreakdown(sales: todaySales)
    }

    private func buildAlerts(inventory: [InventoryItem]) {
        var alerts: [DashboardAlert] = []

        for item in lowStockItems.prefix(3) {
            alerts.append(DashboardAlert(
                type: item.quantity == 0 ? .critical : .warning,
                title: item.quantity == 0 ? "\(item.name) out of stock" : "\(item.name) low stock",
                message: "\(item.quantity) \(item.unit) remaining (reorder level: \(item.reorderLevel))",
                action: "Reorder Now"
            ))
        }

        for item in expiringItems.prefix(2) {
            if let expiry = item.expiryDate {
                let hours = Calendar.current.dateComponents([.hour], from: Date(), to: expiry).hour ?? 0
                alerts.append(DashboardAlert(
                    type: hours <= 4 ? .critical : .warning,
                    title: "\(item.name) expiring soon",
                    message: "Expires in \(hours) hours — \(item.quantity) \(item.unit) at risk",
                    action: "Apply Discount"
                ))
            }
        }

        criticalAlerts = alerts
    }

    private func buildHourlyRevenue(sales: [SaleTransaction]) {
        let calendar = Calendar.current
        var hourMap: [Int: Double] = [:]
        for sale in sales {
            let hour = calendar.component(.hour, from: sale.date)
            hourMap[hour, default: 0] += sale.totalAmount
        }
        let currentHour = calendar.component(.hour, from: Date())
        hourlyRevenue = (6...max(currentHour, 6)).map { hour in
            HourlyData(hour: hour, revenue: hourMap[hour] ?? 0)
        }
    }

    private func buildTopItems(sales: [SaleTransaction]) {
        var itemCounts: [String: (count: Int, revenue: Double)] = [:]
        for sale in sales {
            for item in sale.items {
                let existing = itemCounts[item.itemName] ?? (0, 0)
                itemCounts[item.itemName] = (existing.count + item.quantity, existing.revenue + item.totalPrice)
            }
        }
        topSellingItems = itemCounts.map { TopItem(name: $0.key, quantity: $0.value.count, revenue: $0.value.revenue) }
            .sorted { $0.revenue > $1.revenue }
            .prefix(5)
            .map { $0 }
    }

    private func buildPaymentBreakdown(sales: [SaleTransaction]) {
        var methodTotals: [PaymentMethod: Double] = [:]
        for sale in sales {
            methodTotals[sale.paymentMethod, default: 0] += sale.totalAmount
        }
        paymentBreakdown = methodTotals.map { PaymentBreakdownItem(method: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    var revenueProgress: Double {
        guard revenueTarget > 0 else { return 0 }
        return min(todayRevenue / revenueTarget, 1.0)
    }

    var isOnTrack: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let hoursOpen = max(Double(hour - 6), 1)
        let totalHours: Double = 16
        let expectedProgress = hoursOpen / totalHours
        return revenueProgress >= expectedProgress * 0.8
    }
}

struct DashboardAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let title: String
    let message: String
    let action: String

    enum AlertType {
        case critical, warning, info
    }
}

struct HourlyData: Identifiable {
    let id = UUID()
    let hour: Int
    let revenue: Double

    var label: String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(displayHour)\(period)"
    }
}

struct TopItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let revenue: Double
}

struct PaymentBreakdownItem: Identifiable {
    let id = UUID()
    let method: PaymentMethod
    let amount: Double
}
