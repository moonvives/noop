#if os(iOS)
import SwiftUI

/// Shell principal do VWAR Loop Life no iOS 26.
///
/// A hierarquia de conteúdo é a mesma nas duas edições. A edição do iPhone usa um dock de alcance
/// confortável; a do iPad mantém um rail persistente para aproveitar a tela de 12,9 polegadas.
struct RootTabView: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var router: NavRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("vwar.looplife.abaSelecionada") private var selectedTab = VWARNavigationItem.today.rawValue

    var body: some View {
        Group {
            if VWARDeviceEdition.current.usesCommandRail {
                iPadShell
            } else {
                iPhoneShell
            }
        }
        .background(VWAR26Palette.base.ignoresSafeArea())
        .onAppear {
            if VWARNavigationItem(rawValue: selectedTab) == nil {
                selectedTab = VWARNavigationItem.today.rawValue
            }
        }
        .task { await repo.refresh() }
        .onChange(of: router.requestedDestination) { _, destination in
            guard let destination else { return }
            select(destination.navigationItem)
            router.requestedDestination = nil
        }
        .onChange(of: router.quickActionsRequested) { _, requested in
            guard requested else { return }
            select(.sources)
            router.quickActionsRequested = false
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private var iPhoneShell: some View {
        destinations
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VWARPhoneDock(selection: selection) { item in
                    handle(item)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 5)
            }
    }

    private var iPadShell: some View {
        HStack(spacing: 0) {
            VWARiPadRail(selection: selection) { item in
                handle(item)
            } onRefresh: {
                Task { await repo.refresh() }
            }
            .frame(width: 292)

            Rectangle()
                .fill(VWAR26Palette.line)
                .frame(width: 1)
                .accessibilityHidden(true)

            destinations
        }
    }

    private var destinations: some View {
        TabView(selection: $selectedTab) {
            root(VITAEPerformanceDashboard()).tag(VWARNavigationItem.today.rawValue)
            root(VWARTrendsView()).tag(VWARNavigationItem.trends.rawValue)
            root(VWARSleepIntelligenceView()).tag(VWARNavigationItem.sleep.rawValue)
            root(VWARSourcesView()).tag(VWARNavigationItem.sources.rawValue)
        }
        .toolbar(.hidden, for: .tabBar)
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.82, 0.2, 1, duration: 0.34), value: selectedTab)
    }

    private var selection: VWARNavigationItem {
        VWARNavigationItem(rawValue: selectedTab) ?? .today
    }

    private func handle(_ item: VWARNavigationItem) {
        if item == selection {
            Task { await repo.refresh() }
        } else {
            select(item)
        }
    }

    private func select(_ item: VWARNavigationItem) {
        withAnimation(reduceMotion ? nil : .timingCurve(0.2, 0.82, 0.2, 1, duration: 0.34)) {
            selectedTab = item.rawValue
        }
    }

    private func root<Content: View>(_ content: Content) -> some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                .background(VWAR26Palette.base.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

private extension NavRouter.Destination {
    var navigationItem: VWARNavigationItem {
        switch self {
        case .trends:
            return .trends
        case .devices, .fusedRecord, .insightsHub, .labBook, .rhythm:
            return .sources
        case .activeWorkout, .liveSession:
            return .today
        }
    }
}
#endif
