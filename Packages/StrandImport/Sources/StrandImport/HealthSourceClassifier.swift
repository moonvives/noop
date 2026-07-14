import Foundation

/// Brand identity for a sample source discovered through Apple Health or an equivalent health hub.
///
/// This is deliberately string-only and platform-neutral. HealthKit's `HKSource` is converted to
/// `(name, bundleIdentifier)` by the iOS bridge, while tests and future Android provenance adapters
/// can exercise the exact same clean classification rules without importing a platform SDK.
public enum HealthSourceBrand: String, CaseIterable, Codable, Hashable, Sendable {
    case garminConnect = "garmin-connect"
    case gBand = "g-band"
    case apple = "apple"
    case other

    public var displayName: String {
        switch self {
        case .garminConnect: return "Garmin Connect"
        case .gBand: return "G Band"
        case .apple: return "Apple"
        case .other: return "Other"
        }
    }
}

/// A privacy-safe source descriptor. It contains app identity only, never a sample value, device
/// serial, user identifier, or account detail.
public struct HealthSourceIdentity: Equatable, Hashable, Sendable {
    public let name: String
    public let bundleIdentifier: String
    public let brand: HealthSourceBrand

    public init(name: String, bundleIdentifier: String) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        self.brand = HealthSourceClassifier.classify(name: name, bundleIdentifier: bundleIdentifier)
    }
}

/// Conservative source recognition for health-hub provenance.
///
/// Garmin Connect is commonly shown to users simply as "Connect", so the display name alone is not
/// enough. We accept it only when either the name explicitly says Garmin or the app bundle contains
/// `garmin`. This prevents unrelated apps named Connect from being mislabeled. G Band follows the
/// same rule with its common spacing and punctuation variants.
public enum HealthSourceClassifier {
    public static func classify(name: String, bundleIdentifier: String) -> HealthSourceBrand {
        let normalizedName = normalize(name)
        let normalizedBundle = normalize(bundleIdentifier)

        if normalizedName.contains("garmin") || normalizedBundle.contains("garmin") {
            return .garminConnect
        }

        let compactName = compact(normalizedName)
        let compactBundle = compact(normalizedBundle)
        if compactName.contains("gband") || compactBundle.contains("gband") {
            return .gBand
        }

        if normalizedBundle == "com.apple.health"
            || normalizedBundle.hasPrefix("com.apple.")
            || normalizedName == "apple health"
            || normalizedName == "apple watch"
            || normalizedName == "iphone" {
            return .apple
        }

        return .other
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func compact(_ value: String) -> String {
        value.filter { $0.isLetter || $0.isNumber }
    }
}
