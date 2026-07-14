#if os(iOS)
import Foundation
import StrandDesign
import SwiftUI

struct VWARPortugueseTermsGate: View {
    let onAccept: () -> Void
    @State private var checked = false

    private let points: [(String, String)] = [
        ("Projeto independente", "O VWAR Loop Life não é afiliado, patrocinado nem endossado pela VWAR, G Band, Garmin, WHOOP ou Oura. As marcas pertencem aos respectivos titulares."),
        ("Uso com seus dispositivos e seus dados", "Use o aplicativo somente com aparelhos que você possui e com informações às quais tem autorização legítima de acesso."),
        ("Software experimental", "Bluetooth, sincronização e análises podem falhar, mudar após atualizações de firmware ou apresentar lacunas. Você assume o risco de uso."),
        ("Não é dispositivo médico", "Métricas, tendências, ECG, pressão arterial, glicose e estimativas de composição corporal não servem para diagnóstico, tratamento ou decisão médica."),
        ("Processamento local e sem garantia", "O aplicativo é gratuito, fornecido no estado em que se encontra e mantém os cálculos principais no aparelho. A responsabilidade é limitada ao máximo permitido pela lei aplicável."),
    ]

    var body: some View {
        ZStack {
            VWAR26Palette.base.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ANTES DE COMEÇAR")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.4)
                        .foregroundStyle(VWAR26Palette.teal)
                    Text("Termos essenciais")
                        .font(StrandFont.rounded(34, weight: .semibold))
                        .foregroundStyle(VWAR26Palette.text)
                    Text("Leia os pontos abaixo. A aceitação fica registrada apenas neste aparelho.")
                        .font(StrandFont.subhead)
                        .foregroundStyle(VWAR26Palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(index + 1). \(point.0)")
                                    .font(StrandFont.headline)
                                    .foregroundStyle(VWAR26Palette.text)
                                Text(point.1)
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(VWAR26Palette.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(VWAR26Palette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(VWAR26Palette.line))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                }

                VStack(spacing: 14) {
                    Toggle(isOn: $checked) {
                        Text("Li, compreendi e aceito estes termos para usar meus próprios dispositivos e dados por minha conta e risco.")
                            .font(StrandFont.footnote)
                            .foregroundStyle(VWAR26Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(VWAR26Palette.teal)

                    Button("ACEITAR E CONTINUAR", action: onAccept)
                        .buttonStyle(VWARPrimaryButtonStyle())
                        .disabled(!checked)
                        .opacity(checked ? 1 : 0.38)
                }
                .padding(24)
                .background(VWAR26Palette.base.opacity(0.96))
            }
            .frame(maxWidth: 720)
        }
        .preferredColorScheme(.dark)
    }
}

struct VWARPortugueseOnboarding: View {
    let onFinished: () -> Void
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var health: HealthKitBridge
    @State private var step = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VWAR26Palette.base, VWAR26Palette.surface.opacity(0.92), VWAR26Palette.base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    Group {
                        switch step {
                        case 0: welcome
                        case 1: profileStep
                        case 2: sourcesStep
                        default: ready
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 22)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                controls
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: step)
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                if step > 0 {
                    Button("VOLTAR") { step -= 1 }
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.0)
                        .foregroundStyle(VWAR26Palette.secondary)
                } else {
                    Text("VWAR LOOP LIFE")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.5)
                        .foregroundStyle(VWAR26Palette.teal)
                }
                Spacer()
                Text("\(step + 1) DE 4")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.0)
                    .foregroundStyle(VWAR26Palette.tertiary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(VWAR26Palette.line)
                    Capsule().fill(VWAR26Palette.teal)
                        .frame(width: geometry.size.width * CGFloat(step + 1) / 4)
                        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.35), value: step)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("INTELIGÊNCIA FISIOLÓGICA LOCAL")
                    .font(StrandFont.overlineScaled(9))
                    .tracking(1.5)
                    .foregroundStyle(VWAR26Palette.teal)
                Text("Seu corpo, em contexto.")
                    .font(StrandFont.rounded(42, weight: .semibold))
                    .tracking(-1.0)
                    .foregroundStyle(VWAR26Palette.text)
                Text("Uma experiência criada para a VWAR Loop Life, iPhone 16 Pro Max e iPad Pro M2, com calendário, análises profundas e integração transparente.")
                    .font(StrandFont.body)
                    .foregroundStyle(VWAR26Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 12)], spacing: 12) {
                promise("SEM ASSINATURA", "Histórico e análises permanecem disponíveis sem cobrança recorrente.")
                promise("DADOS REAIS", "Ausências continuam vazias; nenhum gráfico recebe valores inventados.")
                promise("PRIVADO", "Processamento principal no aparelho e permissões solicitadas no momento certo.")
                promise("INTEROPERÁVEL", "G Band e Garmin entram pelo app Saúde com origem identificada.")
            }
            VWARNotice(
                title: "REQUISITO",
                text: "Esta edição exige iOS ou iPadOS 26. Não é um dispositivo médico e não substitui avaliação profissional."
            )
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("SOBRE VOCÊ", "Calibração pessoal", "Esses dados ajustam zonas, gasto energético e referências. Você pode alterá-los depois em Fontes.")
            VWARPanel {
                VStack(spacing: 18) {
                    profileRow("IDADE", "\(profile.age) anos") {
                        Stepper("Idade", value: $profile.age, in: 13...100).labelsHidden()
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
                    profileRow("PESO", String(format: "%.1f kg", profile.weightKg)) {
                        Stepper("Peso", value: $profile.weightKg, in: 35...250, step: 0.5).labelsHidden()
                    }
                    profileRow("ALTURA", "\(Int(profile.heightCm.rounded())) cm") {
                        Stepper("Altura", value: $profile.heightCm, in: 120...230).labelsHidden()
                    }
                }
            }
            Text("Frequência cardíaca máxima estimada: \(profile.hrMax) bpm.")
                .font(StrandFont.footnote)
                .foregroundStyle(VWAR26Palette.tertiary)
        }
    }

    private var sourcesStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("INTEGRAÇÃO", "Traga seu histórico", "A autorização é opcional agora. Você pode continuar e ativar depois em Fontes.")
            VWARPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SAÚDE DA APPLE")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.2)
                        .foregroundStyle(VWAR26Palette.teal)
                    Text("O G Band e o Garmin Connect podem gravar sono, frequência cardíaca, VFC, SpO₂, passos e treinos no app Saúde. O VWAR Loop Life lê somente as categorias que você aprovar.")
                        .font(StrandFont.body)
                        .foregroundStyle(VWAR26Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("G Band → Saúde da Apple → VWAR Loop Life\nGarmin Connect → Saúde da Apple → VWAR Loop Life")
                        .font(StrandFont.mono(11, weight: .medium))
                        .foregroundStyle(VWAR26Palette.teal)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(health.auth == .authorized ? "ACESSO JÁ AUTORIZADO" : "ATIVAR SAÚDE DA APPLE") {
                        Task { await health.requestAuthorization() }
                    }
                    .buttonStyle(VWARPrimaryButtonStyle())
                    .disabled(health.auth == .authorized)
                }
            }
            VWARNotice(
                title: "ASSINATURA DO IPA",
                text: "A integração HealthKit exige o direito correto na assinatura. Se o instalador remover esse direito, o restante do aplicativo continua funcionando, mas a sincronização direta fica indisponível."
            )
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("CONFIGURAÇÃO CONCLUÍDA", "Pronto para começar", "O painel abrirá no dia atual e mostrará somente sinais realmente disponíveis.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 12)], spacing: 12) {
                promise("HOJE", "Calendário, relógio, sinais atuais e inteligência de contexto.")
                promise("TENDÊNCIAS", "Gráficos interativos de recuperação, carga, sono e sinais noturnos.")
                promise("SONO", "Duração, eficiência, composição e regularidade de horários.")
                promise("FONTES", "Saúde da Apple, G Band, Garmin, cobertura local e perfil.")
            }
            Text("Você mantém o controle: sincronize quando quiser, confira a origem e exporte somente por ação explícita.")
                .font(StrandFont.body)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button(step == 3 ? "ABRIR VWAR LOOP LIFE" : "SALVAR E CONTINUAR") {
                if step == 3 { onFinished() } else { step += 1 }
            }
            .buttonStyle(VWARPrimaryButtonStyle())
            if step == 2 {
                Button("CONTINUAR SEM AUTORIZAR") { step += 1 }
                    .font(StrandFont.overlineScaled(9))
                    .tracking(0.8)
                    .foregroundStyle(VWAR26Palette.secondary)
            }
        }
        .padding(24)
        .background(VWAR26Palette.base.opacity(0.94))
    }

    private func heading(_ eyebrow: String, _ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(StrandFont.overlineScaled(9))
                .tracking(1.4)
                .foregroundStyle(VWAR26Palette.teal)
            Text(title)
                .font(StrandFont.rounded(36, weight: .semibold))
                .foregroundStyle(VWAR26Palette.text)
            Text(subtitle)
                .font(StrandFont.body)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promise(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StrandFont.overlineScaled(9))
                .tracking(1.0)
                .foregroundStyle(VWAR26Palette.teal)
            Text(text)
                .font(StrandFont.subhead)
                .foregroundStyle(VWAR26Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background(VWAR26Palette.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(VWAR26Palette.line))
    }

    private func profileRow<Control: View>(_ label: String, _ value: String,
                                           @ViewBuilder control: () -> Control) -> some View {
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
            control()
        }
    }
}

struct VWARPortugueseWhatsNew: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("VERSÃO 11.0.0")
                        .font(StrandFont.overlineScaled(9))
                        .tracking(1.4)
                        .foregroundStyle(VWAR26Palette.teal)
                    Text("Duas experiências dedicadas")
                        .font(StrandFont.rounded(36, weight: .semibold))
                        .foregroundStyle(VWAR26Palette.text)
                    Text("Reconstruída para iOS e iPadOS 26, com edições separadas e interface integralmente em português do Brasil.")
                        .font(StrandFont.body)
                        .foregroundStyle(VWAR26Palette.secondary)
                    change("Composição por aparelho", "Dock de alcance no iPhone e central lateral persistente no iPad Pro.")
                    change("Malha de sinais", "Seis sinais reais em um campo animado, selecionável e sem preencher ausências.")
                    change("Gráficos avançados", "Recuperação, carga, sono, VFC, frequência de repouso, SpO₂ e respiração em séries interativas.")
                    change("Sono aprofundado", "Duração, eficiência, composição e regularidade sem completar lacunas artificialmente.")
                    change("G Band e Garmin", "Proveniência verificada pelo app Saúde e instruções claras de sincronização.")
                    change("Privacidade", "Processamento principal local, transparência de cobertura e nenhuma chave secreta embutida.")
                    VWARNotice(title: "IMPORTANTE", text: "O aplicativo oferece informações de bem-estar, não medições médicas.")
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(VWAR26Palette.base.ignoresSafeArea())
            .navigationTitle("Novidades")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VWAR26Palette.base, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("FECHAR", action: onClose)
                        .font(StrandFont.overlineScaled(9))
                        .foregroundStyle(VWAR26Palette.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func change(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(StrandFont.headline).foregroundStyle(VWAR26Palette.text)
            Text(text).font(StrandFont.subhead).foregroundStyle(VWAR26Palette.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VWAR26Palette.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(VWAR26Palette.line))
    }
}

private struct VWARPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StrandFont.headline)
            .tracking(0.2)
            .foregroundStyle(VWAR26Palette.base)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(VWAR26Palette.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.66 : 1)
    }
}
#endif
