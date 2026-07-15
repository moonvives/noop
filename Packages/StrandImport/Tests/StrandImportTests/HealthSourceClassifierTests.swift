import XCTest
@testable import StrandImport

final class HealthSourceClassifierTests: XCTestCase {
    func testUnrelatedConnectAppRemainsOther() {
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

    func testStravaRecognizedFromNameOrBundle() {
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "Strava", bundleIdentifier: "com.example.health"),
            .strava
        )
        XCTAssertEqual(
            HealthSourceClassifier.classify(name: "Activity", bundleIdentifier: "com.strava.stravaride"),
            .strava
        )
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
        let source = HealthSourceIdentity(name: "  G Band\n", bundleIdentifier: " com.wofit.gband ")
        XCTAssertEqual(source.name, "G Band")
        XCTAssertEqual(source.bundleIdentifier, "com.wofit.gband")
        XCTAssertEqual(source.brand, .gBand)
    }
}
