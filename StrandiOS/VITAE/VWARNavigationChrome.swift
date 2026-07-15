#if os(iOS)
import SwiftUI
import StrandDesign

/// Destinos curtos e estáveis do produto. Os valores inteiros preservam a seleção já salva pelo app.
enum VWARNavigationItem: Int, CaseIterable, Identifiable {
    case today
    case trends
    case sleep
    case sources

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return "Hoje"
        case .trends: return "Tendências"
        case .sleep: return "Sono"
        case .sources: return "Fontes"
        }
    }

    var detail: String {
        switch self {
        case .today: return "Seu estado agora"
        case .trends: return "Evolução dos sinais"
        case .sleep: return "Ritmo e recuperação"
        case .sources: return "VWAR, Saúde e Strava"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "waveform.path.ecg"
        case .trends: return "chart.xyaxis.line"
        case .sleep: return "moon.stars.fill"
        case .sources: return "point.3.connected.trianglepath.dotted"
        }
    }
}

/// Titânio preto como base, com cor apenas onde ela comunica estado ou seleção.
enum VWAR26Palette {
    static let base = Color(red: 0.018, green: 0.022, blue: 0.028)
    static let surface = Color(red: 0.052, green: 0.061, blue: 0.073)
    static let elevated = Color(red: 0.078, green: 0.091, blue: 0.107)
    static let plot = Color(red: 0.031, green: 0.038, blue: 0.047)
    static let line = Color.white.opacity(0.085)
    static let teal = Color(red: 0.39, green: 0.90, blue: 0.80)
    static let blue = Color(red: 0.38, green: 0.63, blue: 1.0)
    static let violet = Color(red: 0.67, green: 0.53, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.32)
    static let rose = Color(red: 1.0, green: 0.40, blue: 0.52)
    static let text = Color.white.opacity(0.96)
    static let secondary = Color.white.opacity(0.64)
    static let tertiary = Color.white.opacity(0.40)

    static let titanium = LinearGradient(
        colors: [
            Color(red: 0.074, green: 0.084, blue: 0.098),
            Color(red: 0.035, green: 0.042, blue: 0.052),
            Color(red: 0.054, green: 0.063, blue: 0.076),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct VWARPhoneDock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Namespace private var selectionNamespace

    let selection: VWARNavigationItem
    let onSelect: (VWARNavigationItem) -> Void

    var body: some View {
        HStack(spacing: 3) {
            ForEach(VWARNavigationItem.allCases) { item in
                dockButton(item)
            }
        }
        .padding(5)
        .frame(maxWidth: 430)
        .background(VWAR26Palette.surface.opacity(0.48), in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.17), .white.opacity(0.035)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        }
        .shadow(color: .black.opacity(0.34), radius: 24, y: 12)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navegação principal")
    }

    private func dockButton(_ item: VWARNavigationItem) -> some View {
        let active = selection == item

        return Button {
            onSelect(item)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.symbol)
                    .font(.system(size: 18, weight: active ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 21)

                Text(item.title)
                    .font(.system(.caption2, design: .default, weight: active ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(active ? VWAR26Palette.text : VWAR26Palette.secondary)
            .frame(maxWidth: .infinity, minHeight: 51)
            .padding(.horizontal, 2)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(VWAR26Palette.elevated.opacity(0.92))
                        .matchedGeometryEffect(id: "dock-selection", in: selectionNamespace)
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(VWAR26Palette.teal)
                                .frame(width: differentiateWithoutColor ? 24 : 16, height: 2)
                                .padding(.top, 1)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(VWARChromeButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(item.title)
        .accessibilityHint(active ? "Atualiza os dados desta tela" : "Abre \(item.detail.lowercased())")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

struct VWARiPadRail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Namespace private var selectionNamespace

    let selection: VWARNavigationItem
    let onSelect: (VWARNavigationItem) -> Void
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 24)
                .padding(.top, 25)

            Text("VISÃO GERAL")
                .font(StrandFont.overlineScaled(10))
                .tracking(1.5)
                .foregroundStyle(VWAR26Palette.tertiary)
                .padding(.horizontal, 26)
                .padding(.top, 42)
                .padding(.bottom, 12)

            VStack(spacing: 7) {
                ForEach(VWARNavigationItem.allCases) { item in
                    railButton(item)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 28)

            privacyNote
                .padding(.horizontal, 18)
                .padding(.bottom, 14)

            Button(action: onRefresh) {
                Label("Atualizar dados", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(VWAR26Palette.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(VWARChromeButtonStyle(reduceMotion: reduceMotion))
            .background(VWAR26Palette.elevated.opacity(0.52), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(VWAR26Palette.line))
            .accessibilityHint("Busca novos dados no app Saúde")
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background {
            ZStack {
                VWAR26Palette.base
                VWAR26Palette.titanium.opacity(0.78)

                LinearGradient(
                    colors: [VWAR26Palette.teal.opacity(0.09), .clear],
                    startPoint: .topTrailing,
                    endPoint: .center
                )
            }
            .ignoresSafeArea()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Navegação principal")
    }

    private var brand: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VWAR26Palette.elevated)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [VWAR26Palette.teal.opacity(0.62), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VWAR26Palette.teal)
            }
            .frame(width: 43, height: 43)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("VWAR")
                    .font(.system(.title3, design: .default, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(VWAR26Palette.text)
                Text("LOOP LIFE")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.8)
                    .foregroundStyle(VWAR26Palette.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("VWAR Loop Life")
    }

    private func railButton(_ item: VWARNavigationItem) -> some View {
        let active = selection == item

        return Button {
            onSelect(item)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(active ? VWAR26Palette.teal.opacity(0.14) : Color.white.opacity(0.035))
                    Image(systemName: item.symbol)
                        .font(.system(size: 17, weight: active ? .semibold : .regular))
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(active ? VWAR26Palette.teal : VWAR26Palette.secondary)
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(.body, design: .default, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? VWAR26Palette.text : VWAR26Palette.secondary)
                    Text(item.detail)
                        .font(.system(.caption, design: .default, weight: .regular))
                        .foregroundStyle(VWAR26Palette.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if active {
                    Capsule()
                        .fill(VWAR26Palette.teal)
                        .frame(width: differentiateWithoutColor ? 4 : 3, height: 28)
                        .matchedGeometryEffect(id: "rail-selection", in: selectionNamespace)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(active ? VWAR26Palette.elevated.opacity(0.72) : .clear, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(VWAR26Palette.line)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(VWARChromeButtonStyle(reduceMotion: reduceMotion))
        .hoverEffect(.highlight)
        .accessibilityLabel(item.title)
        .accessibilityHint(active ? "Atualiza os dados desta tela" : "Abre \(item.detail.lowercased())")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VWAR26Palette.teal)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("Seus dados, no seu controle")
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(VWAR26Palette.secondary)
                Text("O histórico de saúde permanece local.")
                    .font(.system(.caption2, design: .default, weight: .regular))
                    .foregroundStyle(VWAR26Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct VWARChromeButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
#endif
