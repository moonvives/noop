#if os(iOS)
import Combine
import CoreBluetooth
import Foundation
import VWARProtocol

/// Clean-room, read-only CoreBluetooth collector for the VWAR Loop Life family.
///
/// The collector deliberately discovers the peripheral before it interprets it. It inventories every
/// service and characteristic, performs only reads explicitly advertised by GATT, and subscribes only to
/// notify/indicate characteristics. It never writes a vendor command. Bluetooth-SIG standard Battery and
/// Heart Rate characteristics are decoded immediately; every proprietary payload remains raw until a
/// fixture-backed decoder is added to `VWARProtocol`.
@MainActor
final class VWARCaptureManager: NSObject, ObservableObject {
    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        var name: String
        var rssi: Int
        var isLikelyVWAR: Bool
    }

    enum Phase: Equatable {
        case idle
        case bluetoothUnavailable(String)
        case scanning
        case connecting(String)
        case discovering(String)
        case capturing(String)
        case reconnecting(String)
        case stopped
        case failed(String)

        var title: String {
            switch self {
            case .idle: return "PRONTO"
            case .bluetoothUnavailable: return "BLUETOOTH INDISPONÍVEL"
            case .scanning: return "PROCURANDO"
            case .connecting: return "CONECTANDO"
            case .discovering: return "MAPEANDO GATT"
            case .capturing: return "CAPTURANDO"
            case .reconnecting: return "RECONECTANDO"
            case .stopped: return "INTERROMPIDO"
            case .failed: return "FALHA"
            }
        }

        var detail: String? {
            switch self {
            case .bluetoothUnavailable(let value), .connecting(let value), .discovering(let value),
                    .capturing(let value), .reconnecting(let value), .failed(let value):
                return value
            case .idle, .scanning, .stopped:
                return nil
            }
        }

        var isActive: Bool {
            switch self {
            case .scanning, .connecting, .discovering, .capturing, .reconnecting: return true
            default: return false
            }
        }
    }

    struct LiveMetric: Identifiable, Equatable {
        let kind: StandardMetricKind
        var value: Double
        var unit: String
        var capturedAt: Date

        var id: String { kind.rawValue }

        var label: String {
            switch kind {
            case .heartRateBPM: return "FREQUÊNCIA CARDÍACA"
            case .rrIntervalMilliseconds: return "INTERVALO R-R"
            case .batteryPercent: return "BATERIA"
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var eventCount = 0
    @Published private(set) var serviceCount = 0
    @Published private(set) var characteristicCount = 0
    @Published private(set) var liveMetrics: [LiveMetric] = []
    @Published private(set) var evidence: [CharacteristicEvidence] = []
    @Published private(set) var exportURL: URL?
    @Published private(set) var lastExportError: String?

    private static let restorationIdentifier = "com.noopapp.vitae.vwar.capture"

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var seen: [UUID: CBPeripheral] = [:]
    private var advertisedNames: [UUID: String] = [:]
    private var manufacturerData: [UUID: Data] = [:]
    private var desiredPeripheralID: UUID?
    private var userRequestedStop = false
    private var reconnectWorkItem: DispatchWorkItem?
    private var transcript: CaptureTranscript?
    private var sequence = 0
    private var standardSamplesByKind: [StandardMetricKind: StandardMetricSample] = [:]

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restorationIdentifier]
        )
    }

    func startScan() {
        exportURL = nil
        lastExportError = nil
        devices.removeAll()
        seen.removeAll()
        userRequestedStop = false
        desiredPeripheralID = nil

        guard central.state == .poweredOn else {
            phase = .bluetoothUnavailable(Self.stateDescription(central.state))
            return
        }
        phase = .scanning
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func stopScan() {
        if central.state == .poweredOn { central.stopScan() }
        if case .scanning = phase { phase = .idle }
    }

    func connect(to id: UUID) {
        guard let candidate = seen[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else {
            phase = .failed("O dispositivo não está mais disponível. Faça uma nova busca.")
            return
        }
        stopScan()
        reconnectWorkItem?.cancel()
        userRequestedStop = false
        desiredPeripheralID = id
        peripheral = candidate
        candidate.delegate = self
        beginTranscript(for: candidate)
        phase = .connecting(advertisedNames[id] ?? candidate.name ?? "VWAR Loop Life")
        central.connect(candidate, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    func stopCapture() {
        userRequestedStop = true
        desiredPeripheralID = nil
        reconnectWorkItem?.cancel()
        if central.state == .poweredOn { central.stopScan() }
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        finishTranscript()
        phase = .stopped
    }

    /// Creates a shareable research transcript. The peripheral identifier and notes are removed, while
    /// the packet bytes needed for clean-room protocol work are retained. The file remains in the app's
    /// Documents directory until the user removes it.
    func exportRedactedTranscript() {
        guard var transcript else {
            lastExportError = "Ainda não existe uma captura para exportar."
            return
        }
        transcript.endedAt = transcript.endedAt ?? Date()
        let redacted = transcript.redacted(using: .protocolResearch)
        do {
            let root = try Self.captureDirectory()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let url = root.appendingPathComponent("VITAE-VWAR-\(formatter.string(from: Date())).json")
            try redacted.canonicalJSON().write(to: url, options: [.atomic, .completeFileProtection])
            exportURL = url
            lastExportError = nil
        } catch {
            exportURL = nil
            lastExportError = "Não foi possível criar o arquivo: \(error.localizedDescription)"
        }
    }

    private func beginTranscript(for peripheral: CBPeripheral) {
        sequence = 0
        eventCount = 0
        serviceCount = 0
        characteristicCount = 0
        evidence = []
        liveMetrics = []
        standardSamplesByKind = [:]
        let id = peripheral.identifier
        transcript = CaptureTranscript(
            deviceModel: "VWAR Loop Life",
            collectorVersion: "VITAE One iOS read-only 1",
            startedAt: Date(),
            peripheral: PeripheralSnapshot(
                capturedAt: Date(),
                peripheralIdentifier: id.uuidString,
                advertisedName: advertisedNames[id] ?? peripheral.name,
                manufacturerDataHex: manufacturerData[id].map { HexCodec.encode([UInt8]($0)) }
            )
        )
    }

    private func finishTranscript() {
        transcript?.endedAt = Date()
        evidence = ProtocolEvidenceBuilder.build(from: transcript?.events ?? [])
    }

    private func record(
        operation: BLECaptureOperation,
        peripheral: CBPeripheral? = nil,
        service: CBService? = nil,
        characteristic: CBCharacteristic? = nil,
        payload: Data? = nil,
        note: String? = nil
    ) {
        let bytes = payload.map { [UInt8]($0) }
        let event = BLECaptureEvent(
            sequence: sequence,
            timestamp: Date(),
            monotonicNanoseconds: DispatchTime.now().uptimeNanoseconds,
            peripheralIdentifier: (peripheral ?? self.peripheral)?.identifier.uuidString,
            serviceUUID: service?.uuid.uuidString ?? characteristic?.service?.uuid.uuidString,
            characteristicUUID: characteristic?.uuid.uuidString,
            operation: operation,
            payloadHex: bytes.map(HexCodec.encode),
            note: note
        )
        sequence += 1
        transcript?.events.append(event)
        eventCount = transcript?.events.count ?? 0
        evidence = ProtocolEvidenceBuilder.build(from: transcript?.events ?? [])

        guard let characteristic, let bytes else { return }
        let decoded = StandardMetricDecoder.decode(
            serviceUUID: characteristic.service?.uuid.uuidString ?? "",
            characteristicUUID: characteristic.uuid.uuidString,
            payload: bytes,
            capturedAt: event.timestamp
        )
        for sample in decoded { standardSamplesByKind[sample.kind] = sample }
        liveMetrics = standardSamplesByKind.values
            .map { LiveMetric(kind: $0.kind, value: $0.value, unit: $0.unit, capturedAt: $0.capturedAt) }
            .sorted { $0.label < $1.label }
    }

    private func rebuildGATTSnapshot(from peripheral: CBPeripheral) {
        let services = (peripheral.services ?? []).map { service in
            GATTServiceSnapshot(
                uuid: service.uuid.uuidString,
                isPrimary: service.isPrimary,
                characteristics: (service.characteristics ?? []).map { characteristic in
                    GATTCharacteristicSnapshot(
                        serviceUUID: service.uuid.uuidString,
                        uuid: characteristic.uuid.uuidString,
                        properties: Self.properties(characteristic.properties),
                        isNotifying: characteristic.isNotifying,
                        valueHex: characteristic.value.map { HexCodec.encode([UInt8]($0)) },
                        descriptors: (characteristic.descriptors ?? []).map {
                            GATTDescriptorSnapshot(uuid: $0.uuid.uuidString)
                        }
                    )
                }
            )
        }
        transcript?.peripheral?.services = services
        serviceCount = services.count
        characteristicCount = services.reduce(0) { $0 + $1.characteristics.count }
    }

    private func scheduleReconnect(to id: UUID, name: String) {
        guard !userRequestedStop else { return }
        reconnectWorkItem?.cancel()
        phase = .reconnecting(name)
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.userRequestedStop, self.central.state == .poweredOn else { return }
            if let cached = self.central.retrievePeripherals(withIdentifiers: [id]).first {
                self.peripheral = cached
                cached.delegate = self
                self.phase = .connecting(name)
                self.central.connect(cached, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
            } else {
                self.startScan()
            }
        }
        reconnectWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }

    private static func likelyVWAR(name: String) -> Bool {
        let value = name.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        return value.contains("vwar") || value.contains("loop") || value.contains("g band") ||
            value.contains("gband") || value.contains("life") || value.contains("jl")
    }

    private static func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "Bluetooth ativo"
        case .poweredOff: return "Ative o Bluetooth nos Ajustes."
        case .unauthorized: return "Autorize o Bluetooth para o VITAE One nos Ajustes."
        case .unsupported: return "Este dispositivo não oferece Bluetooth Low Energy."
        case .resetting: return "O Bluetooth está reiniciando."
        case .unknown: return "O estado do Bluetooth ainda não está disponível."
        @unknown default: return "Estado de Bluetooth desconhecido."
        }
    }

    private static func properties(_ value: CBCharacteristicProperties) -> Set<GATTCharacteristicProperty> {
        var result = Set<GATTCharacteristicProperty>()
        if value.contains(.broadcast) { result.insert(.broadcast) }
        if value.contains(.read) { result.insert(.read) }
        if value.contains(.writeWithoutResponse) { result.insert(.writeWithoutResponse) }
        if value.contains(.write) { result.insert(.write) }
        if value.contains(.notify) { result.insert(.notify) }
        if value.contains(.indicate) { result.insert(.indicate) }
        if value.contains(.authenticatedSignedWrites) { result.insert(.authenticatedSignedWrites) }
        if value.contains(.extendedProperties) { result.insert(.extendedProperties) }
        if value.contains(.notifyEncryptionRequired) { result.insert(.notifyEncryptionRequired) }
        if value.contains(.indicateEncryptionRequired) { result.insert(.indicateEncryptionRequired) }
        return result
    }

    private static func captureDirectory() throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("VITAE Capturas", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

extension VWARCaptureManager: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if case .bluetoothUnavailable = phase { phase = .idle }
        } else {
            phase = .bluetoothUnavailable(Self.stateDescription(central.state))
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else {
            return
        }
        seen[restored.identifier] = restored
        desiredPeripheralID = restored.identifier
        peripheral = restored
        restored.delegate = self
        advertisedNames[restored.identifier] = restored.name ?? "VWAR Loop Life"
        beginTranscript(for: restored)
        phase = restored.state == .connected
            ? .discovering(restored.name ?? "VWAR Loop Life")
            : .reconnecting(restored.name ?? "VWAR Loop Life")
        if restored.state == .connected { restored.discoverServices(nil) }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advertised = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertised ?? peripheral.name ?? "Dispositivo BLE"
        seen[peripheral.identifier] = peripheral
        advertisedNames[peripheral.identifier] = name
        if let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            manufacturerData[peripheral.identifier] = manufacturer
        }
        let candidate = DiscoveredDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            isLikelyVWAR: Self.likelyVWAR(name: name)
        )
        if let index = devices.firstIndex(where: { $0.id == candidate.id }) {
            devices[index] = candidate
        } else {
            devices.append(candidate)
        }
        devices.sort {
            if $0.isLikelyVWAR != $1.isLikelyVWAR { return $0.isLikelyVWAR && !$1.isLikelyVWAR }
            return $0.rssi > $1.rssi
        }

        if desiredPeripheralID == peripheral.identifier, case .scanning = phase {
            connect(to: peripheral.identifier)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let name = advertisedNames[peripheral.identifier] ?? peripheral.name ?? "VWAR Loop Life"
        record(operation: .connected, peripheral: peripheral, note: "Read-only capture connected")
        phase = .discovering(name)
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let name = advertisedNames[peripheral.identifier] ?? peripheral.name ?? "VWAR Loop Life"
        record(operation: .error, peripheral: peripheral, note: "Connect failed: \(error?.localizedDescription ?? "unknown")")
        scheduleReconnect(to: peripheral.identifier, name: name)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let name = advertisedNames[peripheral.identifier] ?? peripheral.name ?? "VWAR Loop Life"
        record(operation: .disconnected, peripheral: peripheral, note: error?.localizedDescription)
        finishTranscript()
        if desiredPeripheralID == peripheral.identifier, !userRequestedStop {
            scheduleReconnect(to: peripheral.identifier, name: name)
        } else {
            phase = .stopped
        }
    }
}

extension VWARCaptureManager: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            record(operation: .error, peripheral: peripheral, note: "Service discovery: \(error.localizedDescription)")
            phase = .failed("Não foi possível ler os serviços GATT.")
            return
        }
        rebuildGATTSnapshot(from: peripheral)
        record(operation: .servicesDiscovered, peripheral: peripheral, note: "\(peripheral.services?.count ?? 0) services")
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            record(operation: .error, peripheral: peripheral, service: service,
                   note: "Characteristic discovery: \(error.localizedDescription)")
            return
        }
        record(operation: .characteristicsDiscovered, peripheral: peripheral, service: service,
               note: "\(service.characteristics?.count ?? 0) characteristics")
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
        rebuildGATTSnapshot(from: peripheral)
        let name = advertisedNames[peripheral.identifier] ?? peripheral.name ?? "VWAR Loop Life"
        phase = .capturing(name)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            record(operation: .error, peripheral: peripheral, characteristic: characteristic,
                   note: "Descriptor discovery: \(error.localizedDescription)")
        }
        rebuildGATTSnapshot(from: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            record(operation: .error, peripheral: peripheral, characteristic: characteristic,
                   note: "Notification subscription: \(error.localizedDescription)")
        }
        rebuildGATTSnapshot(from: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            record(operation: .error, peripheral: peripheral, characteristic: characteristic,
                   note: "Value update: \(error.localizedDescription)")
            return
        }
        guard let value = characteristic.value else { return }
        let operation: BLECaptureOperation
        if characteristic.isNotifying {
            operation = characteristic.properties.contains(.indicate) && !characteristic.properties.contains(.notify)
                ? .indication : .notification
        } else {
            operation = .read
        }
        record(operation: operation, peripheral: peripheral, characteristic: characteristic, payload: value)
        rebuildGATTSnapshot(from: peripheral)
    }
}
#endif
