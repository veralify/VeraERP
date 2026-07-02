//
//  ContentView.swift
//  veralify
//
//  Created by Abdelrahman Abdelwahab on 01/07/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var supabase = SupabaseClient.shared

    var body: some View {
        if supabase.isAuthenticated {
            TabView {
                ExploreView()
                    .tabItem { Label("Explore", systemImage: "globe") }

                MyESIMsView()
                    .tabItem { Label("My eSIMs", systemImage: "simcard.2.fill") }

                ProfileView()
                    .tabItem { Label("Profile", systemImage: "person.fill") }
            }
        } else {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
