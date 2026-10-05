# Portão 1 · etapa 1 do PRD publicada na VPS (05/10/2026)

Comandos rodados pelo Luiz no console da Hostinger, um por vez, com a sessão
acompanhando de fora (só GET/POST sem credencial).

| Hora (UTC) | Passo | Resultado |
|---|---|---|
| ~14:45 | `app-definir TRANSCRIPTION_API_KEY` (Groq) e `REFUND_WEBHOOK_SECRET` | gravados em `.externos` |
| 14:50 | `backup` | banco do app 484K, uploads 4K, n8n 28K; cópia cifrada no R2 |
| ~14:55 | `app-subir sha-cdc45f5` | **API não subiu**: `CRYSTAL_API_URL precisa ser https em produção`. Swarm voltou a API para `sha-1e17b44`; web e crystal ficaram em `sha-cdc45f5` (estado misto). Script antigo disse `ok 1/1` |
| ~15:05 | `REFUND_WEBHOOK_SECRET` trocado | o primeiro apareceu numa colagem do terminal no chat; regra: vazou, troca |
| ~15:15 | `app-subir sha-1e17b44` | os três serviços de volta à versão anterior (estado consistente) |
| ~15:35 | hotfix `79ba6b7` no `crystal-web-chat` | guard aceita http só para host interno do Docker (sem ponto); imagens por etapa (`otimizacao/etapa-*`); CI e imagens verdes |
| ~15:45 | `app-subir sha-79ba6b7` com o `bootstrap-vps.sh` `965c69b` | **os três serviços em `sha-79ba6b7`**, `ok os três serviços estão em sha-79ba6b7` |

Conferido de fora depois da subida:

- `GET /healthz` → `{"ok":true}`
- `POST /webhooks/reembolso` sem credencial → 401; com bearer errado → 401 (antes: 404, rota não existia)
- `https://app.crystalnowpp.com.br/` → 200; `/offline.html` → 200

Banco: `migrate deploy` encontrou 14 migrações, nenhuma pendente (a etapa 1 não cria tabela).

Lições, já aplicadas:

- `app-subir` agora espera a atualização do Swarm terminar, confere a tag de cada
  serviço e mostra o log do contêiner que morreu (`app_conferir_troca`).
- Guard de produção: `https` continua obrigatório para tudo que sai da máquina;
  `http` só para nome de serviço do Swarm.
- Colagem de terminal no chat: apagar antes qualquer linha com segredo.

Falta para fechar o portão 1: teste em aparelho (lista em `crystal-em-casa/publicar-prd.md`,
release 1) e, quando a Assiny mandar o JSON, o teste do reembolso.
