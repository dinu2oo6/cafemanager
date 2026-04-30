import Foundation

struct DemandForecaster {
    static func forecast(item: InventoryItem, days: Int = 7) -> [DailyForecast] {
        let consumption = item.dailyConsumption
        guard !consumption.isEmpty else { return [] }

        let weekdayPattern = getWeekdayPattern(consumption: consumption)
        let trend = ConsumptionAnalyzer.detectTrend(consumption: consumption)

        var forecasts: [DailyForecast] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        for day in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: day + 1, to: Date()) ?? Date()
            let weekday = Calendar.current.component(.weekday, from: date)
            let adjustedWeekday = (weekday + 5) % 7

            let baseQty = weekdayPattern[adjustedWeekday]
            let trendAdjustment = baseQty * (trend / 100.0)
            let predicted = max(0, baseQty + trendAdjustment)
            let confidence = max(50, 90 - (day * 5))

            forecasts.append(DailyForecast(
                date: date,
                dayName: formatter.string(from: date),
                predictedQuantity: predicted,
                confidence: confidence
            ))
        }

        return forecasts
    }

    static func getWeekdayPattern(consumption: [Int]) -> [Double] {
        var dayTotals = [Double](repeating: 0, count: 7)
        var dayCounts = [Int](repeating: 0, count: 7)

        for (index, value) in consumption.enumerated() {
            let dayIndex = index % 7
            dayTotals[dayIndex] += Double(value)
            dayCounts[dayIndex] += 1
        }

        return (0..<7).map { i in
            dayCounts[i] > 0 ? dayTotals[i] / Double(dayCounts[i]) : 0
        }
    }

    static func totalForecastedDemand(item: InventoryItem, days: Int = 7) -> Double {
        let forecasts = forecast(item: item, days: days)
        return forecasts.reduce(0) { $0 + $1.predictedQuantity }
    }
}
