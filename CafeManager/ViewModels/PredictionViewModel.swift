import Foundation

@MainActor
class PredictionViewModel: ObservableObject {
    @Published var stockRecommendations: [StockRecommendation] = []
    @Published var wasteRisks: [WasteRisk] = []
    @Published var priceInsights: [PriceInsight] = []
    @Published var consumptionInsights: [ConsumptionInsight] = []
    @Published var demandForecasts: [String: [DailyForecast]] = [:]
    @Published var healthScore: Int = 100
    @Published var isRefreshing = false

    var criticalAlerts: [StockRecommendation] {
        stockRecommendations.filter { $0.urgencyLevel == .critical }
    }

    var warningAlerts: [StockRecommendation] {
        stockRecommendations.filter { $0.urgencyLevel == .warning }
    }

    var healthColor: String {
        if healthScore >= 80 { return "green" }
        if healthScore >= 50 { return "yellow" }
        return "red"
    }

    func refreshPredictions(items: [InventoryItem], suppliers: [Supplier]) {
        isRefreshing = true

        stockRecommendations = StockOptimizer.analyzeAll(items: items, suppliers: suppliers)
        wasteRisks = WastePredictor.predictAll(items: items)
        priceInsights = PriceAnalyzer.analyze(items: items, suppliers: suppliers)
        consumptionInsights = items.map { ConsumptionAnalyzer.analyze(item: $0) }

        demandForecasts = Dictionary(uniqueKeysWithValues:
            items.compactMap { item -> (String, [DailyForecast])? in
                guard let id = item.id else { return nil }
                let forecasts = DemandForecaster.forecast(item: item)
                return forecasts.isEmpty ? nil : (id, forecasts)
            }
        )

        calculateHealthScore()
        isRefreshing = false
    }

    private func calculateHealthScore() {
        var score = 100
        score -= criticalAlerts.count * 15
        score -= warningAlerts.count * 5
        score -= wasteRisks.filter { $0.wastePercentage > 20 }.count * 10
        score -= priceInsights.filter { $0.margin < 0 }.count * 10
        healthScore = max(0, min(100, score))
    }
}
