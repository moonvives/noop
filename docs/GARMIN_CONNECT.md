# Garmin no VWAR Loop Life

O VWAR Loop Life oferece três caminhos independentes para dados Garmin. Nenhum deles exige uma
assinatura Garmin adicional, e o aplicativo nunca preenche uma métrica que não tenha recebido.

## 1. Garmin Connect > Apple Health > VWAR Loop Life

Este é o caminho recomendado no iPhone quando a compilação do VWAR Loop Life possui o direito
HealthKit:

1. No **Garmin Connect**, abra **Mais > Configurações > Apps conectados > Apple Health**.
2. Toque em **Conectar ao Apple Health** e autorize as categorias desejadas.
3. Mantenha o Garmin Connect aberto enquanto sincroniza o relógio.
4. No **VWAR Loop Life**, abra **Fontes de dados > Apple Health**, autorize a leitura e toque em
   **Verificar Garmin agora**.

O estado **Detectado** aparece somente depois que o app encontra uma amostra autorizada cuja origem
real é o Garmin Connect. Ter o Garmin Connect instalado não basta. A verificação retém apenas o nome
técnico da origem e as categorias encontradas; ela não guarda valores de saúde, conta Garmin, serial
do relógio ou outro identificador pessoal.

Segundo a documentação da Garmin, o Garmin Connect envia dados ao Apple Health, mas não importa dados
dele. As categorias disponibilizadas atualmente incluem energia, composição corporal, frequência
cardíaca, sono, passos, distância, hidratação, peso e treinos. A disponibilidade exata depende do
dispositivo e dos dados registrados. O Garmin Connect precisa estar em primeiro plano durante a
sincronização; ao ativar a integração, ele pode enviar até duas semanas anteriores.

Limites conhecidos da ponte oficial:

- a rota GPS do treino não é gravada no Apple Health;
- em atividades cronometradas, o detalhamento de frequência cardíaca pode se limitar a valores alto
  e baixo;
- o VWAR Loop Life recebe apenas as categorias que o usuário autorizou e que a Garmin realmente
  publicou.

Referência oficial: [Compartilhar dados do Garmin Connect com o Apple Health](https://support.garmin.com/en-US/?faq=lK5FPB9iPF5PXFkIpFlFPA).

## 2. Frequência cardíaca ao vivo por Bluetooth

Relógios Garmin compatíveis podem transmitir frequência cardíaca usando o serviço Bluetooth padrão
`0x180D`. Ative **Transmitir frequência cardíaca** no relógio e, no VWAR Loop Life, abra
**Dispositivos > Adicionar dispositivo > Relógio Garmin**.

Esta rota é local e serve para batimentos ao vivo. HRV ao vivo só pode ser derivada quando o dispositivo
também transmite intervalos RR válidos. Ela não baixa sono, passos, Body Battery, histórico de treinos ou
outros dados da conta Garmin. A disponibilidade e o nome do menu variam por modelo.

## 3. Importação offline

Em **Fontes de dados > Garmin / Oura / Fitbit data export**, selecione o arquivo obtido em
**Garmin Connect > Exportar seus dados**. O importador processa localmente os registros presentes no
arquivo, incluindo sono, frequência cardíaca de repouso, HRV e passos quando disponíveis. Arquivos de
atividade `.fit`, `.tcx` e `.gpx` também podem ser importados separadamente.

Esta é a alternativa mais completa quando uma instalação por AltStore ou SideStore não preserva o
direito HealthKit. A prontidão, o sono ou outros escores calculados pela Garmin ficam apenas como
referência; os escores VWAR Loop Life continuam sendo calculados localmente a partir dos sinais que
existem no arquivo.

## Garmin Connect IQ e Garmin Health API

O Connect IQ distribui aplicativos de relógio, campos de dados, widgets e mostradores. Por isso, ele
não é necessário para a sincronização acima e, sozinho, não concede ao VWAR Loop Life acesso ao
histórico da nuvem Garmin. Consulte a [visão geral oficial do Connect IQ](https://developer.garmin.com/connect-iq/overview/).

A integração comercial direta com a nuvem usa o Garmin Connect Developer Program e a Garmin Health
API. Ela exige aprovação, consentimento do usuário, servidor credenciado e, para uso comercial, pode
exigir licença. O VWAR Loop Life 9.1.0 não inclui credenciais, servidor oculto ou uma integração cloud
que finja esse acesso. Referências: [visão geral do programa](https://developer.garmin.com/gc-developer-program/overview/)
e [Garmin Health API](https://developer.garmin.com/gc-developer-program/health-api/).

## Privacidade e saúde

O processamento dessas três rotas permanece no dispositivo. Métricas de wearable são informações de
bem-estar e desempenho; não substituem equipamento médico, diagnóstico ou orientação profissional.
