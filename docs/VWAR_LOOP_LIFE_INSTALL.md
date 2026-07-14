# Instalar o VWAR Loop Life no iPhone ou iPad

O pacote do GitHub contém `VWAR-Loop-Life-unsigned.ipa`, uma compilação sem certificado, sem perfil de
provisionamento e sem dados pessoais. O arquivo precisa ser assinado no seu próprio ambiente antes de
abrir no iPhone.

## Instalação rápida com AltStore ou SideStore

1. Baixe `VWAR-Loop-Life-v9.1.0-ios.ipa` na [versão 9.1 do GitHub](https://github.com/moonvives/noop/releases/tag/v9.1.0).
2. Abra o arquivo `.ipa` no AltStore ou SideStore.
3. Assine com o seu Apple ID e conclua a instalação no iPhone.
4. Se o iOS solicitar, autorize o perfil em Ajustes > Geral > VPN e Gerenciamento de Dispositivo.

Uma assinatura gratuita normalmente expira em sete dias e precisa ser renovada pelo sideloader. Um IPA
assinado por um perfil genérico pode perder HealthKit, widgets e outras permissões Apple. Não entregue sua
senha, exportações de saúde ou códigos de autenticação a serviços de assinatura desconhecidos.

## Instalação completa recomendada

Para usar o caminho G Band > Apple Health > VWAR Loop Life com o direito HealthKit preservado, compile
no Xcode usando a sua própria equipe Apple:

1. Instale Xcode e XcodeGen no Mac.
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
VWAR Loop Life > G Band > Apple Health > VWAR Loop Life
```

No G Band, ative a sincronização com Saúde da Apple e autorize frequência cardíaca, distância a pé e
correndo, energia ativa, oxigênio no sangue, passos, sono e temperatura corporal. Depois, no VWAR Loop
Life, abra Apple Health, toque em Enable, aprove as leituras e execute Sync.

A glicose de pulso informada pelo G Band é uma estimativa não validada e permanece excluída de
recuperação, carga, sono, análise avançada e recomendações. Pressão arterial e ECG não entram por essa
ponte. Use dispositivos médicos e orientação profissional para decisões de saúde.

## Sincronizar um Garmin

Com uma compilação que preserva o HealthKit, use **Garmin Connect > Mais > Configurações > Apps
conectados > Apple Health**, conecte as categorias desejadas e mantenha o Garmin Connect aberto ao
sincronizar o relógio. Depois, no VWAR Loop Life, abra **Apple Health** e use **Verificar Garmin agora**.
O estado detectado depende de amostras Garmin reais, não apenas da instalação do aplicativo.

Sem HealthKit, ative a transmissão de frequência cardíaca em um relógio Garmin compatível e adicione-o
em **Dispositivos**, ou importe o arquivo **Export Your Data** em **Fontes de dados**. Consulte o
[guia Garmin](GARMIN_CONNECT.md) para capacidades e limites de cada rota.

## O que há na versão 9.1

- marca visível VWAR Loop Life em iPhone, iPad, Mac, Apple Watch e widgets;
- dia da semana, data completa, ano e relógio atualizado por minuto;
- calendário semanal permanente e seletor mensal completo;
- análise avançada local comparada ao próprio baseline de até 28 dias;
- painel iPad com HRV, carga, sono, matriz de vitais e cobertura dos dados;
- integração G Band via Apple Health e coletor BLE de pesquisa somente leitura;
- integração Garmin com origem verificada no Apple Health, frequência cardíaca Bluetooth e arquivo
  de exportação offline;
- armazenamento local-first, sem conta e sem assinatura obrigatória.
