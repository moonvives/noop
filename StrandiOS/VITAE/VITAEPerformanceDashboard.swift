#if os(iOS)
import Charts
import StrandAnalytics
import StrandDesign
import SwiftUI
import WhoopStore

/// The iPad-first daily command centre for VITAE One.
///
/// It uses the same measured Repository rows and audited analytics as the phone UI, but gives a 12.9-inch
/// display a denser information hierarchy: three honest scores, a scrub-able intraday HR trace, personal
/// baseline bands, sleep architecture/timing, training balance, and per-vital coverage. There is no demo
/// data in the runtime path. Missing input renders as an explicit empty state.
struct VITAEPerformanceDashboard: View {
    @EnvironmentObject private var repo: Repository

    @StateObject private var vwar = VWARCaptureManager()
    @State private var range: RangeWindow = .days30
    @State private var sleepPerformanceByDay: [String: Double] = [:]
    @State private var hrPoints: [IntradayPoint] = []
    @State private var sleepSessions: [CachedSleepSession] = []
    @State private var appleSteps: Double?
    @State private var appleActiveEnergy: Double?
    @State private var appleDistanceKm: Double?
    @State private var selectedHRDate: Date?
    @State private var selectedTrendDate: Date?
    @State private var selectedHrvDate: Date?
    @State private var selectedSleepDate: Date?
    @State private var selectedBalanceStrain: Double?
    @State private var selectedVitalDate: Date?
    @State private var showVWARResearch = false

    private let pagePadding: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                rangeSelector
                scoreGrid
                chartGrid
                methodology
                Color.clear.frame(height: 84)
            }
            .padding(.horizontal, pagePadding)
            .padding(.top, 22)
            .frame(maxWidth: 1_440)
            .frame(maxWidth: .infinity)
        }
        .background(VITAELuxury.base.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task(id: "\(repo.refreshSeq)-\(range.rawValue)") { await load() }
        .refreshable {
            await repo.refresh()
            await load()
        }
        .sheet(isPresented: $showVWARResearch) {
            VWARResearchView(manager: vwar)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("VITAE ONE")
                    .font(StrandFont.overline)
                    .tracking(2.5)
                    .foregroundStyle(VITAELuxury.teal)
                Text("Seu corpo, em contexto")
                    .font(StrandFont.rounded(38, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(Self.longDateFormatter.string(from: Date()))
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
            }
            Spacer(minLength: 18)
            VStack(alignment: .trailing, spacing: 10) {
                Button("VWAR DIRETO") { showVWARResearch = true }
                    .buttonStyle(VITAETextButtonStyle(active: vwar.phase.isActive))
                HStack(spacing: 9) {
                    Circle()
                        .fill(vwar.phase.isActive ? VITAELuxury.teal : StrandPalette.textTertiary)
                        .frame(width: 7, height: 7)
                    Text(vwar.phase.title)
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.2)
                        .foregroundStyle(StrandPalette.textSecondary)
                    if vwar.eventCount > 0 {
                        Text("\(vwar.eventCount) PACOTES")
                            .font(StrandFont.overlineScaled(9))
                            .tracking(1.2)
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(RangeWindow.allCases) { item in
                Button(item.label) {
                    withAnimation(.easeOut(duration: 0.22)) { range = item }
                }
                .buttonStyle(VITAERangeButtonStyle(active: range == item))
            }
            Spacer()
            Text("ARRASTE OS GRÁFICOS PARA INSPECIONAR")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.1)
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    // MARK: - Scores

    private var scoreGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 285), spacing: 16)], spacing: 16) {
            PremiumScoreCard(
                title: "RECUPERAÇÃO",
                value: currentDay?.recovery,
                scale: 100,
                accent: recoveryAccent(currentDay?.recovery),
                confidence: coverage(for: .recovery),
                description: "Baseline pessoal de HRV, FC de repouso, sono e temperatura."
            )
            PremiumScoreCard(
                title: "CARGA",
                value: currentDay?.strain,
                scale: 100,
                accent: VITAELuxury.violet,
                confidence: coverage(for: .strain),
                description: "TRIMP logarítmico calculado apenas sobre frequência cardíaca registrada."
            )
            PremiumScoreCard(
                title: "SONO",
                value: currentSleepScore,
                scale: 100,
                accent: VITAELuxury.blue,
                confidence: coverage(for: .sleep),
                description: "Duração, eficiência e arquitetura disponíveis para a noite mais recente."
            )
        }
    }

    // MARK: - Charts

    private var chartGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 430), spacing: 16, alignment: .top)], spacing: 16) {
            heartRatePanel
            recoveryLoadPanel
            hrvBaselinePanel
            sleepTimingPanel
            sleepArchitecturePanel
            balancePanel
            vitalMatrixPanel
            activityPanel
        }
    }

    private var heartRatePanel: some View {
        VITAEPanel(
            eyebrow: "HOJE",
            title: "Frequência cardíaca",
            value: selectedHRPoint.map { "\(Int($0.bpm.rounded())) bpm" } ??
                hrPoints.last.map { "\(Int($0.bpm.rounded())) bpm" },
            detail: selectedHRPoint.map { Self.timeFormatter.string(from: $0.date) } ?? "Médias de cinco minutos"
        ) {
            if hrPoints.isEmpty {
                VITAEEmptyState("Sem frequência cardíaca registrada hoje.")
            } else {
                Chart(hrPoints) { point in
                    AreaMark(x: .value("Hora", point.date), y: .value("BPM", point.bpm))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VITAELuxury.rose.opacity(0.32), VITAELuxury.rose.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Hora", point.date), y: .value("BPM", point.bpm))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(VITAELuxury.rose)
                    if let selectedHRDate, selectedHRPoint?.id == point.id {
                        RuleMark(x: .value("Seleção", selectedHRDate))
                            .foregroundStyle(.white.opacity(0.24))
                        PointMark(x: .value("Hora", point.date), y: .value("BPM", point.bpm))
                            .symbolSize(58)
                            .foregroundStyle(.white)
                    }
                }
                .chartXSelection(value: $selectedHRDate)
                .chartXAxis { VITAEChartAxis.time }
                .chartYAxis { VITAEChartAxis.numeric(suffix: "") }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 250)
                .accessibilityLabel("Frequência cardíaca de hoje")
            }
        }
    }

    private var recoveryLoadPanel: some View {
        let selection = selectedTrendPoint
        return VITAEPanel(
            eyebrow: range.label,
            title: "Capacidade e carga",
            value: selection?.recovery.map { "\(Int($0.rounded())) rec" },
            detail: selection.map { Self.shortDateFormatter.string(from: $0.date) } ??
                "Recuperação e carga na mesma escala de 0 a 100"
        ) {
            if trendDays.allSatisfy({ $0.recovery == nil && $0.strain == nil }) {
                VITAEEmptyState("Ainda não há dias calculados para esta janela.")
            } else {
                HStack(spacing: 18) {
                    VITAELegend(label: "RECUPERAÇÃO", color: VITAELuxury.teal)
                    VITAELegend(label: "CARGA", color: VITAELuxury.violet)
                }
                Chart {
                    ForEach(trendDays) { point in
                        if let recovery = point.recovery {
                            LineMark(x: .value("Dia", point.date), y: .value("Recuperação", recovery), series: .value("Série", "Recuperação"))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(VITAELuxury.teal)
                        }
                        if let strain = point.strain {
                            LineMark(x: .value("Dia", point.date), y: .value("Carga", strain), series: .value("Série", "Carga"))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(.init(lineWidth: 2.1, lineCap: .round, lineJoin: .round, dash: [5, 4]))
                                .foregroundStyle(VITAELuxury.violet)
                        }
                    }
                    if let selectedTrendDate {
                        RuleMark(x: .value("Seleção", selectedTrendDate))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                }
                .chartXSelection(value: $selectedTrendDate)
                .chartYScale(domain: 0...100)
                .chartXAxis { VITAEChartAxis.days }
                .chartYAxis { VITAEChartAxis.numeric(suffix: "") }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 234)
                .accessibilityLabel("Tendência de recuperação e carga")
            }
        }
    }

    private var hrvBaselinePanel: some View {
        let selection = selectedHrvPoint
        return VITAEPanel(
            eyebrow: "BASELINE PESSOAL",
            title: "HRV noturna",
            value: selection.map { "\(Int($0.value.rounded())) ms" },
            detail: selection.map { Self.shortDateFormatter.string(from: $0.date) } ??
                "Faixa interquartil móvel; valores ausentes permanecem ausentes"
        ) {
            if hrvPoints.isEmpty {
                VITAEEmptyState("São necessárias noites com intervalos R-R válidos para calcular HRV.")
            } else {
                Chart(hrvPoints) { point in
                    if let low = point.low, let high = point.high {
                        AreaMark(
                            x: .value("Dia", point.date),
                            yStart: .value("Base inferior", low),
                            yEnd: .value("Base superior", high)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(VITAELuxury.teal.opacity(0.12))
                    }
                    LineMark(x: .value("Dia", point.date), y: .value("HRV", point.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(VITAELuxury.teal)
                    PointMark(x: .value("Dia", point.date), y: .value("HRV", point.value))
                        .symbolSize(point.id == selectedHrvPoint?.id ? 54 : 10)
                        .foregroundStyle(point.id == selectedHrvPoint?.id ? .white : VITAELuxury.teal.opacity(0.72))
                    if let selectedHrvDate, point.id == selectedHrvPoint?.id {
                        RuleMark(x: .value("Seleção", selectedHrvDate))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
                .chartXSelection(value: $selectedHrvDate)
                .chartXAxis { VITAEChartAxis.days }
                .chartYAxis { VITAEChartAxis.numeric(suffix: " ms") }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 250)
                .accessibilityLabel("HRV noturna e faixa de baseline pessoal")
            }
        }
    }

    private var sleepTimingPanel: some View {
        let selection = selectedSleepWindow
        return VITAEPanel(
            eyebrow: "ÚLTIMAS 14 NOITES",
            title: "Regularidade do sono",
            value: selection.map { "\(Self.timeFormatter.string(from: $0.start))–\(Self.timeFormatter.string(from: $0.end))" },
            detail: selection.map { Self.shortDateFormatter.string(from: $0.date) } ??
                "Horário real de início e término do bloco principal"
        ) {
            if sleepWindows.isEmpty {
                VITAEEmptyState("Nenhuma janela de sono registrada.")
            } else {
                Chart(sleepWindows) { window in
                    RectangleMark(
                        x: .value("Dia", window.date),
                        yStart: .value("Dormiu", window.startHour),
                        yEnd: .value("Acordou", window.endHour),
                        width: .fixed(window.id == selectedSleepWindow?.id ? 14 : 9)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(
                        LinearGradient(colors: [VITAELuxury.blue, VITAELuxury.violet], startPoint: .bottom, endPoint: .top)
                    )
                }
                .chartXSelection(value: $selectedSleepDate)
                .chartYScale(domain: 18...36)
                .chartXAxis { VITAEChartAxis.days }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [18, 21, 24, 27, 30, 33, 36]) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.06))
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(String(format: "%02d:00", hour % 24))
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textTertiary)
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 250)
                .accessibilityLabel("Regularidade dos horários de sono")
            }
        }
    }

    private var sleepArchitecturePanel: some View {
        VITAEPanel(
            eyebrow: "NOITE MAIS RECENTE",
            title: "Arquitetura do sono",
            value: latestSleepDuration,
            detail: sleepSegments.isEmpty
                ? "A composição só aparece quando há estágios registrados"
                : "Linha temporal derivada apenas dos estágios presentes no registro"
        ) {
            if !sleepSegments.isEmpty {
                Chart(sleepSegments) { segment in
                    RectangleMark(
                        xStart: .value("Início", segment.start),
                        xEnd: .value("Fim", segment.end),
                        y: .value("Estágio", segment.stage.label)
                    )
                    .foregroundStyle(segment.stage.color)
                }
                .chartXAxis { VITAEChartAxis.time }
                .chartYAxis {
                    AxisMarks(values: SleepStageKind.axisOrder.map(\.label)) { _ in
                        AxisValueLabel()
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
                }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 250)
                .accessibilityLabel("Linha temporal dos estágios de sono")
            } else if let composition = currentSleepComposition {
                SleepCompositionBar(composition: composition)
                    .frame(minHeight: 205)
            } else {
                VITAEEmptyState("Sem estágios de sono válidos para esta noite.")
            }
        }
    }

    private var balancePanel: some View {
        let selection = selectedBalancePoint
        return VITAEPanel(
            eyebrow: range.label,
            title: "Balanço de treinamento",
            value: selection.map { "\(Int($0.strain.rounded())) carga" },
            detail: selection.map { "\(Int($0.recovery.rounded())) recuperação • \(Self.shortDateFormatter.string(from: $0.date))" }
                ?? "Cada ponto é um dia com os dois scores presentes"
        ) {
            if balancePoints.isEmpty {
                VITAEEmptyState("São necessários dias com recuperação e carga.")
            } else {
                Chart {
                    RuleMark(x: .value("Carga mediana", balanceStrainMedian))
                        .foregroundStyle(.white.opacity(0.09))
                    RuleMark(y: .value("Recuperação mediana", balanceRecoveryMedian))
                        .foregroundStyle(.white.opacity(0.09))
                    ForEach(balancePoints) { point in
                        PointMark(x: .value("Carga", point.strain), y: .value("Recuperação", point.recovery))
                            .symbolSize(point.id == selection?.id ? 96 : 44)
                            .foregroundStyle(balanceColor(point))
                    }
                }
                .chartXSelection(value: $selectedBalanceStrain)
                .chartXScale(domain: 0...100)
                .chartYScale(domain: 0...100)
                .chartXAxis { VITAEChartAxis.numeric(suffix: "") }
                .chartYAxis { VITAEChartAxis.numeric(suffix: "") }
                .chartPlotStyle { $0.background(VITAELuxury.plot).clipped() }
                .frame(height: 250)
                .accessibilityLabel("Dispersão entre carga e recuperação")
            }
        }
    }

    private var vitalMatrixPanel: some View {
        VITAEPanel(
            eyebrow: "DESVIOS DO SEU PADRÃO",
            title: "Vitais em 14 dias",
            value: selectedVitalColumn.map { Self.shortDateFormatter.string(from: $0.date) },
            detail: "Cor indica desvio relativo; cinza indica ausência de medição"
        ) {
            if vitalColumns.isEmpty {
                VITAEEmptyState("Ainda não há vitais suficientes para criar a matriz.")
            } else {
                VitalMatrix(columns: vitalColumns, selectedDate: $selectedVitalDate)
                    .frame(minHeight: 220)
            }
        }
    }

    private var activityPanel: some View {
        VITAEPanel(
            eyebrow: "MOVIMENTO",
            title: "Atividade diária",
            value: currentSteps.map(Self.compactNumber),
            detail: "Passos e energia vêm da fonte registrada; valores estimados são identificados"
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    MetricReadout(label: "PASSOS", value: currentSteps.map(Self.compactNumber) ?? "—")
                    MetricReadout(label: "ENERGIA ATIVA", value: currentActiveEnergy.map { "\(Int($0.rounded())) kcal" } ?? "—")
                    MetricReadout(label: "DISTÂNCIA", value: currentDistance.map { String(format: "%.1f km", $0) } ?? "—")
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("LEITURA CLÍNICA")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.1)
                        .foregroundStyle(StrandPalette.textTertiary)
                    Text("ECG, pressão arterial e glicose de pulso não entram em recuperação, carga, sono ou recomendações. Use equipamento médico para decisões de saúde.")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(VITAELuxury.plot, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .frame(minHeight: 205, alignment: .top)
        }
    }

    private var methodology: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MÉTODO E CONFIANÇA")
                .font(StrandFont.overline)
                .tracking(1.6)
                .foregroundStyle(StrandPalette.textTertiary)
            Text("VITAE calcula HRV por RMSSD após filtragem de intervalos inválidos e ectópicos. A carga usa TRIMP e transformação logarítmica. A recuperação compara seus próprios baselines, não uma tabela genérica. Toda pontuação exige dados mínimos; quando faltam sinais, o app mostra ausência em vez de inventar um resultado.")
                .font(StrandFont.body)
                .foregroundStyle(StrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VITAELuxury.border, lineWidth: 1))
    }

    // MARK: - Data

    private func load() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        async let restSeries = repo.exploreSeries(key: "sleep_performance", source: "my-whoop")
        async let stepsSeries = repo.series(key: "steps", source: "apple-health")
        async let activeEnergySeries = repo.series(key: "active_kcal", source: "apple-health")
        async let distanceSeries = repo.series(key: "walking_running_km", source: "apple-health")
        async let buckets = repo.hrBuckets(
            from: Int(start.timeIntervalSince1970),
            to: Int(Date().timeIntervalSince1970),
            bucketSeconds: 300
        )
        async let sessions = repo.allSleepSessions(days: max(90, range.rawValue + 7))
        let rest = await restSeries
        sleepPerformanceByDay = Dictionary(rest.map { ($0.day, $0.value) }, uniquingKeysWith: { _, newer in newer })
        let currentKey = currentDay?.day ?? Repository.localDayKey(Date())
        appleSteps = Self.value(for: currentKey, in: await stepsSeries)
        appleActiveEnergy = Self.value(for: currentKey, in: await activeEnergySeries)
        appleDistanceKm = Self.value(for: currentKey, in: await distanceSeries)
        hrPoints = (await buckets).map { IntradayPoint(date: Date(timeIntervalSince1970: TimeInterval($0.ts)), bpm: $0.bpm) }
        sleepSessions = await sessions
    }

    private var currentDay: DailyMetric? { repo.today ?? repo.days.last }

    private var currentSleepScore: Double? {
        guard let day = currentDay else { return nil }
        if let score = sleepPerformanceByDay[day.day] { return min(100, max(0, score)) }
        guard let efficiency = day.efficiency else { return nil }
        return min(100, max(0, efficiency <= 1.5 ? efficiency * 100 : efficiency))
    }

    private var trendDays: [DashboardDay] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1), to: Date()) ?? .distantPast
        return repo.days.compactMap { day in
            guard let date = Self.dayFormatter.date(from: day.day), date >= Calendar.current.startOfDay(for: cutoff) else { return nil }
            let sleep = sleepPerformanceByDay[day.day] ?? day.efficiency.map { $0 <= 1.5 ? $0 * 100 : $0 }
            return DashboardDay(
                key: day.day,
                date: date,
                recovery: day.recovery,
                strain: day.strain,
                sleep: sleep,
                hrv: day.avgHrv,
                rhr: day.restingHr.map(Double.init),
                spo2: day.spo2Pct,
                temperature: day.skinTempDevC
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var selectedHRPoint: IntradayPoint? { Self.nearest(hrPoints, to: selectedHRDate) }
    private var selectedTrendPoint: DashboardDay? { Self.nearest(trendDays, to: selectedTrendDate) }

    private var hrvPoints: [BaselinePoint] {
        let full = repo.days.compactMap { day -> (String, Date, Double)? in
            guard let date = Self.dayFormatter.date(from: day.day), let value = day.avgHrv else { return nil }
            return (day.day, date, value)
        }.sorted { $0.1 < $1.1 }
        let visibleKeys = Set(trendDays.map(\.key))
        return full.enumerated().compactMap { index, item in
            guard visibleKeys.contains(item.0) else { return nil }
            let history = Array(full[max(0, index - 28)..<index].map(\.2))
            let band = history.count >= 7 ? Self.interquartileRange(history) : nil
            return BaselinePoint(key: item.0, date: item.1, value: item.2, low: band?.0, high: band?.1)
        }
    }

    private var selectedHrvPoint: BaselinePoint? { Self.nearest(hrvPoints, to: selectedHrvDate) }

    private var sleepWindows: [SleepWindowPoint] {
        let recent = sleepSessions.filter { $0.endTs > Int(Date().addingTimeInterval(-16 * 86_400).timeIntervalSince1970) }
        var longestByDay: [String: CachedSleepSession] = [:]
        for session in recent {
            let date = Date(timeIntervalSince1970: TimeInterval(session.endTs))
            let key = Self.dayFormatter.string(from: date)
            let duration = session.endTs - session.effectiveStartTs
            if duration > (longestByDay[key].map { $0.endTs - $0.effectiveStartTs } ?? -1) { longestByDay[key] = session }
        }
        return longestByDay.compactMap { key, session in
            guard let date = Self.dayFormatter.date(from: key) else { return nil }
            let start = Date(timeIntervalSince1970: TimeInterval(session.effectiveStartTs))
            let end = Date(timeIntervalSince1970: TimeInterval(session.endTs))
            return SleepWindowPoint(key: key, date: date, start: start, end: end,
                                    startHour: Self.unwrappedHour(start), endHour: Self.unwrappedHour(end))
        }.sorted { $0.date < $1.date }
    }

    private var selectedSleepWindow: SleepWindowPoint? { Self.nearest(sleepWindows, to: selectedSleepDate) }

    private var latestSleepSession: CachedSleepSession? {
        sleepSessions.max { $0.endTs < $1.endTs }
    }

    private var sleepSegments: [SleepStagePoint] {
        guard let session = latestSleepSession, let json = session.stagesJSON,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([StageDTO].self, from: data) else { return [] }
        return decoded.compactMap { dto in
            guard dto.end > dto.start, let stage = SleepStageKind(rawValue: dto.stage.lowercased()) else { return nil }
            return SleepStagePoint(start: Date(timeIntervalSince1970: TimeInterval(dto.start)),
                                   end: Date(timeIntervalSince1970: TimeInterval(dto.end)), stage: stage)
        }.sorted { $0.start < $1.start }
    }

    private var latestSleepDuration: String? {
        guard let session = latestSleepSession else { return nil }
        let minutes = max(0, session.endTs - session.effectiveStartTs) / 60
        return "\(minutes / 60)h \(minutes % 60)min"
    }

    private var currentSleepComposition: SleepComposition? {
        guard let day = currentDay else { return nil }
        let composition = SleepComposition(
            awake: max(0, (day.totalSleepMin ?? 0) / max(day.efficiency ?? 1, 0.01) - (day.totalSleepMin ?? 0)),
            light: max(0, day.lightMin ?? 0),
            deep: max(0, day.deepMin ?? 0),
            rem: max(0, day.remMin ?? 0)
        )
        return composition.total > 0 ? composition : nil
    }

    private var balancePoints: [BalancePoint] {
        trendDays.compactMap { day in
            guard let recovery = day.recovery, let strain = day.strain else { return nil }
            return BalancePoint(key: day.key, date: day.date, strain: strain, recovery: recovery)
        }
    }

    private var selectedBalancePoint: BalancePoint? {
        guard let selectedBalanceStrain else { return nil }
        return balancePoints.min { abs($0.strain - selectedBalanceStrain) < abs($1.strain - selectedBalanceStrain) }
    }

    private var balanceStrainMedian: Double { Self.median(balancePoints.map(\.strain)) ?? 50 }
    private var balanceRecoveryMedian: Double { Self.median(balancePoints.map(\.recovery)) ?? 50 }

    private var vitalColumns: [VitalColumn] {
        Array(trendDays.suffix(14)).map { day in
            VitalColumn(
                key: day.key,
                date: day.date,
                cells: [
                    VitalCell(metric: .hrv, value: day.hrv, deviation: Self.robustDeviation(day.hrv, population: trendDays.compactMap(\.hrv), inverse: false)),
                    VitalCell(metric: .rhr, value: day.rhr, deviation: Self.robustDeviation(day.rhr, population: trendDays.compactMap(\.rhr), inverse: true)),
                    VitalCell(metric: .spo2, value: day.spo2, deviation: Self.robustDeviation(day.spo2, population: trendDays.compactMap(\.spo2), inverse: false)),
                    VitalCell(metric: .temperature, value: day.temperature, deviation: day.temperature.map { -min(2, abs($0) / 0.5) })
                ]
            )
        }
    }

    private var selectedVitalColumn: VitalColumn? { Self.nearest(vitalColumns, to: selectedVitalDate) }

    private var currentSteps: Double? { appleSteps ?? currentDay?.steps.map { Double($0) } }
    private var currentActiveEnergy: Double? { appleActiveEnergy ?? currentDay?.activeKcalEst }
    private var currentDistance: Double? { appleDistanceKm }

    private enum CoverageMetric { case recovery, strain, sleep }

    private func coverage(for metric: CoverageMetric) -> CoverageLevel {
        let recent = Array(repo.days.suffix(28))
        let count: Int
        switch metric {
        case .recovery: count = recent.compactMap(\.recovery).count
        case .strain: count = recent.compactMap(\.strain).count
        case .sleep: count = recent.filter { sleepPerformanceByDay[$0.day] != nil || $0.efficiency != nil }.count
        }
        switch count {
        case 14...: return .solid(count)
        case 7..<14: return .building(count)
        case 1..<7: return .calibrating(count)
        default: return .missing
        }
    }

    private func recoveryAccent(_ value: Double?) -> Color {
        guard let value else { return StrandPalette.textTertiary }
        if value < 34 { return VITAELuxury.rose }
        if value < 67 { return VITAELuxury.amber }
        return VITAELuxury.teal
    }

    private func balanceColor(_ point: BalancePoint) -> Color {
        if point.recovery >= balanceRecoveryMedian && point.strain <= balanceStrainMedian { return VITAELuxury.teal }
        if point.recovery < balanceRecoveryMedian && point.strain > balanceStrainMedian { return VITAELuxury.rose }
        return VITAELuxury.violet
    }

    // MARK: - Pure helpers

    private static func nearest<T: DatedPoint>(_ points: [T], to date: Date?) -> T? {
        guard let date else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func percentile(_ values: [Double], _ p: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = min(Double(sorted.count - 1), max(0, p * Double(sorted.count - 1)))
        let lower = Int(index.rounded(.down)), upper = Int(index.rounded(.up))
        if lower == upper { return sorted[lower] }
        let fraction = index - Double(lower)
        return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
    }

    private static func interquartileRange(_ values: [Double]) -> (Double, Double)? {
        guard let q1 = percentile(values, 0.25), let q3 = percentile(values, 0.75) else { return nil }
        return (q1, q3)
    }

    private static func robustDeviation(_ value: Double?, population: [Double], inverse: Bool) -> Double? {
        guard let value, let center = median(population), population.count >= 5 else { return nil }
        let deviations = population.map { abs($0 - center) }
        guard let mad = median(deviations), mad > 0.0001 else { return 0 }
        let z = (value - center) / (1.4826 * mad)
        return min(2, max(-2, inverse ? -z : z))
    }

    private static func unwrappedHour(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        var value = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        if value < 12 { value += 24 }
        return value
    }

    private static func compactNumber(_ value: Double) -> String {
        if value >= 10_000 { return String(format: "%.1f mil", value / 1_000) }
        return NumberFormatter.localizedString(from: NSNumber(value: Int(value.rounded())), number: .decimal)
    }

    private static func value(for day: String, in rows: [(day: String, value: Double)]) -> Double? {
        rows.last(where: { $0.day == day })?.value
    }

    private static let dayFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.dateFormat = "yyyy-MM-dd"
        return value
    }()

    private static let longDateFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.dateFormat = "EEEE, d 'de' MMMM"
        return value
    }()

    fileprivate static let shortDateFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.dateFormat = "d MMM"
        return value
    }()

    private static let timeFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.dateFormat = "HH:mm"
        return value
    }()
}

// MARK: - Research sheet

private struct VWARResearchView: View {
    @ObservedObject var manager: VWARCaptureManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    status
                    safety
                    controls
                    deviceList
                    captureSummary
                    decodedMetrics
                    evidence
                    export
                }
                .padding(24)
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .background(VITAELuxury.base.ignoresSafeArea())
            .navigationTitle("VWAR direto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VITAELuxury.base, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("FECHAR") { dismiss() }
                        .font(StrandFont.overlineScaled(10))
                        .tracking(1.1)
                        .foregroundStyle(VITAELuxury.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var status: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(manager.phase.title)
                    .font(StrandFont.overline)
                    .tracking(1.5)
                    .foregroundStyle(manager.phase.isActive ? VITAELuxury.teal : StrandPalette.textSecondary)
                if let detail = manager.phase.detail {
                    Text(detail)
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textSecondary)
                }
            }
            Spacer()
            if manager.eventCount > 0 {
                Text("\(manager.eventCount) eventos")
                    .font(StrandFont.bodyNumber)
                    .foregroundStyle(StrandPalette.textPrimary)
            }
        }
    }

    private var safety: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTURA CLEAN-ROOM")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.2)
                .foregroundStyle(VITAELuxury.amber)
            Text("O VITAE somente lê características anunciadas e assina notificações. Ele não envia comandos proprietários, não altera firmware e não atribui significado médico a bytes desconhecidos.")
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(VITAELuxury.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VITAELuxury.amber.opacity(0.24)))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(manager.phase == .scanning ? "BUSCANDO" : "BUSCAR DISPOSITIVOS") { manager.startScan() }
                .buttonStyle(VITAETextButtonStyle(active: manager.phase == .scanning))
                .disabled(manager.phase == .scanning)
            Button("PARAR") { manager.stopCapture() }
                .buttonStyle(VITAETextButtonStyle(active: false))
                .disabled(!manager.phase.isActive)
        }
    }

    @ViewBuilder private var deviceList: some View {
        if !manager.devices.isEmpty {
            sectionTitle("DISPOSITIVOS PRÓXIMOS")
            VStack(spacing: 0) {
                ForEach(manager.devices) { device in
                    Button { manager.connect(to: device.id) } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(StrandFont.headline)
                                    .foregroundStyle(StrandPalette.textPrimary)
                                Text(device.isLikelyVWAR ? "COMPATIBILIDADE PROVÁVEL" : "DISPOSITIVO BLE NÃO IDENTIFICADO")
                                    .font(StrandFont.overlineScaled(8))
                                    .tracking(1.0)
                                    .foregroundStyle(device.isLikelyVWAR ? VITAELuxury.teal : StrandPalette.textTertiary)
                            }
                            Spacer()
                            Text("\(device.rssi) dBm")
                                .font(StrandFont.mono(11))
                                .foregroundStyle(StrandPalette.textSecondary)
                            Text("CONECTAR")
                                .font(StrandFont.overlineScaled(9))
                                .tracking(1.0)
                                .foregroundStyle(VITAELuxury.teal)
                        }
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if device.id != manager.devices.last?.id {
                        Rectangle().fill(VITAELuxury.border).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    @ViewBuilder private var captureSummary: some View {
        if manager.eventCount > 0 || manager.serviceCount > 0 {
            sectionTitle("INVENTÁRIO")
            HStack(spacing: 12) {
                MetricReadout(label: "SERVIÇOS", value: "\(manager.serviceCount)")
                MetricReadout(label: "CARACTERÍSTICAS", value: "\(manager.characteristicCount)")
                MetricReadout(label: "EVENTOS", value: "\(manager.eventCount)")
            }
        }
    }

    @ViewBuilder private var decodedMetrics: some View {
        if !manager.liveMetrics.isEmpty {
            sectionTitle("MÉTRICAS PADRÃO BLE")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                ForEach(manager.liveMetrics) { metric in
                    MetricReadout(
                        label: metric.label,
                        value: metric.kind == .batteryPercent
                            ? "\(Int(metric.value.rounded()))%"
                            : "\(Int(metric.value.rounded())) \(metric.unit)"
                    )
                }
            }
        }
    }

    @ViewBuilder private var evidence: some View {
        if !manager.evidence.isEmpty {
            sectionTitle("EVIDÊNCIA POR CARACTERÍSTICA")
            VStack(spacing: 0) {
                ForEach(manager.evidence.prefix(18)) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(item.key.serviceUUID) / \(item.key.characteristicUUID)")
                            .font(StrandFont.mono(11, weight: .medium))
                            .foregroundStyle(StrandPalette.textPrimary)
                            .textSelection(.enabled)
                        Text("\(item.key.operation.rawValue.uppercased()) • \(item.observationCount) amostras • \(item.uniquePayloadCount) cargas únicas • bytes variáveis: \(item.changingByteOffsets.map(String.init).joined(separator: ", "))")
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    if item.id != manager.evidence.prefix(18).last?.id {
                        Rectangle().fill(VITAELuxury.border).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var export: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("EXPORTAÇÃO PRIVADA")
            Text("O arquivo de pesquisa remove o identificador do periférico e notas, mas preserva os bytes necessários para criar decodificadores testáveis.")
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textSecondary)
            HStack(spacing: 10) {
                Button("GERAR JSON REDIGIDO") { manager.exportRedactedTranscript() }
                    .buttonStyle(VITAETextButtonStyle(active: false))
                    .disabled(manager.eventCount == 0)
                if let url = manager.exportURL {
                    ShareLink(item: url) {
                        Text("COMPARTILHAR ARQUIVO")
                    }
                    .buttonStyle(VITAETextButtonStyle(active: true))
                }
            }
            if let error = manager.lastExportError {
                Text(error).font(StrandFont.footnote).foregroundStyle(VITAELuxury.rose)
            }
        }
    }

    private func sectionTitle(_ value: String) -> some View {
        Text(value)
            .font(StrandFont.overlineScaled(9))
            .tracking(1.2)
            .foregroundStyle(StrandPalette.textTertiary)
            .padding(.top, 2)
    }
}

// MARK: - Visual components

private struct PremiumScoreCard: View {
    let title: String
    let value: Double?
    let scale: Double
    let accent: Color
    let confidence: CoverageLevel
    let description: String

    var body: some View {
        HStack(spacing: 20) {
            ScoreArc(value: value, scale: scale, accent: accent)
                .frame(width: 130, height: 130)
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(StrandFont.overline)
                    .tracking(1.5)
                    .foregroundStyle(StrandPalette.textSecondary)
                Text(confidence.label)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(1.0)
                    .foregroundStyle(confidence.color)
                Text(description)
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 174, alignment: .leading)
        .background(VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VITAELuxury.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value.map { String(Int($0.rounded())) } ?? "sem dados"), \(confidence.label)")
    }
}

private struct ScoreArc: View {
    let value: Double?
    let scale: Double
    let accent: Color

    private var progress: Double { min(1, max(0, (value ?? 0) / scale)) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(.white.opacity(0.07), style: .init(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .trim(from: 0.08, to: 0.08 + 0.84 * progress)
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.45), accent], center: .center),
                    style: .init(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .shadow(color: accent.opacity(0.23), radius: 10)
            VStack(spacing: -1) {
                Text(value.map { String(Int($0.rounded())) } ?? "—")
                    .font(StrandFont.display(44))
                    .tracking(StrandFont.displayTracking(44))
                    .foregroundStyle(StrandPalette.textPrimary)
                Text("DE \(Int(scale))")
                    .font(StrandFont.overlineScaled(8))
                    .tracking(1.0)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
        .animation(.easeOut(duration: 0.6), value: progress)
    }
}

private struct VITAEPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let value: String?
    let detail: String
    let content: Content

    init(eyebrow: String, title: String, value: String?, detail: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.value = value
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(eyebrow)
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.25)
                        .foregroundStyle(StrandPalette.textTertiary)
                    Text(title)
                        .font(StrandFont.title2)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text(detail)
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(StrandFont.number(20, weight: .semibold))
                        .foregroundStyle(StrandPalette.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 356, alignment: .topLeading)
        .background(VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VITAELuxury.border, lineWidth: 1))
    }
}

private struct VITAEEmptyState: View {
    let message: String
    init(_ message: String) { self.message = message }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SEM DADOS SUFICIENTES")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.2)
                .foregroundStyle(StrandPalette.textTertiary)
            Text(message)
                .font(StrandFont.body)
                .foregroundStyle(StrandPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .center)
        .padding(18)
        .background(VITAELuxury.plot, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct VITAELegend: View {
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 7) {
            Rectangle().fill(color).frame(width: 20, height: 2)
            Text(label)
                .font(StrandFont.overlineScaled(8))
                .tracking(1.0)
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }
}

private struct MetricReadout: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(StrandFont.overlineScaled(8))
                .tracking(1.0)
                .foregroundStyle(StrandPalette.textTertiary)
            Text(value)
                .font(StrandFont.number(19, weight: .semibold))
                .foregroundStyle(StrandPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VITAELuxury.plot, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VITAELuxury.border, lineWidth: 1))
    }
}

private struct SleepCompositionBar: View {
    let composition: SleepComposition
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(composition.parts) { part in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(part.stage.color)
                            .frame(width: max(3, geometry.size.width * part.value / composition.total))
                    }
                }
            }
            .frame(height: 54)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(composition.parts) { part in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(part.stage.label.uppercased())
                            .font(StrandFont.overlineScaled(8))
                            .tracking(1.0)
                            .foregroundStyle(part.stage.color)
                        Text("\(Int(part.value / 60))h \(Int(part.value.truncatingRemainder(dividingBy: 60)))min")
                            .font(StrandFont.bodyNumber)
                            .foregroundStyle(StrandPalette.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text("A fonte informou totais por estágio, sem linha temporal. O VITAE não inventa a ordem dos ciclos.")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
        }
        .padding(.vertical, 18)
    }
}

private struct VitalMatrix: View {
    let columns: [VitalColumn]
    @Binding var selectedDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Color.clear.frame(height: 22)
                ForEach(VitalMetric.allCases) { metric in
                    Text(metric.label)
                        .font(StrandFont.overlineScaled(8))
                        .tracking(0.8)
                        .foregroundStyle(StrandPalette.textTertiary)
                        .frame(height: 30)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(columns) { column in
                        Button { selectedDate = column.date } label: {
                            VStack(spacing: 8) {
                                Text(VITAEPerformanceDashboard.shortDateFormatter.string(from: column.date))
                                    .font(StrandFont.overlineScaled(7))
                                    .foregroundStyle(selectedDate == column.date ? .white : StrandPalette.textTertiary)
                                    .frame(height: 14)
                                ForEach(column.cells) { cell in
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(cell.color)
                                        .frame(width: 31, height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(selectedDate == column.date ? .white.opacity(0.45) : .clear, lineWidth: 1)
                                        )
                                        .accessibilityLabel("\(cell.metric.label), \(cell.displayValue)")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct VITAETextButtonStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(10))
            .tracking(1.1)
            .foregroundStyle(active ? VITAELuxury.base : StrandPalette.textPrimary)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(active ? VITAELuxury.teal : VITAELuxury.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(active ? VITAELuxury.teal : VITAELuxury.border))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private struct VITAERangeButtonStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(9))
            .tracking(1.0)
            .foregroundStyle(active ? VITAELuxury.base : StrandPalette.textSecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(active ? VITAELuxury.teal : VITAELuxury.panel, in: Capsule())
            .overlay(Capsule().stroke(active ? VITAELuxury.teal : VITAELuxury.border))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Models and styling

private protocol DatedPoint { var date: Date { get } }

private enum RangeWindow: Int, CaseIterable, Identifiable {
    case days7 = 7, days30 = 30, days90 = 90
    var id: Int { rawValue }
    var label: String { "\(rawValue) DIAS" }
}

private struct DashboardDay: Identifiable, DatedPoint {
    let key: String
    let date: Date
    let recovery: Double?
    let strain: Double?
    let sleep: Double?
    let hrv: Double?
    let rhr: Double?
    let spo2: Double?
    let temperature: Double?
    var id: String { key }
}

private struct IntradayPoint: Identifiable, DatedPoint {
    let date: Date
    let bpm: Double
    var id: Date { date }
}

private struct BaselinePoint: Identifiable, DatedPoint {
    let key: String
    let date: Date
    let value: Double
    let low: Double?
    let high: Double?
    var id: String { key }
}

private struct SleepWindowPoint: Identifiable, DatedPoint {
    let key: String
    let date: Date
    let start: Date
    let end: Date
    let startHour: Double
    let endHour: Double
    var id: String { key }
}

private struct BalancePoint: Identifiable, DatedPoint {
    let key: String
    let date: Date
    let strain: Double
    let recovery: Double
    var id: String { key }
}

private struct StageDTO: Decodable { let start: Int; let end: Int; let stage: String }

private enum SleepStageKind: Hashable, CaseIterable {
    case awake, rem, light, deep

    init?(rawValue: String) {
        switch rawValue {
        case "wake", "awake": self = .awake
        case "rem": self = .rem
        case "light", "sleep": self = .light
        case "deep": self = .deep
        default: return nil
        }
    }

    static let axisOrder: [SleepStageKind] = [.deep, .light, .rem, .awake]
    var label: String {
        switch self {
        case .awake: return "Acordado"
        case .rem: return "REM"
        case .light: return "Leve"
        case .deep: return "Profundo"
        }
    }
    var color: Color {
        switch self {
        case .awake: return StrandPalette.textTertiary
        case .rem: return VITAELuxury.violet
        case .light: return VITAELuxury.blue
        case .deep: return Color(red: 0.18, green: 0.28, blue: 0.62)
        }
    }
}

private struct SleepStagePoint: Identifiable {
    let start: Date
    let end: Date
    let stage: SleepStageKind
    var id: String { "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)-\(stage.label)" }
}

private struct SleepComposition {
    struct Part: Identifiable {
        let stage: SleepStageKind
        let value: Double
        var id: SleepStageKind { stage }
    }

    let awake: Double
    let light: Double
    let deep: Double
    let rem: Double
    var total: Double { awake + light + deep + rem }
    var parts: [Part] {
        [Part(stage: .awake, value: awake), Part(stage: .light, value: light),
         Part(stage: .deep, value: deep), Part(stage: .rem, value: rem)]
            .filter { $0.value > 0 }
    }
}

private enum CoverageLevel {
    case missing, calibrating(Int), building(Int), solid(Int)
    var label: String {
        switch self {
        case .missing: return "SEM DADOS"
        case .calibrating(let days): return "CALIBRANDO • \(days) DIAS"
        case .building(let days): return "EM CONSTRUÇÃO • \(days) DIAS"
        case .solid(let days): return "COBERTURA SÓLIDA • \(days) DIAS"
        }
    }
    var color: Color {
        switch self {
        case .missing: return StrandPalette.textTertiary
        case .calibrating: return VITAELuxury.amber
        case .building: return VITAELuxury.blue
        case .solid: return VITAELuxury.teal
        }
    }
}

private enum VitalMetric: String, CaseIterable, Identifiable {
    case hrv, rhr, spo2, temperature
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hrv: return "HRV"
        case .rhr: return "FC REPOUSO"
        case .spo2: return "SpO₂"
        case .temperature: return "TEMP"
        }
    }
}

private struct VitalCell: Identifiable {
    let metric: VitalMetric
    let value: Double?
    let deviation: Double?
    var id: String { metric.rawValue }
    var color: Color {
        guard let deviation else { return .white.opacity(0.055) }
        if deviation < -0.6 { return VITAELuxury.rose.opacity(min(0.9, 0.34 + abs(deviation) * 0.24)) }
        if deviation > 0.6 { return VITAELuxury.teal.opacity(min(0.9, 0.34 + deviation * 0.24)) }
        return VITAELuxury.blue.opacity(0.24)
    }
    var displayValue: String {
        guard let value else { return "sem medição" }
        switch metric {
        case .hrv: return "\(Int(value.rounded())) milissegundos"
        case .rhr: return "\(Int(value.rounded())) batimentos por minuto"
        case .spo2: return String(format: "%.1f por cento", value)
        case .temperature: return String(format: "%+.2f graus Celsius", value)
        }
    }
}

private struct VitalColumn: Identifiable, DatedPoint {
    let key: String
    let date: Date
    let cells: [VitalCell]
    var id: String { key }
}

private enum VITAELuxury {
    static let base = Color(red: 0.035, green: 0.043, blue: 0.052)
    static let panel = Color(red: 0.065, green: 0.078, blue: 0.094)
    static let plot = Color(red: 0.042, green: 0.052, blue: 0.064)
    static let border = Color.white.opacity(0.075)
    static let teal = Color(red: 0.45, green: 0.89, blue: 0.81)
    static let blue = Color(red: 0.38, green: 0.60, blue: 1.0)
    static let violet = Color(red: 0.61, green: 0.48, blue: 1.0)
    static let rose = Color(red: 1.0, green: 0.37, blue: 0.49)
    static let amber = Color(red: 0.98, green: 0.73, blue: 0.34)
}

private enum VITAEChartAxis {
    static var time: some AxisContent {
        AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel(format: .dateTime.hour().minute())
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    static var days: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
        }
    }

    static func numeric(suffix: String) -> some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            AxisGridLine().foregroundStyle(.white.opacity(0.055))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(Int(number.rounded()))\(suffix)")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
            }
        }
    }
}
#endif
