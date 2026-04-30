import SwiftUI

struct DemandForecastView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @State private var selectedItemId: String = ""

    var selectedItem: InventoryItem? {
        dataService.inventoryItems.first { $0.id == selectedItemId }
    }

    var forecasts: [DailyForecast] {
        guard let item = selectedItem else { return [] }
        return DemandForecaster.forecast(item: item)
    }

    var consumptionInsight: ConsumptionInsight? {
        guard let item = selectedItem else { return nil }
        return ConsumptionAnalyzer.analyze(item: item)
    }

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    // MARK: - Item Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Item")
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.secondary)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(dataService.inventoryItems.filter { !$0.dailyConsumption.isEmpty }) { item in
                                    Button {
                                        selectedItemId = item.id ?? ""
                                    } label: {
                                        Text(item.name)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedItemId == item.id ? AppTheme.primary : Color.white)
                                            .foregroundColor(selectedItemId == item.id ? .white : AppTheme.primary)
                                            .cornerRadius(16)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(AppTheme.primary.opacity(0.3), lineWidth: selectedItemId == item.id ? 0 : 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    if forecasts.isEmpty {
                        EmptyStateView(
                            icon: "chart.line.uptrend.xyaxis",
                            title: selectedItemId.isEmpty ? "Select an Item" : "No Forecast Data",
                            message: selectedItemId.isEmpty
                                ? "Choose an item above to see its 7-day demand forecast."
                                : "This item needs consumption data. Log daily usage to generate forecasts."
                        )
                        .frame(height: 300)
                    } else {
                        // MARK: - Summary Card
                        if let insight = consumptionInsight {
                            summaryCard(insight)
                                .padding(.horizontal)
                        }

                        // MARK: - 7-Day Forecast
                        VStack(alignment: .leading, spacing: 8) {
                            Text("7-Day Forecast")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(.horizontal)

                            ForEach(forecasts) { forecast in
                                forecastRow(forecast)
                                    .padding(.horizontal)
                            }
                        }

                        // MARK: - Total Forecast
                        let totalDemand = forecasts.reduce(0) { $0 + $1.predictedQuantity }
                        HStack {
                            Text("Total Forecasted Demand")
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text(String(format: "%.1f %@", totalDemand, selectedItem?.unit ?? ""))
                                .font(.headline)
                                .foregroundColor(AppTheme.primary)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(AppTheme.cornerRadius)
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.top)
            }
        }
        .navigationTitle("Demand Forecast")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedItemId.isEmpty,
               let first = dataService.inventoryItems.first(where: { !$0.dailyConsumption.isEmpty }) {
                selectedItemId = first.id ?? ""
            }
        }
    }

    private func summaryCard(_ insight: ConsumptionInsight) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(insight.itemName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if abs(insight.trendPercentage) > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: insight.trendPercentage > 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(String(format: "%.1f", abs(insight.trendPercentage)))%")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
            }

            HStack(spacing: 20) {
                VStack {
                    Text(String(format: "%.1f", insight.dailyAverage))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Daily Avg")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }

                Divider().frame(height: 30).background(Color.white.opacity(0.3))

                VStack {
                    Text(String(format: "%.1f", insight.weekdayAverage))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Weekday")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }

                Divider().frame(height: 30).background(Color.white.opacity(0.3))

                VStack {
                    Text(String(format: "%.1f", insight.weekendAverage))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text("Weekend")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.blue.opacity(0.2), radius: 6, y: 3)
    }

    private func forecastRow(_ forecast: DailyForecast) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.dayName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Text(formatDate(forecast.date))
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondary)
            }

            Spacer()

            // Predicted quantity
            Text(String(format: "%.1f %@", forecast.predictedQuantity, selectedItem?.unit ?? ""))
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.primary)

            Spacer().frame(width: 12)

            // Confidence badge
            Text("\(forecast.confidence)%")
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor(forecast.confidence))
                .cornerRadius(6)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    private func confidenceColor(_ confidence: Int) -> Color {
        if confidence >= 80 { return AppTheme.success }
        if confidence >= 60 { return AppTheme.warning }
        return AppTheme.error
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
