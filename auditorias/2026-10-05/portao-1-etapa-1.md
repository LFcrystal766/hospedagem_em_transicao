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

## Release único das etapas 2 e 3 (mesmo dia, 16:25 UTC)

Decisão do Luiz: ir ao ar hoje. As etapas 2 e 3 subiram num release só, com a
imagem `sha-da617ac` (contém a 2), porque o commit tinha CI completo verde (33 e2e)
e a volta é um comando. Sequência: `app-remover CRYSTAL_ONBOARDING_URL` (não
existia), `backup` 16:25 UTC (app 488K, uploads 4K, cifrado no R2),
`app-subir sha-da617ac` → os três serviços em `sha-da617ac`, `1/1`.

Conferido de fora: `POST /messages/x/retry` sem credencial → 401 (rota da etapa 3
existe); `/papel-de-parede/escuro.png` → 200 (web da etapa 3); `/healthz` ok.
As migrações `e2_14…e2_18` e `e3_19` rodaram na subida da API (a API só sobe
depois do `migrate deploy`).

Volta, se precisar: `app-subir sha-79ba6b7` (etapa 1). Atenção: a etapa 2 apagou
`onboarding_states`; se a volta para a etapa 1 reclamar da tabela, restaurar o
backup das 16:25 antes.

## QA em aparelho (iPhone), 05/10

Etapa 1: os 6 itens aprovados pelo Luiz (login, offline, áudio transcrito, foto,
DPO nos termos, painel da Crystal). Etapas 2 e 3: os 8 itens aprovados (início e
temas, perfil obrigatório, tiques e bolhas curtas, áudio com tocador e gravação
por toque, **segurar para gravar funcionou**, topo da Crystal, menu e tutorial,
avisos e ritmo pela equipe, modo avião). Decisão: a fase 3 do P12 fica ligada.

Pendente: o mesmo roteiro num Android com Chrome (ninguém tinha o aparelho hoje),
e o teste do reembolso quando a Assiny mandar o JSON de exemplo.

## Ajustes pós-QA publicados (17:13 UTC)

`backup` (app 492K, uploads 760K: já há áudio e foto dos testes) e `app-subir sha-8ed9ce8`:
os três serviços em `sha-8ed9ce8`. Conteúdo: pílula "Manda o print" removida (ícone de
clipe à direita do campo, como no WhatsApp) e folha de notificações fechando sozinha
depois do "Pronto!", com botão Fechar. Imagem com CI e e2e verdes (484 web, 32/32 e2e).

## Releases seguintes do mesmo dia

| Hora (UTC) | Tag | Conteúdo |
|---|---|---|
| 17:40 | `sha-99d80cf` | Conversa não some mais com o teclado no iPhone (tela fixa ao visual viewport); foto padrão da Crystal |
| 17:58 | `sha-398e46e` | Foto recortada no rosto; trava de gravação deslizando para cima (cadeado, como no WhatsApp); erro da Crystal em turno de risco avisa a equipe por e-mail (`EQUIPE_EMAIL`, padrão contato@leticiafelisberto.com, 1 por conversa a cada 30 min) e a bolha mostra os contatos de emergência |

Cada uma com `backup` antes e `ok os três serviços estão em <tag>`. Versão em
produção ao fim do dia: **`sha-398e46e`**. Volta: `app-subir sha-8ed9ce8` ou anterior.

## 06/10 · correções da revisão e contas locais no ar

- 23:29 UTC (05/10): `app-subir sha-8eefecd` (76 achados corrigidos, menos reembolso). Script `d540c07`.
- 00:05 UTC (06/10): `app-subir sha-9a554f6` (+ contas locais de aluno). Script `1387f41`.
- Nas duas: api.env validado pela própria imagem antes do deploy; "nenhum voltou (UpdateStatus
  sem rollback)"; backup com `crystal_agente` e uploads incremental; `app-supabase-teste` HTTP 200.
- Supabase: base de alunas ligada em 05/10 (URL corrigida depois de colarem `/rest/v1/`; função
  `app_verificar_login` criada; login de aluna real testado pelo Luiz). Igor (testador) cadastrado
  na base aproveitando o registro manual de 27/08 que já tinha o WhatsApp dele; cadastro de teste
  duplicado apagado.
- Login de fora com CPF inexistente: 404 LOGIN_NOT_FOUND (base consultada, resposta sem oráculo).
