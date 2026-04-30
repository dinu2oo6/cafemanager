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

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        _authManager = StateObject(wrappedValue: AuthenticationManager())
        _dataService = StateObject(wrappedValue: FirebaseDataService())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                        .environmentObject(authManager)
                        .environmentObject(dataService)
                        .onAppear {
                            if let userId = authManager.currentUser?.uid {
                                dataService.configure(userId: userId)
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
