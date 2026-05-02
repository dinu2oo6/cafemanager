import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.sectionSpacing) {
                        greetingHeader
                        revenueCard
                        if !viewModel.criticalAlerts.isEmpty {
                            alertsSection
                        }
                        quickStatsGrid
                        if !viewModel.hourlyRevenue.isEmpty {
                            hourlyRevenueSection
                        }
                        if !viewModel.topSellingItems.isEmpty {
                            topItemsSection
                        }
                        if !viewModel.paymentBreakdown.isEmpty {
                            paymentSection
                        }
                        if !viewModel.lowStockItems.isEmpty {
                            lowStockSection
                        }
                        Spacer().frame(height: 20)
                    }
                    .padding(.top)
                }
                .refreshable {
                    viewModel.refresh(
                        sales: dataService.sales,
                        inventory: dataService.inventoryItems,
                        customers: dataService.customers
                    )
                }
            }
            .navigationTitle("Dashboard")
            .onAppear { refreshData() }
            .onChange(of: dataService.sales.count) { _ in refreshData() }
            .onChange(of: dataService.inventoryItems.count) { _ in refreshData() }
        }
    }

    private func refreshData() {
        viewModel.refresh(
            sales: dataService.sales,
            inventory: dataService.inventoryItems,
            customers: dataService.customers
        )
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.title2.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.secondary)
            }
            Spacer()
            Image(systemName: "cup.and.saucer.fill")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.primaryGradient)
        }
        .padding(.horizontal)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good Morning!" }
        if hour < 17 { return "Good Afternoon!" }
        return "Good Evening!"
    }

    // MARK: - Revenue Card

    private var revenueCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Revenue")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Text(currencyString(viewModel.todayRevenue))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.isOnTrack ? "arrow.up.right" : "arrow.down.right")
                        Text(viewModel.isOnTrack ? "On track" : "Below target")
                    }
                    .font(.caption.bold())
                    .foregroundColor(viewModel.isOnTrack ? .green.opacity(0.9) : .yellow)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Profit")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text(currencyString(viewModel.todayProfit))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("\(String(format: "%.1f", viewModel.profitMargin))% margin")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Target: \(currencyString(viewModel.revenueTarget))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int(viewModel.revenueProgress * 100))%")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * viewModel.revenueProgress, height: 8)
                            .animation(.easeInOut(duration: 0.6), value: viewModel.revenueProgress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal)
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(AppTheme.error)
                Text("Alerts")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(viewModel.criticalAlerts.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.error)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            ForEach(viewModel.criticalAlerts) { alert in
                alertRow(alert)
            }
            .padding(.horizontal)
        }
    }

    private func alertRow(_ alert: DashboardAlert) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(alert.type == .critical ? AppTheme.error : AppTheme.warning)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(
                    alert.type == .critical ? AppTheme.error.opacity(0.3) : AppTheme.warning.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Quick Stats Grid

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "cart.fill", title: "Orders", value: "\(viewModel.todayOrderCount)", color: .blue)
            statCard(icon: "person.2.fill", title: "Customers", value: "\(viewModel.todayCustomerCount)", color: .purple)
            statCard(icon: "indianrupeesign.circle", title: "Avg Order", value: currencyString(viewModel.averageOrderValue), color: .green)
            statCard(icon: "shippingbox.fill", title: "Low Stock", value: "\(viewModel.lowStockItems.count)", color: viewModel.lowStockItems.isEmpty ? .green : .orange)
        }
        .padding(.horizontal)
    }

    private func statCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
            }
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppTheme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Hourly Revenue

    private var hourlyRevenueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Hourly Revenue")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    let maxRevenue = viewModel.hourlyRevenue.map(\.revenue).max() ?? 1
                    ForEach(viewModel.hourlyRevenue) { data in
                        VStack(spacing: 4) {
                            if data.revenue > 0 {
                                Text(currencyString(data.revenue))
                                    .font(.system(size: 8))
                                    .foregroundColor(AppTheme.secondary)
                            }
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    data.revenue > 0
                                    ? AppTheme.primaryGradient
                                    : LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 28, height: max(4, CGFloat(data.revenue / maxRevenue) * 100))
                            Text(data.label)
                                .font(.system(size: 9))
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

    // MARK: - Top Selling Items

    private var topItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Top Selling Today")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(Array(viewModel.topSellingItems.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(rankColor(index))
                            .cornerRadius(6)
                        Text(item.name)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\(item.quantity) sold")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondary)
                        Text(currencyString(item.revenue))
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.primary)
                    }
                    .padding(.horizontal)
                    if index < viewModel.topSellingItems.count - 1 {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(AppTheme.cornerRadius)
            .padding(.horizontal)
        }
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return Color(red: 1, green: 0.84, blue: 0)
        case 1: return Color.gray
        case 2: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return AppTheme.secondary
        }
    }

    // MARK: - Payment Breakdown

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(.purple)
                Text("Payment Breakdown")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                ForEach(viewModel.paymentBreakdown) { item in
                    VStack(spacing: 8) {
                        Image(systemName: item.method.icon)
                            .font(.title3)
                            .foregroundColor(AppTheme.primary)
                        Text(currencyString(item.amount))
                            .font(.subheadline.bold())
                            .foregroundColor(AppTheme.textPrimary)
                        Text(item.method.rawValue)
                            .font(.caption)
                            .foregroundColor(AppTheme.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(AppTheme.cornerRadius)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Low Stock

    private var lowStockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Low Stock Items")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.lowStockItems.prefix(6)) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            HStack {
                                Text("\(item.quantity) \(item.unit)")
                                    .font(.caption.bold())
                                    .foregroundColor(item.quantity == 0 ? AppTheme.error : AppTheme.warning)
                                Spacer()
                                Text("Min: \(item.reorderLevel)")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.secondary)
                            }
                            ProgressView(value: item.stockLevelPercentage)
                                .tint(item.quantity == 0 ? AppTheme.error : AppTheme.warning)
                        }
                        .padding()
                        .frame(width: 160)
                        .background(Color.white)
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.warning.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Helpers

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}
