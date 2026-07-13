# Instalar VITAE One VWAR Loop Life no iPhone ou iPad

VITAE One VWAR Loop Life é um aplicativo iOS distribuído como código-fonte e IPA não assinado. Nenhuma
conta Apple, certificado, perfil de provisionamento ou dado pessoal de saúde é armazenado no repositório.

## Ponte diária com o G Band

The daily VWAR path is:

```text
VWAR Loop Life → G Band → Saúde da Apple → VITAE One VWAR Loop Life
```

No G Band, ative a Saúde da Apple e permita frequência cardíaca, distância caminhando + correndo,
energia ativa, glicose, oxigênio no sangue, passos, sono e temperatura corporal. No VITAE One VWAR
Loop Life, abra Saúde da Apple, escolha Ativar, aprove as leituras e execute Sincronizar.

O valor de glicose escrito pelo G Band é uma estimativa de pulso não validada. O VITAE One VWAR Loop
Life o identifica como experimental e o exclui de toda pontuação, insight e orientação. Pressão arterial
e ECG não são importados por essa ponte.

## Painel premium no iPad Pro e pesquisa VWAR direta

No iPad, o VITAE One VWAR Loop Life abre um painel em português pensado para telas grandes. Ele mostra
o dia da semana, data completa, ano, hora e minutos em tempo real, inclui calendário gráfico e navegação
semanal, e recalcula a análise para o dia escolhido. Há tendências de recuperação e carga, baseline
pessoal de HRV, horário e arquitetura reais do sono, equilíbrio de treino e cobertura dos vitais. As
telas de uso diário nunca inventam dados: medições ausentes continuam ausentes.

Abra **VWAR DIRETO** para criar uma captura Bluetooth clean-room da Loop Life. Esse modo inventaria
serviços e características GATT, lê apenas características que anunciam acesso de leitura, assina canais
notify/indicate, decodifica somente payloads públicos Bluetooth-SIG de bateria e frequência cardíaca e
exporta um registro JSON anonimizado. Nenhum comando proprietário é enviado. Payloads do fabricante
permanecem brutos até existirem capturas do proprietário e fixtures reproduzíveis que sustentem um decoder.

## Instalação recomendada

Compile no Xcode com sua própria equipe Apple e um perfil que inclua HealthKit. Isso preserva a
autorização necessária para ler a Saúde da Apple.

1. Instale Xcode e XcodeGen no Mac.
2. Clone `moonvives/noop` e use a revisão mais recente do branch `main`.
3. Substitua os identificadores do app, widget e App Group por valores da sua equipe Apple.
4. Defina `DEVELOPMENT_TEAM` em `project.yml`.
5. Execute `xcodegen generate`.
6. Abra `Strand.xcodeproj`, selecione seu iPhone ou iPad e execute o esquema interno `NOOPiOS`.

Um IPA reassinado por um serviço genérico pode perder o entitlement do HealthKit. Nesse caso, o VITAE
One VWAR Loop Life não aparecerá no acesso aos dados de Saúde e não receberá os dados do G Band. Não
forneça credenciais Apple nem exportações de saúde a serviços de assinatura de terceiros.

## Nome do arquivo

O workflow publica `VITAE-One-VWAR-Loop-Life-unsigned.ipa` dentro do artefato
`VITAE-One-VWAR-Loop-Life-iOS-ready-to-sign`. O IPA precisa ser assinado para o seu aparelho antes da
instalação; o arquivo do GitHub não contém identidade Apple.
