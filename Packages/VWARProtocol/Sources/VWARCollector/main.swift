import Foundation
import VWARProtocol

#if canImport(CoreBluetooth) && os(macOS)
import CoreBluetooth
import Darwin

private struct CollectorOptions {
    var listOnly = false
    var nameContains: String?
    var identifier: UUID?
    var scanTimeout: TimeInterval = 45
    var captureDuration: TimeInterval = 300
    var outputDirectory = "VWAR-Loop-Life-Capture"

    static func parse(_ arguments: [String]) throws -> CollectorOptions {
        var options = CollectorOptions()
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--list":
                options.listOnly = true
            case "--name":
                index += 1
                guard index < arguments.count else { throw CLIError.missingValue("--name") }
                options.nameContains = arguments[index]
            case "--identifier":
                index += 1
                guard index < arguments.count, let value = UUID(uuidString: arguments[index]) else {
                    throw CLIError.invalidValue("--identifier")
                }
                options.identifier = value
            case "--scan-timeout":
                index += 1
                guard index < arguments.count, let value = Double(arguments[index]), value > 0 else {
                    throw CLIError.invalidValue("--scan-timeout")
                }
                options.scanTimeout = value
            case "--duration":
                index += 1
                guard index < arguments.count, let value = Double(arguments[index]), value > 0 else {
                    throw CLIError.invalidValue("--duration")
                }
                options.captureDuration = value
            case "--output":
                index += 1
                guard index < arguments.count else { throw CLIError.missingValue("--output") }
                options.outputDirectory = arguments[index]
            case "--help", "-h":
                printUsage()
                exit(EXIT_SUCCESS)
            default:
                throw CLIError.unknownArgument(arguments[index])
            }
            index += 1
        }
        if !options.listOnly, options.nameContains == nil, options.identifier == nil {
            throw CLIError.targetRequired
        }
        return options
    }
}

private enum CLIError: LocalizedError {
    case missingValue(String)
    case invalidValue(String)
    case unknownArgument(String)
    case targetRequired

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag): return "Missing value for \(flag)."
        case .invalidValue(let flag): return "Invalid value for \(flag)."
        case .unknownArgument(let value): return "Unknown argument: \(value)."
        case .targetRequired: return "Choose a device with --name or --identifier. Run --list first."
        }
    }
}

private final class VWARCollector: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let options: CollectorOptions
    private var central: CBCentralManager!
    private var target: CBPeripheral?
    private var startedAt = Date()
    private var endedAt: Date?
    private var advertisedName: String?
    private var manufacturerData: Data?
    private var events: [BLECaptureEvent] = []
    private var standardMetrics: [StandardMetricSample] = []
    private var serviceSnapshots: [String: GATTServiceSnapshot] = [:]
    private var pendingServiceDiscovery: Set<String> = []
    private var pendingReadPaths: Set<String> = []
    private var seenPeripheralIDs: Set<UUID> = []
    private var sequence = 0
    private var scanTimer: Timer?
    private var captureTimer: Timer?
    private var finished = false

    init(options: CollectorOptions) {
        self.options = options
        super.init()
    }

    func start() {
        startedAt = Date()
        central = CBCentralManager(delegate: self, queue: .main)
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler { [weak self] in self?.finish(reason: "Stopped by operator") }
        source.resume()
        interruptSource = source
    }

    private var interruptSource: DispatchSourceSignal?

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if central.state == .unauthorized || central.state == .unsupported {
                fail("Bluetooth unavailable: state \(central.state.rawValue)")
            }
            return
        }
        print("Scanning for Bluetooth Low Energy devices…")
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanTimer = Timer.scheduledTimer(withTimeInterval: options.scanTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.options.listOnly { self.finishList() }
            else { self.fail("No matching device found before the scan timeout.") }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unnamed"
        if seenPeripheralIDs.insert(peripheral.identifier).inserted {
            print("\(peripheral.identifier.uuidString)  RSSI \(RSSI)  \(name)")
        }
        guard !options.listOnly, matches(peripheral: peripheral, name: name) else { return }
        target = peripheral
        advertisedName = name
        manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        append(
            operation: .advertisement,
            payload: manufacturerData,
            note: "name=\(name); rssi=\(RSSI)"
        )
        scanTimer?.invalidate()
        central.stopScan()
        peripheral.delegate = self
        print("Connecting read-only to \(name)…")
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        append(operation: .connected, note: peripheral.name)
        print("Connected. Discovering services and characteristics…")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        fail("Connection failed: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        append(operation: .disconnected, note: error?.localizedDescription)
        if !finished { finish(reason: "Device disconnected") }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { fail("Service discovery failed: \(error.localizedDescription)"); return }
        let services = peripheral.services ?? []
        append(operation: .servicesDiscovered, note: services.map { $0.uuid.uuidString }.joined(separator: ","))
        pendingServiceDiscovery = Set(services.map { $0.uuid.uuidString.lowercased() })
        for service in services {
            serviceSnapshots[service.uuid.uuidString.lowercased()] = GATTServiceSnapshot(
                uuid: service.uuid.uuidString,
                isPrimary: service.isPrimary
            )
            peripheral.discoverCharacteristics(nil, for: service)
        }
        if services.isEmpty { beginCaptureWindow() }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let serviceID = service.uuid.uuidString.lowercased()
        defer {
            pendingServiceDiscovery.remove(serviceID)
            if pendingServiceDiscovery.isEmpty { beginCaptureWindow() }
        }
        if let error {
            append(operation: .error, serviceUUID: service.uuid.uuidString, note: error.localizedDescription)
            return
        }
        var snapshots: [GATTCharacteristicSnapshot] = []
        for characteristic in service.characteristics ?? [] {
            let properties = snapshotProperties(characteristic.properties)
            let path = characteristicPath(characteristic)
            snapshots.append(GATTCharacteristicSnapshot(
                serviceUUID: service.uuid.uuidString,
                uuid: characteristic.uuid.uuidString,
                properties: properties,
                isNotifying: characteristic.isNotifying,
                valueHex: characteristic.value.map { HexCodec.encode($0) }
            ))
            append(
                operation: .characteristicsDiscovered,
                serviceUUID: service.uuid.uuidString,
                characteristicUUID: characteristic.uuid.uuidString,
                note: properties.map(\.rawValue).sorted().joined(separator: ",")
            )
            peripheral.discoverDescriptors(for: characteristic)
            if characteristic.properties.contains(.read) {
                pendingReadPaths.insert(path)
                peripheral.readValue(for: characteristic)
            }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        serviceSnapshots[serviceID]?.characteristics = snapshots.sorted { $0.uuid < $1.uuid }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            append(
                operation: .error,
                serviceUUID: characteristic.service?.uuid.uuidString,
                characteristicUUID: characteristic.uuid.uuidString,
                note: "Descriptor discovery: \(error.localizedDescription)"
            )
            return
        }
        for descriptor in characteristic.descriptors ?? [] { peripheral.readValue(for: descriptor) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil, let characteristic = descriptor.characteristic else { return }
        let description = descriptor.value.map { String(describing: $0) }
        updateDescriptor(
            serviceUUID: characteristic.service?.uuid.uuidString,
            characteristicUUID: characteristic.uuid.uuidString,
            descriptor: GATTDescriptorSnapshot(uuid: descriptor.uuid.uuidString, valueDescription: description)
        )
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            append(
                operation: .error,
                serviceUUID: characteristic.service?.uuid.uuidString,
                characteristicUUID: characteristic.uuid.uuidString,
                note: "Subscription: \(error.localizedDescription)"
            )
        }
        updateCharacteristic(characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let serviceUUID = characteristic.service?.uuid.uuidString
        if let error {
            append(
                operation: .error,
                serviceUUID: serviceUUID,
                characteristicUUID: characteristic.uuid.uuidString,
                note: error.localizedDescription
            )
            return
        }
        let path = characteristicPath(characteristic)
        let operation: BLECaptureOperation
        if pendingReadPaths.remove(path) != nil { operation = .read }
        else if characteristic.properties.contains(.indicate) && !characteristic.properties.contains(.notify) { operation = .indication }
        else { operation = .notification }
        let capturedAt = Date()
        append(
            timestamp: capturedAt,
            operation: operation,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristic.uuid.uuidString,
            payload: characteristic.value
        )
        if let value = characteristic.value, let serviceUUID {
            standardMetrics.append(contentsOf: StandardMetricDecoder.decode(
                serviceUUID: serviceUUID,
                characteristicUUID: characteristic.uuid.uuidString,
                payload: Array(value),
                capturedAt: capturedAt
            ))
        }
        updateCharacteristic(characteristic)
    }

    private func beginCaptureWindow() {
        guard captureTimer == nil else { return }
        print("GATT inventory complete. Capturing read responses and passive notifications for \(Int(options.captureDuration)) seconds.")
        captureTimer = Timer.scheduledTimer(withTimeInterval: options.captureDuration, repeats: false) { [weak self] _ in
            self?.finish(reason: "Capture duration completed")
        }
    }

    private func matches(peripheral: CBPeripheral, name: String) -> Bool {
        if let identifier = options.identifier, peripheral.identifier != identifier { return false }
        if let fragment = options.nameContains, !name.localizedCaseInsensitiveContains(fragment) { return false }
        return true
    }

    private func finishList() {
        central.stopScan()
        print("Scan complete. Re-run with --name <part of name> or --identifier <UUID>.")
        exit(EXIT_SUCCESS)
    }

    private func finish(reason: String) {
        guard !finished else { return }
        finished = true
        endedAt = Date()
        scanTimer?.invalidate()
        captureTimer?.invalidate()
        central?.stopScan()
        if let target { central?.cancelPeripheralConnection(target) }
        do {
            let output = try export(reason: reason)
            print("Capture saved to \(output.path)")
            exit(EXIT_SUCCESS)
        } catch {
            fputs("Export failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private func fail(_ message: String) {
        append(operation: .error, note: message)
        fputs("Error: \(message)\n", stderr)
        if target != nil { finish(reason: message) }
        else { exit(EXIT_FAILURE) }
    }

    private func export(reason: String) throws -> URL {
        let expanded = NSString(string: options.outputDirectory).expandingTildeInPath
        let base = URL(fileURLWithPath: expanded, isDirectory: true)
        let stamp = Self.folderFormatter.string(from: startedAt)
        let directory = base.appendingPathComponent("\(stamp)-vwar-loop-life", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = PeripheralSnapshot(
            capturedAt: startedAt,
            peripheralIdentifier: target?.identifier.uuidString,
            advertisedName: advertisedName ?? target?.name,
            manufacturerDataHex: manufacturerData.map { HexCodec.encode($0) },
            services: serviceSnapshots.values.sorted { $0.uuid < $1.uuid }
        )
        let transcript = CaptureTranscript(
            deviceModel: advertisedName ?? target?.name ?? "VWAR Loop Life",
            collectorVersion: "vwar-loop-life-capture/2",
            startedAt: startedAt,
            endedAt: endedAt,
            peripheral: snapshot,
            events: events
        )
        try transcript.canonicalJSON().write(to: directory.appendingPathComponent("vwar-transcript-private.json"), options: .atomic)
        try transcript.redacted(using: .protocolResearch).canonicalJSON()
            .write(to: directory.appendingPathComponent("vwar-transcript-redacted.json"), options: .atomic)
        try writeJSON(snapshot, to: directory.appendingPathComponent("gatt-snapshot-private.json"))
        try writeJSON(ProtocolEvidenceBuilder.build(from: events), to: directory.appendingPathComponent("protocol-evidence.json"))
        try writeJSON(standardMetrics, to: directory.appendingPathComponent("standard-metrics.json"))
        let notes = """
        # VWAR Loop Life capture

        Result: \(reason)
        Started: \(Self.isoFormatter.string(from: startedAt))
        Ended: \(Self.isoFormatter.string(from: endedAt ?? Date()))
        Device: \(advertisedName ?? target?.name ?? "Unknown")
        Events: \(events.count)
        Bluetooth SIG metric samples: \(standardMetrics.count)

        `vwar-transcript-private.json` and `gatt-snapshot-private.json` contain the device identifier.
        Do not publish them. Share only `vwar-transcript-redacted.json` and `protocol-evidence.json`.

        This collector never writes to an unknown characteristic. Proprietary payloads remain undecoded.
        """
        try Data(notes.utf8).write(to: directory.appendingPathComponent("CAPTURE-NOTES.md"), options: .atomic)
        return directory
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func append(
        timestamp: Date = Date(),
        operation: BLECaptureOperation,
        serviceUUID: String? = nil,
        characteristicUUID: String? = nil,
        payload: Data? = nil,
        note: String? = nil
    ) {
        events.append(BLECaptureEvent(
            sequence: sequence,
            timestamp: timestamp,
            monotonicNanoseconds: DispatchTime.now().uptimeNanoseconds,
            peripheralIdentifier: target?.identifier.uuidString,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            operation: operation,
            payloadHex: payload.map { HexCodec.encode($0) },
            note: note
        ))
        sequence += 1
    }

    private func characteristicPath(_ characteristic: CBCharacteristic) -> String {
        "\(characteristic.service?.uuid.uuidString.lowercased() ?? "unknown")/\(characteristic.uuid.uuidString.lowercased())"
    }

    private func updateCharacteristic(_ characteristic: CBCharacteristic) {
        guard let serviceUUID = characteristic.service?.uuid.uuidString.lowercased(),
              var service = serviceSnapshots[serviceUUID],
              let index = service.characteristics.firstIndex(where: { $0.uuid.caseInsensitiveCompare(characteristic.uuid.uuidString) == .orderedSame })
        else { return }
        service.characteristics[index].isNotifying = characteristic.isNotifying
        service.characteristics[index].valueHex = characteristic.value.map { HexCodec.encode($0) }
        serviceSnapshots[serviceUUID] = service
    }

    private func updateDescriptor(
        serviceUUID: String?,
        characteristicUUID: String,
        descriptor: GATTDescriptorSnapshot
    ) {
        guard let serviceUUID = serviceUUID?.lowercased(),
              var service = serviceSnapshots[serviceUUID],
              let index = service.characteristics.firstIndex(where: { $0.uuid.caseInsensitiveCompare(characteristicUUID) == .orderedSame })
        else { return }
        service.characteristics[index].descriptors.removeAll { $0.uuid.caseInsensitiveCompare(descriptor.uuid) == .orderedSame }
        service.characteristics[index].descriptors.append(descriptor)
        service.characteristics[index].descriptors.sort { $0.uuid < $1.uuid }
        serviceSnapshots[serviceUUID] = service
    }

    private func snapshotProperties(_ value: CBCharacteristicProperties) -> Set<GATTCharacteristicProperty> {
        var result: Set<GATTCharacteristicProperty> = []
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

    private static let folderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()
}

private func printUsage() {
    print("""
    VWAR Loop Life desktop collector

      vwar-loop-life-capture --list [--scan-timeout 30]
      vwar-loop-life-capture --name "Loop" [--duration 300] [--output ~/Documents/VWAR-Loop-Life-Capture]
      vwar-loop-life-capture --identifier UUID [--duration 300]

    The collector performs discovery, permitted reads, and notification subscriptions only.
    It never writes to proprietary characteristics.
    """)
}

@main
private struct VWARCaptureCLI {
    static func main() {
        do {
            let options = try CollectorOptions.parse(Array(CommandLine.arguments.dropFirst()))
            let collector = VWARCollector(options: options)
            collector.start()
            RunLoop.main.run()
        } catch {
            fputs("\(error.localizedDescription)\n\n", stderr)
            printUsage()
            exit(EXIT_FAILURE)
        }
    }
}

#else

@main
private struct UnsupportedPlatformCLI {
    static func main() {
        fputs("vwar-loop-life-capture requires macOS with CoreBluetooth.\n", stderr)
    }
}

#endif
