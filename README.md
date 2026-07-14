# VWAR Loop Life

Uma experiência local e privada para acompanhar a pulseira VWAR Loop Life com contexto, transparência e
controle sobre os próprios dados. Sem assinatura obrigatória, sem conta do projeto e sem transformar
estimativas de pulso em alegações médicas.

Versão atual: **10.0.0**

Requisito Apple: **iOS 26.0 ou iPadOS 26.0**, arm64. O pacote é universal para iPhone e iPad e foi
dimensionado especificamente para iPhone 16 Pro Max e iPad Pro M2 de 12,9 polegadas.

[Abrir a apresentação do produto](docs/index.html) ·
[Instalar no iPhone ou iPad](docs/VWAR_LOOP_LIFE_INSTALL.md) ·
[Integrar com Garmin](docs/GARMIN_CONNECT.md) ·
[Usar o coletor no Mac](docs/VWAR_DESKTOP_COLLECTOR.md) ·
[Revisar o protocolo](docs/VWAR_BLE_CAPTURE.md)

## O que mudou

VWAR Loop Life é o novo nome visível do aplicativo, do site, dos widgets, do Apple Watch, dos pacotes e
dos coletores. Alguns identificadores técnicos antigos, como o esquema Xcode `NOOPiOS`, continuam no
código para preservar compatibilidade de build, assinatura e migração dos dados. Eles não são a marca
mostrada ao usuário.

## Experiência diária

- painel premium, escuro e text-led, sem elementos decorativos desnecessários;
- dia da semana, data completa, ano e relógio atualizado a cada minuto;
- calendário semanal permanente com navegação por dia e por semana;
- recuperação, carga, sono, VFC, frequência cardíaca de repouso, SpO₂, temperatura, passos e energia;
- análise avançada local comparada à própria referência de até 28 dias;
- confiança explícita: alta, em construção ou calibrando;
- ausência preservada quando faltam dados, sem preencher métricas inventadas;
- o mesmo centro de comando responsivo no iPhone e no iPad, com tendências, regularidade e arquitetura
  do sono, balanço de treino e matriz de vitais;
- seleção real do dia: calendário, HR, atividade, sono e análise mudam juntos;
- VWAR Intelligence determinística, testada e local, com mediana pessoal e cobertura explícita.

## Padrão de produto

O objetivo é superar alternativas fechadas nos pontos que o projeto consegue provar: controle local,
ausência de assinatura obrigatória, interoperabilidade, inspeção de origem, exportação e explicação do
cálculo. O projeto não afirma ter precisão fisiológica superior a WHOOP ou Oura sem um estudo comparativo
independente; leituras ausentes ou não validadas permanecem visíveis como tal.

## VWAR Loop Life e G Band

O caminho diário validado nesta versão é:

```text
Pulseira VWAR Loop Life > G Band > Saúde da Apple > VWAR Loop Life
```

O app lê somente as categorias autorizadas pelo usuário no app Saúde. A glicose estimada pelo G Band
é exibida com procedência e permanece excluída de recuperação, carga, sono, análise avançada e coaching.
Pressão arterial e ECG não entram por essa ponte.

O modo de pesquisa Bluetooth direto é independente e somente leitura: inventaria serviços GATT, lê apenas
características anunciadas como legíveis, assina notificações e decodifica somente formatos públicos do
Bluetooth SIG. Ele não envia comandos proprietários desconhecidos, não altera firmware e não atribui
significado médico a bytes não validados.

## Garmin Connect

O suporte Garmin usa rotas documentadas e independentes:

- Garmin Connect > Saúde da Apple > VWAR Loop Life para histórico automático em uma compilação com
  HealthKit;
- Broadcast Heart Rate do relógio > Bluetooth padrão para frequência cardíaca ao vivo;

O app confirma a origem Garmin somente quando encontra amostras reais do Garmin Connect no Apple
Saúde. Connect IQ não é tratado como acesso ao histórico da nuvem. Veja o
[guia Garmin completo](docs/GARMIN_CONNECT.md), com limitações e instruções.

## Download do iOS

[Baixar diretamente o VWAR Loop Life 10 para iOS/iPadOS](https://github.com/moonvives/noop/releases/download/v10.0.0/VWAR-Loop-Life-v10.0.0-ios.ipa)

O workflow **VWAR Loop Life iOS package** publica o artefato:

```text
VWAR-Loop-Life-v10.0.0-iOS-ready-to-sign
  VWAR-Loop-Life-v10.0.0-ios.ipa
  README.md
```

O IPA é deliberadamente não assinado. AltStore e SideStore podem assiná-lo com o Apple ID do usuário;
uma conta gratuita normalmente exige renovação a cada sete dias. Para manter HealthKit, widgets e as
permissões completas, a instalação recomendada é compilar no Xcode com uma equipe Apple própria.

Consulte [o guia completo de instalação](docs/VWAR_LOOP_LIFE_INSTALL.md) antes de instalar.

## Aplicativo e coletor para Mac

O workflow **VWAR Loop Life desktop collector** publica:

```text
VWAR-Loop-Life-Desktop-macOS
  VWAR-Loop-Life-Collector.app.zip
  vwar-loop-life-capture
```

O coletor registra evidência BLE local em um formato versionado e produz transcritos privado e
redigido. O identificador do periférico fica apenas no arquivo privado; publique somente a versão
redigida.

## Build local

Requisitos Apple: macOS 13 ou mais recente, Xcode 26.3 ou mais recente e XcodeGen.

```bash
git clone https://github.com/moonvives/noop.git
cd noop
xcodegen generate
open Strand.xcodeproj
```

O esquema técnico do iPhone é `NOOPiOS`. O nome instalado e exibido pelo sistema é **VWAR Loop Life**.

Para validar o protocolo e compilar o coletor:

```bash
swift test --package-path Packages/VWARProtocol
swift build -c release --package-path Packages/VWARProtocol --product vwar-loop-life-capture
swift build -c release --package-path Packages/VWARProtocol --product VWARLoopLifeDesktop
```

## Privacidade e análise

Os dados ficam no dispositivo por padrão. O Coach opcional é a única área de rede: funciona com chave
própria, consentimento explícito e um resumo compacto, nunca com o stream bruto. Nenhuma chave de API é
armazenada no repositório.

As análises são de bem-estar e desempenho. Frequência cardíaca, HRV, sono, recuperação, carga, SpO2,
temperatura, ECG, pressão arterial, glicose e composição corporal exibidos por wearables não substituem
equipamentos médicos, diagnóstico ou orientação profissional.

## Origem e atribuições

Este repositório continua em `moonvives/noop` para preservar histórico, issues, forks e links de download.
O código-base recuperado veio do projeto NOOP e mantém sua licença e atribuições. A pesquisa de
interoperabilidade também reconhece `johnmiddleton12/my-whoop` e `b-nnett/goose`; o coletor VWAR é uma
implementação original e não incorpora código do Goose.

VWAR Loop Life é independente e não é afiliado, patrocinado ou endossado pela VWAR, G Band, Apple,
Garmin ou WHOOP. Marcas de terceiros são citadas somente para identificar hardware e serviços
compatíveis.

## Licença

O código herdado e as novas alterações seguem a licença disponível em [LICENSE](LICENSE). Consulte
[TERMS.md](TERMS.md) antes de usar o software com um dispositivo próprio.
