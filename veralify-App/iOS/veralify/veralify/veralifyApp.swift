//
//  veralifyApp.swift
//  veralify
//
//  Created by Abdelrahman Abdelwahab on 01/07/2026.
//

import SwiftUI

@main
struct veralifyApp: App {
    @StateObject private var localization = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(localization)
                .environment(\.locale, localization.language.locale)
                .environment(\.layoutDirection, localization.language.direction)
        }
    }
}
