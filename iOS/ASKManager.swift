//
//  ASKManager.swift
//  AKS-WatchOS-Demo
//
//  Created by Ryan on 2025-06-25.
//

import AccessorySetupKit
import CoreBluetooth
import OSLog
import SwiftUI

protocol Accessory {
    var name: String { get }
    var identifier: UUID { get }
}

extension ASAccessory: Accessory {
    var name: String { displayName }
    var identifier: UUID { bluetoothIdentifier ?? UUID() }
}

@MainActor
final class ASKManager: NSObject, ObservableObject {
    
    @Published private(set) var connectedAccessory: Accessory?
    
    static let shared = ASKManager(
        bluetoothManager: .shared,
        searchFor: [.heartRateMonitor]
    )
    
    private let accessoryTypes: [ASPickerDisplayItem]
    private let autoConnect = true
    private let bluetoothManager: BluetoothManager
    private let session = ASAccessorySession()
    
    init(
        bluetoothManager: BluetoothManager,
        searchFor accessoryTypes: [ASPickerDisplayItem]
    ) {
        self.bluetoothManager = bluetoothManager
        self.accessoryTypes = accessoryTypes
        super.init()
        self.session.activate(
            on: DispatchQueue.main,
            eventHandler: handleSessionEvent(event:)
        )
    }
    
    func presentPicker() {
        session.showPicker(for: accessoryTypes) { [weak self] error in
            if let error {
                self?.log.error("Failed to show picker due to: \(error.localizedDescription)")
            }
        }
    }
        
    func remove() {
        guard let accessory = connectedAccessory as? ASAccessory else {
            connectedAccessory = nil // Remove mocked accessory
            log.warning("No connected accessory to remove")
            return
        }
        session.removeAccessory(accessory) { [weak self] error in
            if let error {
                self?.log.error("Error removing accessory: \(error)")
            } else {
                self?.connectedAccessory = nil
            }
        }
    }
    
    func rename() {
        guard let accessory = connectedAccessory as? ASAccessory else {
            return log.warning("No connected accessory to rename")
        }
        session.renameAccessory(accessory) { [weak self] error in
            if let error {
                self?.log.error("Error renaming accessory: \(error)")
            }
        }
    }
    
    func toggleMockedBike(_ isOn: Bool) {
        connectedAccessory = isOn ? MockedAccessory() : nil
    }
    
    private func handleSessionEvent(event: ASAccessoryEvent) {
        log.info("\(event)")
        switch event.eventType {
        case .accessoryAdded, .accessoryChanged:
            guard let accessory = event.accessory else { return }
            save(accessory)
        case .activated:
            guard autoConnect, let accessory = session.accessories.first else { return }
            save(accessory)
        default: return
        }
    }
    
    private func save(_ accessory: ASAccessory) {
        connectedAccessory = accessory
        guard let bluetoothIdentifier = accessory.bluetoothIdentifier else {
            return log.error("Accessory is missing Bluetooth UUID")
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            bluetoothManager.connect(to: bluetoothIdentifier)
        }
    }
    
    private let log = Logger(
        subsystem: "com.SuperTurboRyan.ASK-WatchOS-Demo",
        category: "\(ASKManager.self)"
    )
}

extension ASPickerDisplayItem {
    
    static var heartRateMonitor: ASPickerDisplayItem {
        let descriptor = ASDiscoveryDescriptor()
        descriptor.bluetoothServiceUUID = CBUUID.heartRateService
        return ASPickerDisplayItem(
            name: "Heart Rate Monitor",
            productImage: UIImage(systemName: "heart.circle")!.withTintColor(.systemPink),
            descriptor: descriptor
        )
    }
}

private struct MockedAccessory: Accessory {
    let name = "My Bike"
    let identifier = UUID()
}
