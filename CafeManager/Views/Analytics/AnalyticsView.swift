import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @State private var selectedPeriod: AnalyticsPeriod = .week

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    periodPicker
                    overviewCards
                    revenueChart
                    itemPerformance
                    marginAnalysis
                    wasteOverview
                    customerMetrics
                    Spacer().frame(height: 20)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Analytics")
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        let data = computeOverview()
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            overviewCard(icon: "indianrupeesign.circle.fill", title: "Revenue", value: currencyString(data.revenue), trend: data.revenueTrend, color: AppTheme.primary)
            overviewCard(icon: "chart.line.uptrend.xyaxis", title: "Profit", value: currencyString(data.profit), trend: data.profitTrend, color: AppTheme.success)
            overviewCard(icon: "cart.fill", title: "Orders", value: "\(data.orderCount)", trend: data.orderTrend, color: .blue)
            overviewCard(icon: "leaf.fill", title: "Waste Value", value: currencyString(data.wasteValue), trend: nil, color: .orange)
        }
        .padding(.horizontal)
    }

    private func overviewCard(icon: String, title: String, value: String, trend: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
                if let trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(String(format: "%.1f", abs(trend)))%")
                            .font(.caption2)
                    }
                    .foregroundColor(trend >= 0 ? AppTheme.success : AppTheme.error)
                }
            }
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Revenue Chart

    private var revenueChart: some View {
        let daily = computeDailyRevenue()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Revenue Trend")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            if daily.isEmpty {
                Text("No sales data for this period")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 6) {
                        let maxVal = daily.map(\.value).max() ?? 1
                        ForEach(daily, id: \.label) { entry in
                            VStack(spacing: 4) {
                                Text(currencyString(entry.value))
                                    .font(.system(size: 8))
                                    .foregroundColor(AppTheme.secondary)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppTheme.primaryGradient)
                                    .frame(width: 24, height: max(4, CGFloat(entry.value / maxVal) * 100))
                                Text(entry.label)
                                    .font(.system(size: 8))
                                    .foregroundColor(AppTheme.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(minHeight: 140, alignment: .bottom)
                }
                .background(Color.white)
                .cornerRadius(AppTheme.cornerRadius)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Item Performance

    private var itemPerformance: some View {
        let items = computeItemPerformance()
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.orange)
                Text("Item Performance")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            if items.isEmpty {
                Text("No sales data")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(8).enumerated()), id: \.element.name) { index, item in
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(item.quantity) sold")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondary)
                            Text(currencyString(item.revenue))
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if index < min(items.count, 8) - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(AppTheme.cornerRadius)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Margin Analysis

    private var marginAnalysis: some View {
        let insights = PriceAnalyzer.analyze(items: dataService.inventoryItems, suppliers: dataService.suppliers)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.green)
                Text("Margin Analysis")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            if insights.isEmpty {
                Text("Add inventory items with pricing to see margin analysis")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(insights.sorted(by: { $0.margin > $1.margin }).prefix(6)) { insight in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(insight.itemName)
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                HStack {
                                    Text("Cost: \(currencyString(insight.currentCost))")
                                        .font(.caption)
                                    Spacer()
                                    Text("Sell: \(currencyString(insight.sellingPrice))")
                                        .font(.caption)
                                }
                                .foregroundColor(AppTheme.secondary)
                                HStack {
                                    Text("\(String(format: "%.1f", insight.margin))%")
                                        .font(.title3.bold())
                                        .foregroundColor(insight.margin >= 40 ? AppTheme.success : (insight.margin >= 20 ? AppTheme.warning : AppTheme.error))
                                    Spacer()
                                }
                                Text(insight.suggestion)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.secondary)
                                    .lineLimit(2)
                            }
                            .padding()
                            .frame(width: 180)
                            .background(Color.white)
                            .cornerRadius(AppTheme.cornerRadius)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Waste Overview

    private var wasteOverview: some View {
        let wasteItems = dataService.inventoryItems.filter { !$0.wasteRecord.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.orange)
                Text("Waste Summary")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            if wasteItems.isEmpty {
                Text("No waste recorded")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(wasteItems) { item in
                            let totalWaste = item.wasteRecord.reduce(0) { $0 + $1.quantity }
                            let wasteValue = Double(totalWaste) * item.costPrice
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.textPrimary)
                                HStack {
                                    Text("\(totalWaste) \(item.unit)")
                                        .font(.caption.bold())
                                        .foregroundColor(AppTheme.error)
                                    Spacer()
                                    Text(currencyString(wasteValue) + " lost")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.error)
                                }
                                Text("\(item.wasteRecord.count) events")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.secondary)
                            }
                            .padding()
                            .frame(width: 170)
                            .background(Color.white)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.error.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Customer Metrics

    private var customerMetrics: some View {
        let customers = dataService.customers
        let gold = customers.filter { $0.loyaltyTier == .gold }.count
        let silver = customers.filter { $0.loyaltyTier == .silver }.count
        let bronze = customers.filter { $0.loyaltyTier == .bronze }.count
        let churnRisk = customers.filter { $0.isChurnRisk }.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("Customer Metrics")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                metricPill(label: "Total", value: "\(customers.count)", color: .blue)
                metricPill(label: "Gold", value: "\(gold)", color: Color(red: 1, green: 0.84, blue: 0))
                metricPill(label: "Silver", value: "\(silver)", color: .gray)
                metricPill(label: "Bronze", value: "\(bronze)", color: Color(red: 0.8, green: 0.5, blue: 0.2))
                metricPill(label: "At Risk", value: "\(churnRisk)", color: .red)
            }
            .padding(.horizontal)
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Computations

    private func periodSales() -> [SaleTransaction] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        switch selectedPeriod {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        }
        return dataService.sales.filter { $0.date >= startDate }
    }

    private func previousPeriodSales() -> [SaleTransaction] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date
        switch selectedPeriod {
        case .today:
            endDate = calendar.startOfDay(for: now)
            startDate = calendar.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            endDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            startDate = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        case .month:
            endDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            startDate = calendar.date(byAdding: .month, value: -2, to: now) ?? now
        }
        return dataService.sales.filter { $0.date >= startDate && $0.date < endDate }
    }

    private func computeOverview() -> OverviewData {
        let current = periodSales()
        let previous = previousPeriodSales()

        let revenue = current.reduce(0) { $0 + $1.totalAmount }
        let prevRevenue = previous.reduce(0) { $0 + $1.totalAmount }
        let profit = current.reduce(0) { $0 + $1.grossProfit }
        let prevProfit = previous.reduce(0) { $0 + $1.grossProfit }

        let wasteValue = dataService.inventoryItems.reduce(0.0) { total, item in
            total + item.wasteRecord.reduce(0.0) { $0 + Double($1.quantity) * item.costPrice }
        }

        return OverviewData(
            revenue: revenue,
            revenueTrend: prevRevenue > 0 ? ((revenue - prevRevenue) / prevRevenue) * 100 : 0,
            profit: profit,
            profitTrend: prevProfit > 0 ? ((profit - prevProfit) / prevProfit) * 100 : 0,
            orderCount: current.count,
            orderTrend: previous.count > 0 ? (Double(current.count - previous.count) / Double(previous.count)) * 100 : 0,
            wasteValue: wasteValue
        )
    }

    private func computeDailyRevenue() -> [(label: String, value: Double)] {
        let sales = periodSales()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = selectedPeriod == .today ? "ha" : "d MMM"

        var grouped: [String: Double] = [:]
        var order: [String] = []

        for sale in sales {
            let key: String
            if selectedPeriod == .today {
                let hour = calendar.component(.hour, from: sale.date)
                key = "\(hour > 12 ? hour - 12 : hour)\(hour >= 12 ? "PM" : "AM")"
            } else {
                key = formatter.string(from: sale.date)
            }
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: 0] += sale.totalAmount
        }

        return order.map { (label: $0, value: grouped[$0] ?? 0) }
    }

    private func computeItemPerformance() -> [(name: String, quantity: Int, revenue: Double)] {
        let sales = periodSales()
        var items: [String: (quantity: Int, revenue: Double)] = [:]
        for sale in sales {
            for item in sale.items {
                let existing = items[item.itemName] ?? (0, 0)
                items[item.itemName] = (existing.quantity + item.quantity, existing.revenue + item.totalPrice)
            }
        }
        return items.map { (name: $0.key, quantity: $0.value.quantity, revenue: $0.value.revenue) }
            .sorted { $0.revenue > $1.revenue }
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}

private struct OverviewData {
    let revenue: Double
    let revenueTrend: Double
    let profit: Double
    let profitTrend: Double
    let orderCount: Int
    let orderTrend: Double
    let wasteValue: Double
}
