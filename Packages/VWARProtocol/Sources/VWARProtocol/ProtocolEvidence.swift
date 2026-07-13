import Foundation

public struct CharacteristicEvidenceKey: Codable, Equatable, Hashable, Sendable {
    public var serviceUUID: String
    public var characteristicUUID: String
    public var operation: BLECaptureOperation

    public init(serviceUUID: String, characteristicUUID: String, operation: BLECaptureOperation) {
        self.serviceUUID = serviceUUID.lowercased()
        self.characteristicUUID = characteristicUUID.lowercased()
        self.operation = operation
    }
}

public struct CharacteristicEvidence: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        "\(key.serviceUUID)/\(key.characteristicUUID)/\(key.operation.rawValue)"
    }
    public var key: CharacteristicEvidenceKey
    public var observationCount: Int
    public var decodablePayloadCount: Int
    public var minimumPayloadLength: Int?
    public var maximumPayloadLength: Int?
    public var uniquePayloadCount: Int
    public var changingByteOffsets: [Int]

    public init(
        key: CharacteristicEvidenceKey,
        observationCount: Int,
        decodablePayloadCount: Int,
        minimumPayloadLength: Int?,
        maximumPayloadLength: Int?,
        uniquePayloadCount: Int,
        changingByteOffsets: [Int]
    ) {
        self.key = key
        self.observationCount = observationCount
        self.decodablePayloadCount = decodablePayloadCount
        self.minimumPayloadLength = minimumPayloadLength
        self.maximumPayloadLength = maximumPayloadLength
        self.uniquePayloadCount = uniquePayloadCount
        self.changingByteOffsets = changingByteOffsets
    }
}

public enum ProtocolEvidenceBuilder {
    /// Produces byte-level observations only. It deliberately makes no claim about field semantics.
    public static func build(from events: [BLECaptureEvent]) -> [CharacteristicEvidence] {
        let candidates = events.filter {
            $0.operation.carriesCharacteristicPayload &&
                $0.serviceUUID != nil &&
                $0.characteristicUUID != nil
        }
        let grouped = Dictionary(grouping: candidates) { event in
            CharacteristicEvidenceKey(
                serviceUUID: event.serviceUUID!,
                characteristicUUID: event.characteristicUUID!,
                operation: event.operation
            )
        }

        return grouped.map { key, observations in
            let payloads = observations.compactMap { event -> [UInt8]? in
                guard let payloadHex = event.payloadHex else { return nil }
                return try? HexCodec.decode(payloadHex)
            }
            let lengths = payloads.map(\.count)
            let maximumLength = lengths.max() ?? 0
            let changingOffsets = (0..<maximumLength).filter { offset in
                let values = Set(payloads.map { payload -> Int in
                    offset < payload.count ? Int(payload[offset]) : -1
                })
                return values.count > 1
            }

            return CharacteristicEvidence(
                key: key,
                observationCount: observations.count,
                decodablePayloadCount: payloads.count,
                minimumPayloadLength: lengths.min(),
                maximumPayloadLength: lengths.max(),
                uniquePayloadCount: Set(payloads.map { HexCodec.encode($0) }).count,
                changingByteOffsets: changingOffsets
            )
        }
        .sorted { $0.id < $1.id }
    }
}
