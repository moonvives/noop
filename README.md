# VWAR Loop Life

Aplicativo iOS/iPadOS local para acompanhar a pulseira **VWAR Loop Life** usada com o **G Band**. A
versão atual é **11.1.0**, exige **iOS 26.0 ou iPadOS 26.0** e tem interface integralmente em português
do Brasil.

O fluxo suportado é objetivo:

```text
VWAR Loop Life → G Band → Saúde da Apple → aplicativo VWAR Loop Life
                                      ↘ atividades do Strava
```

Não existe pareamento Bluetooth dentro do aplicativo, importador de outros wearables ou provedor de
assistente na experiência iOS. O Strava entra somente como procedência de atividades registradas na
Saúde da Apple.

[Guia de instalação](docs/VWAR_LOOP_LIFE_INSTALL.md) ·
[Apresentação](docs/index.html) ·
[Termos](TERMS.md)

## Duas edições reais

- **iPhone 16 Pro Max:** dock inferior, hierarquia compacta e gráficos táteis para 6,9 polegadas;
- **iPad Pro M2 12,9:** rail persistente, painéis simultâneos e composição expandida.

Os targets são arm64 independentes, têm famílias iPhone/iPad distintas, bundle IDs próprios e mínimo
de sistema 26.0 validado também no Mach-O. O iOS restringe por família, não pelo nome comercial de um
único modelo.

## Experiência 11.1

- visual preto-titânio com luz espectral restrita aos dados e estados;
- Hoje, Tendências, Sono e Fontes como únicas áreas principais;
- calendário e seleção real do dia;
- recuperação, carga, sono, VFC, frequência cardíaca de repouso, passos, energia, SpO₂ e temperatura;
- gráficos inspecionáveis, feedback tátil, Dynamic Type e Reduzir Movimento;
- referências pessoais calculadas no aparelho e ausência honesta quando faltam medições;
- identificação de G Band e Strava pela origem das amostras no HealthKit;
- widget e Atividade ao Vivo em pt-BR.

## Privacidade e limites

O aplicativo lê somente as categorias autorizadas no HealthKit e não solicita permissão Bluetooth. Os
dados permanecem locais por padrão. O app não acessa a conta do G Band ou do Strava e não inventa
amostras que não chegaram à Saúde da Apple.

Estimativas do wearable são informações de bem-estar. Pressão arterial, ECG e estimativas de glicose
não são tratadas como medições clínicas nem alimentam os escores principais.

## Build

Requisitos: macOS compatível com Xcode 26.3 ou mais recente e XcodeGen.

```bash
xcodegen generate
open Strand.xcodeproj
```

O esquema técnico continua chamado `NOOPiOS` para preservar o histórico do projeto; o nome exibido no
sistema é **VWAR Loop Life**. Os workflows geram:

```text
VWAR-Loop-Life-v11.1.0-iPhone-16-Pro-Max-iOS26.ipa
VWAR-Loop-Life-v11.1.0-iPad-Pro-M2-12.9-iPadOS26.ipa
```

Os artefatos públicos são deliberadamente não assinados. Para o HealthKit funcionar, assine com uma
equipe e um perfil Apple que incluam o direito HealthKit.

## Licença

O código segue a licença em [LICENSE](LICENSE). O projeto é independente e não é afiliado à VWAR,
G Band, Apple ou Strava.
