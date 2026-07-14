# Garmin no VWAR Loop Life

O VWAR Loop Life oferece dois caminhos independentes para dados Garmin. Nenhum deles exige uma
assinatura Garmin adicional, e o aplicativo nunca preenche uma métrica que não tenha recebido.

## 1. Garmin Connect > Saúde da Apple > VWAR Loop Life

Este é o caminho recomendado no iPhone quando a compilação do VWAR Loop Life possui o direito
HealthKit:

1. No **Garmin Connect**, abra **Mais > Configurações > Apps conectados > Saúde**.
2. Autorize as categorias desejadas no app Saúde.
3. Mantenha o Garmin Connect aberto enquanto sincroniza o relógio.
4. No **VWAR Loop Life**, abra **Fontes**, autorize a leitura e toque em **Sincronizar 90 dias**.

O estado **Verificado** aparece somente depois que o app encontra uma amostra autorizada cuja origem
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
**Hoje > VWAR direto** para procurar características Bluetooth anunciadas.

Esta rota é local e serve para batimentos ao vivo. VFC ao vivo só pode ser derivada quando o dispositivo
também transmite intervalos RR válidos. Ela não baixa sono, passos, Body Battery, histórico de treinos ou
outros dados da conta Garmin. A disponibilidade e o nome do menu variam por modelo.

## Garmin Connect IQ e Garmin Health API

O Connect IQ distribui aplicativos de relógio, campos de dados, widgets e mostradores. Por isso, ele
não é necessário para a sincronização acima e, sozinho, não concede ao VWAR Loop Life acesso ao
histórico da nuvem Garmin. Consulte a [visão geral oficial do Connect IQ](https://developer.garmin.com/connect-iq/overview/).

A integração comercial direta com a nuvem usa o Garmin Connect Developer Program e a Garmin Health
API. Ela exige aprovação, consentimento do usuário, servidor credenciado e, para uso comercial, pode
exigir licença. O VWAR Loop Life 10.0.0 não inclui credenciais, servidor oculto ou uma integração em nuvem
que finja esse acesso. Referências: [visão geral do programa](https://developer.garmin.com/gc-developer-program/overview/)
e [Garmin Health API](https://developer.garmin.com/gc-developer-program/health-api/).

## Privacidade e saúde

O processamento dessas duas rotas permanece no dispositivo. Métricas de pulseiras são informações de
bem-estar e desempenho; não substituem equipamento médico, diagnóstico ou orientação profissional.
