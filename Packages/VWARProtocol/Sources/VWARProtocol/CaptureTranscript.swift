import Foundation

public struct CaptureRedactionPolicy: Equatable, Sendable {
    public var includePeripheralIdentifier: Bool
    public var includeAdvertisementPayload: Bool
    public var includeCharacteristicPayloads: Bool
    public var includeNotes: Bool

    public init(
        includePeripheralIdentifier: Bool,
        includeAdvertisementPayload: Bool,
        includeCharacteristicPayloads: Bool,
        includeNotes: Bool
    ) {
        self.includePeripheralIdentifier = includePeripheralIdentifier
        self.includeAdvertisementPayload = includeAdvertisementPayload
        self.includeCharacteristicPayloads = includeCharacteristicPayloads
        self.includeNotes = includeNotes
    }

    /// Suitable for sharing protocol evidence: preserves bytes but strips device identity and notes.
    public static let protocolResearch = CaptureRedactionPolicy(
        includePeripheralIdentifier: false,
        includeAdvertisementPayload: true,
        includeCharacteristicPayloads: true,
        includeNotes: false
    )

    /// Suitable for bug reports where raw payloads are not necessary.
    public static let metadataOnly = CaptureRedactionPolicy(
        includePeripheralIdentifier: false,
        includeAdvertisementPayload: false,
        includeCharacteristicPayloads: false,
        includeNotes: false
    )
}

public struct CaptureTranscript: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var sessionIdentifier: UUID
    public var deviceModel: String
    public var collectorVersion: String?
    public var startedAt: Date
    public var endedAt: Date?
    public var peripheral: PeripheralSnapshot?
    public var events: [BLECaptureEvent]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        sessionIdentifier: UUID = UUID(),
        deviceModel: String,
        collectorVersion: String? = nil,
        startedAt: Date,
        endedAt: Date? = nil,
        peripheral: PeripheralSnapshot? = nil,
        events: [BLECaptureEvent] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sessionIdentifier = sessionIdentifier
        self.deviceModel = deviceModel
        self.collectorVersion = collectorVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.peripheral = peripheral
        self.events = events.sorted { $0.sequence < $1.sequence }
    }

    public func redacted(using policy: CaptureRedactionPolicy) -> CaptureTranscript {
        var copy = self
        if !policy.includePeripheralIdentifier {
            copy.peripheral?.peripheralIdentifier = nil
        }
        if !policy.includeAdvertisementPayload {
            copy.peripheral?.manufacturerDataHex = nil
        }

        copy.events = copy.events.map { event in
            var redacted = event
            if !policy.includePeripheralIdentifier {
                redacted.peripheralIdentifier = nil
            }
            if !policy.includeNotes {
                redacted.note = nil
            }
            if event.operation == .advertisement, !policy.includeAdvertisementPayload {
                redacted.payloadHex = nil
            } else if event.operation.carriesCharacteristicPayload,
                      !policy.includeCharacteristicPayloads {
                redacted.payloadHex = nil
            }
            return redacted
        }
        return copy
    }

    public func canonicalJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
