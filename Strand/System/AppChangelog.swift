import Foundation

/// Fonte única do conteúdo exibido em "Novidades" e das expectativas apresentadas no onboarding.
enum AppChangelog {
    static let currentVersion = "11.1.0"

    struct Release: Identifiable {
        let version: String
        let title: String
        let date: String
        let items: [String]
        var id: String { version }
    }

    static let releases: [Release] = [
        Release(
            version: currentVersion,
            title: "Uma nova experiência VWAR para iOS 26",
            date: "14 de julho de 2026",
            items: [
                "**Interface refeita do zero.** O iPhone ganha um fluxo de telemetria confortável; o iPad recebe uma central expandida com painéis simultâneos e navegação persistente.",
                "**VWAR Loop Life e G Band.** O histórico principal entra pelo fluxo G Band → app Saúde → VWAR Loop Life, preservando a origem real das amostras.",
                "**Strava com proveniência verificável.** O painel reconhece somente amostras que o Strava realmente gravou no app Saúde; instalar o aplicativo não é apresentado como sincronização concluída.",
                "**Português do Brasil na experiência ativa.** Termos, atalhos, mensagens operacionais e notificações foram revisados em pt-BR.",
                "**Privacidade por padrão.** Conectores legados de pulseiras e anéis não são iniciados no iOS; os tipos antigos permanecem vinculados apenas para ler o armazenamento histórico.",
            ]),
    ]

    struct Expectation: Identifiable {
        let icon: String
        let title: String
        let body: String
        var id: String { title }
    }

    static let expectations: [Expectation] = [
        Expectation(
            icon: "waveform.path.ecg",
            title: "Feito para VWAR Loop Life",
            body: "O caminho recomendado é usar o G Band para gravar no app Saúde e deixar o VWAR Loop Life analisar os dados autorizados no aparelho."),
        Expectation(
            icon: "heart.text.square",
            title: "App Saúde como ponte",
            body: "A disponibilidade de cada métrica depende do que o G Band realmente envia e das permissões concedidas ao VWAR Loop Life."),
        Expectation(
            icon: "figure.run",
            title: "Strava sem falso positivo",
            body: "O aplicativo mostra o Strava como fonte somente quando encontra amostras gravadas por ele no app Saúde."),
        Expectation(
            icon: "lock.shield",
            title: "Privacidade e limites claros",
            body: "Os cálculos principais são locais, valores ausentes não são inventados e nenhuma métrica substitui avaliação médica."),
    ]
}
