#if os(iOS)
import Foundation
import SwiftUI
import StrandDesign

/// Navegação principal exclusiva do iOS/iPadOS 26.
///
/// A superfície antiga expunha dezenas de telas compartilhadas com o macOS e, por isso, misturava
/// idiomas e hierarquias. A experiência VWAR 11 mantém quatro destinos objetivos, todos em pt-BR,
/// sem dados demonstrativos e sem ícones decorativos.
struct RootTabView: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var router: NavRouter
    @AppStorage("vwar.looplife.abaSelecionada") private var selectedTab = 0

    var body: some View {
        Group {
            if VWARDeviceEdition.current.usesCommandRail {
                iPadCommandShell
            } else {
                iPhoneCommandShell
            }
        }
        .background(VWAR26Palette.base.ignoresSafeArea())
        .task { await repo.refresh() }
        .onChange(of: router.requestedDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .trends:
                selectedTab = 1
            case .devices, .fusedRecord, .insightsHub, .labBook, .rhythm:
                selectedTab = 3
            case .activeWorkout, .liveSession:
                selectedTab = 0
            }
            router.requestedDestination = nil
        }
        .onChange(of: router.quickActionsRequested) { _, requested in
            guard requested else { return }
            selectedTab = 3
            router.quickActionsRequested = false
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private var iPhoneCommandShell: some View {
        ZStack(alignment: .bottom) {
            destinations
            VWARPortugueseTabBar(selection: $selectedTab) {
                Task { await repo.refresh() }
            }
        }
    }

    private var iPadCommandShell: some View {
        HStack(spacing: 0) {
            VWARiPadCommandRail(selection: $selectedTab) {
                Task { await repo.refresh() }
            }
            .frame(width: 236)

            Rectangle()
                .fill(VWAR26Palette.line)
                .frame(width: 1)

            destinations
        }
    }

    private var destinations: some View {
        TabView(selection: $selectedTab) {
            raiz(VITAEPerformanceDashboard()).tag(0)
            raiz(VWARTrendsView()).tag(1)
            raiz(VWARSleepIntelligenceView()).tag(2)
            raiz(VWARSourcesView()).tag(3)
        }
        .toolbar(.hidden, for: .tabBar)
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28), value: selectedTab)
    }

    private func raiz<Content: View>(_ content: Content) -> some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .background(VWAR26Palette.base.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

enum VWAR26Palette {
    static let base = Color(red: 0.025, green: 0.032, blue: 0.041)
    static let surface = Color(red: 0.055, green: 0.067, blue: 0.082)
    static let elevated = Color(red: 0.075, green: 0.090, blue: 0.108)
    static let plot = Color(red: 0.035, green: 0.044, blue: 0.055)
    static let line = Color.white.opacity(0.09)
    static let teal = Color(red: 0.42, green: 0.92, blue: 0.82)
    static let blue = Color(red: 0.35, green: 0.61, blue: 1.0)
    static let violet = Color(red: 0.64, green: 0.49, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.31)
    static let rose = Color(red: 1.0, green: 0.37, blue: 0.50)
    static let text = Color.white.opacity(0.96)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.39)
}

private struct VWARPortugueseTabBar: View {
    @Binding var selection: Int
    let onReselect: () -> Void

    private let items = ["HOJE", "TENDÊNCIAS", "SONO", "FONTES"]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items.indices, id: \.self) { index in
                let active = selection == index
                Button {
                    if active {
                        onReselect()
                    } else {
                        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
                            selection = index
                        }
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text(items[index])
                            .font(StrandFont.overlineScaled(index == 1 ? 8 : 9))
                            .tracking(index == 1 ? 0.55 : 0.9)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Rectangle()
                            .fill(active ? VWAR26Palette.teal : .clear)
                            .frame(height: 2)
                    }
                    .foregroundStyle(active ? VWAR26Palette.teal : VWAR26Palette.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(items[index].capitalized)
                .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(VWAR26Palette.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(VWAR26Palette.line))
        .padding(.horizontal, 12)
        .padding(.bottom, 7)
    }
}

private struct VWARiPadCommandRail: View {
    @Binding var selection: Int
    let onReselect: () -> Void

    private let items: [(String, String)] = [
        ("HOJE", "Comando diário"),
        ("TENDÊNCIAS", "Séries e relações"),
        ("SONO", "Arquitetura noturna"),
        ("FONTES", "Origem e sincronização"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("VWAR LOOP LIFE")
                    .font(StrandFont.overline)
                    .tracking(2.1)
                    .foregroundStyle(VWAR26Palette.teal)
                Text("CENTRAL 12,9")
                    .font(StrandFont.number(22, weight: .semibold))
                    .foregroundStyle(VWAR26Palette.text)
                Text("iPadOS 26 · M2")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.0)
                    .foregroundStyle(VWAR26Palette.tertiary)
            }
            .padding(.horizontal, 18)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.date.string(from: context.date).uppercased())
                        .font(StrandFont.overlineScaled(8))
                        .tracking(0.8)
                        .foregroundStyle(VWAR26Palette.tertiary)
                    Text(Self.time.string(from: context.date))
                        .font(StrandFont.number(34, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(VWAR26Palette.text)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VWAR26Palette.plot, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VWAR26Palette.line))
            }
            .padding(.horizontal, 10)

            VStack(spacing: 8) {
                ForEach(items.indices, id: \.self) { index in
                    let active = selection == index
                    Button {
                        if active {
                            onReselect()
                        } else {
                            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28)) {
                                selection = index
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(active ? VWAR26Palette.teal : VWAR26Palette.line)
                                .frame(width: 3, height: 38)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(items[index].0)
                                    .font(StrandFont.overlineScaled(9))
                                    .tracking(1.0)
                                Text(items[index].1)
                                    .font(StrandFont.footnote)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(active ? VWAR26Palette.text : VWAR26Palette.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(active ? VWAR26Palette.elevated : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)

            Button("SINCRONIZAR AGORA") { onReselect() }
                .font(StrandFont.overlineScaled(9))
                .tracking(1.0)
                .foregroundStyle(VWAR26Palette.base)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(VWAR26Palette.teal, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .padding(.horizontal, 14)

            Text("PROCESSAMENTO LOCAL\nSEM ASSINATURA OBRIGATÓRIA")
                .font(StrandFont.overlineScaled(7))
                .tracking(0.8)
                .foregroundStyle(VWAR26Palette.tertiary)
                .lineSpacing(4)
                .padding(.horizontal, 18)
        }
        .padding(.vertical, 22)
        .background(VWAR26Palette.surface.opacity(0.72))
        .glassEffect(.regular, in: Rectangle())
    }

    private static let date: DateFormatter = {
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
#endif
