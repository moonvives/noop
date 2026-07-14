#if os(iOS)
import SwiftUI
import StrandDesign

/// Navegação principal exclusiva do iOS/iPadOS 26.
///
/// A superfície antiga expunha dezenas de telas compartilhadas com o macOS e, por isso, misturava
/// idiomas e hierarquias. A experiência VWAR 10 mantém quatro destinos objetivos, todos em pt-BR,
/// sem dados demonstrativos e sem ícones decorativos.
struct RootTabView: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var router: NavRouter
    @AppStorage("vwar.looplife.abaSelecionada") private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                raiz(VITAEPerformanceDashboard()).tag(0)
                raiz(VWARTrendsView()).tag(1)
                raiz(VWARSleepIntelligenceView()).tag(2)
                raiz(VWARSourcesView()).tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
            .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.28), value: selectedTab)

            VWARPortugueseTabBar(selection: $selectedTab) {
                Task {
                    await repo.refresh()
                }
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
#endif
