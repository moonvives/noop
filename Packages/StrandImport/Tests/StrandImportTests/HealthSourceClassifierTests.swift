import XCTest
@testable import StrandImport

final class HealthSourceClassifierTests: XCTestCase {
    func testGarminConnectRecognizedFromBundleWhenHealthShowsGenericConnectName() {
        let source = HealthSourceIdentity(name: "Connect", bundleIdentifier: "com.garmin.connect.mobile")
        XCTAssertEqual(source.brand, .garminConnect)
        XCTAssertEqual(source.name, "Connect")
    }

    func testGarminRecognizedFromExplicitDisplayName() {
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "Garmin Connect", bundleIdentifier: "com.example.health"),
            .garminConnect
        )
    }

    func testUnrelatedConnectAppIsNotMisclassifiedAsGarmin() {
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "Connect", bundleIdentifier: "com.example.connect"),
            .other
        )
    }

    func testGBandSpacingAndPunctuationVariants() {
        XCTAssertEqual(HealthSourceClassifier.classify(name: "G Band", bundleIdentifier: ""), .gBand)
        XCTAssertEqual(HealthSourceClassifier.classify(name: "G-Band", bundleIdentifier: ""), .gBand)
        XCTAssertEqual(HealthSourceClassifier.classify(name: "Health", bundleIdentifier: "com.wofit.gband"), .gBand)
    }

    func testAppleSourcesRemainDistinctFromThirdPartySources() {
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "Apple Watch", bundleIdentifier: "com.apple.health"),
            .apple
        )
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "iPhone", bundleIdentifier: "com.apple.health.iphone"),
            .apple
        )
    }

    func testIdentityTrimsPresentationStrings() {
        let source = HealthSourceIdentity(name: "  Garmin Connect\n", bundleIdentifier: " com.garmin.connect.mobile ")
        XCTAssertEqual(source.name, "Garmin Connect")
        XCTAssertEqual(source.bundleIdentifier, "com.garmin.connect.mobile")
        XCTAssertEqual(source.brand, .garminConnect)
    }
}
