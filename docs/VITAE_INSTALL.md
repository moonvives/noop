# Install VITAE One on iPhone

VITAE One is an iOS source build. The GitHub artifact contains an unsigned IPA so no Apple account,
certificate, provisioning profile, or personal health data is ever stored in the repository.

## Required for the G Band bridge

The daily VWAR path is:

```text
VWAR Loop Life → G Band → Apple Health → VITAE One
```

In G Band, enable Apple Health and allow Heart Rate, Walking + Running Distance, Active Energy,
Blood Glucose, Blood Oxygen, Steps, Sleep, and Body Temperature. In VITAE One, open Apple Health,
choose Enable, approve reads, then run Sync.

The glucose value written by G Band is an unvalidated wrist estimate. VITAE One displays it with an
experimental label and excludes it from every score, insight, and coaching input. Blood pressure and
ECG are not imported through this bridge.

## Recommended installation

Build from Xcode with your own Apple development team and a provisioning profile that includes
HealthKit. This keeps the HealthKit entitlement intact.

1. Install Xcode and XcodeGen on the Mac.
2. Clone `moonvives/noop` and check out the VITAE branch or merged revision.
3. Give the app, widget, and App Group bundle identifiers values owned by your Apple team.
4. Set your `DEVELOPMENT_TEAM` in `project.yml`.
5. Run `xcodegen generate`.
6. Open `Strand.xcodeproj`, select the iPhone, and run the `NOOPiOS` scheme.

An IPA re-signed by a generic sideloading service may lose the HealthKit entitlement. If that happens,
VITAE One cannot appear in Health data access and cannot receive G Band data. Do not provide Apple
credentials or health exports to third-party signing services.
