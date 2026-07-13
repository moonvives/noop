<p align="center">
  <sub>PRIVADO · LOCAL · SEM ASSINATURA</sub>
</p>

<h1 id="vitae-one-vwar-loop-life" align="center">VITAE One VWAR Loop Life</h1>

<p align="center"><b>Análise diária premium para a pulseira VWAR Loop Life, com seus dados sob seu controle.</b></p>

<p align="center">
  <a href="https://moonvives.github.io/noop/">Site</a> ·
  <a href="docs/VITAE_INSTALL.md">Instalação no iPhone e iPad</a> ·
  <a href="docs/VWAR_BLE_CAPTURE.md">Pesquisa Bluetooth</a> ·
  <a href="docs/PRIVACY_SECURITY.md">Privacidade</a>
</p>

<p align="center">
  <img alt="iOS e iPadOS 17 ou superior" src="https://img.shields.io/badge/iOS%20%7C%20iPadOS-17%2B-77E3CF?style=flat-square">
  <img alt="Processamento local" src="https://img.shields.io/badge/processamento-local-77E3CF?style=flat-square">
  <img alt="Sem conta obrigatória" src="https://img.shields.io/badge/conta-n%C3%A3o%20exigida-5E97FF?style=flat-square">
  <img alt="Interface em português do Brasil" src="https://img.shields.io/badge/idioma-pt--BR-9C7AFF?style=flat-square">
</p>

---

## Produto

VITAE One VWAR Loop Life é a experiência iOS e iPadOS deste repositório para acompanhar dados da
pulseira VWAR Loop Life sem assinatura. O painel grande do iPad reúne calendário, hora local ao vivo,
frequência cardíaca intradiária, recuperação, carga, sono, HRV, vitais e atividade em uma interface
original, densa e interativa.

O aplicativo não apresenta estimativas como diagnósticos. Quando faltam dados, a interface mostra a
ausência. ECG, pressão arterial e glicose estimada no pulso não entram nos scores nem em recomendações.

Atualização da experiência VITAE: 13 de julho de 2026.

## Fluxo recomendado para uso diário

```text
VWAR Loop Life → G Band → Saúde da Apple → VITAE One VWAR Loop Life
```

O G Band continua sendo a ponte mais confiável enquanto o protocolo proprietário completo da pulseira
não estiver documentado por capturas reproduzíveis. O app também inclui um modo de pesquisa direta,
somente leitura, que inventaria GATT, assina notificações e decodifica apenas perfis públicos Bluetooth-SIG.

| Dado | Ponte Saúde da Apple | Uso na análise |
|---|---:|---|
| Frequência cardíaca | Sim | Tendência, repouso, carga e contexto diário |
| HRV | Quando fornecido pela origem | Baseline pessoal e recuperação |
| SpO₂ | Sim | Tendência e cobertura de vitais |
| Sono | Sim | Duração, eficiência, horário e arquitetura disponível |
| Temperatura | Sim | Desvio do baseline pessoal |
| Passos, distância e energia | Sim | Atividade diária |
| Glicose estimada no pulso | Pode aparecer | Experimental; excluída de todo score |
| Pressão arterial e ECG | Não nesta ponte | Não tratados como medição clínica |

## Experiência premium no iPad

- relógio local ao vivo com hora e minutos;
- dia da semana, data completa, mês e ano em português do Brasil;
- calendário gráfico e faixa semanal para navegar por qualquer dia registrado;
- análise recalculada para a data escolhida, inclusive frequência cardíaca intradiária e sono;
- gráficos interativos de recuperação e carga, HRV com faixa de baseline, regularidade e arquitetura do
  sono, equilíbrio de treino, matriz de vitais e atividade;
- indicadores de cobertura para separar uma leitura sólida de uma calibração ainda incompleta;
- estados vazios honestos, sem números demonstrativos no caminho de uso real;
- modo VWAR DIRETO para pesquisa clean-room e exportação JSON anonimizada.

## Instalar no iPhone ou iPad

O pacote automatizado do GitHub contém:

```text
VITAE-One-VWAR-Loop-Life-unsigned.ipa
README.md
```

O IPA é intencionalmente não assinado. Para manter HealthKit, a instalação recomendada é compilar ou
assinar no Xcode com sua própria equipe Apple. Serviços genéricos de sideload podem remover entitlements
e impedir que o aplicativo apareça nas permissões da Saúde.

Consulte [o guia completo de instalação](docs/VITAE_INSTALL.md). O workflow
[`VITAE One VWAR Loop Life iOS package`](.github/workflows/vitae-ios-package.yml) valida o projeto e
publica um novo pacote pronto para assinatura em cada pull request relevante.

## Compilar

Requisitos: macOS, Xcode 16 ou superior e XcodeGen.

```bash
git clone https://github.com/moonvives/noop.git
cd noop
xcodegen generate
open Strand.xcodeproj
```

Selecione o esquema interno `NOOPiOS`, defina sua equipe Apple e execute no iPhone ou iPad. O nome do
esquema, os bundle identifiers `com.noopapp.*`, o App Group e alguns nomes de módulos permanecem como
identificadores de compatibilidade com a base original. O nome exibido do produto e dos artefatos é
**VITAE One VWAR Loop Life**.

## Arquitetura e privacidade

- SwiftUI, Charts, CoreBluetooth, HealthKit e Swift Concurrency;
- banco local e processamento no aparelho;
- nenhum login obrigatório e nenhuma nuvem necessária para o painel;
- coleta direta VWAR limitada a leitura, notify e indicate até existir evidência segura para comandos;
- exportação de pesquisa com identificadores removidos;
- algoritmos derivados documentados e separados de medidas clínicas.

Documentação técnica:

- [Instalação VITAE](docs/VITAE_INSTALL.md)
- [Captura BLE da VWAR](docs/VWAR_BLE_CAPTURE.md)
- [Coletor desktop](docs/VWAR_DESKTOP_COLLECTOR.md)
- [Arquitetura](docs/ARCHITECTURE.md)
- [Modelo de dados](docs/DATA_MODEL.md)
- [Privacidade e segurança](docs/PRIVACY_SECURITY.md)
- [Aviso de saúde](DISCLAIMER.md)

## Origem e compatibilidade

Este repositório é uma evolução independente construída sobre a base recuperada do projeto comunitário
NOOP. O nome NOOP permanece onde é necessário para atribuição histórica, compatibilidade técnica,
esquemas, módulos e migração de dados. A marca atual da experiência VWAR é VITAE One VWAR Loop Life.

O projeto não é afiliado, patrocinado ou endossado pela VWAR, G Band, Apple, WHOOP ou Oura. Marcas de
terceiros são citadas apenas para identificar dispositivos, formatos e integrações compatíveis.

## Limites de saúde

VITAE One VWAR Loop Life não é um dispositivo médico. Frequência cardíaca, HRV, sono, recuperação,
carga, SpO₂, temperatura e outras métricas destinam-se a bem-estar e observação pessoal. Não use o app
para diagnosticar, tratar ou tomar uma decisão médica. Em caso de sintomas ou dúvida clínica, consulte
um profissional qualificado e use equipamento validado.

## Licença

O código permanece sob a [PolyForm Noncommercial License 1.0.0](LICENSE). Consulte também
[TERMS.md](TERMS.md) e [DISCLAIMER.md](DISCLAIMER.md).
