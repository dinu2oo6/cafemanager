import Foundation
import UserNotifications

@MainActor
final class StockAlertNotificationManager: ObservableObject {
    private let center = UNUserNotificationCenter.current()
    private let categoryIdentifier = "stock_alert"

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func refreshStockAlerts(items: [InventoryItem], suppliers: [Supplier]) async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("stock-alert-") }

        if !ids.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        let supplierById = Dictionary(uniqueKeysWithValues: suppliers.compactMap { supplier -> (String, Supplier)? in
            guard let id = supplier.id else { return nil }
            return (id, supplier)
        })

        for item in items {
            guard let itemId = item.id else { continue }
            guard item.averageDailyConsumption > 0 else { continue }

            let leadTime = max(1, supplierById[item.supplierId]?.leadTimeInDays ?? 3)
            let daysLeft = item.daysUntilStockout
            guard daysLeft <= leadTime + 5 else { continue }

            let daysBeforeStockoutToNotify = max(1, daysLeft - leadTime)
            let triggerSeconds: TimeInterval = daysLeft <= leadTime ? 5 : TimeInterval(daysBeforeStockoutToNotify * 24 * 60 * 60)

            let content = UNMutableNotificationContent()
            content.title = "Stock Alert: \(item.name)"
            content.body = "Only \(item.quantity) \(item.unit) left. Order in advance to avoid stockout in ~\(daysLeft) day(s)."
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerSeconds, repeats: false)
            let request = UNNotificationRequest(
                identifier: "stock-alert-\(itemId)",
                content: content,
                trigger: trigger
            )

            try? await center.add(request)
        }
    }
}
