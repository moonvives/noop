# Instalar o VWAR Loop Life no iPhone ou iPad

A versão 11.1.0 foi feita exclusivamente para o ecossistema Apple 26 e usa uma única cadeia de dados:

```text
Pulseira VWAR Loop Life → G Band → Saúde da Apple → VWAR Loop Life
                                          ↘ atividades do Strava
```

Não há pareamento direto com a pulseira dentro do VWAR Loop Life. Também não há telas de importação,
provedores de relógios ou transmissão de frequência cardíaca por Bluetooth. O Strava não é tratado
como pulseira: suas atividades só entram quando aparecem na Saúde da Apple.

## Escolha o arquivo correto

- `VWAR-Loop-Life-v11.1.0-iPhone-16-Pro-Max-iOS26.ipa`: família iPhone, composição calibrada para o
  painel de 6,9 polegadas do iPhone 16 Pro Max;
- `VWAR-Loop-Life-v11.1.0-iPad-Pro-M2-12.9-iPadOS26.ipa`: família iPad, central lateral calibrada para
  o iPad Pro M2 de 12,9 polegadas.

Os dois pacotes contêm somente arm64, exigem iOS/iPadOS 26.0 ou mais recente e têm interface pt-BR.
O iOS permite restringir a família do aparelho, mas não um modelo comercial específico; por isso a
composição é otimizada para os modelos solicitados e o bloqueio técnico é por iPhone ou iPad.

## Assinatura e instalação

Os artefatos públicos são `ready-to-sign`: não contêm certificado nem perfil de terceiros. AltStore e
SideStore conseguem assinar o IPA com o Apple ID do usuário, mas uma assinatura gratuita normalmente
precisa ser renovada a cada sete dias.

Para preservar HealthKit, widgets e App Groups com mais confiabilidade, a instalação recomendada é uma
compilação no Xcode 26.3 ou mais recente, usando identificadores e uma equipe Apple pertencentes a você.
O direito HealthKit precisa constar no perfil usado para assinar; sem isso, nenhum IPA modificado pode
ler a Saúde da Apple.

## Configurar o G Band

1. No G Band, ative a sincronização com a Saúde da Apple.
2. Autorize apenas as categorias que deseja compartilhar, como frequência cardíaca, VFC, sono, passos,
   distância, energia ativa, SpO₂ e temperatura quando disponíveis.
3. No VWAR Loop Life, abra **Fontes** e autorize a leitura da Saúde da Apple.
4. Toque em **Sincronizar agora**. O app preserva lacunas quando uma categoria não existe.

## Configurar o Strava

Conecte o Strava à Saúde da Apple e habilite a gravação das atividades. O VWAR Loop Life lê essas
atividades pela Saúde da Apple e identifica a procedência Strava; não acessa conta, senha ou nuvem do
Strava diretamente.

Métricas de bem-estar não são diagnóstico. Pressão arterial, ECG e estimativas de glicose da pulseira
não são usadas como medições clínicas nem entram nos escores principais.
