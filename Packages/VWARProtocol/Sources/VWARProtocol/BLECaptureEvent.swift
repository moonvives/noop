import Foundation

public enum BLECaptureOperation: String, Codable, CaseIterable, Sendable {
    case advertisement
    case connected
    case disconnected
    case servicesDiscovered
    case characteristicsDiscovered
    case read
    case notification
    case indication
    case writeRequest
    case writeAcknowledged
    case error

    public var carriesCharacteristicPayload: Bool {
        switch self {
        case .read, .notification, .indication, .writeRequest:
            true
        default:
            false
        }
    }
}

public struct BLECaptureEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { sequence }
    public var sequence: Int
    public var timestamp: Date
    public var monotonicNanoseconds: UInt64?
    public var peripheralIdentifier: String?
    public var serviceUUID: String?
    public var characteristicUUID: String?
    public var operation: BLECaptureOperation
    public var payloadHex: String?
    public var writeWithResponse: Bool?
    public var note: String?

    public init(
        sequence: Int,
        timestamp: Date,
        monotonicNanoseconds: UInt64? = nil,
        peripheralIdentifier: String? = nil,
        serviceUUID: String? = nil,
        characteristicUUID: String? = nil,
        operation: BLECaptureOperation,
        payloadHex: String? = nil,
        writeWithResponse: Bool? = nil,
        note: String? = nil
    ) {
        self.sequence = sequence
        self.timestamp = timestamp
        self.monotonicNanoseconds = monotonicNanoseconds
        self.peripheralIdentifier = peripheralIdentifier
        self.serviceUUID = serviceUUID
        self.characteristicUUID = characteristicUUID
        self.operation = operation
        self.payloadHex = payloadHex
        self.writeWithResponse = writeWithResponse
        self.note = note
    }

    public init(
        sequence: Int,
        timestamp: Date,
        peripheralIdentifier: String? = nil,
        serviceUUID: String? = nil,
        characteristicUUID: String? = nil,
        operation: BLECaptureOperation,
        payload: [UInt8],
        writeWithResponse: Bool? = nil,
        note: String? = nil
    ) {
        self.init(
            sequence: sequence,
            timestamp: timestamp,
            peripheralIdentifier: peripheralIdentifier,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            operation: operation,
            payloadHex: HexCodec.encode(payload),
            writeWithResponse: writeWithResponse,
            note: note
        )
    }
}
