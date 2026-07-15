#if os(iOS)
import SwiftUI
import StrandDesign

/// iOS entry point. Unlike the macOS app (which adds a `MenuBarExtra` scene), iOS uses a single
/// `WindowGroup`; the glanceable menu-bar role is filled by the Home/Lock-Screen widget instead.
///
/// The iOS shell is `RootTabView` (a `TabView`), NOT the macOS `ContentView`. `ContentView` embeds
/// `RootView()` — the `NavigationSplitView` sidebar shell — and `RootView.swift` is excluded from the
/// iOS target in `project.yml` (the sidebar has no iPhone analogue), so `ContentView` cannot compile
/// on iOS. The first-run onboarding/pairing wizard, the Terms acknowledgment gate, and the post-update
/// "What's New" sheet that `ContentView` layers on are reproduced here as `iOSRootView`, wrapped around
/// `RootTabView` so the iOS app keeps the same gating without depending on the macOS-only shell.
@main
struct StrandiOSApp: App {
    @StateObject private var model: AppModel
    @StateObject private var health: HealthKitBridge
    /// Navegação compartilhada entre Hoje, Tendências, Sono e Fontes.
    @StateObject private var router = NavRouter()
    @State private var liveActivity = LiveActivityController()
    @Environment(\.scenePhase) private var scenePhase
    /// Appearance preference (System/Light/Dark). Default follows the OS; the Settings picker writes it.
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    /// Chart data-colour style (Titanium / Classic throwback). Re-colours gauges + charts.
    @AppStorage(ChartStyle.storageKey) private var chartStyleRaw = ChartStyle.titanium.rawValue

    init() {
        // Debug-only canary: trips if the App Group entitlement is missing on this target before any
        // silent no-op (PendingIntents, WidgetSnapshot.publish, Live Activity) can mask the issue as
        // "the widget doesn't show anything yet." No-op in Release.
        WidgetSnapshot.assertGroupProvisioned()
        // #510: register the scheduled debug auto-export's BGTask handler BEFORE launch finishes — iOS
        // only delivers a background task whose identifier was registered at launch AND listed in the
        // target's BGTaskSchedulerPermittedIdentifiers (project.yml). Without this the overnight drop
        // never fires; the macOS timer, foreground catch-up, and "Run now" already work without it.
        ScheduledDebugExport.register()
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        _health = StateObject(wrappedValue: HealthKitBridge(
            repo: model.repo,
            appleDeviceId: model.appleDeviceId,
            noopDeviceId: model.deviceId
        ))
    }

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environmentObject(model)
                .environmentObject(model.live)
                .environmentObject(model.repo)
                .environmentObject(model.profile)
                .environmentObject(model.behavior)
                .environmentObject(model.intelligence)
                .environmentObject(health)
                .environmentObject(router)
                .environmentObject(UpdateStore.shared)
                // A edição iOS/iPadOS 11.1 é uma experiência pt-BR dedicada. Isto também localiza
                // elementos fornecidos pelo sistema (calendário, seletores e autorizações) sem depender
                // do idioma global do aparelho.
                .environment(\.locale, Locale(identifier: "pt_BR"))
                // v5 L3: the shared stress check-in nudge surface, so the Breathe screen's passive
                // card observes the SAME instance the central detector (AppModel.evaluateStress) posts to.
                .environment(\.stressNudgeCenter, model.stressNudgeCenter)
                .preferredColorScheme(AppearanceMode.resolve(appearanceRaw).colorScheme)
                .chartStyle(chartStyleRaw)
                // Dynamic Type now scales the prose/label roles (StrandFont). Cap the upper end so the
                // fixed-geometry tiles/gauges stay legible at the largest accessibility sizes rather than
                // clipping; the common Larger-Text range still scales fully.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .onReceive(model.live.$heartRate) { _ in
                    // #911: anchor the Live Activity on the SAME shared `Repository.widgetAnchor` the
                    // Home/Lock widget uses, so this surface can't drift to a
                    // different day at the rollover (it previously read `days.last(where: recovery != nil)`,
                    // which kept pointing at yesterday's scored row after Today had moved on).
                    let day = Repository.widgetAnchor(days: model.repo.days)
                    liveActivity.update(
                        bpm: model.live.connected ? (model.bpm ?? model.live.heartRate) : nil,
                        recovery: day?.recovery.map { Int($0.rounded()) },
                        connected: model.live.connected,
                        effort: day?.strain.map { Int($0.rounded()) }
                    )
                }
                // End the Live Activity the moment the link drops, even if no further HR tick arrives.
                .onReceive(model.live.$connected) { isConnected in
                    // #911: same shared anchor as the heartRate site above, so the Live Activity,
                    // widget and Today never disagree about which day they describe.
                    let day = Repository.widgetAnchor(days: model.repo.days)
                    liveActivity.update(
                        bpm: isConnected ? (model.bpm ?? model.live.heartRate) : nil,
                        recovery: day?.recovery.map { Int($0.rounded()) },
                        connected: isConnected,
                        effort: day?.strain.map { Int($0.rounded()) }
                    )
                }
                // #911/#759: republish the Home/Lock-Screen widget whenever the dashboard caches actually
                // change mid-session. The only other publish site is the scenePhase .active handler, so
                // during a long foreground session the widget froze at the last-foreground snapshot while
                // Today and the Live Activity kept updating. `refreshSeq` is diff-guarded (Repository.refresh
                // skips the bump when the merged caches are byte-identical) and refresh() assigns every cache
                // BEFORE bumping the seq, so this publish always reads fresh data. `dropFirst()` skips the
                // publisher's attach-time replay of the current value; the .active publish already covers
                // launch. Publish only while active; the widget's timeline and the next foreground refresh
                // cover background changes without consuming unnecessary reload budget.
                .onReceive(model.repo.$refreshSeq.dropFirst()) { _ in
                    guard scenePhase == .active else { return }
                    Task { await WidgetSnapshot.publish(from: model) }
                }
                // #581: the `noop://import-health` deep link the iOS Shortcut opens after building the
                // HealthKit-free payload. Filter on the host so other future schemes don't trip the
                // importer; macOS never registers the scheme so this stays iOS-only.
                .onOpenURL { url in
                    if url.host == "import-health" {
                        model.handleHealthImportURL(url)
                    }
                }
                // Um App Intent também pode ser executado enquanto o app já está ativo, situação em que
                // `scenePhase` não muda. Drene a pequena fila compartilhada uma vez por segundo para que
                // "Sincronizar Saúde" sempre produza uma sincronização real, sem depender de reabertura.
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        if model.drainPendingIntents() {
                            health.refreshAuthIfPreviouslyGranted()
                            await health.sync()
                            await WidgetSnapshot.publish(from: model)
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
        }
        // HealthKit authorization is intentionally NOT requested on launch. The system permission
        // dialog without prior in-app rationale violates Apple HIG / App Review guidance — the user
        // sees the prompt before any context. It is requested from the explicit "Ativar acesso"
        // action on the dedicated Fontes screen.
        // Below, `refreshAuthIfPreviouslyGranted` re-primes `auth` for users who already granted
        // access (it only reads write/share status, never prompts) so background syncs resume; and
        // HealthKitBridge.sync guards on `auth == .authorized`, so the scenePhase trigger stays a
        // safe no-op until the user opts in.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.drainPendingIntents()
                Task {
                    health.refreshAuthIfPreviouslyGranted()
                    await health.sync()
                    await WidgetSnapshot.publish(from: model)
                }
            } else if phase == .background {
                // #155: refresh the Documents/noop_sync.txt drop file the user's Siri Shortcut logs
                // into Apple Health. Gated inside writeIfEnabled on the opt-in default (OFF) — a
                // no-op until the user turns on Shortcuts Export.
                Task { await ShortcutHealthExport.writeIfEnabled(repo: model.repo) }
            }
        }
    }
}

/// iOS root — the `RootTabView` shell with the dedicated pt-BR onboarding overlaid until
/// complete, the Terms acknowledgment gate over everything until the current version is accepted, and
/// a "What's New" changelog sheet shown automatically after an update.
///
/// The legacy shared onboarding and screen catalog are intentionally excluded from this target; only
/// the VWAR-specific gates below can be presented on iPhone and iPad.
private struct iOSRootView: View {
    @AppStorage("vwar.looplife.ptbr.onboarded.v10") private var onboarded = false
    @AppStorage("vwar.looplife.ptbr.lastSeenChangelogVersion") private var lastSeenChangelog = ""
    @AppStorage("vwar.looplife.ptbr.acceptedTermsVersion") private var acceptedTerms = ""
    @State private var showWhatsNew = false

    var body: some View {
        shell
    }

    private var shell: some View {
        ZStack {
            RootTabView()
            if !onboarded && !demoBypass {
                VWARPortugueseOnboarding(onFinished: {
                    onboarded = true
                    // A brand-new user just saw the expectations in onboarding — don't also pop the
                    // changelog at them; mark them current.
                    lastSeenChangelog = AppChangelog.currentVersion
                })
                .transition(.opacity)
                .zIndex(1)
            }
            // Terms acknowledgment gate — over EVERYTHING before onboarding and HealthKit setup until
            // the current terms version is accepted; re-appears if the terms materially change.
            if acceptedTerms != Terms.currentVersion && !demoBypass {
                VWARPortugueseTermsGate(onAccept: { acceptedTerms = Terms.currentVersion })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarded)
        .animation(.easeInOut(duration: 0.35), value: acceptedTerms)
        .sheet(isPresented: $showWhatsNew) {
            VWARPortugueseWhatsNew(onClose: {
                lastSeenChangelog = AppChangelog.currentVersion
                showWhatsNew = false
            })
        }
        // The Terms gate must stay "over everything" — don't pop What's New on top of it after a
        // combined terms+version update. Gate on terms being current, and re-check when they're
        // accepted (onAppear already fired before acceptance), so What's New shows right after.
        .onAppear {
            showWhatsNewIfDue()
            // Seed the current What's New into the Updates inbox (idempotent per version) so the bell
            // collects it even if the user dismisses the auto sheet.
            UpdateStore.shared.seedWhatsNewIfNeeded()
        }
        .onChange(of: acceptedTerms) { _, _ in showWhatsNewIfDue() }
    }

    /// DEBUG: launched with --demo-seed, skip the first-run gates (onboarding / terms / What's New) so the
    /// FULL shell with the tab bar renders populated for verification + screenshots. No-op in Release.
    private var demoBypass: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--demo-seed")
        #else
        return false
        #endif
    }

    private func showWhatsNewIfDue() {
        if demoBypass { return }
        // Existing users who updated: their last-seen version is behind the current one.
        if onboarded && acceptedTerms == Terms.currentVersion
            && lastSeenChangelog != AppChangelog.currentVersion {
            showWhatsNew = true
        }
    }
}

#endif
