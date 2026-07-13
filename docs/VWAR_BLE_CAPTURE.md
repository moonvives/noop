# VWAR / G Band clean-room capture plan

This document defines the evidence needed before VITAE One VWAR Loop Life implements any proprietary G Band command.
It is limited to interoperability with hardware you own. It does not bypass authentication, extract
firmware, impersonate cloud services, or reuse credentials from another person or account.

## Safety rule

Start read-only. Do not replay an unknown write, install a key, change firmware, factory-reset the band,
or send an opcode merely because a different wearable uses a similar UUID. VWAR / G Band is a separate
protocol from WHOOP, Oura, Huami, and the Bluetooth SIG standard services.

Every conclusion must carry one of these evidence states:

- **Observed** — present in one capture.
- **Repeated** — reproduced in at least three isolated captures.
- **Decoded** — byte-level hypothesis explains all current examples.
- **Validated** — the hypothesis predicts a new capture and a safe device response.

## Equipment

- The owner's VWAR Loop Life band and iPhone.
- A Mac running the matching Xcode release.
- Apple's PacketLogger from Additional Tools for Xcode, or another lawful BLE sniffer available to the
  owner. Use nRF Connect only for GATT enumeration and known-safe reads/subscriptions.
- The G Band app solely as the behavioral reference during clean-room observation.

## Capture matrix

Record each action in a separate session. Begin with 30–60 seconds of idle traffic, perform exactly one
action, wait for traffic to settle, then stop. Repeat each session three times.

| Session | Single action | Expected evidence, not assumed meaning |
| --- | --- | --- |
| A0 | Band advertises; app closed | Advertisement cadence, local name, manufacturer bytes |
| A1 | Open G Band and connect | Service discovery, subscriptions, initialization writes |
| A2 | Refresh battery | Read or request/response correlated with the displayed charge |
| A3 | Start and stop live heart rate | Notification channel, cadence, start/stop boundary |
| A4 | Perform one ECG measurement | Control sequence and data stream shape only |
| A5 | Perform one SpO2 measurement | Control sequence and data stream shape only |
| A6 | Sync a known short sleep interval | Pagination, record boundaries, timestamps |
| A7 | Start and stop one workout | Command boundary and live/history record differences |
| A8 | Change phone time by a known offset, then reconnect | Candidate clock/time-zone fields |

For sessions A3–A8, also record the band display and the exact phone time. Do not label a payload as a
health metric until its scale, units, endianness, missing-value sentinel, range, and checksum behavior
are supported by repeated evidence.

## Capture artifacts

Use a stable, private session folder:

```text
YYYYMMDD-HHMM-session-code/
  packetlogger.pklg
  gatt-snapshot.json
  vitae-transcript.json
  operator-notes.md
```

`vitae-transcript.json` uses the versioned `CaptureTranscript` model in `Packages/VWARProtocol`. Share
only a redacted export. Peripheral identifiers and free-form notes are removed by the protocol-research
policy; use the metadata-only policy when raw BLE payloads are unnecessary.

## Analysis order

1. Inventory services, characteristics, properties, descriptors, and notification subscriptions.
2. Diff the one-action captures against A0/A1.
3. Group traffic by service, characteristic, operation, payload length, and changing byte offsets.
4. Identify framing, counters, lengths, and checksums before attempting semantic fields.
5. Write fixture-based tests for every hypothesis.
6. Permit a write in VITAE One VWAR Loop Life only after it is known-safe, narrowly scoped, and user initiated.

Health values decoded from an undocumented protocol remain **experimental** until independently
validated. They must not be presented as diagnoses, laboratory results, or medical-device readings.
