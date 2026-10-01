# Incidente: "A resposta foi interrompida" no app (30/09 à noite a 01/10)

## Sintoma

O aluno mandava mensagem e a bolha da Crystal voltava "A resposta foi
interrompida. Me manda a pergunta de novo?". O site, a API e o login
continuaram no ar o tempo todo.

## Causas (três, em sequência)

1. **LendChat (canal da agência)**: com `CHAT_TRANSPORT=chatwoot`, a caixa
   "Crystal App - Stage" devolve 500 ao criar conversa pela API pública
   (contato e listagem funcionam). Reproduzido em 01/10 com contato de teste.
   Lado da agência; pedido ao Tuan.
2. **Valor errado gravado**: na volta para a nossa Crystal, um comando colado
   no lugar de `crystal` foi gravado em `CHAT_TRANSPORT`. Pego antes de subir.
3. **Modelo automático do OpenRouter**: com `openrouter/auto`, parte dos
   pedidos ia para um provedor instável ou lento (um 502 registrado; o app
   desiste em 60 s). Depois de fixar o modelo, nenhuma falha.

O que atrasou o diagnóstico: o app mostrava a mesma mensagem genérica para
qualquer falha e nem a API nem a Crystal registravam o motivo.

## O que mudou

| Commit | Mudança |
|---|---|
| crystal-web-chat `fdd5824` | Falha do canal grava o motivo na bolha e o status HTTP no log |
| crystal-web-chat `4595d32` | A Crystal tenta o modelo de novo uma vez se falhar antes do primeiro texto |
| crystal-web-chat `5436c9d` | fastify 5.12.5 (alertas de segurança de 01/10) |
| crystal-web-chat `9630b72` | Modelo padrão `anthropic/claude-haiku-4.5`; API registra o motivo da falha da Crystal |
| hospedagem `d1c9f21` | `app-definir CHAT_TRANSPORT` só aceita `crystal` ou `chatwoot` |

No ar: `sha-9630b72`, `CHAT_TRANSPORT=crystal`. Conferido em 01/10: teste
direto 200, nenhuma linha `crystal: resposta falhou`, só 200 na Crystal.

## Diagnóstico rápido, se voltar

```bash
bash bootstrap-vps.sh crystal-nossa-teste
docker service logs crystal_app_app_api --since 10m 2>&1 | grep -E 'crystal: resposta falhou|canal:' | tail -5
docker service logs crystal_app_app_crystal --since 10m 2>&1 | grep -oE 'modelo falhou[^"]*|"err":"[a-z_A-Z]+"|"statusCode":[0-9]+' | sort | uniq -c
```

## Antes de voltar para o LendChat

Só depois de o Tuan confirmar a correção e de criar conversa pela API pública
responder 200 (dá para testar daqui, sem mexer no app).
