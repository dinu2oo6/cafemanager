//
//  CafeManagerApp.swift
//  CafeManager
//
//  Created by Dinesh Sai on 30/04/26.
//

import SwiftUI
import FirebaseCore

@main
struct CafeManagerApp: App {
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var dataService: FirebaseDataService
    @StateObject private var stockAlertManager = StockAlertNotificationManager()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        _authManager = StateObject(wrappedValue: AuthenticationManager())
        _dataService = StateObject(wrappedValue: FirebaseDataService())
    }

    private var inventoryAlertSignature: String {
        dataService.inventoryItems
            .map { item in
                "\(item.id ?? "")|\(item.quantity)|\(item.dailyConsumption.count)|\(item.supplierId)"
            }
            .sorted()
            .joined(separator: ",")
    }

    private var supplierAlertSignature: String {
        dataService.suppliers
            .map { supplier in
                "\(supplier.id ?? "")|\(supplier.leadTimeInDays)"
            }
            .sorted()
            .joined(separator: ",")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(dataService)
                        .task {
                            await stockAlertManager.requestAuthorizationIfNeeded()
                            await stockAlertManager.refreshStockAlerts(
                                items: dataService.inventoryItems,
                                suppliers: dataService.suppliers
                            )
                        }
                        .onAppear {
                            if let userId = authManager.currentUser?.uid {
                                dataService.configure(userId: userId)
                            }
                        }
                        .onChange(of: inventoryAlertSignature) { _ in
                            Task {
                                await stockAlertManager.refreshStockAlerts(
                                    items: dataService.inventoryItems,
                                    suppliers: dataService.suppliers
                                )
                            }
                        }
                        .onChange(of: supplierAlertSignature) { _ in
                            Task {
                                await stockAlertManager.refreshStockAlerts(
                                    items: dataService.inventoryItems,
                                    suppliers: dataService.suppliers
                                )
                            }
                        }
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .onChange(of: authManager.isAuthenticated) { isAuth in
                if isAuth, let userId = authManager.currentUser?.uid {
                    dataService.configure(userId: userId)
                } else if !isAuth {
                    dataService.reset()
                }
            }
        }
    }
}
