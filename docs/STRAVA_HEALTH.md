# Strava na Saúde da Apple

Na edição iOS 26, o Strava é uma fonte de **atividades**, não um wearable e não uma conexão direta do
VWAR Loop Life.

1. No Strava, conecte a Saúde da Apple e permita o envio das atividades.
2. Em **Ajustes > Saúde > Acesso a Dados e Dispositivos**, confirme as categorias autorizadas.
3. No VWAR Loop Life, abra **Fontes**, autorize o HealthKit e sincronize.

O aplicativo só marca a procedência Strava quando encontra amostras reais cujo `HKSource` corresponde
ao Strava. Instalar o Strava sem gravar uma atividade na Saúde da Apple não cria dados nem um estado
falso de conexão.
