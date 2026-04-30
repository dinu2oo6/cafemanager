import SwiftUI

struct WastePredictionView: View {
    @EnvironmentObject var dataService: FirebaseDataService

    var wasteRisks: [WasteRisk] {
        WastePredictor.predictAll(items: dataService.inventoryItems)
    }

    var itemsWithoutExpiry: [InventoryItem] {
        dataService.inventoryItems.filter { $0.expiryDate == nil }
    }

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            Group {
                if wasteRisks.isEmpty && itemsWithoutExpiry.isEmpty {
                    EmptyStateView(
                        icon: "leaf",
                        title: "No Waste Data",
                        message: "Set expiry dates on your inventory items to get waste predictions and reduction recommendations."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: AppTheme.sectionSpacing) {
                            // Summary
                            if !wasteRisks.isEmpty {
                                summaryCard
                                    .padding(.horizontal)
                            }

                            // Waste Risk Items
                            if !wasteRisks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Items at Risk")
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .padding(.horizontal)

                                    ForEach(wasteRisks) { risk in
                                        wasteCard(risk)
                                            .padding(.horizontal)
                                    }
                                }
                            }

                            // Items without expiry
                            if !itemsWithoutExpiry.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(Color.blue)
                                        Text("No Expiry Set (\(itemsWithoutExpiry.count) items)")
                                            .font(.headline)
                                            .foregroundColor(AppTheme.textPrimary)
                                    }
                                    .padding(.horizontal)

                                    ForEach(itemsWithoutExpiry) { item in
                                        HStack {
                                            Text(item.name)
                                                .font(.subheadline)
                                                .foregroundColor(AppTheme.textPrimary)
                                            Spacer()
                                            Text("\(item.quantity) \(item.unit)")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.secondary)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(AppTheme.cornerRadius)
                                        .padding(.horizontal)
                                    }
                                }
                            }

                            Spacer().frame(height: 20)
                        }
                        .padding(.top)
                    }
                }
            }
        }
        .navigationTitle("Waste Prediction")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        let highRisk = wasteRisks.filter { $0.wastePercentage > 50 }.count
        let mediumRisk = wasteRisks.filter { $0.wastePercentage > 20 && $0.wastePercentage <= 50 }.count
        let lowRisk = wasteRisks.filter { $0.wastePercentage > 0 && $0.wastePercentage <= 20 }.count
        let safe = wasteRisks.filter { $0.wastePercentage == 0 }.count

        return VStack(spacing: 12) {
            HStack {
                Text("Waste Risk Overview")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 12) {
                riskPill(count: highRisk, label: "High", color: .red)
                riskPill(count: mediumRisk, label: "Medium", color: .orange)
                riskPill(count: lowRisk, label: "Low", color: .yellow)
                riskPill(count: safe, label: "Safe", color: .green)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: Color.orange.opacity(0.2), radius: 6, y: 3)
    }

    private func riskPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.3))
        .cornerRadius(8)
    }

    private func wasteCard(_ risk: WasteRisk) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(risk.itemName)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                riskBadge(risk.wastePercentage)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Expires In")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text(risk.daysUntilExpiry == 0 ? "EXPIRED" : "\(risk.daysUntilExpiry) days")
                        .font(.caption.bold())
                        .foregroundColor(risk.daysUntilExpiry <= 3 ? AppTheme.error : AppTheme.textPrimary)
                }

                VStack(alignment: .leading) {
                    Text("Will Waste")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondary)
                    Text("\(Int(risk.predictedWasteQuantity)) \(risk.unit)")
                        .font(.caption.bold())
                        .foregroundColor(risk.predictedWasteQuantity > 0 ? AppTheme.error : AppTheme.success)
                }
            }

            // Waste bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(wasteColor(risk.wastePercentage))
                        .frame(width: geo.size.width * min(1, risk.wastePercentage / 100), height: 6)
                }
            }
            .frame(height: 6)

            Text(risk.recommendation)
                .font(.caption)
                .foregroundColor(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(wasteColor(risk.wastePercentage).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    private func riskBadge(_ percentage: Double) -> some View {
        Text("\(Int(percentage))% risk")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(wasteColor(percentage))
            .cornerRadius(6)
    }

    private func wasteColor(_ percentage: Double) -> Color {
        if percentage > 50 { return AppTheme.error }
        if percentage > 20 { return AppTheme.warning }
        if percentage > 0 { return Color.yellow }
        return AppTheme.success
    }
}
