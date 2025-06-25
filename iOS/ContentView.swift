//
//  ContentView.swift
//  AKS-WatchOS-Demo Watch App
//
//  Created by Ryan on 2025-06-25.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var askManager: ASKManager
    
    var body: some View {
        NavigationStack {
            VStack {
                Button {
                    askManager.presentPicker()
                } label: {
                    Text("Start Scan")
                        .font(.title2)
                        .fontWeight(.medium)
                        .tracking(1)
                        .padding(.horizontal, 80)
                        .padding(.vertical)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.green.gradient)
            }
            .padding()
            .fontDesign(.rounded)
            .navigationTitle("ASK 📱 Demo")
        }
    }
}

#Preview {
    ContentView()
}
