import SwiftUI

struct PriceOptimizationView: View {
    @EnvironmentObject var dataService: FirebaseDataService

    var priceInsights: [PriceInsight] {
        PriceAnalyzer.analyze(items: dataService.inventoryItems, suppliers: dataService.suppliers)
            .sorted { $0.margin < $1.margin }
    }

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            Group {
                if priceInsights.isEmpty {
                    EmptyStateView(
                        icon: "indianrupeesign.circle",
                        title: "No Price Data",
                        message: "Add inventory items with cost and selling prices to see margin analysis and optimization suggestions."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.sectionSpacing) {
                            // Summary
                            summaryCard
                                .padding(.horizontal)

                            // Items
                            ForEach(priceInsights) { insight in
                                priceCard(insight)
                                    .padding(.horizontal)
                            }

                            Spacer().frame(height: 20)
                        }
                        .padding(.top)
                    }
                }
            }
        }
        .navigationTitle("Price Optimization")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Margin Overview")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 16) {
                VStack {
                    Text("\(priceInsights.filter { $0.margin < 0 }.count)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("At Loss")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(priceInsights.filter { $0.margin >= 0 && $0.margin < 20 }.count)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Low Margin")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)

                VStack {
                    Text("\(priceInsights.filter { $0.margin >= 20 }.count)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Healthy")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.6, blue: 0.4), Color(red: 0.05, green: 0.4, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.green.opacity(0.2), radius: 6, y: 3)
    }

    private func priceCard(_ insight: PriceInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(insight.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                marginBadge(insight.margin)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Cost")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text("\u{20B9}\(String(format: "%.0f", insight.currentCost))")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.error)
                }

                VStack(alignment: .leading) {
                    Text("Selling")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text("\u{20B9}\(String(format: "%.0f", insight.sellingPrice))")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.success)
                }

                VStack(alignment: .leading) {
                    Text("Monthly Qty")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(String(format: "%.0f", insight.monthlyQuantity))
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.primary)
                }
            }

            // Margin bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(marginColor(insight.margin))
                        .frame(width: geo.size.width * max(0, min(1, insight.margin / 100)), height: 6)
                }
            }
            .frame(height: 6)

            Text(insight.suggestion)
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(marginColor(insight.margin).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    private func marginBadge(_ margin: Double) -> some View {
        Text("\(String(format: "%.0f", margin))%")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(marginColor(margin))
            .cornerRadius(6)
    }

    private func marginColor(_ margin: Double) -> Color {
        if margin < 0 { return AppTheme.error }
        if margin < 20 { return AppTheme.warning }
        if margin < 40 { return Color.blue }
        return AppTheme.success
    }
}
