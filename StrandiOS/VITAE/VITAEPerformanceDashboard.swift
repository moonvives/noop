#if os(iOS)
import Charts
import StrandAnalytics
import StrandDesign
import SwiftUI
import WhoopStore

/// Central de sinais do VWAR Loop Life.
///
/// Os dois perfis de produto compartilham somente o carregamento e as métricas medidas. A edição para
/// iPhone privilegia leitura vertical e alcance com uma mão; a edição para iPad usa uma mesa de telemetria
/// com trilho persistente e painéis simultâneos. Nenhum estado visual cria valores de demonstração.
struct VITAEPerformanceDashboard: View {
    @EnvironmentObject private var repo: Repository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var range: RangeWindow = .days30
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var intelligenceFocus: VWARDailyFocus = .recovery
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

    private var isPadEdition: Bool { VWARDeviceEdition.current == .iPadProM2 }
    private var isCompact: Bool { !isPadEdition }
    private var chartHeight: CGFloat { isPadEdition ? 268 : 232 }

    var body: some View {
        ZStack {
            VWARSpectralBackground(reduceMotion: reduceMotion)

            ScrollView {
                Group {
                    if isPadEdition {
                        iPadCommandCenter
                    } else {
                        iPhoneTelemetryStream
                    }
                }
                .frame(maxWidth: isPadEdition ? 1_620 : 620)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 110)
            }
        }
        .preferredColorScheme(.dark)
        .task(id: "\(repo.refreshSeq)-\(range.rawValue)-\(selectedDayKey)") { await load() }
        .refreshable {
            await repo.refresh()
            await load()
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
        .sensoryFeedback(.selection, trigger: range)
        .sensoryFeedback(.selection, trigger: intelligenceFocus)
        .sensoryFeedback(.impact(weight: .light), trigger: selectedHRPoint?.id)
        .sensoryFeedback(.impact(weight: .light), trigger: selectedTrendPoint?.id)
    }

    // MARK: - Composições por produto

    private var iPhoneTelemetryStream: some View {
        VStack(alignment: .leading, spacing: 18) {
            phoneHeader
            phoneDayDeck
            phonePrimaryTelemetry
            vitalRibbon
            rangeSelector
            recoveryLoadPanel
            heartRatePanel
            intelligencePanel

            VWARSectionMarker(
                index: "02",
                title: "Sono e recuperação",
                detail: "Sinais registrados no app Saúde"
            )
            sleepArchitecturePanel
            hrvBaselinePanel
            sleepTimingPanel

            VWARSectionMarker(
                index: "03",
                title: "Contexto do dia",
                detail: "Movimento, equilíbrio e cobertura"
            )
            activityPanel
            balancePanel
            vitalMatrixPanel
            methodology
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var iPadCommandCenter: some View {
        VStack(alignment: .leading, spacing: 22) {
            iPadHeader

            HStack(alignment: .top, spacing: 20) {
                iPadTelemetryRail
                    .frame(width: 276)

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 20) {
                        iPadReadinessCore
                            .frame(width: 390)
                        heartRatePanel
                    }

                    HStack(alignment: .top, spacing: 20) {
                        recoveryLoadPanel
                        intelligencePanel
                    }

                    VWARSectionMarker(
                        index: "02",
                        title: "Matriz fisiológica",
                        detail: "Histórico real, inspecionável por toque ou ponteiro"
                    )

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 390), spacing: 20, alignment: .top),
                            GridItem(.flexible(minimum: 390), spacing: 20, alignment: .top),
                        ],
                        spacing: 20
                    ) {
                        hrvBaselinePanel
                        sleepTimingPanel
                        sleepArchitecturePanel
                        activityPanel
                        balancePanel
                        vitalMatrixPanel
                    }

                    methodology
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Cabeçalhos

    private var phoneHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    VWARLiveGlyph(color: VITAELuxury.spectralCyan)
                    Text("VWAR / SINAL DO DIA")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.8)
                        .foregroundStyle(VITAELuxury.spectralCyan)
                }
                Text("Seu dia,\nem sinais.")
                    .font(StrandFont.rounded(39, weight: .semibold))
                    .tracking(-1.2)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.longDateFormatter.string(from: selectedDay))
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textSecondary)
            }
            Spacer(minLength: 8)
            liveClock(alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private var iPadHeader: some View {
        HStack(alignment: .center, spacing: 18) {
            HStack(spacing: 14) {
                VWARLiveGlyph(color: VITAELuxury.spectralCyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text("VWAR LOOP LIFE")
                        .font(StrandFont.rounded(28, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text("CENTRAL FISIOLÓGICA / IPAD PRO 12,9")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.55)
                        .foregroundStyle(VITAELuxury.spectralCyan)
                }
            }
            Spacer(minLength: 24)
            Text(Self.longDateFormatter.string(from: selectedDay).uppercased())
                .font(StrandFont.overlineScaled(10))
                .tracking(1.15)
                .foregroundStyle(StrandPalette.textSecondary)
            Divider()
                .frame(height: 32)
                .overlay(VITAELuxury.border)
            liveClock(alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .contain)
    }

    private func liveClock(alignment: HorizontalAlignment) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: alignment, spacing: 3) {
                Text("HORA LOCAL")
                    .font(StrandFont.overlineScaled(7))
                    .tracking(1.1)
                    .foregroundStyle(StrandPalette.textTertiary)
                Text(Self.timeFormatter.string(from: context.date))
                    .font(StrandFont.number(isPadEdition ? 24 : 20, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(StrandPalette.textPrimary)
            }
        }
    }

    // MARK: - Navegação temporal

    private var phoneDayDeck: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button { moveWeek(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(VWARIconButtonStyle())
                .accessibilityLabel("Semana anterior")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(weekDates, id: \.self) { dayButton(for: $0, compact: true) }
                    }
                }

                Button { moveWeek(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(VWARIconButtonStyle())
                .disabled(!canMoveToNextWeek)
                .opacity(canMoveToNextWeek ? 1 : 0.3)
                .accessibilityLabel("Próxima semana")
            }
            Button("VOLTAR PARA HOJE") { selectToday() }
                .font(StrandFont.overlineScaled(8))
                .tracking(1.0)
                .foregroundStyle(
                    Calendar.current.isDateInToday(selectedDay)
                        ? StrandPalette.textTertiary
                        : VITAELuxury.spectralCyan
                )
                .disabled(Calendar.current.isDateInToday(selectedDay))
        }
        .padding(12)
        .background(VWARTitaniumShape(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(VITAELuxury.border)
        )
    }

    private var iPadTelemetryRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("LINHA DO TEMPO")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.35)
                    .foregroundStyle(VITAELuxury.spectralCyan)
                Spacer()
                Button("HOJE") { selectToday() }
                    .buttonStyle(
                        VWARTextCapsuleStyle(
                            active: Calendar.current.isDateInToday(selectedDay)
                        )
                    )
            }

            VStack(spacing: 7) {
                ForEach(weekDates, id: \.self) { dayButton(for: $0, compact: false) }
            }

            HStack(spacing: 8) {
                Button { moveWeek(-1) } label: {
                    Label("Anterior", systemImage: "chevron.left")
                }
                .buttonStyle(VWARTextCapsuleStyle())

                Button { moveWeek(1) } label: {
                    Label("Próxima", systemImage: "chevron.right")
                }
                .buttonStyle(VWARTextCapsuleStyle())
                .disabled(!canMoveToNextWeek)
                .opacity(canMoveToNextWeek ? 1 : 0.3)
            }

            Divider().overlay(VITAELuxury.border)

            Text("JANELA ANALÍTICA")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.35)
                .foregroundStyle(StrandPalette.textTertiary)

            VStack(spacing: 7) {
                ForEach(RangeWindow.allCases) { item in
                    Button {
                        updateRange(item)
                    } label: {
                        HStack {
                            Text(item.label)
                            Spacer()
                            if range == item { Image(systemName: "checkmark") }
                        }
                        .font(StrandFont.overlineScaled(9))
                        .tracking(0.8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(VWARTextCapsuleStyle(active: range == item))
                }
            }

            Divider().overlay(VITAELuxury.border)
            sourceStatus
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(minHeight: 760, alignment: .top)
        .background(VWARTitaniumShape(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(VITAELuxury.border)
        )
    }

    @ViewBuilder
    private func dayButton(for date: Date, compact: Bool) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDay)
        let future = date > Calendar.current.startOfDay(for: Date())
        Button {
            guard !future else { return }
            updateSelectedDay(date)
        } label: {
            if compact {
                VStack(spacing: 4) {
                    Text(Self.weekdayFormatter.string(from: date).uppercased())
                        .font(StrandFont.overlineScaled(7))
                    Text(Self.dayNumberFormatter.string(from: date))
                        .font(StrandFont.number(17, weight: .semibold))
                        .monospacedDigit()
                }
                .frame(width: 43, height: 54)
            } else {
                HStack(spacing: 12) {
                    Text(Self.weekdayFormatter.string(from: date).uppercased())
                        .font(StrandFont.overlineScaled(8))
                        .frame(width: 24, alignment: .leading)
                    Text(Self.dayNumberFormatter.string(from: date))
                        .font(StrandFont.number(17, weight: .semibold))
                        .monospacedDigit()
                    Spacer()
                    if Calendar.current.isDateInToday(date) {
                        Text("HOJE")
                            .font(StrandFont.overlineScaled(7))
                            .tracking(0.8)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .buttonStyle(
            VWARDayButtonStyle(
                selected: selected,
                accent: recoveryAccent(currentDay?.recovery)
            )
        )
        .disabled(future)
        .opacity(future ? 0.24 : 1)
        .accessibilityLabel(Self.longDateFormatter.string(from: date))
        .accessibilityValue(selected ? "Selecionado" : "")
    }

    private var rangeSelector: some View {
        HStack(spacing: 5) {
            ForEach(RangeWindow.allCases) { item in
                Button(item.label) { updateRange(item) }
                    .buttonStyle(VWARSegmentStyle(active: range == item))
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.26), in: Capsule())
        .overlay(Capsule().stroke(VITAELuxury.border))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Janela analítica")
    }

    private func updateSelectedDay(_ date: Date) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            selectedDay = Calendar.current.startOfDay(for: date)
        }
    }

    private func updateRange(_ item: RangeWindow) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            range = item
        }
    }

    // MARK: - Telemetria principal

    private var phonePrimaryTelemetry: some View {
        VStack(spacing: 12) {
            VWARReadinessCore(
                title: "RECUPERAÇÃO",
                value: currentDay?.recovery,
                accent: recoveryAccent(currentDay?.recovery),
                confidence: coverage(for: .recovery),
                compact: true,
                reduceMotion: reduceMotion
            )
            HStack(spacing: 12) {
                loadPlate
                sleepPlate
            }
        }
    }

    private var iPadReadinessCore: some View {
        VStack(alignment: .leading, spacing: 16) {
            VWARReadinessCore(
                title: "RECUPERAÇÃO",
                value: currentDay?.recovery,
                accent: recoveryAccent(currentDay?.recovery),
                confidence: coverage(for: .recovery),
                compact: false,
                reduceMotion: reduceMotion
            )
            HStack(spacing: 12) {
                loadPlate
                sleepPlate
            }
        }
    }

    private var loadPlate: some View {
        VWARMetricPlate(
            label: "CARGA",
            value: currentDay?.strain.map { String(format: "%.1f", $0) } ?? "—",
            unit: "/ 100",
            progress: currentDay?.strain.map { $0 / 100 },
            accent: VITAELuxury.spectralViolet,
            confidence: coverage(for: .strain)
        )
    }

    private var sleepPlate: some View {
        VWARMetricPlate(
            label: "SONO",
            value: currentSleepScore.map { String(Int($0.rounded())) } ?? "—",
            unit: "/ 100",
            progress: currentSleepScore.map { $0 / 100 },
            accent: VITAELuxury.spectralBlue,
            confidence: coverage(for: .sleep)
        )
    }

    private var vitalRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                VWARSignalChip(
                    label: "VFC",
                    value: currentDay?.avgHrv.map { "\(Int($0.rounded())) ms" },
                    color: VITAELuxury.spectralCyan
                )
                VWARSignalChip(
                    label: "FC REPOUSO",
                    value: currentDay?.restingHr.map { "\($0) bpm" },
                    color: VITAELuxury.spectralRose
                )
                VWARSignalChip(
                    label: "OXIGENAÇÃO",
                    value: currentDay?.spo2Pct.map { String(format: "%.1f%%", $0) },
                    color: VITAELuxury.spectralAmber
                )
                VWARSignalChip(
                    label: "PASSOS",
                    value: currentSteps.map(Self.compactNumber),
                    color: VITAELuxury.spectralViolet
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sinais do dia")
    }

    private var sourceStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ORIGEM DOS DADOS")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.35)
                .foregroundStyle(StrandPalette.textTertiary)
            Label("Saúde da Apple", systemImage: "heart.text.square.fill")
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textPrimary)
            Text("O painel exibe somente sinais já sincronizados e disponíveis no repositório local.")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Inteligência diária

    private var intelligencePanel: some View {
        VITAEPanel(
            eyebrow: "CONTEXTO PESSOAL",
            title: "Leitura do dia",
            value: dailyInsight.score.map { String(Int($0.rounded())) },
            detail: "Comparação determinística com até 28 dias do seu próprio histórico"
        ) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 6) {
                    ForEach(VWARDailyFocus.allCases) { focus in
                        Button(focusLabel(focus)) {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                                intelligenceFocus = focus
                            }
                        }
                        .buttonStyle(VWARSegmentStyle(active: intelligenceFocus == focus))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(intelligenceHeadline)
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(intelligenceSummary)
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let primary = dailyInsight.comparisons.first {
                    VWARComparisonStrip(
                        label: signalLabel(primary.metric),
                        current: signalValue(primary.current, metric: primary.metric),
                        baseline: signalValue(primary.baselineMedian, metric: primary.metric),
                        position: positionLabel(primary.position),
                        color: comparisonColor(primary)
                    )
                } else {
                    VITAEEmptyState(
                        "São necessários pelo menos cinco dias comparáveis para formar sua referência pessoal."
                    )
                }

                Text("Leitura descritiva, não diagnóstica. Ausências permanecem vazias.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Gráficos inspecionáveis

    private var heartRatePanel: some View {
        VITAEPanel(
            eyebrow: Calendar.current.isDateInToday(selectedDay) ? "HOJE" : Self.shortDateFormatter.string(from: selectedDay).uppercased(),
            title: "Frequência cardíaca",
            value: selectedHRPoint.map { "\(Int($0.bpm.rounded())) bpm" } ??
                hrPoints.last.map { "\(Int($0.bpm.rounded())) bpm" },
            detail: selectedHRPoint.map { Self.timeFormatter.string(from: $0.date) } ?? "Médias de cinco minutos"
        ) {
            if hrPoints.isEmpty {
                VITAEEmptyState("Sem frequência cardíaca registrada no dia selecionado.")
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
                .frame(height: chartHeight)
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
                .frame(height: chartHeight)
                .accessibilityLabel("Tendência de recuperação e carga")
            }
        }
    }

    private var hrvBaselinePanel: some View {
        let selection = selectedHrvPoint
        return VITAEPanel(
            eyebrow: "REFERÊNCIA PESSOAL",
            title: "VFC noturna",
            value: selection.map { "\(Int($0.value.rounded())) ms" },
            detail: selection.map { Self.shortDateFormatter.string(from: $0.date) } ??
                "Faixa interquartil móvel; valores ausentes permanecem ausentes"
        ) {
            if hrvPoints.isEmpty {
                VITAEEmptyState("São necessárias noites com intervalos R-R válidos para calcular VFC.")
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
                    LineMark(x: .value("Dia", point.date), y: .value("VFC", point.value))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(.init(lineWidth: 2.3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(VITAELuxury.teal)
                    PointMark(x: .value("Dia", point.date), y: .value("VFC", point.value))
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
                .frame(height: chartHeight)
                .accessibilityLabel("VFC noturna e faixa de referência pessoal")
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
                .frame(height: chartHeight)
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
                .frame(height: chartHeight)
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
                ?? "Cada ponto é um dia com as duas pontuações presentes"
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
                .frame(height: chartHeight)
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: isCompact ? 94 : 130), spacing: 12)], spacing: 12) {
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
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VITAELuxury.spectralCyan)
                .frame(width: 38, height: 38)
                .background(VITAELuxury.spectralCyan.opacity(0.09), in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                Text("MÉTODO E CONFIANÇA")
                    .font(StrandFont.overline)
                    .tracking(1.6)
                    .foregroundStyle(StrandPalette.textTertiary)
                Text("VFC usa RMSSD após filtragem de intervalos inválidos. Carga usa TRIMP e transformação logarítmica. Recuperação compara apenas suas referências. Toda pontuação exige dados mínimos; quando faltam sinais, o painel mostra ausência.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VWARTitaniumShape(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(VITAELuxury.border, lineWidth: 1))
    }

    // MARK: - Data

    private func load() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: selectedDay)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let end = min(Date(), nextDay.addingTimeInterval(-1))
        async let restSeries = repo.exploreSeries(key: "sleep_performance", source: "my-whoop")
        async let stepsSeries = repo.series(key: "steps", source: "apple-health")
        async let activeEnergySeries = repo.series(key: "active_kcal", source: "apple-health")
        async let distanceSeries = repo.series(key: "walking_running_km", source: "apple-health")
        async let buckets = repo.hrBuckets(
            from: Int(start.timeIntervalSince1970),
            to: Int(max(start, end).timeIntervalSince1970),
            bucketSeconds: 300
        )
        async let sessions = repo.allSleepSessions(days: max(90, range.rawValue + 7))
        let rest = await restSeries
        sleepPerformanceByDay = Dictionary(rest.map { ($0.day, $0.value) }, uniquingKeysWith: { _, newer in newer })
        let currentKey = selectedDayKey
        appleSteps = Self.value(for: currentKey, in: await stepsSeries)
        appleActiveEnergy = Self.value(for: currentKey, in: await activeEnergySeries)
        appleDistanceKm = Self.value(for: currentKey, in: await distanceSeries)
        hrPoints = (await buckets).map { IntradayPoint(date: Date(timeIntervalSince1970: TimeInterval($0.ts)), bpm: $0.bpm) }
        sleepSessions = await sessions
    }

    private var selectedDayKey: String { Repository.localDayKey(selectedDay) }

    private var currentDay: DailyMetric? {
        if let exact = repo.days.last(where: { $0.day == selectedDayKey }) { return exact }
        if Calendar.current.isDateInToday(selectedDay), repo.today?.day == selectedDayKey { return repo.today }
        return nil
    }

    private var currentSleepScore: Double? {
        guard let day = currentDay else { return nil }
        if let score = sleepPerformanceByDay[day.day] { return min(100, max(0, score)) }
        guard let efficiency = day.efficiency else { return nil }
        return min(100, max(0, efficiency <= 1.5 ? efficiency * 100 : efficiency))
    }

    private var trendDays: [DashboardDay] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: selectedDay) ?? .distantPast
        let selectedEnd = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay.addingTimeInterval(86_400)
        return repo.days.compactMap { day in
            guard let date = Self.dayFormatter.date(from: day.day),
                  date >= calendar.startOfDay(for: cutoff), date < selectedEnd else { return nil }
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
        let lower = selectedDay.addingTimeInterval(-16 * 86_400)
        let upper = selectedDay.addingTimeInterval(2 * 86_400)
        let recent = sleepSessions.filter {
            $0.endTs > Int(lower.timeIntervalSince1970) && $0.endTs < Int(upper.timeIntervalSince1970)
        }
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
        sleepSessions
            .filter {
                let end = Date(timeIntervalSince1970: TimeInterval($0.endTs))
                return Repository.localDayKey(end) == selectedDayKey
            }
            .max { $0.endTs < $1.endTs }
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

    private var currentSignalSnapshot: VWARDailySignals? {
        guard let day = currentDay else { return nil }
        return VWARDailySignals(
            day: day.day,
            recovery: day.recovery,
            load: day.strain,
            sleep: currentSleepScore,
            hrvMilliseconds: day.avgHrv,
            restingHeartRate: day.restingHr.map(Double.init),
            steps: currentSteps
        )
    }

    private var signalHistory: [VWARDailySignals] {
        repo.days.compactMap { day in
            guard let date = Self.dayFormatter.date(from: day.day), date <= selectedDay else { return nil }
            let sleep = sleepPerformanceByDay[day.day] ?? day.efficiency.map { $0 <= 1.5 ? $0 * 100 : $0 }
            return VWARDailySignals(
                day: day.day,
                recovery: day.recovery,
                load: day.strain,
                sleep: sleep,
                hrvMilliseconds: day.avgHrv,
                restingHeartRate: day.restingHr.map(Double.init),
                steps: day.steps.map(Double.init)
            )
        }
    }

    private var dailyInsight: VWARDailyInsight {
        VWARDailyIntelligence.analyze(
            current: currentSignalSnapshot,
            history: signalHistory,
            focus: intelligenceFocus
        )
    }

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

    private var weekDates: [Date] { Self.week(containing: selectedDay) }

    private var canMoveToNextWeek: Bool {
        guard let candidate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDay) else { return false }
        return Calendar.current.startOfDay(for: candidate) <= Calendar.current.startOfDay(for: Date())
    }

    private func moveWeek(_ direction: Int) {
        guard let candidate = Calendar.current.date(byAdding: .day, value: direction * 7, to: selectedDay) else { return }
        let today = Calendar.current.startOfDay(for: Date())
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
            selectedDay = min(today, Calendar.current.startOfDay(for: candidate))
        }
    }

    private func selectToday() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
            selectedDay = Calendar.current.startOfDay(for: Date())
        }
    }

    private func focusLabel(_ focus: VWARDailyFocus) -> String {
        switch focus {
        case .recovery: return "RECUPERAÇÃO"
        case .sleep: return "SONO"
        case .load: return "CARGA"
        }
    }

    private var intelligenceHeadline: String {
        guard dailyInsight.score != nil else {
            return "Sem leitura de \(focusLabel(intelligenceFocus).lowercased()) neste dia"
        }
        guard let position = dailyInsight.primaryPosition else {
            return "Referência de \(focusLabel(intelligenceFocus).lowercased()) em formação"
        }
        switch position {
        case .aboveBaseline: return "\(focusLabel(intelligenceFocus).capitalized) acima do seu padrão"
        case .nearBaseline: return "\(focusLabel(intelligenceFocus).capitalized) dentro do seu padrão"
        case .belowBaseline: return "\(focusLabel(intelligenceFocus).capitalized) abaixo do seu padrão"
        }
    }

    private var intelligenceSummary: String {
        guard dailyInsight.score != nil else {
            return "Nenhum valor foi estimado para preencher a ausência. Selecione outro dia ou sincronize uma fonte compatível."
        }
        guard let primary = dailyInsight.comparisons.first(where: { $0.metric == primaryMetric }) else {
            return "O valor do dia existe, mas ainda faltam dias comparáveis para formar uma referência pessoal estável."
        }
        let percent = Int((abs(primary.relativeDifference) * 100).rounded())
        let direction: String
        switch primary.position {
        case .aboveBaseline: direction = "acima"
        case .nearBaseline: direction = "próximo"
        case .belowBaseline: direction = "abaixo"
        }
        return "O valor está \(percent)% \(direction) da mediana de \(primary.referenceDays) dias comparáveis. Os sinais abaixo são contexto, não uma explicação causal."
    }

    private var intelligenceReferenceLabel: String {
        let days = dailyInsight.confidence.dayCount
        return days == 0 ? "SEM BASE" : "\(days) DIAS"
    }

    private var primaryMetric: VWARSignalMetric {
        switch intelligenceFocus {
        case .recovery: return .recovery
        case .sleep: return .sleep
        case .load: return .load
        }
    }

    private func signalLabel(_ metric: VWARSignalMetric) -> String {
        switch metric {
        case .recovery: return "RECUPERAÇÃO"
        case .load: return "CARGA"
        case .sleep: return "SONO"
        case .hrv: return "VFC"
        case .restingHeartRate: return "FC DE REPOUSO"
        case .steps: return "PASSOS"
        }
    }

    private func signalValue(_ value: Double, metric: VWARSignalMetric) -> String {
        switch metric {
        case .recovery, .load, .sleep: return "\(Int(value.rounded()))/100"
        case .hrv: return "\(Int(value.rounded())) ms"
        case .restingHeartRate: return "\(Int(value.rounded())) bpm"
        case .steps: return Self.compactNumber(value)
        }
    }

    private func positionLabel(_ position: VWARSignalPosition) -> String {
        switch position {
        case .aboveBaseline: return "ACIMA"
        case .nearBaseline: return "PADRÃO"
        case .belowBaseline: return "ABAIXO"
        }
    }

    private func comparisonColor(_ comparison: VWARSignalComparison) -> Color {
        if comparison.position == .nearBaseline { return VITAELuxury.blue }
        if comparison.metric == .load || comparison.metric == .steps { return VITAELuxury.violet }
        if comparison.metric == .restingHeartRate {
            return comparison.position == .belowBaseline ? VITAELuxury.teal : VITAELuxury.rose
        }
        return comparison.position == .aboveBaseline ? VITAELuxury.teal : VITAELuxury.rose
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
        value.dateFormat = "EEEE, d 'de' MMMM 'de' yyyy"
        return value
    }()

    private static func week(containing selectedDay: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "pt_BR")
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start
            ?? calendar.startOfDay(for: selectedDay)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private static let weekdayFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.dateFormat = "EEEEE"
        return value
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "pt_BR")
        value.dateFormat = "d"
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

// MARK: - Superfície visual VWAR

private struct VWARSpectralBackground: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
            GeometryReader { geometry in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let horizontalDrift = CGFloat(sin(phase * 0.08)) * 34
                let verticalDrift = CGFloat(cos(phase * 0.06)) * 24

                ZStack {
                    VITAELuxury.base

                    RadialGradient(
                        colors: [
                            VITAELuxury.spectralCyan.opacity(0.105),
                            VITAELuxury.spectralBlue.opacity(0.035),
                            .clear,
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: max(geometry.size.width, geometry.size.height) * 0.78
                    )
                    .offset(x: horizontalDrift, y: verticalDrift)

                    RadialGradient(
                        colors: [
                            VITAELuxury.spectralViolet.opacity(0.075),
                            .clear,
                        ],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.7
                    )
                    .offset(x: -horizontalDrift * 0.6, y: -verticalDrift)

                    Canvas { context, size in
                        let spacing: CGFloat = 42
                        var grid = Path()
                        var x: CGFloat = 0
                        while x <= size.width {
                            grid.move(to: CGPoint(x: x, y: 0))
                            grid.addLine(to: CGPoint(x: x, y: size.height))
                            x += spacing
                        }
                        var y: CGFloat = 0
                        while y <= size.height {
                            grid.move(to: CGPoint(x: 0, y: y))
                            grid.addLine(to: CGPoint(x: size.width, y: y))
                            y += spacing
                        }
                        context.stroke(grid, with: .color(.white.opacity(0.018)), lineWidth: 0.5)
                    }

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.32)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VWARTitaniumShape: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        VITAELuxury.titaniumTop,
                        VITAELuxury.panel,
                        VITAELuxury.titaniumBottom,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.13), .clear, .white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
    }
}

private struct VWARLiveGlyph: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.22), lineWidth: 1)
                .frame(width: 24, height: 24)
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.75), radius: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct VWARSectionMarker: View {
    let index: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(index)
                .font(StrandFont.number(13, weight: .semibold))
                .foregroundStyle(VITAELuxury.spectralCyan)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [VITAELuxury.spectralCyan.opacity(0.7), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 34, height: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(StrandFont.rounded(22, weight: .semibold))
                    .foregroundStyle(StrandPalette.textPrimary)
                Text(detail.uppercased())
                    .font(StrandFont.overlineScaled(8))
                    .tracking(1.0)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct VWARReadinessCore: View {
    let title: String
    let value: Double?
    let accent: Color
    let confidence: CoverageLevel
    let compact: Bool
    let reduceMotion: Bool

    private var progress: Double {
        min(1, max(0, (value ?? 0) / 100))
    }

    var body: some View {
        HStack(spacing: compact ? 20 : 26) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.045), lineWidth: compact ? 16 : 18)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                accent.opacity(0.22),
                                accent,
                                VITAELuxury.spectralBlue,
                                accent,
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(
                            lineWidth: compact ? 16 : 18,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.3), radius: 14)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
                    .padding(compact ? 25 : 29)

                VStack(spacing: -2) {
                    Text(value.map { String(Int($0.rounded())) } ?? "—")
                        .font(StrandFont.display(compact ? 52 : 62))
                        .tracking(StrandFont.displayTracking(compact ? 52 : 62))
                        .foregroundStyle(StrandPalette.textPrimary)
                        .contentTransition(.numericText())
                    Text("DE 100")
                        .font(StrandFont.overlineScaled(8))
                        .tracking(1.0)
                        .foregroundStyle(StrandPalette.textTertiary)
                }
            }
            .frame(width: compact ? 158 : 188, height: compact ? 158 : 188)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: accent.opacity(0.7), radius: 5)
                    Text(title)
                        .font(StrandFont.overlineScaled(10))
                        .tracking(1.35)
                        .foregroundStyle(StrandPalette.textSecondary)
                }
                Text(value == nil ? "Aguardando sinais" : "Referência pessoal")
                    .font(StrandFont.rounded(compact ? 18 : 21, weight: .semibold))
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(confidence.label)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(0.9)
                    .foregroundStyle(confidence.color)
                Text("VFC, repouso, sono e temperatura quando disponíveis.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 18 : 22)
        .frame(maxWidth: .infinity, minHeight: compact ? 204 : 236, alignment: .leading)
        .background(VWARTitaniumShape(cornerRadius: compact ? 26 : 30))
        .overlay(alignment: .top) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, accent.opacity(0.75), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: compact ? 180 : 220, height: 1)
        }
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 26 : 30, style: .continuous)
                .stroke(VITAELuxury.border)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.85), value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(value.map { "\(Int($0.rounded())) de 100, \(confidence.label)" } ?? "Sem dados")
    }
}

private struct VWARMetricPlate: View {
    let label: String
    let value: String
    let unit: String
    let progress: Double?
    let accent: Color
    let confidence: CoverageLevel

    private var clampedProgress: Double {
        min(1, max(0, progress ?? 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle().fill(accent).frame(width: 5, height: 5)
                Text(label)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(1.1)
                    .foregroundStyle(StrandPalette.textTertiary)
                Spacer()
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(StrandFont.number(28, weight: .semibold))
                    .foregroundStyle(StrandPalette.textPrimary)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(StrandFont.overlineScaled(7))
                    .foregroundStyle(StrandPalette.textTertiary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.055))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.35), accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * clampedProgress)
                        .shadow(color: accent.opacity(0.25), radius: 5)
                }
            }
            .frame(height: 4)

            Text(confidence.label)
                .font(StrandFont.overlineScaled(7))
                .tracking(0.75)
                .foregroundStyle(confidence.color)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .background(VWARTitaniumShape(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VITAELuxury.border)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value == "—" ? "Sem dados" : "\(value) \(unit)")
    }
}

private struct VWARSignalChip: View {
    let label: String
    let value: String?
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: 28)
                .shadow(color: color.opacity(0.4), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(StrandFont.overlineScaled(7))
                    .tracking(0.85)
                    .foregroundStyle(StrandPalette.textTertiary)
                Text(value ?? "Sem dados")
                    .font(StrandFont.bodyNumber)
                    .foregroundStyle(value == nil ? StrandPalette.textTertiary : StrandPalette.textPrimary)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(VWARTitaniumShape(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VITAELuxury.border)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct VWARComparisonStrip: View {
    let label: String
    let current: String
    let baseline: String
    let position: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(color)
                .frame(width: 3, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(0.9)
                    .foregroundStyle(StrandPalette.textTertiary)
                Text(current)
                    .font(StrandFont.number(19, weight: .semibold))
                    .foregroundStyle(StrandPalette.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(position)
                    .font(StrandFont.overlineScaled(8))
                    .tracking(0.9)
                    .foregroundStyle(color)
                Text("BASE \(baseline)")
                    .font(StrandFont.overlineScaled(7))
                    .tracking(0.65)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
        }
        .padding(13)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(VITAELuxury.border)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct VITAEPanel<Content: View>: View {
    let eyebrow: String
    let title: String
    let value: String?
    let detail: String
    let content: Content

    init(
        eyebrow: String,
        title: String,
        value: String?,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
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
                    HStack(spacing: 7) {
                        Rectangle()
                            .fill(VITAELuxury.spectralCyan)
                            .frame(width: 16, height: 1)
                        Text(eyebrow)
                            .font(StrandFont.overlineScaled(8))
                            .tracking(1.25)
                            .foregroundStyle(StrandPalette.textTertiary)
                    }
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
                        .contentTransition(.numericText())
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 350, alignment: .topLeading)
        .background(VWARTitaniumShape(cornerRadius: 24))
        .overlay(alignment: .topTrailing) {
            RadialGradient(
                colors: [VITAELuxury.spectralBlue.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 150
            )
            .frame(width: 210, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VITAELuxury.border, lineWidth: 1)
        )
    }
}

private struct VITAEEmptyState: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(VITAELuxury.spectralCyan.opacity(0.7))
            Text("SEM DADOS SUFICIENTES")
                .font(StrandFont.overlineScaled(9))
                .tracking(1.2)
                .foregroundStyle(StrandPalette.textTertiary)
            Text(message)
                .font(StrandFont.body)
                .foregroundStyle(StrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
        .padding(18)
        .background(
            Color.black.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VITAELuxury.border)
        )
    }
}

private struct VITAELegend: View {
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(color)
                .frame(width: 20, height: 3)
                .shadow(color: color.opacity(0.3), radius: 4)
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
        .background(
            Color.black.opacity(0.2),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VITAELuxury.border, lineWidth: 1)
        )
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

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
                spacing: 10
            ) {
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

            Text("A fonte informou totais por estágio, sem linha temporal. O app não inventa a ordem dos ciclos.")
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
                        Button {
                            selectedDate = column.date
                        } label: {
                            VStack(spacing: 8) {
                                Text(VITAEPerformanceDashboard.shortDateFormatter.string(from: column.date))
                                    .font(StrandFont.overlineScaled(7))
                                    .foregroundStyle(
                                        selectedDate == column.date
                                            ? .white
                                            : StrandPalette.textTertiary
                                    )
                                    .frame(height: 14)
                                ForEach(column.cells) { cell in
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(cell.color)
                                        .frame(width: 31, height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(
                                                    selectedDate == column.date
                                                        ? .white.opacity(0.45)
                                                        : .clear,
                                                    lineWidth: 1
                                                )
                                        )
                                        .accessibilityLabel("\(cell.metric.label), \(cell.displayValue)")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedDate)
    }
}

private struct VWARIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(StrandPalette.textSecondary)
            .frame(width: 36, height: 54)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VITAELuxury.border)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct VWARTextCapsuleStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(8))
            .tracking(0.75)
            .foregroundStyle(active ? VITAELuxury.base : StrandPalette.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                active ? VITAELuxury.spectralCyan : Color.black.opacity(0.24),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(active ? VITAELuxury.spectralCyan : VITAELuxury.border)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct VWARDayButtonStyle: ButtonStyle {
    let selected: Bool
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? VITAELuxury.base : StrandPalette.textSecondary)
            .background(
                selected ? accent : Color.black.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(selected ? accent : VITAELuxury.border)
            )
            .shadow(color: selected ? accent.opacity(0.18) : .clear, radius: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

private struct VWARSegmentStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.overlineScaled(8))
            .tracking(0.75)
            .foregroundStyle(active ? VITAELuxury.base : StrandPalette.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                active ? VITAELuxury.spectralCyan : Color.clear,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(active ? VITAELuxury.spectralCyan.opacity(0.9) : .clear)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
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
        case .hrv: return "VFC"
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
    static let base = Color(red: 0.014, green: 0.017, blue: 0.022)
    static let panel = Color(red: 0.044, green: 0.050, blue: 0.060)
    static let plot = Color(red: 0.024, green: 0.029, blue: 0.037)
    static let titaniumTop = Color(red: 0.075, green: 0.082, blue: 0.094)
    static let titaniumBottom = Color(red: 0.028, green: 0.033, blue: 0.041)
    static let border = Color.white.opacity(0.085)

    static let spectralCyan = Color(red: 0.38, green: 0.96, blue: 0.91)
    static let spectralBlue = Color(red: 0.34, green: 0.58, blue: 1.0)
    static let spectralViolet = Color(red: 0.68, green: 0.43, blue: 1.0)
    static let spectralRose = Color(red: 1.0, green: 0.31, blue: 0.52)
    static let spectralAmber = Color(red: 1.0, green: 0.72, blue: 0.29)

    // Aliases mantêm a semântica dos gráficos e dos estágios de sono.
    static let teal = spectralCyan
    static let blue = spectralBlue
    static let violet = spectralViolet
    static let rose = spectralRose
    static let amber = spectralAmber
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
