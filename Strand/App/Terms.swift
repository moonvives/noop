import Foundation

/// The Terms of Use the first-run gate presents. Bump `currentVersion` when the terms MATERIALLY
/// change (risk / liability / medical / affiliation wording) to re-prompt every user for a fresh
/// acknowledgment; leave it for typo fixes.
enum Terms {
    static let currentVersion = "1.2"

    /// Pontos essenciais aceitos no primeiro uso. Cada item é `(título, corpo)` e espelha o gate
    /// conciso do iOS.
    static let points: [(String, String)] = [
        ("Projeto independente",
         "O VWAR Loop Life não é afiliado, patrocinado nem endossado pela VWAR, G Band, Apple ou Strava."),
        ("Uso com seus dispositivos e seus dados",
         "Use o aplicativo somente com aparelhos que você possui e com informações às quais tem autorização legítima de acesso."),
        ("Software experimental",
         "A sincronização pelo app Saúde e as análises podem apresentar atrasos, falhas ou lacunas conforme os dados disponibilizados pelo G Band e pelo Strava."),
        ("Não é dispositivo médico",
         "Métricas e tendências não servem para diagnóstico, tratamento ou decisão médica."),
        ("Sem garantia",
         "O aplicativo é gratuito, fornecido no estado em que se encontra e processa os cálculos principais no aparelho."),
    ]
}
