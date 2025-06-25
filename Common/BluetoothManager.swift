//
//  BluetoothManager.swift
//  AKS-WatchOS-Demo
//
//  Created by Ryan on 2025-06-25.
//

import Combine
import CoreBluetooth
import OSLog
import SwiftUI

struct BluetoothMessage: Equatable {
    let characteristic: CBUUID
    let payload: Data?
}

@MainActor
protocol BlueoothMessageProvider {
    var isConnectingToPeripheral: Bool { get set }
    var connectedPeripheral: CBPeripheral? { get set }
    func messages(for characteristics: [CBUUID]) -> AnyPublisher<BluetoothMessage, Never>
}

@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    
    typealias SignalStrength = Int
    
    enum Permissions {
        case allowed
        case notAllowed
        case unknown
    }
    
    static let shared = BluetoothManager(
        discoverPeripheralsWithServices: [.heartRateService],
        discoverServices: [.heartRateService],
        publishMessagesForCharacteristics: [.heartRateMeasurement],
    )
    
    // Published
    @Published var isPoweredOn = false
    @Published var isScanning = false
    @Published var isConnectingToPeripheral = false
    @Published var connectedPeripheral: CBPeripheral?
    @Published var connectedPeripheralRSSI: Int?
    @Published var discoveredPeripherals: [(CBPeripheral, SignalStrength)] = []
    @Published var permissions: Permissions = .unknown
    
    var cachedPeripheralUUID: String? {
        didSet {
            UserDefaults.standard.set(cachedPeripheralUUID, forKey: .cachedPeripheralUUID)
        }
    }
    
    private let discoverPeripheralsWithServices: [CBUUID]
    private let discoverServices: [CBUUID]
    private let publishMessagesForCharacteristics: [CBUUID]
    
    private let messagePublisher = PassthroughSubject<BluetoothMessage, Never>()
    private let autoConnect: Bool
    
    private let log = Logger(subsystem: "com.SuperTurboRyan.ASK-WatchOS-Demo", category: "\(BluetoothManager.self)")
    
    private var centralManager: CBCentralManager!
    
    private var cancelScanTask: Task<Void, Never>?
    private var rssiPollingTask: Task<Void, Never>?
    
    init(
        discoverPeripheralsWithServices: [CBUUID],
        discoverServices: [CBUUID],
        publishMessagesForCharacteristics: [CBUUID],
        autoConnect: Bool = true
    ) {
        self.discoverPeripheralsWithServices = discoverPeripheralsWithServices
        self.discoverServices = discoverServices
        self.publishMessagesForCharacteristics = publishMessagesForCharacteristics
        self.autoConnect = autoConnect
        self.cachedPeripheralUUID = UserDefaults.standard.string(forKey: "cachedPeripheralUUID")
        
        super.init()
        
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil // Defaults to main thread
        )
    }
    
    func startScanning() {
        guard centralManager.isPoweredOn else {
            return log("‼️ Central manager not powered on")
        }
        
        centralManager.scanForPeripherals(
            withServices: discoverPeripheralsWithServices
        )
        isScanning = true
        stopScanningAfterDelay()
        log("🟢 Scanning started")
    }
    
    func stopScanning() {
        guard isScanning else {
            return
        }
        centralManager.stopScan()
        isScanning = centralManager.isScanning
        log("🛑 Scanning stopped")
    }

    func connect(to peripheral: CBPeripheral) {
        cachedPeripheralUUID = peripheral.identifier.uuidString
        connectedPeripheral = peripheral
        discoveredPeripherals.removeAll()
        isConnectingToPeripheral = true
        centralManager.connect(peripheral, options: nil)
    }
    
    #if os(iOS)
    // Use with ASK
    func connect(to peripheralID: UUID) {
        guard let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralID]).first else {
            return log("Periperhal with id \(peripheralID) not found", isError: true)
        }
        connect(to: peripheral)
    }
    #endif
    
    func disconnect() {
        guard let connectedPeripheral else {
            return log("No connected peripheral to disconnect")
        }
        centralManager.cancelPeripheralConnection(connectedPeripheral)
        self.discoveredPeripherals.removeAll()
        self.connectedPeripheral = nil
        self.cachedPeripheralUUID = nil
    }
    
    func messages(for characteristics: [CBUUID]) -> AnyPublisher<BluetoothMessage, Never> {
        messagePublisher
            .filter { characteristics.contains($0.characteristic) }
            .share()
            .eraseToAnyPublisher()
    }
}

extension BluetoothManager: @preconcurrency CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("💗 CBCentralManager state: \(central.state)")
        
        isPoweredOn = central.isPoweredOn
        permissions = CBCentralManager.authorization == .denied ? .notAllowed : .allowed
        
        guard central.isPoweredOn else {
            connectedPeripheral = nil
            isScanning = false
            discoveredPeripherals = []
            return
        }

        if
            central.isPoweredOn
            && autoConnect
            && connectedPeripheral == nil,
            let cachedPeripheralUUID
        {
            if let knownPeripheral = centralManager.retrievePeripherals(withIdentifiers: [UUID(uuidString: cachedPeripheralUUID)!]).first {
                connect(to: knownPeripheral)
            } else {
                startScanning()
            }
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        if let index = discoveredPeripherals.map(\.0).firstIndex(of: peripheral) {
            // Already discovered this peripheral, just update its RSSI
            discoveredPeripherals[index].1 = RSSI.intValue
            return log("📶 Updated RSSI of \(peripheral.nameWithFallbackUUID): \(RSSI.intValue)")
        }
        
        log("👀 Discovered \(peripheral.nameWithFallbackUUID) with advertisement data: \n\(advertisementData) \nRSSI: \(RSSI.intValue)")
        discoveredPeripherals.append((peripheral, RSSI.intValue))
        
        if let cachedPeripheralUUID, peripheral.isSameAs(cachedPeripheralUUID), autoConnect {
            connect(to: peripheral)
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        peripheral.delegate = self
        peripheral.discoverServices(discoverServices)
        log("✅ Connected to \(peripheral.nameWithFallbackUUID)")
        stopScanning()
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        isConnectingToPeripheral = false
        log("‼️ Failed to connect to \(peripheral.nameWithFallbackUUID): \(error?.localizedDescription ?? "Unknown error")")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        log("❌ Disconnected from \(peripheral.nameWithFallbackUUID) \(error == nil ? "normally" : "with error: \(error!.localizedDescription)")")
        connectedPeripheral = nil
        connectedPeripheralRSSI = nil
        rssiPollingTask?.cancel()
    }
}

extension BluetoothManager: @preconcurrency CBPeripheralDelegate {
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard let services = peripheral.services else {
            return log("Failed to discover any services for peripheral \(peripheral.nameWithFallbackUUID)🤔")
        }
        for service in services {
            log("👀 Discovered service: \(service.uuid) \(service.uuid.uuidString)")
            peripheral.discoverCharacteristics(publishMessagesForCharacteristics, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else {
            return log("Failed to discover any characteristics for service \(service.uuid) 🤔")
        }
        for characteristic in characteristics {
            log("👀 Discovered characteristic for service \(service.uuid): \n\(characteristic.uuid) \(characteristic.uuid.uuidString), properties: \(characteristic.properties.rawValue)")
           
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    // Read OR Notify
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        log("🆕 didUpdateValueFor \(characteristic.uuid.uuidString): \(characteristic.value?.bytes ?? [])")
        
        guard publishMessagesForCharacteristics.contains(characteristic.uuid) else {
            return log("Received update for unexpected characteristic: \(characteristic.uuid.uuidString)")
        }
        
        messagePublisher.send(
            BluetoothMessage(
                characteristic: characteristic.uuid,
                payload: characteristic.value
            )
        )
    }
        
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        isConnectingToPeripheral = false
        log("🔔 \(characteristic.uuid.uuidString) isNotifying: \(characteristic.isNotifying)")
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: (any Error)?
    ) {
        connectedPeripheralRSSI = RSSI.intValue
    }
}

// MARK: - Helpers 🙋🙋

private extension BluetoothManager {

    func stopScanningAfterDelay(_ seconds: Int = 30) {
        cancelScanTask?.cancel()
        cancelScanTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            if isScanning && !Task.isCancelled {
                stopScanning()
            }
        }
    }

    func log(_ message: String, isError: Bool = false) {
        isError ?
        log.error("\(message, privacy: .public)") :
        log.info("\(message, privacy: .public)")
    }
}

extension CBCentralManager {
    
    var isPoweredOn: Bool { state == .poweredOn }
}

extension CBPeripheral {
    
    var nameWithFallbackUUID: String { name ?? identifier.uuidString }
    
    func isSameAs(_ id: String) -> Bool { identifier ==  UUID(uuidString: id) }
}

extension CBManagerState: @retroactive CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "unknown"
        }
    }
}

private extension String {
    static let cachedPeripheralUUID = "cachedPeripheralUUID"
}

extension Data {
    var bytes: [UInt8] { [UInt8](self) }
}
