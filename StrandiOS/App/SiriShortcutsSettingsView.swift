#if os(iOS)
import SwiftUI
import AppIntents
import StrandDesign

/// Surfaces VWAR Loop Life's already-registered App Intents (see StrandiOS/System/NOOPAppIntents.swift) in the
/// UI so users discover them. `NOOPShortcuts` registers Health sync and moment marking with
/// Siri/Spotlight/Shortcuts, but nothing in-app advertised them — this is the iOS analogue of the
/// Mac's strap-double-tap-runs-a-Shortcut feature. Apple's `SiriTipView`/`ShortcutsLink` (iOS 16+)
/// do exactly that: tip the user on the spoken phrase and deep-link into the Shortcuts app, scoped to
/// this app automatically.
struct SiriShortcutsSettingsView: View {
    var body: some View {
        ScreenScaffold(title: "Siri e Atalhos",
                       subtitle: "Execute ações do VWAR Loop Life sem usar as mãos.") {
            tips
            shortcutsCard
        }
    }

    private var tips: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(StrandPalette.accent)
                        .accessibilityHidden(true)
                    Text("Ações prontas")
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                Text("Sincronize o app Saúde ou marque um momento pela Siri, Spotlight, Atalhos, Tocar Atrás ou uma automação.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                SiriTipView(intent: SyncHealthIntent(), isVisible: .constant(true))
                    .siriTipViewStyle(.dark)
                SiriTipView(intent: MarkMomentIntent(), isVisible: .constant(true))
                    .siriTipViewStyle(.dark)
            }
        }
    }

    private var shortcutsCard: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(StrandPalette.accent)
                        .accessibilityHidden(true)
                    Text("Crie sua automação")
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                Text("Combine as ações do VWAR Loop Life com Tocar Atrás, um modo Foco ou um atalho maior. Por exemplo, toque duas vezes atrás do iPhone para sincronizar o app Saúde.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                ShortcutsLink()
            }
        }
    }
}
#endif
