import Foundation

/// Brand identity for a sample source discovered through Apple Health or an equivalent health hub.
///
/// This is deliberately string-only and platform-neutral. HealthKit's `HKSource` is converted to
/// `(name, bundleIdentifier)` by the iOS bridge, while tests and future Android provenance adapters
/// can exercise the exact same clean classification rules without importing a platform SDK.
public enum HealthSourceBrand: String, CaseIterable, Codable, Hashable, Sendable {
    case gBand = "g-band"
    case strava
    case apple = "apple"
    case other

    public var displayName: String {
        switch self {
        case .gBand: return "G Band"
        case .strava: return "Strava"
        case .apple: return "Apple"
        case .other: return "Outro"
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
/// G Band is recognized through its common spacing and punctuation variants. Strava is kept as a
/// separate provenance source so the app never presents an installed app as proof of shared data.
public enum HealthSourceClassifier {
    public static func classify(name: String, bundleIdentifier: String) -> HealthSourceBrand {
        let normalizedName = normalize(name)
        let normalizedBundle = normalize(bundleIdentifier)

        let compactName = compact(normalizedName)
        let compactBundle = compact(normalizedBundle)
        if compactName.contains("gband") || compactBundle.contains("gband") {
            return .gBand
        }

        if normalizedName.contains("strava") || normalizedBundle.contains("strava") {
            return .strava
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
