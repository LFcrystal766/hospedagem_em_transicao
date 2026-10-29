# Suporte: áudio ou foto com "Não consegui enviar. Tentar de novo"

Escrito em 29/10 para um cliente no Android com dois áudios de 1 segundo recusados. Vale para qualquer caso
igual, de áudio ou de foto.

## O que a frase quer dizer (versão no ar `sha-088d07d`; igual até a `466886d`)

- **"Não consegui enviar. Tentar de novo"**: o arquivo ou a mensagem não chegaram, ou o servidor falhou. As causas
  possíveis são estas:
  - rede do aparelho caiu ou o envio passou do prazo;
  - limite de envios: 10 arquivos por minuto por sessão, 20 por minuto por IP, 200 por dia por pessoa;
  - sessão que não renovou por erro de rede ou do servidor (sessão vencida de verdade manda para o login);
  - erro interno da API.
- **"Não consegui enviar esse arquivo. Quer tentar outro?"**: o servidor recusou o arquivo pelo tipo ou pelo tamanho
  (413/415). Tentar de novo não resolve.
- Quando a **resposta** da Crystal falha (transcrição, Crystal fora), o aviso vai na bolha dela, não na do cliente.
  O áudio do cliente fica com os tiques normais.

O app não reenvia áudio nem foto sozinho; a fila automática é só de texto. Cada "Tentar de novo" sobe o arquivo outra
vez, se ele não tinha subido.

## Primeiro passo: cadastro

No Supabase, `select app_verificar_login_email('<e-mail>');` tem de voltar o contato com o último campo `t`
(liberado). Se voltar vazio ou `f`, o caso é de acesso, não de envio.

## Segundo passo: o log da API (dono, na VPS)

Troque `DIA`, `DE` e `ATE` pela data e pelos minutos do print, na hora de Brasília. O comando lê o log da API e
mostra só os envios de arquivo, as renovações de sessão e as mensagens que **não** deram certo nesse intervalo,
com hora, rota e código. Ele não mostra e-mail, nome nem IP.

```bash
DIA=2026-10-29; DE=09:54; ATE=09:59
de=$(date -d "$DIA $DE -0300" +%s)000; ate=$(date -d "$DIA $ATE -0300" +%s)000
docker service logs --since "$(date -u -d "$DIA $DE -0300 1 hour ago" +%Y-%m-%dT%H:%M:%SZ)" crystal_app_app_api 2>&1 \
| awk -v de="$de" -v ate="$ate" '
{ id = "" }
!match($0, /"time":[0-9]+/) { next }
{ ms = substr($0, RSTART + 7, RLENGTH - 7) + 0 }
ms < de || ms > ate { next }
{ s = (int(ms / 1000) - 10800) % 86400; hora = sprintf("%02d:%02d:%02d", int(s / 3600), int(s % 3600 / 60), s % 60) }
match($0, /"reqId":"[^"]+"/) { id = substr($0, RSTART + 9, RLENGTH - 10) }
match($0, /"method":"POST","url":"\/(uploads|messages|auth\/refresh)[^"?]*/) { u[id] = hora " " substr($0, RSTART + 23, RLENGTH - 23); next }
/"msg":"erro interno"/ { print hora, "ERRO INTERNO no pedido", id; next }
(id in u) && match($0, /"statusCode":[0-9]+/) { c = substr($0, RSTART + 13, RLENGTH - 13); if (!(u[id] ~ / \/messages/ && c == "201")) print u[id], "->", c; delete u[id] }'
df -h / | tail -1
```

O log de cada contêiner guarda 30 MB (3 arquivos de 10 MB). Se o intervalo já saiu do log, o comando não mostra
nada; nesse caso, peça ao cliente para tentar de novo e rode o comando com os minutos novos.

## Como ler

| O que aparece na hora do print | Causa | O que fazer |
|---|---|---|
| Nenhum `/uploads` | O arquivo nem chegou: rede do aparelho, ou o app aberto há muito tempo | Cliente fecha e abre o app, confere a internet e toca em "Tentar de novo" |
| `/uploads -> 429` | Limite de envios | Esperar um minuto. Se for o de 200 por dia, só no dia seguinte |
| `/uploads -> 401` e depois `/auth/refresh -> 5xx` ou nada | A sessão não renovou | Sair e entrar de novo no app |
| `/uploads -> 500` ou `ERRO INTERNO` | Falha do servidor (disco cheio, pasta de uploads) | Ver a última linha (`df`): disco acima de 90% é a causa. Mandar o print para a sessão |
| `/uploads -> 201` e `/messages -> 4xx/5xx` | O arquivo subiu e a mensagem foi recusada | Mandar o print para a sessão |
| `/uploads -> 413` ou `415` | Tipo ou tamanho | No app aparece a outra frase ("Quer tentar outro?") |
