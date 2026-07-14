# Instalar o VWAR Loop Life no iPhone ou iPad

O pacote do GitHub contém `VWAR-Loop-Life-unsigned.ipa`, uma compilação sem certificado, sem perfil de
provisionamento e sem dados pessoais. O arquivo precisa ser assinado no seu próprio ambiente antes de
abrir no iPhone.

Esta versão exige **iOS 26.0 ou iPadOS 26.0**. O mesmo IPA arm64 contém as famílias de dispositivo
iPhone e iPad e é compatível com iPhone 16 Pro Max e iPad Pro M2 de 12,9 polegadas atualizados.

## Instalação rápida com AltStore ou SideStore

1. Baixe `VWAR-Loop-Life-v10.0.0-ios.ipa` na [versão 10 do GitHub](https://github.com/moonvives/noop/releases/tag/v10.0.0).
2. Abra o arquivo `.ipa` no AltStore ou SideStore.
3. Assine com o seu Apple ID e conclua a instalação no iPhone.
4. Se o iOS solicitar, autorize o perfil em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.

Uma assinatura gratuita normalmente expira em sete dias e precisa ser renovada pelo sideloader. Um IPA
assinado por um perfil genérico pode perder HealthKit, widgets e outras permissões Apple. Não entregue sua
senha, exportações de saúde ou códigos de autenticação a serviços de assinatura desconhecidos.

## Instalação completa recomendada

Para usar o caminho G Band > Saúde da Apple > VWAR Loop Life com o direito HealthKit preservado, compile
no Xcode usando a sua própria equipe Apple:

1. Instale Xcode 26.3 ou mais recente e XcodeGen no Mac.
2. Clone `https://github.com/moonvives/noop.git`.
3. Configure identificadores de app, widget, Watch e App Group pertencentes à sua conta.
4. Informe `DEVELOPMENT_TEAM` em `project.yml`.
5. Execute `xcodegen generate`.
6. Abra `Strand.xcodeproj`, selecione o esquema técnico `NOOPiOS`, escolha o iPhone e execute.

`NOOPiOS` é mantido apenas como identificador interno de build para preservar compatibilidade. O nome
mostrado no iPhone, Apple Watch, widgets e permissões do sistema é **VWAR Loop Life**.

## Sincronizar a VWAR Loop Life

O caminho diário validado nesta versão é:

```text
Pulseira VWAR Loop Life > G Band > Saúde da Apple > VWAR Loop Life
```

No G Band, ative a sincronização com Saúde da Apple e autorize frequência cardíaca, distância a pé e
correndo, energia ativa, oxigênio no sangue, passos, sono e temperatura corporal. Depois, no VWAR Loop
Life, abra **Fontes**, toque em **Ativar acesso**, aprove as leituras e use **Sincronizar 90 dias**.

A glicose de pulso informada pelo G Band é uma estimativa não validada e permanece excluída de
recuperação, carga, sono, análise avançada e recomendações. Pressão arterial e ECG não entram por essa
ponte. Use dispositivos médicos e orientação profissional para decisões de saúde.

## Sincronizar um Garmin

Com uma compilação que preserva o HealthKit, use **Garmin Connect > Mais > Configurações > Apps
conectados > Saúde**, conecte as categorias desejadas e mantenha o Garmin Connect aberto ao
sincronizar o relógio. Depois, no VWAR Loop Life, abra **Fontes** e use **Sincronizar 90 dias**.
O estado **Verificado** depende de amostras Garmin reais, não apenas da instalação do aplicativo.

Sem HealthKit, ative a transmissão de frequência cardíaca em um relógio Garmin compatível e use
**Hoje > VWAR direto** para a captura local de características Bluetooth anunciadas. Consulte o
[guia Garmin](GARMIN_CONNECT.md) para capacidades e limites dessa rota.

## O que há na versão 10

- marca visível VWAR Loop Life em iPhone, iPad, Mac, Apple Watch e widgets;
- dia da semana, data completa, ano e relógio atualizado por minuto;
- calendário semanal permanente e seletor mensal completo;
- análise avançada local comparada à própria referência de até 28 dias;
- centro de comando único e responsivo no iPhone e no iPad;
- calendário semanal que recarrega as métricas do dia realmente selecionado;
- VWAR Intelligence local com comparação de recuperação, sono e carga contra até 28 dias anteriores;
- VFC, carga, sono, matriz de sinais e cobertura dos dados em ambos os formatos;
- integração G Band via Saúde da Apple e coletor BLE de pesquisa somente leitura;
- integração Garmin com origem verificada no app Saúde e frequência cardíaca Bluetooth;
- armazenamento local-first, sem conta e sem assinatura obrigatória.
