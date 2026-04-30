//
//  ContentView.swift
//  CafeManager
//
//  Created by Dinesh Sai on 30/04/26.
//
//  Note: This file is kept for compatibility.
//  The app entry point routes directly to LoginView or MainTabView
//  from CafeManagerApp.swift based on authentication state.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // This view is not used in the main app flow.
        // See CafeManagerApp.swift for routing logic.
        Text("CafeManager")
            .font(.title)
            .foregroundColor(AppTheme.primary)
    }
}

#Preview {
    ContentView()
}
