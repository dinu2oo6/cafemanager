import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var dataService: FirebaseDataService

    @State private var cafeName = "My Café"
    @State private var showingLogoutAlert = false

    var body: some View {
        ZStack {
            AppTheme.accent.ignoresSafeArea()

            List {
                    // MARK: - Café Profile
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppTheme.primary, AppTheme.secondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(cafeName)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                if let email = authManager.currentUser?.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Profile")
                    }

                    // MARK: - Statistics
                    Section {
                        HStack {
                            Label("Inventory Items", systemImage: "shippingbox")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(dataService.inventoryItems.count)")
                                .foregroundColor(AppTheme.secondary)
                                .bold()
                        }
                        HStack {
                            Label("Suppliers", systemImage: "person.2")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(dataService.suppliers.count)")
                                .foregroundColor(AppTheme.secondary)
                                .bold()
                        }
                        HStack {
                            Label("Active Orders", systemImage: "cart")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(dataService.orders.filter { $0.status != .delivered }.count)")
                                .foregroundColor(AppTheme.secondary)
                                .bold()
                        }
                        HStack {
                            Label("Low Stock Items", systemImage: "exclamationmark.triangle")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("\(dataService.inventoryItems.filter { $0.isLow }.count)")
                                .foregroundColor(AppTheme.error)
                                .bold()
                        }
                    } header: {
                        Text("Quick Stats")
                    }

                    // MARK: - About
                    Section {
                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(AppTheme.secondary)
                        }
                        HStack {
                            Label("Platform", systemImage: "iphone")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("iOS 16+")
                                .foregroundColor(AppTheme.secondary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Label("About CafeManager", systemImage: "cup.and.saucer")
                                .foregroundColor(AppTheme.textPrimary)
                                .font(.subheadline.bold())
                            Text("An AI-powered café inventory management app that predicts demand, optimizes stock levels, reduces waste, and analyzes pricing — helping café owners make smarter business decisions.")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("About")
                    }

                    // MARK: - Logout
                    Section {
                        Button(role: .destructive) {
                            showingLogoutAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.headline)
                                Spacer()
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .alert("Sign Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                dataService.reset()
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
        }
    }
}
