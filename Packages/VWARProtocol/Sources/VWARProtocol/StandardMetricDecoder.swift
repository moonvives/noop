import Foundation

public enum StandardMetricKind: String, Codable, Equatable, Sendable {
    case heartRateBPM = "heart_rate_bpm"
    case rrIntervalMilliseconds = "rr_interval_ms"
    case batteryPercent = "battery_percent"
}

public struct StandardMetricSample: Codable, Equatable, Sendable {
    public var capturedAt: Date
    public var serviceUUID: String
    public var characteristicUUID: String
    public var kind: StandardMetricKind
    public var value: Double
    public var unit: String
    public var rawHex: String

    public init(
        capturedAt: Date,
        serviceUUID: String,
        characteristicUUID: String,
        kind: StandardMetricKind,
        value: Double,
        unit: String,
        rawHex: String
    ) {
        self.capturedAt = capturedAt
        self.serviceUUID = serviceUUID.lowercased()
        self.characteristicUUID = characteristicUUID.lowercased()
        self.kind = kind
        self.value = value
        self.unit = unit
        self.rawHex = rawHex
    }
}

/// Decodes only Bluetooth SIG characteristics with published byte layouts.
/// Proprietary VWAR payloads deliberately remain raw until fixture-backed evidence exists.
public enum StandardMetricDecoder {
    public static func decode(
        serviceUUID: String,
        characteristicUUID: String,
        payload: [UInt8],
        capturedAt: Date
    ) -> [StandardMetricSample] {
        switch normalized(characteristicUUID) {
        case "2a19":
            return decodeBattery(
                serviceUUID: serviceUUID,
                characteristicUUID: characteristicUUID,
                payload: payload,
                capturedAt: capturedAt
            )
        case "2a37":
            return decodeHeartRate(
                serviceUUID: serviceUUID,
                characteristicUUID: characteristicUUID,
                payload: payload,
                capturedAt: capturedAt
            )
        default:
            return []
        }
    }

    private static func decodeBattery(
        serviceUUID: String,
        characteristicUUID: String,
        payload: [UInt8],
        capturedAt: Date
    ) -> [StandardMetricSample] {
        guard let first = payload.first, first <= 100 else { return [] }
        return [sample(
            capturedAt: capturedAt,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            kind: .batteryPercent,
            value: Double(first),
            unit: "%",
            payload: payload
        )]
    }

    private static func decodeHeartRate(
        serviceUUID: String,
        characteristicUUID: String,
        payload: [UInt8],
        capturedAt: Date
    ) -> [StandardMetricSample] {
        guard payload.count >= 2 else { return [] }
        let flags = payload[0]
        let usesUInt16 = flags & 0x01 != 0
        let hasEnergyExpended = flags & 0x08 != 0
        let hasRRIntervals = flags & 0x10 != 0
        var cursor = 1

        let bpm: UInt16
        if usesUInt16 {
            guard payload.count >= 3 else { return [] }
            bpm = UInt16(payload[1]) | UInt16(payload[2]) << 8
            cursor = 3
        } else {
            bpm = UInt16(payload[1])
            cursor = 2
        }

        var result = [sample(
            capturedAt: capturedAt,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            kind: .heartRateBPM,
            value: Double(bpm),
            unit: "bpm",
            payload: payload
        )]

        if hasEnergyExpended {
            guard payload.count >= cursor + 2 else { return result }
            cursor += 2
        }
        if hasRRIntervals {
            while payload.count >= cursor + 2 {
                let ticks = UInt16(payload[cursor]) | UInt16(payload[cursor + 1]) << 8
                result.append(sample(
                    capturedAt: capturedAt,
                    serviceUUID: serviceUUID,
                    characteristicUUID: characteristicUUID,
                    kind: .rrIntervalMilliseconds,
                    value: Double(ticks) / 1_024 * 1_000,
                    unit: "ms",
                    payload: payload
                ))
                cursor += 2
            }
        }
        return result
    }

    private static func sample(
        capturedAt: Date,
        serviceUUID: String,
        characteristicUUID: String,
        kind: StandardMetricKind,
        value: Double,
        unit: String,
        payload: [UInt8]
    ) -> StandardMetricSample {
        StandardMetricSample(
            capturedAt: capturedAt,
            serviceUUID: serviceUUID,
            characteristicUUID: characteristicUUID,
            kind: kind,
            value: value,
            unit: unit,
            rawHex: HexCodec.encode(payload)
        )
    }

    private static func normalized(_ uuid: String) -> String {
        let lower = uuid.lowercased()
        if lower.hasPrefix("0000"), lower.hasSuffix("-0000-1000-8000-00805f9b34fb") {
            return String(lower.dropFirst(4).prefix(4))
        }
        return lower
    }
}
