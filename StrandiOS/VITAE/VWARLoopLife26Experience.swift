#if os(iOS)
import Charts
import Foundation
import StrandDesign
import SwiftUI
import WhoopStore

// MARK: - Tendências

struct VWARTrendsView: View {
    @EnvironmentObject private var repo: Repository
    @State private var range: VWARAnalysisRange = .days30
    @State private var selectedDate: Date?

    private var compact: Bool { VWARDeviceEdition.current != .iPadProM2 }
    private var points: [VWARTrendPoint] {
        Array(repo.days.suffix(range.rawValue)).compactMap(VWARTrendPoint.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VWARPageHeader(
                    eyebrow: "ANÁLISE LONGITUDINAL",
                    title: "Tendências",
                    subtitle: "Referências pessoais formadas somente com sinais disponíveis no app Saúde."
                )
                VWARRangePicker(range: $range)
                summaryGrid
                adaptivePanels
                interpretation
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.top, 22)
            .frame(maxWidth: 1_440)
            .frame(maxWidth: .infinity)
        }
        .background(VWAR26Palette.base.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .refreshable { await repo.refresh() }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 145 : 205), spacing: 12)], spacing: 12) {
            VWARMetricTile(label: "RECUPERAÇÃO MEDIANA", value: format(median(points.compactMap(\.recovery)), suffix: "%"), accent: VWAR26Palette.teal)
            VWARMetricTile(label: "CARGA MEDIANA", value: format(median(points.compactMap(\.load)), suffix: ""), accent: VWAR26Palette.blue)
            VWARMetricTile(label: "SONO MEDIANO", value: format(median(points.compactMap(\.sleepScore)), suffix: "%"), accent: VWAR26Palette.violet)
            VWARMetricTile(label: "COBERTURA", value: "\(pointsWithAnySignal) de \(range.rawValue) dias", accent: VWAR26Palette.amber)
        }
    }

    @ViewBuilder private var adaptivePanels: some View {
        if compact {
            VStack(spacing: 14) { readinessPanel; hrvPanel; balancePanel; vitalPanel }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                readinessPanel
                hrvPanel
                balancePanel
                vitalPanel
            }
        }
    }

    private var readinessPanel: some View {
        VWARChartPanel(
            eyebrow: "PANORAMA",
            title: "Recuperação, carga e sono",
            detail: selectedPoint.map(selectedSummary) ?? "Toque e arraste para inspecionar um dia.",
            minimumHeight: 360
        ) {
            if points.isEmpty {
                VWAREmptyState("Sincronize o VWAR Loop Life no G Band com o app Saúde. Atividades do Strava aparecem apenas quando também estiverem registradas no Saúde.")
            } else {
                Chart(points) { point in
                    if let value = point.recovery {
                        LineMark(x: .value("Dia", point.date), y: .value("Recuperação", value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.teal)
                            .lineStyle(.init(lineWidth: 2.4))
                    }
                    if let value = point.sleepScore {
                        LineMark(x: .value("Dia", point.date), y: .value("Sono", value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.violet)
                            .lineStyle(.init(lineWidth: 2.0))
                    }
                    if let value = point.load {
                        LineMark(x: .value("Dia", point.date), y: .value("Carga normalizada", min(100, value * 5)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.blue)
                            .lineStyle(.init(lineWidth: 1.8, dash: [5, 4]))
                    }
                    if selectedDate.map({ Calendar.current.isDate($0, inSameDayAs: point.date) }) == true {
                        RuleMark(x: .value("Selecionado", point.date))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.percent }
                .chartXSelection(value: $selectedDate)
                .frame(height: 245)
                VWARLegendRow(items: [
                    ("Recuperação", VWAR26Palette.teal),
                    ("Sono", VWAR26Palette.violet),
                    ("Carga × 5", VWAR26Palette.blue),
                ])
            }
        }
    }

    private var hrvPanel: some View {
        VWARChartPanel(
            eyebrow: "SISTEMA AUTÔNOMO",
            title: "VFC e frequência de repouso",
            detail: "A leitura conjunta reduz interpretações isoladas de um único sinal.",
            minimumHeight: 360
        ) {
            if points.allSatisfy({ $0.hrv == nil && $0.restingHeartRate == nil }) {
                VWAREmptyState("São necessárias noites com VFC ou frequência cardíaca de repouso.")
            } else {
                Chart(points) { point in
                    if let value = point.hrv {
                        LineMark(x: .value("Dia", point.date), y: .value("VFC", value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.teal)
                            .lineStyle(.init(lineWidth: 2.4))
                        PointMark(x: .value("Dia", point.date), y: .value("VFC", value))
                            .foregroundStyle(VWAR26Palette.teal.opacity(0.5))
                    }
                    if let value = point.restingHeartRate {
                        LineMark(x: .value("Dia", point.date), y: .value("Repouso", value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.rose)
                            .lineStyle(.init(lineWidth: 1.8, dash: [4, 4]))
                    }
                }
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.numeric }
                .frame(height: 245)
                VWARLegendRow(items: [("VFC em ms", VWAR26Palette.teal), ("Repouso em bpm", VWAR26Palette.rose)])
            }
        }
    }

    private var balancePanel: some View {
        VWARChartPanel(
            eyebrow: "RELAÇÃO DOSE–RESPOSTA",
            title: "Carga versus recuperação",
            detail: "Cada ponto é um dia real. A posição ajuda a observar tolerância individual.",
            minimumHeight: 360
        ) {
            let valid = points.filter { $0.load != nil && $0.recovery != nil }
            if valid.count < 3 {
                VWAREmptyState("São necessários pelo menos três dias com carga e recuperação.")
            } else {
                Chart(valid) { point in
                    PointMark(
                        x: .value("Carga", point.load ?? 0),
                        y: .value("Recuperação", point.recovery ?? 0)
                    )
                    .symbolSize(52)
                    .foregroundStyle(balanceColor(point))
                }
                .chartXScale(domain: 0...max(20, (valid.compactMap(\.load).max() ?? 20) * 1.08))
                .chartYScale(domain: 0...100)
                .chartXAxisLabel("Carga diária")
                .chartYAxisLabel("Recuperação")
                .chartXAxis { VWARChartAxis.numeric }
                .chartYAxis { VWARChartAxis.percent }
                .frame(height: 250)
            }
        }
    }

    private var vitalPanel: some View {
        VWARChartPanel(
            eyebrow: "SINAIS NOTURNOS",
            title: "Oxigenação e respiração",
            detail: "Linhas separadas preservam unidade e origem; lacunas continuam visíveis.",
            minimumHeight: 360
        ) {
            if points.allSatisfy({ $0.spo2 == nil && $0.respiratoryRate == nil }) {
                VWAREmptyState("Ainda não há SpO₂ nem frequência respiratória suficientes.")
            } else {
                Chart(points) { point in
                    if let value = point.spo2 {
                        LineMark(x: .value("Dia", point.date), y: .value("SpO₂", value))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.blue)
                            .lineStyle(.init(lineWidth: 2.3))
                    }
                    if let value = point.respiratoryRate {
                        LineMark(x: .value("Dia", point.date), y: .value("Respiração × 5", value * 5))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(VWAR26Palette.amber)
                            .lineStyle(.init(lineWidth: 1.8, dash: [5, 4]))
                    }
                }
                .chartYScale(domain: 60...105)
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.percent }
                .frame(height: 245)
                VWARLegendRow(items: [("SpO₂ em %", VWAR26Palette.blue), ("Respiração × 5", VWAR26Palette.amber)])
            }
        }
    }

    private var interpretation: some View {
        VWARNotice(
            title: "COMO LER",
            text: "Tendência não é diagnóstico. Compare semanas, observe a cobertura e confirme qualquer medida clínica com equipamento validado. Pressão arterial, glicose e ECG da pulseira não são tratados como medições médicas pelo VWAR Loop Life."
        )
    }

    private var selectedPoint: VWARTrendPoint? {
        guard let selectedDate else { return nil }
        return points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var pointsWithAnySignal: Int {
        points.filter { $0.recovery != nil || $0.load != nil || $0.sleepScore != nil || $0.hrv != nil }.count
    }

    private func selectedSummary(_ point: VWARTrendPoint) -> String {
        let date = Self.shortDate.string(from: point.date)
        return "\(date): recuperação \(format(point.recovery, suffix: "%")), carga \(format(point.load, suffix: "")) e sono \(format(point.sleepScore, suffix: "%"))."
    }

    private func balanceColor(_ point: VWARTrendPoint) -> Color {
        guard let recovery = point.recovery, let load = point.load else { return VWAR26Palette.secondary }
        if recovery >= 67 && load >= 12 { return VWAR26Palette.teal }
        if recovery < 34 && load >= 12 { return VWAR26Palette.rose }
        return VWAR26Palette.blue
    }

    private func format(_ value: Double?, suffix: String) -> String {
        value.map { "\(Int($0.rounded()))\(suffix)" } ?? "Sem dados"
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d 'de' MMM"
        return formatter
    }()
}

// MARK: - Sono

struct VWARSleepIntelligenceView: View {
    @EnvironmentObject private var repo: Repository
    @State private var range: VWARAnalysisRange = .days30
    @State private var sessions: [CachedSleepSession] = []

    private var compact: Bool { VWARDeviceEdition.current != .iPadProM2 }
    private var points: [VWARSleepDay] { Array(repo.days.suffix(range.rawValue)).compactMap(VWARSleepDay.init) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VWARPageHeader(
                    eyebrow: "ARQUITETURA E REGULARIDADE",
                    title: "Sono",
                    subtitle: "Duração, eficiência, estágios e horários trazidos do G Band pelo app Saúde."
                )
                VWARRangePicker(range: $range)
                sleepSummary
                adaptivePanels
                VWARNotice(
                    title: "CONTEXTO",
                    text: "Os estágios e pontuações são estimativas de bem-estar. O aplicativo mantém ausências como ausências e não cria ciclos para preencher lacunas."
                )
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.top, 22)
            .frame(maxWidth: 1_440)
            .frame(maxWidth: .infinity)
        }
        .background(VWAR26Palette.base.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: "\(repo.refreshSeq)-\(range.rawValue)") {
            sessions = await repo.allSleepSessions(days: max(100, range.rawValue + 7))
        }
        .refreshable {
            await repo.refresh()
            sessions = await repo.allSleepSessions(days: max(100, range.rawValue + 7))
        }
    }

    private var sleepSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 145 : 205), spacing: 12)], spacing: 12) {
            VWARMetricTile(label: "ÚLTIMA NOITE", value: lastNightDuration, accent: VWAR26Palette.violet)
            VWARMetricTile(label: "MÉDIA DE SONO", value: duration(mean(points.compactMap(\.minutes))), accent: VWAR26Palette.blue)
            VWARMetricTile(label: "EFICIÊNCIA MEDIANA", value: percentage(median(points.compactMap(\.efficiency))), accent: VWAR26Palette.teal)
            VWARMetricTile(label: "NOITES REGISTRADAS", value: "\(points.filter { $0.minutes != nil }.count) de \(range.rawValue)", accent: VWAR26Palette.amber)
        }
    }

    @ViewBuilder private var adaptivePanels: some View {
        if compact {
            VStack(spacing: 14) { durationPanel; stagesPanel; efficiencyPanel; timingPanel }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                durationPanel
                stagesPanel
                efficiencyPanel
                timingPanel
            }
        }
    }

    private var durationPanel: some View {
        VWARChartPanel(eyebrow: "QUANTIDADE", title: "Duração por noite", detail: "A linha pontilhada marca oito horas.", minimumHeight: 350) {
            let valid = points.filter { $0.minutes != nil }
            if valid.isEmpty {
                VWAREmptyState("Nenhuma duração de sono do G Band foi encontrada no app Saúde neste intervalo.")
            } else {
                Chart(valid) { point in
                    AreaMark(x: .value("Dia", point.date), y: .value("Horas", (point.minutes ?? 0) / 60))
                        .foregroundStyle(LinearGradient(colors: [VWAR26Palette.violet.opacity(0.48), VWAR26Palette.violet.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Dia", point.date), y: .value("Horas", (point.minutes ?? 0) / 60))
                        .foregroundStyle(VWAR26Palette.violet)
                        .lineStyle(.init(lineWidth: 2.3))
                    RuleMark(y: .value("Referência", 8))
                        .foregroundStyle(.white.opacity(0.20))
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                }
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.hours }
                .frame(height: 240)
            }
        }
    }

    private var stagesPanel: some View {
        VWARChartPanel(eyebrow: "COMPOSIÇÃO", title: "Estágios registrados", detail: "Minutos empilhados por noite, sem reconstrução artificial.", minimumHeight: 350) {
            if stageRows.isEmpty {
                VWAREmptyState("O app Saúde ainda não recebeu do G Band totais de sono leve, profundo ou REM.")
            } else {
                Chart(stageRows) { row in
                    BarMark(x: .value("Dia", row.date), y: .value("Minutos", row.minutes))
                        .foregroundStyle(by: .value("Estágio", row.stage))
                }
                .chartForegroundStyleScale([
                    "Leve": VWAR26Palette.blue,
                    "Profundo": VWAR26Palette.violet,
                    "REM": VWAR26Palette.teal,
                ])
                .chartLegend(position: .bottom, alignment: .leading, spacing: 12)
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.minutes }
                .frame(height: 250)
            }
        }
    }

    private var efficiencyPanel: some View {
        VWARChartPanel(eyebrow: "CONTINUIDADE", title: "Eficiência do sono", detail: "Percentual do período na cama efetivamente dormido.", minimumHeight: 350) {
            let valid = points.filter { $0.efficiency != nil }
            if valid.isEmpty {
                VWAREmptyState("O app Saúde ainda não contém eficiência do sono para este intervalo.")
            } else {
                Chart(valid) { point in
                    LineMark(x: .value("Dia", point.date), y: .value("Eficiência", point.efficiency ?? 0))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(VWAR26Palette.teal)
                        .lineStyle(.init(lineWidth: 2.4))
                    PointMark(x: .value("Dia", point.date), y: .value("Eficiência", point.efficiency ?? 0))
                        .foregroundStyle(VWAR26Palette.teal.opacity(0.6))
                }
                .chartYScale(domain: 50...100)
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis { VWARChartAxis.percent }
                .frame(height: 240)
            }
        }
    }

    private var timingPanel: some View {
        VWARChartPanel(eyebrow: "REGULARIDADE", title: "Janela de sono", detail: "Horário local de início e término de cada sessão principal.", minimumHeight: 350) {
            if timingRows.isEmpty {
                VWAREmptyState("Não há sessões com início e fim neste intervalo.")
            } else {
                Chart(timingRows) { row in
                    BarMark(
                        x: .value("Dia", row.date),
                        yStart: .value("Início", row.startHour),
                        yEnd: .value("Fim", row.endHour),
                        width: .fixed(8)
                    )
                    .foregroundStyle(VWAR26Palette.blue.gradient)
                    .cornerRadius(4)
                }
                .chartYScale(domain: 18...34)
                .chartXAxis { VWARChartAxis.days }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [20, 24, 28, 32]) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel {
                            if let hour = value.as(Double.self) {
                                Text(String(format: "%02d:00", Int(hour) % 24))
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(VWAR26Palette.tertiary)
                            }
                        }
                    }
                }
                .frame(height: 250)
            }
        }
    }

    private var stageRows: [VWARSleepStageRow] {
        points.flatMap { point in
            [
                point.light.map { VWARSleepStageRow(date: point.date, stage: "Leve", minutes: $0) },
                point.deep.map { VWARSleepStageRow(date: point.date, stage: "Profundo", minutes: $0) },
                point.rem.map { VWARSleepStageRow(date: point.date, stage: "REM", minutes: $0) },
            ].compactMap { $0 }
        }
    }

    private var timingRows: [VWARSleepTimingRow] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -range.rawValue, to: Date()) ?? .distantPast
        var longest: [String: CachedSleepSession] = [:]
        for session in sessions where Date(timeIntervalSince1970: TimeInterval(session.endTs)) >= cutoff {
            let key = Repository.localDayKey(Date(timeIntervalSince1970: TimeInterval(session.endTs)))
            let duration = session.endTs - session.effectiveStartTs
            if duration > (longest[key].map { $0.endTs - $0.effectiveStartTs } ?? -1) { longest[key] = session }
        }
        return longest.compactMap { key, session in
            guard let date = VWARDate.day.date(from: key) else { return nil }
            let start = Date(timeIntervalSince1970: TimeInterval(session.effectiveStartTs))
            let end = Date(timeIntervalSince1970: TimeInterval(session.endTs))
            let startHour = VWARDate.decimalHour(start, unwrapped: true)
            var endHour = VWARDate.decimalHour(end, unwrapped: false)
            while endHour <= startHour { endHour += 24 }
            return VWARSleepTimingRow(date: date, startHour: startHour, endHour: endHour)
        }.sorted { $0.date < $1.date }
    }

    private var lastNightDuration: String {
        guard let session = sessions.max(by: { $0.endTs < $1.endTs }) else { return "Sem dados" }
        return duration(Double(max(0, session.endTs - session.effectiveStartTs)) / 60)
    }

    private func duration(_ minutes: Double?) -> String {
        guard let minutes else { return "Sem dados" }
        let value = max(0, Int(minutes.rounded()))
        return "\(value / 60) h \(value % 60) min"
    }

    private func percentage(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))%" } ?? "Sem dados"
    }

    private func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let values = values.sorted(), middle = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
    }
}

// MARK: - Fontes e perfil

struct VWARSourcesView: View {
    @EnvironmentObject private var health: HealthKitBridge
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var repo: Repository

    private var compact: Bool { VWARDeviceEdition.current != .iPadProM2 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VWARPageHeader(
                    eyebrow: "CONTROLE E PROVENIÊNCIA",
                    title: "Fontes",
                    subtitle: "Um único fluxo: VWAR Loop Life no G Band, app Saúde e atividades do Strava."
                )
                healthPanel
                integrationGrid
                freshnessPanel
                profilePanel
                systemPanel
                VWARNotice(
                    title: "PRIVACIDADE POR PADRÃO",
                    text: "Os cálculos principais permanecem no aparelho. Nenhuma chave de API, conta Strava ou credencial G Band é incorporada ao IPA. Dados só saem do dispositivo quando você escolhe exportar ou compartilhar."
                )
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.top, 22)
            .frame(maxWidth: 1_100)
            .frame(maxWidth: .infinity)
        }
        .background(VWAR26Palette.base.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task { health.refreshAuthIfPreviouslyGranted() }
        .refreshable {
            await health.sync(days: 90)
            await repo.refresh()
        }
    }

    private var healthPanel: some View {
        VWARPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SAÚDE DA APPLE")
                            .font(StrandFont.overlineScaled(9))
                            .tracking(1.2)
                            .foregroundStyle(VWAR26Palette.teal)
                        Text(healthStatusTitle)
                            .font(StrandFont.title2)
                            .foregroundStyle(VWAR26Palette.text)
                        Text(healthStatusDetail)
                            .font(StrandFont.subhead)
                            .foregroundStyle(VWAR26Palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 10)
                    VWARStatusPill(text: healthStatusShort, active: health.auth == .authorized)
                }

                HStack(spacing: 10) {
                    if health.auth != .authorized {
                        Button("ATIVAR ACESSO") {
                            Task {
                                await health.requestAuthorization()
                                await health.sync(days: 90)
                                await repo.refresh()
                            }
                        }
                        .buttonStyle(VWARActionButtonStyle(primary: true))
                    }
                    Button(health.syncing ? "SINCRONIZANDO" : "SINCRONIZAR 90 DIAS") {
                        Task {
                            await health.sync(days: 90)
                            await repo.refresh()
                        }
                    }
                    .buttonStyle(VWARActionButtonStyle(primary: health.auth == .authorized))
                    .disabled(health.auth != .authorized || health.syncing)
                }

                if let lastSync = health.lastSync {
                    Text("Última sincronização: \(Self.dateTime.string(from: lastSync)).")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
                if let error = health.lastError {
                    Text("Falha informada pelo sistema: \(error)")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.rose)
                }
            }
        }
    }

    private var integrationGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 280 : 390), spacing: 14)], spacing: 14) {
            sourceCard(
                title: "G BAND",
                source: health.gBandSource,
                route: "G Band → Saúde da Apple → VWAR Loop Life",
                detail: "No G Band, abra Serviços de dados, ative Saúde da Apple e permita batimentos, passos, sono, oxigênio e temperatura. Depois sincronize aqui."
            )
            sourceCard(
                title: "STRAVA / ATIVIDADES",
                source: health.stravaSource,
                route: "Strava → Saúde da Apple → VWAR Loop Life",
                detail: "No Strava, ative o envio de atividades ao app Saúde. O VWAR Loop Life usa somente atividades realmente gravadas ali; instalar o app, sozinho, não conta como conexão."
            )
        }
    }

    private func sourceCard(title: String, source: HealthKitBridge.HealthSourceSummary?, route: String, detail: String) -> some View {
        VWARPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(StrandFont.overline)
                        .tracking(1.4)
                        .foregroundStyle(VWAR26Palette.text)
                    Spacer()
                    VWARStatusPill(text: source == nil ? "AGUARDANDO" : "VERIFICADO", active: source != nil)
                }
                Text(route)
                    .font(StrandFont.mono(11, weight: .medium))
                    .foregroundStyle(VWAR26Palette.teal)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(StrandFont.subhead)
                    .foregroundStyle(VWAR26Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let source {
                    Text("\(source.metricTypeCount) tipos de métrica encontrados em \(source.sourceNames.joined(separator: ", ")).")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                } else {
                    Text("O estado muda para verificado somente depois que amostras dessa origem forem encontradas no app Saúde.")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }

    private var freshnessPanel: some View {
        VWARPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text("COBERTURA LOCAL")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.2)
                    .foregroundStyle(VWAR26Palette.teal)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    VWARMetricTile(label: "DIAS DO APP SAÚDE", value: "\(repo.freshness.appleDays)", accent: VWAR26Palette.violet)
                    VWARMetricTile(label: "DIAS NO PAINEL", value: "\(repo.days.count)", accent: VWAR26Palette.blue)
                    VWARMetricTile(label: "DIAS ANALISADOS", value: "\(repo.freshness.computedDays)", accent: VWAR26Palette.teal)
                    VWARMetricTile(label: "SONOS ANALISADOS", value: "\(repo.freshness.computedSleeps)", accent: VWAR26Palette.amber)
                }
                Text(freshnessRange)
                    .font(StrandFont.footnote)
                    .foregroundStyle(VWAR26Palette.tertiary)
            }
        }
    }

    private var profilePanel: some View {
        VWARPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("SEU PERFIL")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.2)
                    .foregroundStyle(VWAR26Palette.teal)
                Text("Ajusta zonas, gasto energético e referências pessoais. Todos os valores ficam neste aparelho.")
                    .font(StrandFont.subhead)
                    .foregroundStyle(VWAR26Palette.secondary)

                VWARProfileRow(label: "IDADE", value: "\(profile.age) anos") {
                    Stepper("Idade", value: $profile.age, in: 13...100)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("SEXO PARA EQUAÇÕES FISIOLÓGICAS")
                        .font(StrandFont.overlineScaled(8))
                        .tracking(0.8)
                        .foregroundStyle(VWAR26Palette.tertiary)
                    Picker("Sexo para equações fisiológicas", selection: $profile.sex) {
                        Text("Masculino").tag("male")
                        Text("Feminino").tag("female")
                        Text("Não binário").tag("nonbinary")
                    }
                    .pickerStyle(.segmented)
                }

                VWARProfileRow(label: "PESO", value: String(format: "%.1f kg", profile.weightKg)) {
                    Stepper("Peso", value: $profile.weightKg, in: 35...250, step: 0.5)
                        .labelsHidden()
                }
                VWARProfileRow(label: "ALTURA", value: "\(Int(profile.heightCm.rounded())) cm") {
                    Stepper("Altura", value: $profile.heightCm, in: 120...230, step: 1)
                        .labelsHidden()
                }
                VWARProfileRow(label: "FREQUÊNCIA MÁXIMA ESTIMADA", value: "\(profile.hrMax) bpm") {
                    Text(profile.hrMaxOverride > 0 ? "MANUAL" : "AUTOMÁTICA")
                        .font(StrandFont.overlineScaled(8))
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }

    private var systemPanel: some View {
        VWARPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("AMBIENTE DE EXECUÇÃO")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.2)
                    .foregroundStyle(VWAR26Palette.teal)
                VWARKeyValue(label: "Aplicativo", value: "VWAR Loop Life 11.1.0")
                VWARKeyValue(label: "Sistema mínimo", value: "iOS ou iPadOS 26")
                VWARKeyValue(label: "Idioma", value: "Português do Brasil")
                VWARKeyValue(label: "Edição", value: VWARDeviceEdition.current.shortLabel)
                VWARKeyValue(label: "Composição", value: VWARDeviceEdition.current.interfaceDescription)
                VWARKeyValue(label: "Processamento", value: "Local e privado")
            }
        }
    }

    private var healthStatusTitle: String {
        switch health.auth {
        case .authorized: return "Acesso autorizado"
        case .denied: return "Acesso não concedido"
        case .entitlementMissing: return "Assinatura sem direito ao app Saúde"
        case .unavailable: return "App Saúde indisponível"
        case .unknown: return "Pronto para autorização"
        }
    }

    private var healthStatusShort: String {
        switch health.auth {
        case .authorized: return "ATIVO"
        case .denied: return "NEGADO"
        case .entitlementMissing: return "SEM DIREITO"
        case .unavailable: return "INDISPONÍVEL"
        case .unknown: return "NÃO CONFIGURADO"
        }
    }

    private var healthStatusDetail: String {
        switch health.auth {
        case .authorized:
            return "O aplicativo pode ler somente as categorias que você aprovou e gravar métricas compatíveis quando permitido."
        case .denied:
            return "Revise as permissões em Ajustes, Privacidade e Segurança, Saúde, VWAR Loop Life."
        case .entitlementMissing:
            return "Um IPA assinado gratuitamente pode perder o direito HealthKit. Para integração completa, compile no Xcode com sua equipe e o recurso HealthKit habilitado."
        case .unavailable:
            return "Este aparelho ou ambiente não oferece HealthKit."
        case .unknown:
            return "A solicitação do sistema só aparece depois que você tocar em Ativar acesso."
        }
    }

    private var freshnessRange: String {
        guard let first = repo.freshness.earliestDay, let last = repo.freshness.latestDay else {
            return "Nenhum intervalo local disponível ainda."
        }
        return "Intervalo disponível: \(first) a \(last)."
    }

    private static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy 'às' HH:mm"
        return formatter
    }()
}

// MARK: - Componentes

private enum VWARAnalysisRange: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90
    var id: Int { rawValue }
    var label: String { "\(rawValue) DIAS" }
}

private struct VWARPageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) { identity; Spacer(minLength: 12); clock }
            VStack(alignment: .leading, spacing: 14) { identity; clock }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(StrandFont.overlineScaled(9))
                .tracking(1.4)
                .foregroundStyle(VWAR26Palette.teal)
            Text(title)
                .font(StrandFont.rounded(38, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(VWAR26Palette.text)
            Text(subtitle)
                .font(StrandFont.subhead)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .trailing, spacing: 3) {
                Text(Self.longDate.string(from: context.date).uppercased())
                    .font(StrandFont.overlineScaled(8))
                    .tracking(0.8)
                    .foregroundStyle(VWAR26Palette.tertiary)
                Text(Self.time.string(from: context.date))
                    .font(StrandFont.number(22))
                    .monospacedDigit()
                    .foregroundStyle(VWAR26Palette.text)
            }
        }
    }

    private static let longDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
        return formatter
    }()

    private static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct VWARRangePicker: View {
    @Binding var range: VWARAnalysisRange
    var body: some View {
        HStack(spacing: 7) {
            ForEach(VWARAnalysisRange.allCases) { item in
                Button(item.label) { range = item }
                    .buttonStyle(VWARRangeButtonStyle(active: range == item))
            }
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.selection, trigger: range)
    }
}

private struct VWARRangeButtonStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(9))
            .tracking(0.8)
            .foregroundStyle(active ? VWAR26Palette.base : VWAR26Palette.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(active ? VWAR26Palette.teal : VWAR26Palette.surface, in: Capsule())
            .overlay(Capsule().stroke(active ? VWAR26Palette.teal : VWAR26Palette.line))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct VWARPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VWAR26Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(VWAR26Palette.line))
    }
}

private struct VWARChartPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let minimumHeight: CGFloat
    let content: Content

    init(eyebrow: String, title: String, detail: String, minimumHeight: CGFloat,
         @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.detail = detail
        self.minimumHeight = minimumHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(1.1)
                    .foregroundStyle(VWAR26Palette.teal)
                Text(title)
                    .font(StrandFont.title2)
                    .foregroundStyle(VWAR26Palette.text)
                Text(detail)
                    .font(StrandFont.footnote)
                    .foregroundStyle(VWAR26Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .topLeading)
        .background(VWAR26Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(VWAR26Palette.line))
    }
}

private struct VWARMetricTile: View {
    let label: String
    let value: String
    let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(StrandFont.overlineScaled(8))
                .tracking(0.9)
                .foregroundStyle(VWAR26Palette.tertiary)
            Text(value)
                .font(StrandFont.number(20, weight: .semibold))
                .foregroundStyle(VWAR26Palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
            Rectangle().fill(accent).frame(height: 2)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
        .background(VWAR26Palette.plot, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(VWAR26Palette.line))
    }
}

private struct VWAREmptyState: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DADOS INSUFICIENTES")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.1)
                .foregroundStyle(VWAR26Palette.tertiary)
            Text(text)
                .font(StrandFont.subhead)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
        .background(VWAR26Palette.plot, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct VWARLegendRow: View {
    let items: [(String, Color)]
    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Rectangle().fill(item.1).frame(width: 17, height: 2)
                    Text(item.0)
                        .font(StrandFont.overlineScaled(7))
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }
}

struct VWARNotice: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StrandFont.overlineScaled(9))
                .tracking(1.2)
                .foregroundStyle(VWAR26Palette.amber)
            Text(text)
                .font(StrandFont.subhead)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VWAR26Palette.amber.opacity(0.065), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(VWAR26Palette.amber.opacity(0.22)))
    }
}

private struct VWARStatusPill: View {
    let text: String
    let active: Bool
    var body: some View {
        Text(text)
            .font(StrandFont.overlineScaled(8))
            .tracking(0.8)
            .foregroundStyle(active ? VWAR26Palette.base : VWAR26Palette.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(active ? VWAR26Palette.teal : VWAR26Palette.elevated, in: Capsule())
            .overlay(Capsule().stroke(active ? VWAR26Palette.teal : VWAR26Palette.line))
    }
}

private struct VWARActionButtonStyle: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(9))
            .tracking(0.8)
            .foregroundStyle(primary ? VWAR26Palette.base : VWAR26Palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(primary ? VWAR26Palette.teal : VWAR26Palette.elevated, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(primary ? VWAR26Palette.teal : VWAR26Palette.line))
            .opacity(configuration.isPressed ? 0.64 : 1)
    }
}

private struct VWARProfileRow<Control: View>: View {
    let label: String
    let value: String
    let control: Control

    init(label: String, value: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.value = value
        self.control = control()
    }
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(0.8)
                    .foregroundStyle(VWAR26Palette.tertiary)
                Text(value)
                    .font(StrandFont.bodyNumber)
                    .foregroundStyle(VWAR26Palette.text)
            }
            Spacer()
            control
        }
        .padding(.vertical, 4)
    }
}

private struct VWARKeyValue: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).font(StrandFont.subhead).foregroundStyle(VWAR26Palette.secondary)
            Spacer(minLength: 12)
            Text(value).font(StrandFont.body).foregroundStyle(VWAR26Palette.text).multilineTextAlignment(.trailing)
        }
    }
}

private enum VWARChartAxis {
    static var days: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .font(StrandFont.footnote)
                .foregroundStyle(VWAR26Palette.tertiary)
        }
    }

    static var percent: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded()))%")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }

    static var numeric: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded()))")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }

    static var hours: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(String(format: "%.0f h", number))
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }

    static var minutes: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded())) min")
                        .font(StrandFont.footnote)
                        .foregroundStyle(VWAR26Palette.tertiary)
                }
            }
        }
    }
}

private struct VWARTrendPoint: Identifiable {
    let key: String
    let date: Date
    let recovery: Double?
    let load: Double?
    let sleepScore: Double?
    let hrv: Double?
    let restingHeartRate: Double?
    let spo2: Double?
    let respiratoryRate: Double?
    var id: String { key }

    init?(_ day: DailyMetric) {
        guard let date = VWARDate.day.date(from: day.day) else { return nil }
        key = day.day
        self.date = date
        recovery = day.recovery
        load = day.strain
        sleepScore = day.efficiency.map { min(100, max(0, $0 <= 1.5 ? $0 * 100 : $0)) }
        hrv = day.avgHrv
        restingHeartRate = day.restingHr.map(Double.init)
        spo2 = day.spo2Pct
        respiratoryRate = day.respRateBpm
    }
}

private struct VWARSleepDay: Identifiable {
    let key: String
    let date: Date
    let minutes: Double?
    let efficiency: Double?
    let light: Double?
    let deep: Double?
    let rem: Double?
    var id: String { key }

    init?(_ day: DailyMetric) {
        guard let date = VWARDate.day.date(from: day.day) else { return nil }
        key = day.day
        self.date = date
        minutes = day.totalSleepMin
        efficiency = day.efficiency.map { min(100, max(0, $0 <= 1.5 ? $0 * 100 : $0)) }
        light = day.lightMin
        deep = day.deepMin
        rem = day.remMin
    }
}

private struct VWARSleepStageRow: Identifiable {
    let date: Date
    let stage: String
    let minutes: Double
    var id: String { "\(date.timeIntervalSince1970)-\(stage)" }
}

private struct VWARSleepTimingRow: Identifiable {
    let date: Date
    let startHour: Double
    let endHour: Double
    var id: Date { date }
}

private enum VWARDate {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func decimalHour(_ date: Date, unwrapped: Bool) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        var value = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        if unwrapped && value < 18 { value += 24 }
        return value
    }
}
#endif
