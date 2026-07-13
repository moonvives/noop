import Foundation

public enum GATTCharacteristicProperty: String, Codable, CaseIterable, Hashable, Sendable {
    case broadcast
    case read
    case writeWithoutResponse
    case write
    case notify
    case indicate
    case authenticatedSignedWrites
    case extendedProperties
    case notifyEncryptionRequired
    case indicateEncryptionRequired
}

public struct GATTDescriptorSnapshot: Codable, Equatable, Sendable {
    public var uuid: String
    public var valueDescription: String?

    public init(uuid: String, valueDescription: String? = nil) {
        self.uuid = uuid
        self.valueDescription = valueDescription
    }
}

public struct GATTCharacteristicSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(serviceUUID.lowercased())/\(uuid.lowercased())" }
    public var serviceUUID: String
    public var uuid: String
    public var properties: Set<GATTCharacteristicProperty>
    public var isNotifying: Bool
    public var valueHex: String?
    public var descriptors: [GATTDescriptorSnapshot]

    public init(
        serviceUUID: String,
        uuid: String,
        properties: Set<GATTCharacteristicProperty>,
        isNotifying: Bool = false,
        valueHex: String? = nil,
        descriptors: [GATTDescriptorSnapshot] = []
    ) {
        self.serviceUUID = serviceUUID
        self.uuid = uuid
        self.properties = properties
        self.isNotifying = isNotifying
        self.valueHex = valueHex
        self.descriptors = descriptors
    }
}

public struct GATTServiceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: String { uuid.lowercased() }
    public var uuid: String
    public var isPrimary: Bool
    public var characteristics: [GATTCharacteristicSnapshot]

    public init(
        uuid: String,
        isPrimary: Bool,
        characteristics: [GATTCharacteristicSnapshot] = []
    ) {
        self.uuid = uuid
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}

public struct PeripheralSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var capturedAt: Date
    public var peripheralIdentifier: String?
    public var advertisedName: String?
    public var manufacturerDataHex: String?
    public var services: [GATTServiceSnapshot]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        capturedAt: Date,
        peripheralIdentifier: String? = nil,
        advertisedName: String? = nil,
        manufacturerDataHex: String? = nil,
        services: [GATTServiceSnapshot] = []
    ) {
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.peripheralIdentifier = peripheralIdentifier
        self.advertisedName = advertisedName
        self.manufacturerDataHex = manufacturerDataHex
        self.services = services
    }
}
