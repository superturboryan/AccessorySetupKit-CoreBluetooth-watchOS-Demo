//
//  AKS_WatchOS_DemoApp.swift
//  AKS-WatchOS-Demo Watch App
//
//  Created by Ryan on 2025-06-25.
//

import SwiftUI

@main
struct AKS_WatchOS_Demo_Watch_AppApp: App {
    
    @StateObject var askManager = ASKManager(
        bluetoothManager: .shared,
        searchFor: [.heartRateMonitor]
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(askManager)
        }
    }
}
