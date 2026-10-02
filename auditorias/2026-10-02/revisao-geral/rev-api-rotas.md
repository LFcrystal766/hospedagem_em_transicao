# Revisão da API do crystal-web-chat — rotas, plugins, lib, app/server/env/seed

Data: 2026-10-02. Repositório: `/home/user/crystal-web-chat` (pnpm monorepo, Fastify 5 + Prisma + zod).
Escopo lido na íntegra (linha a linha): `apps/api/src/routes/*.ts` (inclusive `.test.ts`),
`apps/api/src/plugins/*.ts`, `apps/api/src/lib/*.ts`, `app.ts`, `server.ts`, `deps.ts`, `env.ts`, `seed.ts`.
Nada foi modificado nem executado. Para confirmar achados, consultei trechos de
`services/chatwoot-channel.ts`, `services/chatwoot-bot.ts`, `services/messages.ts`,
`services/otp-login.ts`, `services/push.ts`, `services/daily-summary.ts`, `test/helpers.ts`,
`packages/shared/src/{schemas,roles,staff,integrations}.ts` e `prisma/schema.prisma` (fora do escopo de achados).

Convenção de gravidade: **crítico** (exploração direta de dado sensível ou perda de dados sem
pré-condição) · **alto** (falha de segurança/correção com pré-condição plausível em produção) ·
**médio** · **baixo** · **observação**. "A confirmar" marca o que depende de configuração ou
comportamento de terceiro que não dá para verificar só pelo código.

---

## 1. Achados

### ALTO

**A1 — `plugins/rate-limit.ts:34-36`, `env.ts:21`, `app.ts:88` — rate limit por IP depende de `TRUST_PROXY`, cujo default é desligado.** Com Traefik (e, no futuro, o Cloudflare laranja) na frente, `request.ip` é o IP do proxy para todo mundo. `login-ip` (`auth.ts:23`), `verify-ip`, `resend-ip`, `staff-login-ip` usam `RATE_AUTH_MAX=5` por 15 min: cinco logins de alunas diferentes bloqueiam o login de todas por 15 minutos. Se, para "resolver", alguém colocar `TRUST_PROXY=true`, abre spoof de `X-Forwarded-For` e bypass de todos os limites. Correção: no boot de produção exigir `TRUST_PROXY` numérico ou em lista (recusar vazio e `true`), e documentar que com Cloudflare + Traefik são **2** saltos. *A confirmar o valor usado na VPS.*

**A2 — `routes/chatwoot-bot.ts:154` e `routes/channel-webhook.ts:69` — a verificação exige `X-Chatwoot-Signature` + `X-Chatwoot-Timestamp` (HMAC de `"<ts>.<corpo>"`), que o Chatwoot de fábrica não envia.** Os webhooks de conta e de agent bot do Chatwoot upstream vão sem assinatura; o HMAC do Chatwoot é só o `identifier_hash` do contato. Se "o nosso Chatwoot" for a imagem oficial, **todo evento recebe 401** e a Crystal nunca responde (e o balde `chatwoot-bot-invalid`, 30/min, ainda bloqueia o IP do Chatwoot). Correção: confirmar com a stack em `crystal-em-casa/stacks-app/20-atendimento.yaml` se há middleware assinando (n8n/Traefik) ou fork; se não houver, trocar por segredo fixo em header/query (`?token=`) com `safeEqualSecret` e manter a janela de tempo via campo do payload. *A confirmar — alto se for Chatwoot stock.*

**A3 — `env.ts:213-312` — o guard de produção não exige `DATABASE_URL` nem `REDIS_URL`.** Produção sem `DATABASE_URL` sobe em memória (`server.ts:97-99`) e perde tudo no restart; sem `REDIS_URL` o `MemoryKv` (`server.ts:112-114`) deixa OTP, nonce anti-replay, dedup de webhook e rate limit por processo. Nos dois casos o log só imprime "memória (demo)". Correção: em `assertProductionSecrets`, recusar subir sem as duas variáveis (ou exigir `ALLOW_MOCK_INTEGRATIONS=1` explicitamente para isso).

### MÉDIO

**M1 — `routes/auth-otp.ts:109-124` — `/auth/verify` não confere `user.status`.** O bloqueio de conta desligada está só no passo 1 (`auth.ts:61-65`). Quem já tem um desafio aberto (5 min + reenvios) completa o login depois de ser desligado e ganha sessão nova, anulando o `revokeAllForUser` que o admin acabou de disparar em `staff-users.ts:170`. Correção: em verify, `if (user.status !== "active")` → 403 `ACCOUNT_DISABLED` e apagar o desafio.

**M2 — `routes/auth-otp.ts:49-98` — contador de tentativas do OTP não é atômico.** `get` → `attempts += 1` → `set`: N requisições paralelas com código errado leem o mesmo valor e gravam `attempts = 1`. O limite de 5 por desafio deixa de valer sob concorrência; sobra só o `verify-ip` (que o A1 pode estar neutralizando). Correção: usar `incrWithTtl` numa chave `otp:att:<id>` (atômico no Redis) e comparar o retorno, em vez de contar dentro do JSON do desafio.

**M3 — `routes/me.ts:125-126` e `:183-184` — `deps.crystal.forget` fora de try/catch, depois do commit.** Em `/me/data` e `/me/account` o purge e a exclusão já foram gravados e as sessões revogadas; se a Crystal estiver fora, a rota responde 500 sem limpar cookies, o app mostra "falhou" e a aluna tenta de novo (e recebe 401). Correção: envolver em try/catch com `request.log.warn`, ou enfileirar o esquecimento (job com retry) e responder 204 sempre.

**M4 — `routes/me.ts:206-244` — `PUT /me/password` sem rate limit e sem revogar as outras sessões.** Com um cookie de sessão roubado (15 min de access + refresh), dá para tentar a senha atual sem limite (scrypt N=16384 ajuda, mas não substitui o balde) e, ao trocar, as demais sessões continuam válidas. Correção: `rateLimit` por `userKey` (ex.: 5/15 min) e `sessions.revokeAllForUser` exceto a atual dentro da mesma transação.

**M5 — `routes/uploads.ts:112` — admin lê a mídia de qualquer aluna sem trilha de auditoria.** `GET /uploads/:name` libera qualquer arquivo para `role === "admin"`; imagens e áudios são dado sensível (saúde). Não há `audit.record` e nenhum teste cobre esse caminho. Correção: ou remover a exceção (admin não precisa ver mídia do chat), ou registrar `audit` com `targetId` da dona e exigir motivo.

**M6 — `routes/push.ts:11-17` + `services/push.ts:16-22` — endpoint de Web Push é URL arbitrária do cliente (SSRF cega).** `pushSubscribeSchema.endpoint` é `z.string().url()`; o servidor fará POST (web-push) para `http://10.x.x.x:9000/…`, Portainer, n8n, Docker socket exposto etc. a cada notificação. O corpo é cifrado, mas a requisição em si chega à rede interna da VPS. Correção: allowlist de hosts de push (`fcm.googleapis.com`, `*.push.apple.com`, `*.notify.windows.com`, `updates.push.services.mozilla.com`) e recusar IP privado/literal.

**M7 — `routes/chatwoot-bot.ts:189-202` — responde 200 antes de trabalhar, com fila só em memória.** Restart entre o 200 e a resposta (deploy, OOM, `reportFatal`) perde a mensagem; o dedup `chatwoot-bot:msg:<id>` já foi consumido, então o reenvio do Chatwoot vira `duplicate` e a conversa fica `pending` para sempre, sem handoff. Correção: gravar o dedup só depois de responder (ou `kv.del` no `catch` da fila, como faz `channel-webhook.ts:113`), e no boot passar para a equipe conversas que estavam na fila.

**M8 — `server.ts:325`, `services/stream-hub`, `MessageService.pending`, `chatwoot-bot.ts:75` — estado por processo não combina com mais de uma réplica no Swarm.** `failAllStreaming()` numa réplica marca como erro as respostas em streaming das outras; a reconexão SSE (`messages.ts:114`) pode cair numa réplica sem o stream (`STREAM_LOST`); a resposta da inbox (`channel-webhook.ts:106`) pode cair numa réplica sem a bolha pendente e virar mensagem "proativa"; a ordem por conversa do robô só vale dentro de uma réplica. Correção: fixar `replicas: 1` com `order: start-first` desligado (ou sticky session no Traefik) e documentar; *a confirmar o número de réplicas na stack.*

**M9 — `routes/staff-users.ts:92-96` e `:78-90` — lookup por CPF e listagem sem auditoria e sem rate limit.** Suporte e técnico (não só admin) podem enumerar CPFs ("existe/não existe") e listar e-mail, consentimento e `crystal_contact_id` de todas as alunas; nada disso gera `audit.record`. LGPD exige registrar acesso a dado pessoal pela equipe. Correção: `audit.record({action: "user.lookup"|"user.list"})` com hash do CPF consultado e `rateLimit` por `userKey` (ex.: 30/h no lookup).

**M10 — `routes/staff-users.ts:98-134` e `routes/auth.ts:93-96` — e-mail não é único (`prisma/schema.prisma:19`, `email String?`).** Admin pode criar uma conta de equipe com o e-mail de uma aluna; `repos.users.findByEmail` em `auth-staff.ts:34` passa a ser ambíguo (qual linha volta depende do banco). Correção: checar `findByEmail` antes de criar (409) e, idealmente, índice único parcial `WHERE role <> 'user'` ou único global.

**M11 — `env.ts:90-95`, `:324-327` — `NODE_ENV` ausente = `development`: defaults inseguros e rate limit 1000, sem nenhum guard.** Um `docker service` sem `NODE_ENV=production` sobe com `JWT_SECRET` conhecido, `WEBHOOK_SECRET` conhecido e sem limites, mesmo com `DATABASE_URL` real. Correção: se `DATABASE_URL` ou `REDIS_URL` existirem e `NODE_ENV !== "production"`, exigir `ALLOW_MOCK_INTEGRATIONS=1`/`STAGING=1` explícito; ou aplicar `assertProductionSecrets` sempre que houver banco.

**M12 — `routes/webhooks.ts:143-150` e `:235-247` — idempotência de `message`/`nudge` dura só 15 min.** `WEBHOOK_DEDUP_TTL_S = 900`; um reenvio do n8n depois disso (fila travada, retry manual) cria a mensagem proativa duas vezes e dispara dois pushes. `suggestion` tem chave durável (`@@unique([eventId, suggestionId])`), `message` não. Correção: gravar `event_id` em `crystalMessageId` (ou coluna própria com unique) e tratar violação como `duplicate`.

**M13 — `seed.ts:211-224` + `server.ts:298` — staging com banco real e `DEMO_SEED=1` cria admin e equipe com a senha fixa `crystal-equipe-1`.** Se o staging estiver acessível pela internet (é o caso quando se testa o PWA), é acesso de admin trivial. Correção: só aplicar a senha demo quando não houver `DATABASE_URL`, ou exigir `DEMO_STAFF_PASSWORD` no env.

### BAIXO

**B1 — `routes/staff-users.ts:198-203`** — senha fraca devolve `PASSWORD_WEAK` com `MICROCOPY.invalidCredentials` ("E-mail ou senha incorretos"). Correção: usar a mensagem do Zod, como `me.ts:216`.

**B2 — `routes/auth.ts:141-143`** — 500 com texto interno "Conta de revisão sem código configurado." vaza detalhe de configuração. Correção: `request.log.error` + `MICROCOPY.internalError`.

**B3 — `routes/onboarding.ts:18-24`** — fuso validado só por regex (`Foo/Bar` passa) e inconsistente com `me.ts:31` (`isIanaTimezone`); se o serviço usar `Intl` com esse valor, vira 500. Correção: reutilizar `isIanaTimezone`.

**B4 — `routes/uploads.ts:72`** — tipo do arquivo é o `mimetype` declarado pelo cliente; não há checagem de magic bytes. Como o `content-type` da resposta vem da extensão e o helmet manda `nosniff`, o impacto é baixo, mas um `.png` com HTML dentro ainda é servido. Correção: validar os primeiros bytes (file-type) antes de gravar.

**B5 — `routes/tickets-me.ts:51-67`** — sem rate limit em `POST /me/tickets/:id/messages` (só na criação). Correção: balde por `userKey`.

**B6 — `routes/chatwoot-bot.ts:81, 92, 101, 133`** — `console.warn` em vez de `app.log`/`request.log`: perde nível, `reqId`, redaction e formato pino. Correção: receber `app.log` no `registerChatwootBot` (os testes já leem `console.warn`; ajustar para `log.warn`).

**B7 — `routes/health.ts:7`** — `/health/channel` sem autenticação expõe modo backup e estado da Meta. Correção: mover para trás de `requireArea("canal")` ou devolver só `{ok:true}`.

**B8 — `env.ts:25, 84`** — `CRYSTAL_API_URL` e `DIRECTORY_API_URL` não exigem `https://` em produção (o guard só cobre Supabase e Chatwoot); a API key iria em claro. Correção: mesma regra do `CHATWOOT_BASE_URL` em `assertProductionSecrets`.

**B9 — `routes/me.ts:104`** — `DELETE /me/data` é irreversível e não exige confirmação no corpo, ao contrário de `/me/account:156`. Correção: mesmo `{ confirm: "EXCLUIR" }`.

**B10 — `routes/chatwoot-bot.ts:68-73`** — limite só por IP (600/min do próprio Chatwoot): uma inbox de WhatsApp com flood gera até 600 chamadas de LLM por minuto. Correção: balde por `conversa` (ex.: 10/min) e por `contato`.

**B11 — `routes/auth.ts:93-96`** — se o CPF de alguém da equipe existir na base de alunas, login com e-mail divergente confirmado pela base troca o e-mail da conta de equipe, mudando o login de `/auth/staff/login`. Correção: só atualizar e-mail quando `user.role === "user"`.

**B12 — `routes/messages.ts:76`** — `existsSync` síncrono no event loop a cada mensagem com mídia. Correção: `fs.promises.access`.

**B13 — `routes/messages.ts:113-137`** — depois de `reply.hijack()`, uma exceção em `findReplyTo` não fecha `conn`; o error handler não consegue responder e a conexão SSE fica aberta até o cliente desistir. Correção: `try { … } catch { conn.send("error", …); conn.close(); }`.

**B14 — `routes/admin.ts:43-49`** — `detail` dos `health_events` vai cru para tech/admin; pode carregar mensagens de erro de sondas (URL, host interno). Correção: truncar/normalizar na sonda.

### OBSERVAÇÕES

**O1 — `routes/prontuario.ts:48-52`** — há rota para dar o consentimento sensível, mas nenhuma para revogá-lo (LGPD art. 8 §5). Hoje a única saída é `DELETE /me/data`.

**O2 — `routes/me.ts:88-94`** — o export inclui `finance.notes` (texto livre escrito pela equipe, ex.: "pagou pela chave pix pessoal"). O direito de acesso cobre isso, mas vale orientar a equipe a não escrever dado de terceiros nas notas.

**O3 — `routes/me.ts:44-100`** — `/me/export` sem rate limit e montando todo o histórico em memória; aceitável hoje, mas é o endpoint mais pesado da API.

**O4 — `routes/integrations.ts:62-79`** — o evento de teste com `crystal_contact_id` real escreve na conversa de uma aluna de verdade e dispara push. Está auditado; só registrar que é intencional.

**O5 — `server.ts:63-64`** — `unhandledRejection` → `process.exit(1)`: fail-fast correto, mas um bug num job de fundo (alerts, retention, hub) derruba a API para todas; depende do `restart_policy` do Swarm.

**O6 — `server.ts:104-111`** — Redis fora do ar faz `kv.incrWithTtl` lançar no preHandler → 500 em login/mensagens (fail-closed). É o comportamento desejado, mas o alerta operacional precisa cobrir isso.

---

## 2. O que está bem feito

- **Autenticação em duas etapas** (CPF+e-mail → OTP → cookies) sem cookie no passo 1; refresh opaco com hash e rotação; access JWT revogável de verdade pela sessão (`plugins/auth.ts:120-129`).
- **Sem oráculo**: 404 idêntico para CPF inexistente e e-mail errado; 401 único no login de equipe com scrypt sempre executado (`lib/password.ts:30-39`); rotas de equipe respondem 404 (não 401/403) para quem não pertence à área.
- **Comparações em tempo constante** em todos os segredos (`safeEqualHex`, `safeEqualSecret`, `verifyInboxWebhook`), com hash prévio para esconder tamanho.
- **Webhook n8n**: HMAC do corpo cru, janela ±5 min, nonce atômico (Lua) gravado só após a assinatura, nonce liberado se nada persistiu, efeitos colaterais best-effort, log só com metadados (`webhook-log.ts`).
- **LGPD**: CPF nunca em claro (hash+last4, serializer de log sem query em `/staff/users`), campos sensíveis em AES-256-GCM com IV por valor, purge transacional tudo-ou-nada, cópia anônima na exclusão de conta, financeiro anonimizado, `/me/export` completo.
- **Boot guard de produção** (`env.ts:213-312`) barra defaults de dev, entropia baixa, `DEMO_SEED`, OTP mock e combinações inválidas do Chatwoot.
- **Isolamento por dona** em prontuário, tickets, uploads (prefixo `uuid__`), conversas e streams, com testes cruzados dedicados (`prontuario-cross-user.test.ts`).
- **Chamadas externas** com `AbortSignal.timeout` e `redirect: "manual"` (sem seguir redirecionamento com token).
- **Lockout de admin** (próprio papel/status e último admin ativo) e revogação de sessões ao mudar papel ou desligar.
- **Rate limit** em todas as rotas sensíveis que dependem de entrada anônima (login, verify, resend, webhooks, daily-summary, uploads, mensagens, tickets, push nativo).

---

## 3. Testes — cobertura e lacunas

**Coberto bem**: fluxo completo de login/OTP (expiração, tentativas, reenvio, conta de revisão), isolamento entre usuárias, paginação (inclusive empates de timestamp), webhook n8n (assinatura, replay, dedup, modo header, falha de persistência, falha de push), inbox Chatwoot (eco, nota privada, dono errado, timeout de resposta), robô do Chatwoot (conta errada, handoff, pedido de atendente, falha da Crystal, ordem na fila), equipe (áreas por papel, lockout, auditoria), financeiro, uploads (tipo, tamanho, path traversal, dona), LGPD (export, purge transacional, exclusão de conta).

**Lacunas importantes (casos negativos / autorização)**:

1. `/auth/verify` com conta desligada entre o passo 1 e o 2 (M1) — não há teste; hoje passaria.
2. Tentativas concorrentes de OTP (M2) — nenhum teste de paralelismo.
3. `TRUST_PROXY`/`X-Forwarded-For` (A1) — nenhum teste de que o IP do rate limit é o real atrás de proxy, nem de que `true` é recusado.
4. `GET /uploads/:name` por admin em arquivo alheio (M5) — comportamento sem teste.
5. `PUT /me/password` — sem teste de rate limit nem de sessões antigas após a troca (M4).
6. `/push/subscribe` — nenhum teste de validação do endpoint (M6); `push-devices.test.ts` cobre só o nativo.
7. `/me/data` e `/me/account` com `crystal.forget` lançando (M3) — nenhum teste do caminho de erro.
8. Webhook `message`/`nudge` reenviado após o TTL do nonce (M12) — só `suggestion` tem o teste "idempotência durável".
9. `chatwoot-bot`: conteúdo vazio (`AVISO_SEM_TEXTO`), `conversation.id` ausente, timeout da Crystal (`AbortSignal`), e restart com fila cheia (M7) — sem teste.
10. `channel-webhook`: baldes separados de assinatura válida/inválida — sem teste de 429.
11. `/staff/users` com e-mail duplicado (M10) e `lookup` por suporte (autorizado, mas sem teste de auditoria/limite).
12. `/staff/finance/users/:id/status` com alvo de equipe (deve 404) — sem teste.
13. `serializeRequestForLog` para `/me/password` e `/auth/staff/login` — só `/staff/users` testado.
14. `/health/channel` e `/healthz` — sem teste (menor).
15. `env.ts`: há `env.test.ts` fora do escopo desta revisão; verificar se cobre `CHAT_TRANSPORT=chatwoot` + bot e `ALLOW_MOCK_INTEGRATIONS`.

---

## 4. Contagem

- **Arquivos lidos integralmente no escopo**: 66 (`routes/` 49 incl. 24 testes, `plugins/` 3, `lib/` 12 incl. 2 testes, raiz 5).
- **Linhas lidas no escopo**: 10.103 (`wc -l`).
- **Arquivos consultados fora do escopo para confirmação**: 9 (trechos).
- **Achados**: crítico 0 · alto 3 · médio 13 · baixo 14 · observação 6 — total 36.
- **Marcados "a confirmar"**: A1 (valor de `TRUST_PROXY` na VPS), A2 (assinatura no Chatwoot em uso), M8 (número de réplicas no Swarm).

## 5. Ordem sugerida de correção

1. A2 (sem isso o robô não funciona) → A1 e A3 (guards de boot, 20 linhas em `env.ts`).
2. M1, M2, M4 (auth) e M6 (SSRF do push) — pequenos e de segurança.
3. M3, M7, M12 (robustez de produção) e M8 (decisão de réplicas).
4. M5, M9, M10, M13 (LGPD e equipe), depois os baixos.
