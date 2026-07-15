import Foundation

@main
struct ParserSmoke {
    static func main() throws {
        guard CommandLine.arguments.count >= 2 else {
            fputs("uso: ParserSmoke <exportar.zip|xml> [--fixture]\n", stderr)
            exit(2)
        }
        let input = URL(fileURLWithPath: CommandLine.arguments[1])
        let summary = try HealthArchiveImporter.importArchive(at: input)
        guard summary.recordCount > 0 else {
            fputs("nenhum registro encontrado\n", stderr)
            exit(3)
        }

        if CommandLine.arguments.contains("--fixture") {
            let heartRate = summary.metrics.first { $0.id == "HKQuantityTypeIdentifierHeartRate" }
            let restingHeartRate = summary.metrics.first { $0.id == "HKQuantityTypeIdentifierRestingHeartRate" }
            guard summary.recordCount == 5,
                  summary.workoutCount == 1,
                  summary.gBandRecords == 3,
                  summary.stravaRecords == 1,
                  summary.appleHealthRecords == 2,
                  heartRate?.value == "68 bpm",
                  restingHeartRate?.value == "59 bpm" else {
                fputs("classificação da fixture divergiu\n", stderr)
                exit(4)
            }
        }
        print("OK: \(summary.recordCount) registros, \(summary.workoutCount) atividades")
        print("G Band: \(summary.gBandRecords) | Strava: \(summary.stravaRecords) | Saúde da Apple: \(summary.appleHealthRecords)")
    }
}
