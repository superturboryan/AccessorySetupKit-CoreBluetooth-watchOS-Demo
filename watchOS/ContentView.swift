//
//  ContentView.swift
//  AKS-WatchOS-Demo
//
//  Created by Ryan on 2025-06-25.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        NavigationStack {
            VStack {
                Button {
                    bluetoothManager.startScanning()
                } label: {
                    Text("Start Scan")
                        .font(.title2)
                        .fontWeight(.medium)
                        .tracking(1)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.green.gradient)
            }
            .padding()
            .fontDesign(.rounded)
            .navigationTitle("ASK ⌚️ Demo")
        }
    }
}

#Preview {
    ContentView()
}
