//
//  AKS_WatchOS_DemoApp.swift
//  AKS-WatchOS-Demo
//
//  Created by Ryan on 2025-06-25.
//

import SwiftUI

@main
struct AKS_WatchOS_DemoApp: App {
    
    @StateObject var bluetoothManager = BluetoothManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
        }
    }
}
