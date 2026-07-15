# VWAR Loop Life para macOS Monterey

Aplicativo nativo em SwiftUI/AppKit para macOS 12.0 ou posterior. Ele importa o
`exportar.zip` ou o XML criado pelo app Saúde no iPhone e monta um painel local
com dados do G Band, atividades do Strava e registros consolidados pela Saúde da
Apple.

## Privacidade e funcionamento

- Não usa rede e não envia o arquivo para nenhum servidor.
- O XML é lido de forma incremental, inclusive quando tem centenas de megabytes.
- A origem é classificada pelos metadados `sourceName` e `device`, com versão da
  fonte como fallback quando o nome é genérico.
- Apenas o resumo calculado é salvo em `~/Library/Application Support/VWAR Loop Life/`.
- O macOS 12 não oferece acesso direto ao banco da Saúde da Apple; por isso a
  importação do arquivo exportado pelo iPhone é necessária.

## Compilar

```sh
./MacMonterey/build.sh
```

Por padrão, o script cria um binário para a arquitetura do Mac em que é executado,
define `LC_BUILD_VERSION` com mínimo 12.0, aplica assinatura ad hoc, executa um
teste de classificação e gera:

`../VWAR-Loop-Life-macOS12.7.6.app.zip`

Também é possível informar explicitamente uma ou mais arquiteturas disponíveis no
toolchain:

```sh
TARGET_ARCHS="x86_64 arm64" ./MacMonterey/build.sh
```
