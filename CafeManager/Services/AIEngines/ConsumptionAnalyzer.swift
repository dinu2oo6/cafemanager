import Foundation

struct ConsumptionAnalyzer {
    static func analyze(item: InventoryItem) -> ConsumptionInsight {
        let consumption = item.dailyConsumption
        guard !consumption.isEmpty else {
            return ConsumptionInsight(
                itemId: item.id ?? "", itemName: item.displayName,
                dailyAverage: 0, weekdayAverage: 0, weekendAverage: 0,
                trendPercentage: 0, isAnomalous: false
            )
        }

        let dailyAverage = Double(consumption.reduce(0, +)) / Double(consumption.count)

        let weekdayValues = consumption.enumerated()
            .filter { $0.offset % 7 < 5 }.map { $0.element }
        let weekendValues = consumption.enumerated()
            .filter { $0.offset % 7 >= 5 }.map { $0.element }

        let weekdayAvg = weekdayValues.isEmpty ? dailyAverage
            : Double(weekdayValues.reduce(0, +)) / Double(weekdayValues.count)
        let weekendAvg = weekendValues.isEmpty ? dailyAverage
            : Double(weekendValues.reduce(0, +)) / Double(weekendValues.count)

        let trend = detectTrend(consumption: consumption)
        let anomalous = isAnomalous(consumption: consumption)

        return ConsumptionInsight(
            itemId: item.id ?? "", itemName: item.displayName,
            dailyAverage: dailyAverage, weekdayAverage: weekdayAvg,
            weekendAverage: weekendAvg, trendPercentage: trend,
            isAnomalous: anomalous
        )
    }

    static func detectTrend(consumption: [Int]) -> Double {
        guard consumption.count >= 14 else { return 0 }
        let recent = Array(consumption.suffix(7))
        let previous = Array(consumption.suffix(14).prefix(7))
        let recentAvg = Double(recent.reduce(0, +)) / 7.0
        let previousAvg = Double(previous.reduce(0, +)) / 7.0
        guard previousAvg > 0 else { return 0 }
        return ((recentAvg - previousAvg) / previousAvg) * 100
    }

    static func isAnomalous(consumption: [Int]) -> Bool {
        guard consumption.count >= 7, let latest = consumption.last else { return false }
        let values = consumption.map { Double($0) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        return Double(latest) > mean + (2 * stdDev) || Double(latest) < max(0, mean - (2 * stdDev))
    }

    static func calculateVariance(consumption: [Int]) -> Double {
        guard !consumption.isEmpty else { return 0 }
        let values = consumption.map { Double($0) }
        let mean = values.reduce(0, +) / Double(values.count)
        return values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
    }
}
