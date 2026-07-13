import XCTest
@testable import VWARProtocol

final class VWARProtocolTests: XCTestCase {
    func testHexRoundTripAndHumanFormatting() throws {
        let bytes: [UInt8] = [0x00, 0x0f, 0xa5, 0xff]
        XCTAssertEqual(HexCodec.encode(bytes), "000fa5ff")
        XCTAssertEqual(try HexCodec.decode("00:0F-a5 ff"), bytes)
    }

    func testHexRejectsOddLengthAndInvalidBytes() {
        XCTAssertThrowsError(try HexCodec.decode("abc")) { error in
            XCTAssertEqual(error as? HexCodecError, .oddLength)
        }
        XCTAssertThrowsError(try HexCodec.decode("00zz")) { error in
            XCTAssertEqual(error as? HexCodecError, .invalidByte(index: 1, value: "zz"))
        }
    }

    func testTranscriptRedactionAndCanonicalEncoding() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let peripheral = PeripheralSnapshot(
            capturedAt: date,
            peripheralIdentifier: "PRIVATE-ID",
            advertisedName: "VWAR",
            manufacturerDataHex: "0102"
        )
        let transcript = CaptureTranscript(
            sessionIdentifier: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            deviceModel: "VWAR Loop Life",
            startedAt: date,
            peripheral: peripheral,
            events: [
                BLECaptureEvent(
                    sequence: 0,
                    timestamp: date,
                    peripheralIdentifier: "PRIVATE-ID",
                    operation: .advertisement,
                    payloadHex: "0102",
                    note: "personal note"
                ),
                BLECaptureEvent(
                    sequence: 1,
                    timestamp: date,
                    peripheralIdentifier: "PRIVATE-ID",
                    serviceUUID: "fff0",
                    characteristicUUID: "fff1",
                    operation: .notification,
                    payloadHex: "0304",
                    note: "triggered after tapping HR"
                ),
            ]
        )

        let research = transcript.redacted(using: .protocolResearch)
        XCTAssertNil(research.peripheral?.peripheralIdentifier)
        XCTAssertEqual(research.peripheral?.manufacturerDataHex, "0102")
        XCTAssertEqual(research.events.map(\.payloadHex), ["0102", "0304"])
        XCTAssertTrue(research.events.allSatisfy { $0.peripheralIdentifier == nil && $0.note == nil })

        let metadataOnly = transcript.redacted(using: .metadataOnly)
        XCTAssertNil(metadataOnly.peripheral?.manufacturerDataHex)
        XCTAssertTrue(metadataOnly.events.allSatisfy { $0.payloadHex == nil })

        let data = try research.canonicalJSON()
        let decoded = try JSONDecoder.iso8601.decode(CaptureTranscript.self, from: data)
        XCTAssertEqual(decoded, research)
    }

    func testEvidenceReportsLengthsUniquenessAndChangingOffsets() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let events = [
            event(0, "100020", date),
            event(1, "100120", date),
            event(2, "100120ff", date),
            BLECaptureEvent(
                sequence: 3,
                timestamp: date,
                serviceUUID: "fff0",
                characteristicUUID: "fff1",
                operation: .notification,
                payloadHex: "zz"
            ),
        ]

        let evidence = ProtocolEvidenceBuilder.build(from: events)
        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(evidence[0].observationCount, 4)
        XCTAssertEqual(evidence[0].decodablePayloadCount, 3)
        XCTAssertEqual(evidence[0].minimumPayloadLength, 3)
        XCTAssertEqual(evidence[0].maximumPayloadLength, 4)
        XCTAssertEqual(evidence[0].uniquePayloadCount, 3)
        XCTAssertEqual(evidence[0].changingByteOffsets, [1, 3])
    }

    func testStandardBatteryDecoderRejectsImpossiblePercentage() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let valid = StandardMetricDecoder.decode(
            serviceUUID: "180F",
            characteristicUUID: "2A19",
            payload: [87],
            capturedAt: date
        )
        XCTAssertEqual(valid.map(\.kind), [.batteryPercent])
        XCTAssertEqual(valid.map(\.value), [87])

        XCTAssertTrue(StandardMetricDecoder.decode(
            serviceUUID: "180F",
            characteristicUUID: "2A19",
            payload: [101],
            capturedAt: date
        ).isEmpty)
    }

    func testStandardHeartRateDecoderHandlesUInt16AndRRIntervals() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        // UInt16 HR + RR present; 72 bpm and 1024 ticks = 1000 ms.
        let samples = StandardMetricDecoder.decode(
            serviceUUID: "180D",
            characteristicUUID: "00002A37-0000-1000-8000-00805F9B34FB",
            payload: [0x11, 0x48, 0x00, 0x00, 0x04],
            capturedAt: date
        )
        XCTAssertEqual(samples.map(\.kind), [.heartRateBPM, .rrIntervalMilliseconds])
        XCTAssertEqual(samples[0].value, 72)
        XCTAssertEqual(samples[1].value, 1_000, accuracy: 0.001)
    }

    private func event(_ sequence: Int, _ payloadHex: String, _ date: Date) -> BLECaptureEvent {
        BLECaptureEvent(
            sequence: sequence,
            timestamp: date,
            serviceUUID: "FFF0",
            characteristicUUID: "FFF1",
            operation: .notification,
            payloadHex: payloadHex
        )
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
