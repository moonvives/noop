import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case sources
    case importGuide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Visão geral"
        case .sources: return "Fontes"
        case .importGuide: return "Como importar"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .sources: return "point.3.connected.trianglepath.dotted"
        case .importGuide: return "square.and.arrow.down.fill"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: HealthArchiveModel
    @State private var selectedSection: DashboardSection = .overview
    @State private var presentsImporter = false

    var body: some View {
        ZStack {
            VWARPalette.background
                .ignoresSafeArea()

            HStack(spacing: 0) {
                sidebar
                Rectangle()
                    .fill(VWARPalette.stroke)
                    .frame(width: 1)
                content
            }

            if model.isImporting {
                loadingOverlay
            }
        }
        .frame(minWidth: 1_020, minHeight: 700)
        .fileImporter(
            isPresented: $presentsImporter,
            allowedContentTypes: [.zip, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    model.importArchive(from: url)
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert(isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Importação não concluída"),
                message: Text(model.errorMessage ?? "Tente novamente."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .vwarOpenHealthArchive)) { _ in
            presentsImporter = true
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                AppMark(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("VWAR LOOP LIFE")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .kerning(1.5)
                        .foregroundColor(.white)
                    Text("G Band no seu Mac")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(VWARPalette.secondaryText)
                }
            }
            .padding(.bottom, 34)

            VStack(spacing: 8) {
                ForEach(DashboardSection.allCases) { section in
                    SidebarButton(section: section, isSelected: selectedSection == section) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedSection = section
                        }
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Label("PROCESSAMENTO LOCAL", systemImage: "lock.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(VWARPalette.green)
                Text("Seu histórico não sai deste Mac. O app lê o arquivo e guarda somente o resumo.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(VWARPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VWARPalette.panel.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(VWARPalette.green.opacity(0.22), lineWidth: 1)
                    )
            )

            Text("Compatível com macOS 12.7.6+")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(VWARPalette.mutedText)
                .padding(.top, 16)
        }
        .padding(26)
        .frame(width: 270)
        .background(VWARPalette.sidebar)
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                Group {
                    switch selectedSection {
                    case .overview:
                        overview
                    case .sources:
                        sources
                    case .importGuide:
                        importGuide
                    }
                }
                .padding(34)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(selectedSection.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(model.statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(VWARPalette.secondaryText)
            }
            Spacer()
            Button {
                presentsImporter = true
            } label: {
                Label(model.summary == nil ? "Importar Saúde" : "Atualizar histórico", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(VWARPrimaryButtonStyle())
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 34)
        .frame(height: 82)
        .background(VWARPalette.background.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle().fill(VWARPalette.stroke).frame(height: 1)
        }
    }

    @ViewBuilder
    private var overview: some View {
        if let summary = model.summary {
            VStack(alignment: .leading, spacing: 24) {
                summaryHero(summary)
                sourceStrip(summary)

                HStack {
                    SectionTitle(
                        eyebrow: "TELEMETRIA DO ARQUIVO",
                        title: "Seus sinais mais recentes",
                        detail: "A origem indicada em cada cartão vem dos metadados da Saúde da Apple."
                    )
                    Spacer()
                }

                if summary.metrics.isEmpty {
                    EmptyMetricsCard()
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(summary.metrics) { metric in
                            MetricCard(metric: metric)
                        }
                    }
                }
            }
        } else {
            welcome
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("VWAR LOOP LIFE · MONTEREY")
                        .font(.system(size: 11, weight: .black))
                        .kerning(1.8)
                        .foregroundColor(VWARPalette.cyan)
                    Text("Seu G Band,\norganizado no Mac.")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Importe a exportação da Saúde da Apple para visualizar sinais do G Band e atividades do Strava em uma experiência feita para o macOS 12.7.6.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(VWARPalette.secondaryText)
                        .lineSpacing(5)
                        .frame(maxWidth: 580, alignment: .leading)

                    Button {
                        presentsImporter = true
                    } label: {
                        Label("Selecionar exportar.zip", systemImage: "folder.fill.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(VWARPrimaryButtonStyle())
                    .controlSize(.large)
                }
                Spacer(minLength: 10)
                TelemetryOrb()
                    .frame(width: 240, height: 240)
            }

            HStack(spacing: 14) {
                FlowCard(number: "01", title: "G Band", detail: "A pulseira envia seus dados ao app no iPhone.", icon: "waveform.path.ecg")
                FlowChevron()
                FlowCard(number: "02", title: "Saúde da Apple", detail: "A exportação reúne o histórico em um ZIP.", icon: "heart.fill")
                FlowChevron()
                FlowCard(number: "03", title: "VWAR no Mac", detail: "O resumo é calculado localmente e fica privado.", icon: "desktopcomputer")
            }
        }
    }

    private func summaryHero(_ summary: HealthArchiveSummary) -> some View {
        HStack(alignment: .center, spacing: 22) {
            AppMark(size: 70)
            VStack(alignment: .leading, spacing: 6) {
                Text("HISTÓRICO PRONTO")
                    .font(.system(size: 10, weight: .black))
                    .kerning(1.7)
                    .foregroundColor(VWARPalette.green)
                Text("VWAR Loop Life")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(rangeText(summary))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(VWARPalette.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(NumberFormatter.vwarDecimal.string(from: NSNumber(value: summary.recordCount)) ?? "\(summary.recordCount)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("REGISTROS LIDOS")
                    .font(.system(size: 9, weight: .black))
                    .kerning(1.3)
                    .foregroundColor(VWARPalette.mutedText)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VWARPalette.panel, VWARPalette.blue.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(VWARPalette.cyan.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func sourceStrip(_ summary: HealthArchiveSummary) -> some View {
        HStack(spacing: 14) {
            CompactSourceCard(origin: .gBand, count: summary.gBandRecords, emphasized: true)
            CompactSourceCard(origin: .strava, count: summary.stravaRecords, emphasized: false)
            CompactSourceCard(origin: .appleHealth, count: summary.appleHealthRecords, emphasized: false)
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 21))
                    .foregroundColor(VWARPalette.cyan)
                Text("\(summary.workoutCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("ATIVIDADES")
                    .font(.system(size: 9, weight: .black))
                    .kerning(1.1)
                    .foregroundColor(VWARPalette.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(CardBackground())
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle(
                eyebrow: "FLUXO DE DADOS",
                title: "Somente as suas fontes reais",
                detail: "O VWAR identifica G Band e Strava pelos metadados de origem de cada registro no XML."
            )

            if let summary = model.summary {
                SourceDetailCard(
                    origin: .gBand,
                    count: summary.gBandRecords,
                    headline: "Fonte principal",
                    explanation: "Sinais de saúde sincronizados pelo app G Band com a Saúde da Apple."
                )
                SourceDetailCard(
                    origin: .strava,
                    count: summary.stravaRecords,
                    headline: "Atividades",
                    explanation: "Treinos e atividades encontrados no arquivo com origem Strava."
                )
                SourceDetailCard(
                    origin: .appleHealth,
                    count: summary.appleHealthRecords,
                    headline: "Arquivo central",
                    explanation: "Registros do iPhone e entradas consolidadas pela Saúde da Apple."
                )

                Text("Quando G Band ou Strava não aparecem, o arquivo selecionado ainda não contém registros com essa origem. Sincronize no iPhone e faça uma nova exportação.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(VWARPalette.secondaryText)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CardBackground(stroke: VWARPalette.orange.opacity(0.28)))
            } else {
                NoArchiveCard(action: { presentsImporter = true })
            }
        }
    }

    private var importGuide: some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionTitle(
                eyebrow: "IMPORTAÇÃO SEGURA",
                title: "Do iPhone para o Mac",
                detail: "O acesso direto à Saúde da Apple não existe no macOS 12. O arquivo exportado preserva o histórico completo."
            )

            HStack(alignment: .top, spacing: 16) {
                GuideStep(number: "1", title: "Sincronize", detail: "Abra o app G Band no iPhone e confirme a sincronização com a Saúde da Apple.", symbol: "arrow.triangle.2.circlepath")
                GuideStep(number: "2", title: "Exporte", detail: "Na Saúde, abra seu perfil e escolha Exportar Todos os Dados de Saúde.", symbol: "square.and.arrow.up")
                GuideStep(number: "3", title: "Importe aqui", detail: "Envie o ZIP ao Mac e selecione-o no VWAR Loop Life.", symbol: "square.and.arrow.down")
            }

            VStack(alignment: .leading, spacing: 16) {
                Label("O que o aplicativo faz", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Divider().background(VWARPalette.stroke)
                ChecklistRow(text: "Lê ZIP e XML grandes de forma incremental, sem carregar tudo na memória.")
                ChecklistRow(text: "Classifica G Band, Strava e Saúde da Apple usando nome da fonte e dispositivo.")
                ChecklistRow(text: "Mostra métricas recentes, totais diários e período coberto pelo arquivo.")
                ChecklistRow(text: "Processa tudo localmente e não envia dados para a internet.")
            }
            .padding(22)
            .background(CardBackground())

            Button {
                presentsImporter = true
            } label: {
                Label("Abrir exportação de saúde", systemImage: "folder.fill")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(VWARPrimaryButtonStyle())
            .controlSize(.large)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: VWARPalette.cyan))
                    .scaleEffect(1.2)
                Text("Analisando seu histórico")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Arquivos grandes podem levar alguns minutos.")
                    .font(.system(size: 12))
                    .foregroundColor(VWARPalette.secondaryText)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(VWARPalette.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(VWARPalette.cyan.opacity(0.28), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 32, y: 12)
        }
    }

    private func rangeText(_ summary: HealthArchiveSummary) -> String {
        guard let first = summary.firstRecordDate, let last = summary.lastRecordDate else {
            return "Arquivo importado em \(VWARDateFormatters.dateTime.string(from: summary.importedAt))"
        }
        return "\(VWARDateFormatters.day.string(from: first)) — \(VWARDateFormatters.day.string(from: last))"
    }
}

private struct SidebarButton: View {
    let section: DashboardSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 20)
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if isSelected {
                    Circle().fill(VWARPalette.cyan).frame(width: 5, height: 5)
                }
            }
            .foregroundColor(isSelected ? .white : VWARPalette.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? VWARPalette.blue.opacity(0.24) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? VWARPalette.cyan.opacity(0.22) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SectionTitle: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .black))
                .kerning(1.6)
                .foregroundColor(VWARPalette.cyan)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(VWARPalette.secondaryText)
        }
    }
}

private struct MetricCard: View {
    let metric: MetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(metric.origin == .gBand ? VWARPalette.green : VWARPalette.cyan)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VWARPalette.blue.opacity(0.18)))
                Spacer()
                Text(metric.origin.title.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .kerning(1)
                    .foregroundColor(VWARPalette.mutedText)
            }
            Text(metric.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(VWARPalette.secondaryText)
            Text(metric.value)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.note)
                Text(VWARDateFormatters.dateTime.string(from: metric.recordedAt))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(VWARPalette.mutedText)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(CardBackground())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.title), \(metric.value), \(metric.origin.title)")
    }
}

private struct CompactSourceCard: View {
    let origin: VWARDataOrigin
    let count: Int
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: origin.systemImage)
                .font(.system(size: 20))
                .foregroundColor(emphasized ? VWARPalette.green : VWARPalette.cyan)
            Text(NumberFormatter.vwarDecimal.string(from: NSNumber(value: count)) ?? "\(count)")
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.white)
            Text(origin.title.uppercased())
                .font(.system(size: 9, weight: .black))
                .kerning(1.0)
                .foregroundColor(VWARPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CardBackground(stroke: emphasized ? VWARPalette.green.opacity(0.24) : VWARPalette.stroke))
    }
}

private struct SourceDetailCard: View {
    let origin: VWARDataOrigin
    let count: Int
    let headline: String
    let explanation: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: origin.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(origin == .gBand ? VWARPalette.green : VWARPalette.cyan)
                .frame(width: 54, height: 54)
                .background(Circle().fill(VWARPalette.blue.opacity(0.18)))
            VStack(alignment: .leading, spacing: 5) {
                Text(headline.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .kerning(1.4)
                    .foregroundColor(VWARPalette.mutedText)
                Text(origin.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(VWARPalette.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(count > 0 ? VWARPalette.green : VWARPalette.orange)
                        .frame(width: 7, height: 7)
                    Text(count > 0 ? "DETECTADO" : "NÃO ENCONTRADO")
                        .font(.system(size: 9, weight: .black))
                        .kerning(1.0)
                        .foregroundColor(count > 0 ? VWARPalette.green : VWARPalette.orange)
                }
                Text(NumberFormatter.vwarDecimal.string(from: NSNumber(value: count)) ?? "\(count)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                Text("registros")
                    .font(.system(size: 10))
                    .foregroundColor(VWARPalette.mutedText)
            }
        }
        .padding(22)
        .background(CardBackground(stroke: origin == .gBand ? VWARPalette.green.opacity(0.22) : VWARPalette.stroke))
    }
}

private struct GuideStep: View {
    let number: String
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(number)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(VWARPalette.background)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(VWARPalette.cyan))
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(VWARPalette.green)
            }
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(VWARPalette.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .padding(20)
        .background(CardBackground())
    }
}

private struct ChecklistRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(VWARPalette.green)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(VWARPalette.secondaryText)
        }
    }
}

private struct FlowCard: View {
    let number: String
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(number)
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(VWARPalette.cyan)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(VWARPalette.green)
            }
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(VWARPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(CardBackground())
    }
}

private struct FlowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(VWARPalette.mutedText)
            .frame(width: 14)
    }
}

private struct NoArchiveCard: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 34))
                .foregroundColor(VWARPalette.cyan)
            Text("Importe um arquivo para verificar as fontes")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Button("Selecionar arquivo", action: action)
                .buttonStyle(VWARPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 250)
        .background(CardBackground())
    }
}

private struct EmptyMetricsCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 24))
                .foregroundColor(VWARPalette.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Nenhuma métrica compatível encontrada")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("O arquivo foi lido, mas não contém os sinais exibidos neste painel.")
                    .font(.system(size: 12))
                    .foregroundColor(VWARPalette.secondaryText)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(stroke: VWARPalette.orange.opacity(0.25)))
    }
}

private struct AppMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [VWARPalette.blue.opacity(0.62), VWARPalette.green.opacity(0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(
                    LinearGradient(colors: [VWARPalette.cyan, VWARPalette.green], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.2
                )
                .padding(1)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: VWARPalette.cyan.opacity(0.22), radius: 16)
        .accessibilityHidden(true)
    }
}

private struct TelemetryOrb: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(VWARPalette.stroke, lineWidth: 1)
                .padding(4)
            Circle()
                .stroke(VWARPalette.cyan.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [5, 8]))
                .padding(25)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VWARPalette.blue.opacity(0.40), VWARPalette.panel.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 115
                    )
                )
            AppMark(size: 92)
            VStack {
                Spacer()
                Text("LOCAL · PRIVADO · NATIVO")
                    .font(.system(size: 8, weight: .black))
                    .kerning(1.2)
                    .foregroundColor(VWARPalette.mutedText)
                    .padding(.bottom, 28)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CardBackground: View {
    var stroke: Color = VWARPalette.stroke

    var body: some View {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
            .fill(VWARPalette.panel.opacity(0.78))
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

private struct VWARPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(VWARPalette.background)
            .padding(.horizontal, 17)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [VWARPalette.green, VWARPalette.cyan]
                                : [VWARPalette.cyan, VWARPalette.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum VWARPalette {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.060)
    static let sidebar = Color(red: 0.035, green: 0.047, blue: 0.075)
    static let panel = Color(red: 0.065, green: 0.082, blue: 0.115)
    static let stroke = Color.white.opacity(0.09)
    static let blue = Color(red: 0.13, green: 0.42, blue: 0.92)
    static let cyan = Color(red: 0.22, green: 0.86, blue: 0.98)
    static let green = Color(red: 0.35, green: 0.93, blue: 0.67)
    static let orange = Color(red: 1.0, green: 0.64, blue: 0.28)
    static let secondaryText = Color.white.opacity(0.68)
    static let mutedText = Color.white.opacity(0.40)
}

private enum VWARDateFormatters {
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension NumberFormatter {
    static let vwarDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
