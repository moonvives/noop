import Combine
import Foundation

enum VWARDataOrigin: String, Codable, CaseIterable, Hashable {
    case gBand
    case strava
    case appleHealth

    var title: String {
        switch self {
        case .gBand: return "G Band"
        case .strava: return "Strava"
        case .appleHealth: return "Saúde da Apple"
        }
    }

    var systemImage: String {
        switch self {
        case .gBand: return "waveform.path.ecg"
        case .strava: return "flame.fill"
        case .appleHealth: return "heart.fill"
        }
    }
}

enum VWARSourceClassifier {
    static func classify(attributes: [String: String]) -> VWARDataOrigin {
        let sourceName = attributes["sourceName", default: ""].lowercased()
        if let detected = detectKnownOrigin(in: sourceName) {
            return detected
        }

        let genericSourceNames: Set<String> = ["", "saúde", "saude", "health", "apple health"]
        if genericSourceNames.contains(sourceName) {
            if let detected = detectKnownOrigin(in: attributes["device", default: ""].lowercased()) {
                return detected
            }
            if let detected = detectKnownOrigin(in: attributes["sourceVersion", default: ""].lowercased()) {
                return detected
            }
        }
        return .appleHealth
    }

    private static func detectKnownOrigin(in metadata: String) -> VWARDataOrigin? {
        if metadata.contains("strava") {
            return .strava
        }
        if metadata.contains("g band") || metadata.contains("g-band") ||
            metadata.contains("gband") || metadata.contains("vwar loop life") ||
            metadata.contains("vwarlooplife") {
            return .gBand
        }
        return nil
    }
}

struct MetricSnapshot: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let note: String
    let recordedAt: Date
    let origin: VWARDataOrigin
    let systemImage: String
}

struct HealthArchiveSummary: Codable, Hashable {
    let importedAt: Date
    let exportDate: Date?
    let firstRecordDate: Date?
    let lastRecordDate: Date?
    let recordCount: Int
    let workoutCount: Int
    let gBandRecords: Int
    let stravaRecords: Int
    let appleHealthRecords: Int
    let metrics: [MetricSnapshot]

    func count(for origin: VWARDataOrigin) -> Int {
        switch origin {
        case .gBand: return gBandRecords
        case .strava: return stravaRecords
        case .appleHealth: return appleHealthRecords
        }
    }
}

enum HealthArchiveError: LocalizedError {
    case unsupportedFile
    case extractionFailed(String)
    case exportXMLNotFound
    case invalidHealthExport
    case parserFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Escolha o arquivo exportar.zip ou o XML exportado pela Saúde da Apple."
        case .extractionFailed(let details):
            return "Não foi possível abrir o arquivo ZIP. \(details)"
        case .exportXMLNotFound:
            return "O ZIP não contém um XML de exportação da Saúde da Apple."
        case .invalidHealthExport:
            return "O XML selecionado não é uma exportação válida da Saúde da Apple."
        case .parserFailed(let details):
            return "A leitura do histórico foi interrompida. \(details)"
        }
    }
}

@MainActor
final class HealthArchiveModel: ObservableObject {
    @Published private(set) var summary: HealthArchiveSummary?
    @Published private(set) var isImporting = false
    @Published private(set) var statusText = "Pronto para importar"
    @Published var errorMessage: String?

    init() {
        summary = SummaryStore.load()
        if summary != nil {
            statusText = "Resumo salvo neste Mac"
        }
    }

    func importArchive(from url: URL) {
        guard !isImporting else { return }
        isImporting = true
        errorMessage = nil
        statusText = "Lendo a exportação com privacidade…"

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                if hasScopedAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let imported = try HealthArchiveImporter.importArchive(at: url)
                SummaryStore.save(imported)
                DispatchQueue.main.async {
                    self.summary = imported
                    self.isImporting = false
                    self.statusText = "Importação concluída"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.statusText = "Não foi possível importar"
                    self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}

enum SummaryStore {
    private static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base
            .appendingPathComponent("VWAR Loop Life", isDirectory: true)
            .appendingPathComponent("resumo-saude.json", isDirectory: false)
    }

    static func load() -> HealthArchiveSummary? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HealthArchiveSummary.self, from: data)
    }

    static func save(_ summary: HealthArchiveSummary) {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(summary)
            try data.write(to: url, options: .atomic)
        } catch {
            // The imported summary still remains available for the current session.
        }
    }
}

enum HealthArchiveImporter {
    private struct PreparedXML {
        let url: URL
        let temporaryDirectory: URL?
    }

    static func importArchive(at inputURL: URL) throws -> HealthArchiveSummary {
        let prepared = try prepareXML(from: inputURL)
        defer {
            if let directory = prepared.temporaryDirectory {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        guard looksLikeHealthExport(prepared.url) else {
            throw HealthArchiveError.invalidHealthExport
        }
        guard let parser = XMLParser(contentsOf: prepared.url) else {
            throw HealthArchiveError.invalidHealthExport
        }

        let collector = AppleHealthXMLCollector()
        parser.delegate = collector
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else {
            let details = parser.parserError?.localizedDescription ?? "XML inválido."
            throw HealthArchiveError.parserFailed(details)
        }
        guard collector.sawHealthDataRoot else {
            throw HealthArchiveError.invalidHealthExport
        }
        return collector.makeSummary()
    }

    private static func prepareXML(from inputURL: URL) throws -> PreparedXML {
        let extensionName = inputURL.pathExtension.lowercased()
        if extensionName == "xml" {
            return PreparedXML(url: inputURL, temporaryDirectory: nil)
        }
        guard extensionName == "zip" else {
            throw HealthArchiveError.unsupportedFile
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VWAR-Health-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", inputURL.path, temporaryDirectory.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw HealthArchiveError.extractionFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let details = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Arquivo inválido."
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw HealthArchiveError.extractionFailed(details.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        guard let enumerator = FileManager.default.enumerator(
            at: temporaryDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw HealthArchiveError.exportXMLNotFound
        }

        var candidates: [(url: URL, size: Int)] = []
        for case let candidate as URL in enumerator where candidate.pathExtension.lowercased() == "xml" {
            let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile == true {
                candidates.append((candidate, values?.fileSize ?? 0))
            }
        }

        let healthXML = candidates
            .sorted { $0.size > $1.size }
            .map(\.url)
            .first(where: looksLikeHealthExport)
        guard let healthXML else {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            throw HealthArchiveError.exportXMLNotFound
        }
        return PreparedXML(url: healthXML, temporaryDirectory: temporaryDirectory)
    }

    private static func looksLikeHealthExport(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let prefix = handle.readData(ofLength: 16_384)
        guard let text = String(data: prefix, encoding: .utf8) else { return false }
        return text.contains("<HealthData") || text.contains("<!DOCTYPE HealthData")
    }
}

private final class AppleHealthXMLCollector: NSObject, XMLParserDelegate {
    private struct LatestKey: Hashable {
        let type: String
        let origin: VWARDataOrigin
    }

    private struct DailyKey: Hashable {
        let type: String
        let origin: VWARDataOrigin
        let day: Date
    }

    private struct SleepInterval {
        let origin: VWARDataOrigin
        let start: Date
        let end: Date
        let isAsleep: Bool
    }

    private struct LatestValue {
        let value: Double
        let unit: String
        let date: Date
    }

    private let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    private let gregorianCalendar = Calendar(identifier: .gregorian)

    private var latestValues: [LatestKey: LatestValue] = [:]
    private var dailyTotals: [DailyKey: Double] = [:]
    private var sleepIntervals: [SleepInterval] = []
    private var originCounts: [VWARDataOrigin: Int] = [:]
    private var exportDate: Date?
    private var firstRecordDate: Date?
    private var lastRecordDate: Date?
    private(set) var sawHealthDataRoot = false
    private var recordCount = 0
    private var workoutCount = 0

    private let dailyTypes: Set<String> = [
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierDistanceWalkingRunning"
    ]

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "HealthData":
            sawHealthDataRoot = true
        case "ExportDate":
            exportDate = date(from: attributeDict["value"])
        case "Record":
            consumeRecord(attributeDict)
        case "Workout":
            consumeWorkout(attributeDict)
        default:
            break
        }
    }

    private func consumeRecord(_ attributes: [String: String]) {
        recordCount += 1
        let origin = VWARSourceClassifier.classify(attributes: attributes)
        originCounts[origin, default: 0] += 1

        let start = date(from: attributes["startDate"])
        let end = date(from: attributes["endDate"])
        updateDateRange(start: start, end: end)

        guard let type = attributes["type"] else { return }
        if type == "HKCategoryTypeIdentifierSleepAnalysis",
           let start, let end, end > start,
           let rawValue = attributes["value"]?.lowercased() {
            let isAsleep = rawValue.contains("asleep") && !rawValue.contains("awake")
            let isInBed = rawValue.contains("inbed")
            if isAsleep || isInBed {
                sleepIntervals.append(SleepInterval(origin: origin, start: start, end: end, isAsleep: isAsleep))
            }
            return
        }

        guard let raw = attributes["value"], let value = Double(raw), let sampleDate = end ?? start else {
            return
        }
        let unit = attributes["unit"] ?? ""

        if dailyTypes.contains(type) {
            let day = gregorianCalendar.startOfDay(for: sampleDate)
            let key = DailyKey(type: type, origin: origin, day: day)
            dailyTotals[key, default: 0] += normalizedDailyValue(value, unit: unit, type: type)
        } else if metricDefinition(for: type) != nil {
            let key = LatestKey(type: type, origin: origin)
            if latestValues[key] == nil || sampleDate > latestValues[key]!.date {
                latestValues[key] = LatestValue(value: value, unit: unit, date: sampleDate)
            }
        }
    }

    private func consumeWorkout(_ attributes: [String: String]) {
        workoutCount += 1
        let origin = VWARSourceClassifier.classify(attributes: attributes)
        originCounts[origin, default: 0] += 1
        updateDateRange(start: date(from: attributes["startDate"]), end: date(from: attributes["endDate"]))
    }

    private func updateDateRange(start: Date?, end: Date?) {
        if let start, firstRecordDate == nil || start < firstRecordDate! {
            firstRecordDate = start
        }
        if let end, lastRecordDate == nil || end > lastRecordDate! {
            lastRecordDate = end
        }
    }

    private func date(from string: String?) -> Date? {
        guard let string else { return nil }
        if let seconds = AppleHealthTimestampParser.epochSeconds(from: string) {
            return Date(timeIntervalSince1970: seconds)
        }
        return fallbackDateFormatter.date(from: string)
    }

    private func normalizedDailyValue(_ value: Double, unit: String, type: String) -> Double {
        if type == "HKQuantityTypeIdentifierDistanceWalkingRunning" {
            if unit.lowercased() == "m" { return value / 1_000 }
            if unit.lowercased() == "mi" { return value * 1.609_344 }
        }
        if type == "HKQuantityTypeIdentifierActiveEnergyBurned" && unit.lowercased() == "kj" {
            return value / 4.184
        }
        return value
    }

    func makeSummary() -> HealthArchiveSummary {
        var metrics: [MetricSnapshot] = []
        let latestMetricTypes = [
            "HKQuantityTypeIdentifierRestingHeartRate",
            "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
            "HKQuantityTypeIdentifierHeartRate",
            "HKQuantityTypeIdentifierOxygenSaturation",
            "HKQuantityTypeIdentifierRespiratoryRate",
            "HKQuantityTypeIdentifierBodyTemperature"
        ]

        for type in latestMetricTypes {
            if let metric = makeLatestMetric(type: type) {
                metrics.append(metric)
            }
        }
        for type in [
            "HKQuantityTypeIdentifierStepCount",
            "HKQuantityTypeIdentifierActiveEnergyBurned",
            "HKQuantityTypeIdentifierDistanceWalkingRunning"
        ] {
            if let metric = makeDailyMetric(type: type) {
                metrics.append(metric)
            }
        }
        if let sleepMetric = makeSleepMetric() {
            metrics.append(sleepMetric)
        }

        return HealthArchiveSummary(
            importedAt: Date(),
            exportDate: exportDate,
            firstRecordDate: firstRecordDate,
            lastRecordDate: lastRecordDate,
            recordCount: recordCount,
            workoutCount: workoutCount,
            gBandRecords: originCounts[.gBand, default: 0],
            stravaRecords: originCounts[.strava, default: 0],
            appleHealthRecords: originCounts[.appleHealth, default: 0],
            metrics: metrics
        )
    }

    private func preferredOrigin<T>(value: (VWARDataOrigin) -> T?) -> (VWARDataOrigin, T)? {
        for origin in [VWARDataOrigin.gBand, .appleHealth, .strava] {
            if let candidate = value(origin) {
                return (origin, candidate)
            }
        }
        return nil
    }

    private func makeLatestMetric(type: String) -> MetricSnapshot? {
        guard let definition = metricDefinition(for: type),
              let (origin, latest) = preferredOrigin(value: { latestValues[LatestKey(type: type, origin: $0)] }) else {
            return nil
        }
        return MetricSnapshot(
            id: type,
            title: definition.title,
            value: formatted(value: latest.value, unit: latest.unit, type: type),
            note: "Último registro · \(origin.title)",
            recordedAt: latest.date,
            origin: origin,
            systemImage: definition.symbol
        )
    }

    private func makeDailyMetric(type: String) -> MetricSnapshot? {
        guard let definition = metricDefinition(for: type),
              let (origin, latest) = preferredOrigin(value: { origin -> (Date, Double)? in
                  dailyTotals
                      .filter { $0.key.type == type && $0.key.origin == origin }
                      .max { $0.key.day < $1.key.day }
                      .map { ($0.key.day, $0.value) }
              }) else {
            return nil
        }
        return MetricSnapshot(
            id: type,
            title: definition.title,
            value: formatted(value: latest.1, unit: definition.dailyUnit, type: type),
            note: "Total diário · \(origin.title)",
            recordedAt: latest.0,
            origin: origin,
            systemImage: definition.symbol
        )
    }

    private func makeSleepMetric() -> MetricSnapshot? {
        let selected: (VWARDataOrigin, [SleepInterval])? = preferredOrigin { origin in
            let sourceIntervals = sleepIntervals.filter { $0.origin == origin }
            let asleep = sourceIntervals.filter(\.isAsleep)
            if !asleep.isEmpty { return asleep }
            let inBed = sourceIntervals.filter { !$0.isAsleep }
            return inBed.isEmpty ? nil : inBed
        }
        guard let (origin, intervals) = selected, let lastEnd = intervals.map(\.end).max() else { return nil }
        let windowStart = lastEnd.addingTimeInterval(-18 * 60 * 60)
        let recent = intervals
            .filter { $0.end > windowStart && $0.start < lastEnd }
            .map { DateInterval(start: max($0.start, windowStart), end: min($0.end, lastEnd)) }
            .sorted { $0.start < $1.start }
        guard !recent.isEmpty else { return nil }

        var merged: [DateInterval] = []
        for interval in recent {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        let seconds = merged.reduce(0) { $0 + $1.duration }
        let minutes = Int((seconds / 60).rounded())
        let display = "\(minutes / 60) h \(minutes % 60) min"
        return MetricSnapshot(
            id: "HKCategoryTypeIdentifierSleepAnalysis",
            title: "Sono",
            value: display,
            note: "Última noite · \(origin.title)",
            recordedAt: lastEnd,
            origin: origin,
            systemImage: "moon.stars.fill"
        )
    }

    private func formatted(value: Double, unit: String, type: String) -> String {
        switch type {
        case "HKQuantityTypeIdentifierStepCount":
            return NumberFormatter.decimal.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            return "\(Int(value.rounded())) kcal"
        case "HKQuantityTypeIdentifierDistanceWalkingRunning":
            return String(format: "%.2f km", value)
        case "HKQuantityTypeIdentifierOxygenSaturation":
            let percentage = value <= 1.01 ? value * 100 : value
            return String(format: "%.0f%%", percentage)
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            return String(format: "%.0f ms", value)
        case "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierRestingHeartRate":
            return String(format: "%.0f bpm", value)
        case "HKQuantityTypeIdentifierRespiratoryRate":
            return String(format: "%.1f resp/min", value)
        case "HKQuantityTypeIdentifierBodyTemperature":
            return String(format: "%.1f °C", value)
        default:
            return String(format: "%.1f %@", value, unit)
        }
    }

    private func metricDefinition(for type: String) -> (title: String, symbol: String, dailyUnit: String)? {
        switch type {
        case "HKQuantityTypeIdentifierRestingHeartRate":
            return ("FC em repouso", "heart.circle.fill", "count/min")
        case "HKQuantityTypeIdentifierHeartRateVariabilitySDNN":
            return ("VFC", "waveform.path.ecg.rectangle", "ms")
        case "HKQuantityTypeIdentifierHeartRate":
            return ("Frequência cardíaca", "heart.fill", "count/min")
        case "HKQuantityTypeIdentifierOxygenSaturation":
            return ("Oxigênio no sangue", "drop.fill", "%")
        case "HKQuantityTypeIdentifierRespiratoryRate":
            return ("Respiração", "lungs.fill", "count/min")
        case "HKQuantityTypeIdentifierBodyTemperature":
            return ("Temperatura", "thermometer", "degC")
        case "HKQuantityTypeIdentifierStepCount":
            return ("Passos", "figure.walk", "count")
        case "HKQuantityTypeIdentifierActiveEnergyBurned":
            return ("Energia ativa", "flame.fill", "kcal")
        case "HKQuantityTypeIdentifierDistanceWalkingRunning":
            return ("Distância", "map.fill", "km")
        default:
            return nil
        }
    }
}

private enum AppleHealthTimestampParser {
    static func epochSeconds(from text: String) -> TimeInterval? {
        let bytes = Array(text.utf8)
        guard bytes.count >= 20,
              let year = number(bytes, 0, 4),
              let month = number(bytes, 5, 2),
              let day = number(bytes, 8, 2),
              let hour = number(bytes, 11, 2),
              let minute = number(bytes, 14, 2),
              let second = number(bytes, 17, 2),
              (1...12).contains(month),
              (1...31).contains(day),
              (0...23).contains(hour),
              (0...59).contains(minute),
              (0...60).contains(second) else {
            return nil
        }

        let offsetSeconds: Int
        if bytes.count == 20, bytes[19] == 90 { // Z
            offsetSeconds = 0
        } else {
            guard bytes.count >= 25 else { return nil }
            let sign: Int
            if bytes[20] == 43 { // +
                sign = 1
            } else if bytes[20] == 45 { // -
                sign = -1
            } else {
                return nil
            }
            guard let offsetHour = number(bytes, 21, 2) else { return nil }
            let minuteIndex = bytes.count > 23 && bytes[23] == 58 ? 24 : 23
            guard let offsetMinute = number(bytes, minuteIndex, 2),
                  (0...23).contains(offsetHour),
                  (0...59).contains(offsetMinute) else {
                return nil
            }
            offsetSeconds = sign * ((offsetHour * 60 + offsetMinute) * 60)
        }

        let adjustedYear = year - (month <= 2 ? 1 : 0)
        let era = adjustedYear >= 0 ? adjustedYear / 400 : (adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - era * 400
        let shiftedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        let daysSinceEpoch = era * 146_097 + dayOfEra - 719_468
        let localSeconds = daysSinceEpoch * 86_400 + hour * 3_600 + minute * 60 + second
        return TimeInterval(localSeconds - offsetSeconds)
    }

    private static func number(_ bytes: [UInt8], _ start: Int, _ count: Int) -> Int? {
        guard start >= 0, count > 0, start + count <= bytes.count else { return nil }
        var value = 0
        for index in start..<(start + count) {
            let byte = bytes[index]
            guard byte >= 48, byte <= 57 else { return nil }
            value = value * 10 + Int(byte - 48)
        }
        return value
    }
}

private extension NumberFormatter {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
