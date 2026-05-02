import SwiftUI

struct PredictionDashboardView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = PredictionViewModel()

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            Group {
                if dataService.inventoryItems.isEmpty {
                    EmptyStateView(
                        icon: "target",
                        title: "No Predictions Yet",
                        message: "Add inventory items and log daily consumption to see AI-powered demand forecasts, stock optimization, and waste predictions."
                    )
                } else {
                    predictionContent
                }
            }
        }
        .navigationTitle("Predictions")
        .onAppear {
            viewModel.refreshPredictions(
                items: dataService.inventoryItems,
                suppliers: dataService.suppliers
            )
        }
        .onChange(of: dataService.inventoryItems.count) { _ in
            viewModel.refreshPredictions(
                items: dataService.inventoryItems,
                suppliers: dataService.suppliers
            )
        }
    }

    private var predictionContent: some View {
        ScrollView {
            VStack(spacing: AppTheme.sectionSpacing) {
                // MARK: - Health Score
                healthScoreCard
                    .padding(.horizontal)

                // MARK: - Critical Alerts
                if !viewModel.criticalAlerts.isEmpty {
                    alertSection(
                        title: "Critical Alerts",
                        icon: "exclamationmark.octagon.fill",
                        color: AppTheme.error,
                        alerts: viewModel.criticalAlerts
                    )
                }

                // MARK: - Warning Alerts
                if !viewModel.warningAlerts.isEmpty {
                    alertSection(
                        title: "Warnings",
                        icon: "exclamationmark.triangle.fill",
                        color: AppTheme.warning,
                        alerts: viewModel.warningAlerts
                    )
                }

                // MARK: - Insights Navigation
                insightsSection

                // MARK: - Consumption Patterns
                if !viewModel.consumptionInsights.filter({ $0.dailyAverage > 0 }).isEmpty {
                    consumptionSection
                }

                Spacer().frame(height: 20)
            }
            .padding(.top)
        }
        .refreshable {
            viewModel.refreshPredictions(
                items: dataService.inventoryItems,
                suppliers: dataService.suppliers
            )
        }
    }

    // MARK: - Health Score Card
    private var healthScoreCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Inventory Health")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(healthMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.healthScore) / 100)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: viewModel.healthScore)

                    Text("\(viewModel.healthScore)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }

            HStack(spacing: 16) {
                statPill(icon: "exclamationmark.octagon", count: viewModel.criticalAlerts.count, label: "Critical", color: .red)
                statPill(icon: "exclamationmark.triangle", count: viewModel.warningAlerts.count, label: "Warnings", color: .yellow)
                statPill(icon: "checkmark.circle", count: viewModel.stockRecommendations.filter { $0.urgencyLevel == .normal }.count, label: "Healthy", color: .green)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: healthGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: healthGradient[0].opacity(0.3), radius: 8, y: 4)
    }

    private func statPill(icon: String, count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
        }
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.3))
        .cornerRadius(8)
    }

    private var healthGradient: [Color] {
        if viewModel.healthScore >= 80 {
            return [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.1, green: 0.5, blue: 0.3)]
        } else if viewModel.healthScore >= 50 {
            return [Color(red: 0.9, green: 0.7, blue: 0.1), Color(red: 0.8, green: 0.5, blue: 0.1)]
        }
        return [Color(red: 0.9, green: 0.3, blue: 0.2), Color(red: 0.7, green: 0.2, blue: 0.15)]
    }

    private var healthMessage: String {
        if viewModel.healthScore >= 80 { return "Your inventory is well-managed!" }
        if viewModel.healthScore >= 50 { return "Some items need attention." }
        return "Immediate action required!"
    }

    // MARK: - Alert Sections
    private func alertSection(title: String, icon: String, color: Color, alerts: [StockRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(alerts.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(alerts) { alert in
                        alertCard(alert, color: color)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func alertCard(_ alert: StockRecommendation, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(alert.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(alert.currentQuantity) \(alert.unit)")
                    .font(.caption.bold())
                    .foregroundColor(color)
            }

            Text(alert.message)
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
                .lineLimit(3)

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Order by")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(formatDate(alert.recommendedOrderDate))
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Suggest")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text("\(alert.recommendedQuantity) \(alert.unit)")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
        .padding()
        .frame(width: 260)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 4, y: 2)
    }

    // MARK: - Insights Section
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color.blue)
                Text("Insights")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                NavigationLink {
                    DemandForecastView()
                } label: {
                    insightRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Demand Forecast",
                        subtitle: "7-day demand predictions with confidence levels",
                        color: .blue
                    )
                }

                NavigationLink {
                    PriceOptimizationView()
                } label: {
                    insightRow(
                        icon: "indianrupeesign.circle",
                        title: "Price Optimization",
                        subtitle: "\(viewModel.priceInsights.filter { $0.margin < 20 }.count) items with low margins",
                        color: .green
                    )
                }

                NavigationLink {
                    WastePredictionView()
                } label: {
                    insightRow(
                        icon: "leaf.fill",
                        title: "Waste Prediction",
                        subtitle: "\(viewModel.wasteRisks.filter { $0.wastePercentage > 20 }.count) items at risk of waste",
                        color: .orange
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func insightRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppTheme.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - Consumption Patterns
    private var consumptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Consumption Patterns")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.consumptionInsights.filter { $0.dailyAverage > 0 }) { insight in
                        consumptionCard(insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func consumptionCard(_ insight: ConsumptionInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                if insight.isAnomalous {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppTheme.warning)
                        .font(.caption)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Daily Avg")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(String(format: "%.1f", insight.dailyAverage))
                        .font(.caption.bold())
                }
                VStack(alignment: .leading) {
                    Text("Weekday")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(String(format: "%.1f", insight.weekdayAverage))
                        .font(.caption.bold())
                }
                VStack(alignment: .leading) {
                    Text("Weekend")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(String(format: "%.1f", insight.weekendAverage))
                        .font(.caption.bold())
                }
            }

            if abs(insight.trendPercentage) > 0 {
                HStack {
                    Image(systemName: insight.trendPercentage > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(String(format: "%.1f", abs(insight.trendPercentage)))% \(insight.trendPercentage > 0 ? "increase" : "decrease")")
                        .font(.caption)
                }
                .foregroundColor(insight.trendPercentage > 0 ? AppTheme.error : AppTheme.success)
            }
        }
        .padding()
        .frame(width: 200)
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
