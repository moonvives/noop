# VITAE One VWAR Loop Life — coletor desktop

VITAE One VWAR Loop Life is the clean-room macOS application and command-line collector for the VWAR Loop Life /
G Band protocol.
It follows the useful architectural lesson from Goose — preserve raw transport evidence before parsing —
but contains no Goose code. Goose's Rust core declares itself `UNLICENSED`, so VITAE uses an original
implementation and its own versioned capture schema.

## What this release does

- scans for the owner's selected Bluetooth Low Energy device;
- connects to exactly the name fragment or UUID selected by the operator;
- inventories every exposed GATT service, characteristic, property, and descriptor;
- reads characteristics only when the peripheral marks them readable;
- subscribes to notification and indication characteristics;
- stores every advertisement, read, notification, indication, connection event, and error;
- decodes Bluetooth SIG Battery Level and Heart Rate Measurement payloads;
- computes byte-level evidence for proprietary payloads without assigning invented meanings;
- exports a private transcript and a redacted research transcript.

It never sends a proprietary write, changes device settings, installs firmware, replays an unknown
command, bypasses authentication, or contacts a G Band cloud service.

## Install the macOS application

Download `VITAE-One-VWAR-Loop-Life-Desktop.app.zip`, extract it, and move `VITAE One VWAR Loop Life.app` to Applications. The build
is ad-hoc signed because the project does not store or use an Apple Developer identity. On first open,
Control-click the app, choose Open, and confirm. macOS will then request Bluetooth permission.

The application provides device scan, name/UUID selection, capture duration, destination folder,
start/stop controls, and a selectable live log. The standalone CLI is included for automation.

## Build from source on macOS

Requirements: macOS 13 or newer, Xcode Command Line Tools, and Bluetooth permission for Terminal.

```bash
git clone https://github.com/moonvives/noop.git
cd noop
swift build -c release --package-path Packages/VWARProtocol --product vitae-vwar-capture
swift build -c release --package-path Packages/VWARProtocol --product VITAEVWARDesktop
```

The executable is created at:

```text
Packages/VWARProtocol/.build/release/vitae-vwar-capture
```

The GitHub Actions workflow also publishes a zipped macOS binary for each validated PR or manual run.

## Capture the Loop Life

Close G Band on the iPhone and temporarily disable the iPhone's Bluetooth so it does not retain the
single BLE connection. Keep the band charged and near the Mac.

First list nearby devices:

```bash
vitae-vwar-capture --list --scan-timeout 30
```

Then capture by a distinctive part of the advertised name:

```bash
vitae-vwar-capture \
  --name "Loop" \
  --duration 600 \
  --output ~/Documents/VITAE-VWAR-Capture
```

If the name is ambiguous, use the UUID printed by `--list`:

```bash
vitae-vwar-capture --identifier 00000000-0000-0000-0000-000000000000 --duration 600
```

macOS will request Bluetooth access on first use. Grant it in System Settings → Privacy & Security →
Bluetooth if the scan returns no devices.

## Output

Each run creates a timestamped folder:

```text
YYYYMMDD-HHMMSS-vwar-loop-life/
  vitae-transcript-private.json
  vitae-transcript-redacted.json
  gatt-snapshot-private.json
  protocol-evidence.json
  standard-metrics.json
  CAPTURE-NOTES.md
```

The two files marked `private` contain the macOS peripheral identifier. Do not publish them. The
redacted transcript removes device identity and operator notes while preserving protocol bytes.

## Required evidence sessions

Run an idle capture first. Then run one separate capture for each single action performed in G Band:
battery refresh, live heart rate, SpO₂, ECG, sleep sync, workout start/stop, and time synchronization.
Repeat every session three times. Do not combine actions in one capture.

The collector can observe passive and standards-based data immediately. A complete subscription-free
VWAR sync driver becomes possible only after these owner-generated captures establish framing,
commands, timestamps, units, pagination, checksums, and safe initialization. Until then, proprietary
bytes remain evidence rather than health measurements.
