# Revisão de código — API: serviços, camada de dados, Prisma, testes e imagem

**Repositório:** `/home/user/crystal-web-chat` (commit `44f356b`, "a nossa Crystal como robô do nosso Chatwoot")
**Escopo lido linha a linha:** `apps/api/src/services/*.ts` (37 arquivos, inclusive `.test.ts`), `apps/api/src/db/*.ts` (35), `apps/api/prisma/schema.prisma` + 14 migrações + `migration_lock.toml`, `apps/api/src/test/helpers.ts`, `apps/api/Dockerfile`, `apps/api/package.json`.
**Leituras de apoio (fora do escopo, só para confirmar achados):** `lib/field-crypto.ts`, `lib/crypto.ts`, `lib/kv.ts`, `lib/otp-challenge.ts`, trechos de `routes/me.ts`, `routes/channel-webhook.ts`, `routes/chatwoot-bot.ts`, `routes/uploads.ts`, `server.ts`, `env.ts`, e os logs `09-prisma-migracoes.log` e `10-smoke-prisma.log` desta mesma rodada.
**Data:** 2026-10-02. Nada foi modificado nem executado.

Legenda de gravidade: **crítico** (perda/vazamento de dado ou quebra em produção, agir já) · **alto** (bug ou falha de LGPD/segurança concreta) · **médio** (bug latente, risco operacional, dívida que vai doer) · **baixo** (melhoria pontual) · **observação** (nota, sem ação obrigatória, ou "a confirmar").

---

## 1. Achados

### 1.1 Alto

**A1 — A exclusão de conta/dados não alcança a inbox (Chatwoot/LendChat): a conversa do aluno continua lá.**
`apps/api/src/services/prontuario.ts:281-298` (purge) e `apps/api/src/routes/me.ts:104-199` (confirmação de apoio).
No modo `CHAT_TRANSPORT=chatwoot` cada mensagem do aluno e cada resposta da Crystal ficam gravadas na conversa da inbox (`chatwoot-channel.ts:157-163`). O purge apaga só o vínculo local (`conversations.deleteForUser`); nenhuma chamada apaga o contato/conversa na inbox, e o `forget` da Crystal (`crystal.ts:134-152`) nem roda quando `path !== "/v1/messages"`. Pior: como o contato é identificado pelo telefone, o próximo envio depois de um `DELETE /me/data` reencontra o mesmo contato e **reaproveita a conversa antiga ainda aberta** (`chatwoot-channel.ts:142-150`), ou seja, o histórico "apagado" volta a servir de contexto.
*Correção:* na exclusão, chamar a API de agente do Chatwoot para apagar o contato (ou ao menos resolver a conversa e apagar as mensagens) e gravar o resultado na auditoria; enquanto não houver token com esse escopo, documentar o procedimento manual e o prazo.

**A2 — A redação da cópia anônima deixa passar nomes em início de frase e nomes em minúsculas.**
`apps/api/src/services/anonymous-copy.ts:68-72` (`inicioDeFrase`) e `:94-103` (`redigir`).
Um nome próprio só vira `[nome]` se (a) estiver em `NOMES_COMUNS`/no nome do titular ou (b) estiver com maiúscula **e** não for início de frase. Logo "Zuleide me ligou", "Chorei. Zuleide ligou" e qualquer nome digitado em minúsculas fora da lista ("a zuleide", "moro em campinas", "trabalho na magalu") sobrevivem. Conversa de WhatsApp/app é majoritariamente minúscula. Confirmei relendo: em `pos === 0` `inicioDeFrase` devolve `true` e a palavra é mantida; `maiuscula === false` também mantém. O próprio cabeçalho admite que "a redação é por regra, não é perfeita", mas a tabela é guardada por prazo indeterminado como "não dado pessoal" (art. 12), e esse enquadramento não se sustenta com esses vazamentos.
*Correção:* tratar a cópia como pseudonimizada (ciclo de vida, acesso restrito) ou acrescentar uma passada de NER/LLM na redação antes de gravar; no mínimo redigir também palavras em início de frase que não estejam numa lista de palavras comuns do português.

### 1.2 Médio

**M1 — Estado em memória que quebra com 2 réplicas ou com reinício.**
`messages.ts:44` (`pending`), `stream-hub.ts:29` (`streams`), `chatwoot-channel.ts:85` (`linking`), `backup.ts:20`, `health.ts:51-53`.
Com duas réplicas, o webhook da inbox pode cair na réplica que não tem a bolha de espera: a resposta vira mensagem "proativa" nova e, 3 min depois, a bolha da outra réplica recebe o texto de timeout (duplicação visível ao aluno). O replay do SSE (`?after=seq`) também se perde. Está documentado ("por isso a API roda com uma réplica só"), mas nada impede o scale-out.
*Correção:* mover `pending` para o Redis (chave por `outMsgId` com TTL) e, enquanto isso, travar `replicas: 1` no compose/stack com comentário apontando para este ponto.

**M2 — `fetch` sem timeout no FCM (OAuth e envio).**
`native-push.ts:93-100` e `:134-141`.
Nenhum `AbortSignal.timeout`. Um Google pendurado bloqueia `notifyUser`, que é aguardado na resposta do suporte (`tickets.ts:292`) e no webhook do canal (`channel-webhook.ts:125`).
*Correção:* `signal: AbortSignal.timeout(10_000)` nas duas chamadas.

**M3 — `INVALID_ARGUMENT` do FCM apaga o token do dispositivo, mas também é o erro de payload malformado.**
`native-push.ts:148-152`.
Se por qualquer motivo o corpo da mensagem for recusado (campo inválido, mudança da API), **todos** os tokens de todos os dispositivos daquela rodada entram em `invalid` e são removidos (`push.ts:138-140`). Só `UNREGISTERED` identifica token morto com segurança.
*Correção:* remover só em `UNREGISTERED` (e 404); em `INVALID_ARGUMENT` logar e manter o token.

**M4 — Sonda da Meta sem timeout e `tick` do monitor sem guarda de sobreposição.**
`health.ts:32-35` (fetch sem `signal`) e `:102-110` (`setInterval` chama `tick` mesmo com o anterior em andamento).
*Correção:* `AbortSignal.timeout(5_000)` na sonda e um flag `running` no `start()`.

**M5 — A trilha de auditoria guarda o texto de `notes` do financeiro, que sobrevive à exclusão do aluno.**
`finance.ts:93-114` monta `changes[notes] = { from, to }` com o conteúdo inteiro; `audit_log` não tem FK e não é tocado no purge, enquanto `anonymizeByUser` zera `notes` em `finance_entries` (`prisma-finance.ts:74`). Notas livres sobre a aluna ("pagou atrasado porque está desempregada") ficam para sempre na auditoria, contrariando o comentário de `user-types.ts:78`.
*Correção:* em `changes.notes` gravar só `{ changed: true }` (ou hash), nunca o texto.

**M6 — Push nativo da resposta do suporte leva o assunto do ticket em claro pelo FCM/APNs.**
`tickets.ts:292-296` chama `notifyUser` sem `privado: true`; `push.ts:75-78` só substitui o corpo quando `privado` vem. O assunto é texto livre do aluno ("compulsão à noite", "não aguento mais").
*Correção:* `privado: true` nessa chamada (o Web Push continua levando o texto, cifrado ponta a ponta).

**M7 — N+1 e cargas integrais em listagens quentes.**
- `finance.ts:35-51` (`dto`): 2 `users.findById` por linha; `list()` com `limit` 50–100 vira 100–200 consultas.
- `tickets.ts:103-129` (`toDto` + `toStaffDto`): `countForTicket` + `users.findById` + `author()` por ticket da página.
- `daily-summary.ts:25-31`: carrega **todas** as mensagens da conversa (páginas de 200 até acabar) só para filtrar o dia.
- `prisma-finance.ts:78` (`aggregate`): `findMany()` sem `where`, agrega em JS — cresce com o histórico inteiro.
- `push.ts:72`: `push.listAll()` e filtra por `userId` em memória a cada mensagem proativa (não há `listForUser` em `PushRepo`).
*Correção:* `findMany({ where: { id: { in } } })` em lote para usuários/autores, `count` agrupado, `listBetween(conversationId, start, end)` para o resumo, `groupBy`/`aggregate` no banco para o financeiro e `push.listForUser`.

**M8 — Divergência confirmada entre `schema.prisma` e as migrações (tipos `TIMESTAMPTZ`).**
`schema.prisma:54,61-63` declaram `DateTime` (Prisma gera `TIMESTAMP(3)`); `migrations/10_finance:9,16,17` e `11_finance_anonymize:4` criam `TIMESTAMPTZ`. O log `09-prisma-migracoes.log` mostra `migrate diff` com exit=2 (4 colunas "type changed" e as duas FKs recriadas). Em produção o `migrate deploy` não reclama, mas o próximo `migrate dev` vai gerar uma migração que altera o tipo das colunas (e recria FKs), com risco de alguém aplicar sem querer.
*Correção:* anotar `@db.Timestamptz(6)` nessas quatro colunas no schema (sem migração nova) ou, se a intenção era `TIMESTAMP(3)`, gerar a migração conscientemente; depois validar que `migrate diff` fica vazio.

**M9 — Nome das migrações sem zero à esquerda: a ordem de aplicação não é a numérica.**
`prisma/migrations/` (`0_init`, `1_prontuario`, `10_finance`, …, `9_staff_password`). O mesmo log mostra a ordem real num banco vazio: `0, 1, 10, 11, 12, 13, 2, 3, …, 9`. Hoje funciona porque 10–13 só dependem de `users`/`conversations` (criadas em `0_init`). A próxima migração `14_x` que alterar uma tabela criada em `2`–`9` (ex.: `audit_log`, `tickets`, `suggestions`) **vai falhar em banco novo/CI** e passar em produção, onde a história já está gravada.
*Correção:* a partir de agora usar prefixo de timestamp (`20261002120000_nome`) como o Prisma recomenda; não renomear as já aplicadas.

**M10 — Índices faltando em colunas consultadas.**
- `users.crystal_contact_id`: `prisma-users.ts:30-33` faz `findFirst` por ele (webhook n8n → BFF, por evento) e o schema não tem `@@index([crystalContactId])`.
- `messages.created_at` sozinho: `deleteOlderThan`, `listMediaOlderThan` e `countSince` (`prisma-chat.ts:88-111`) filtram só por data; o índice existente é `(conversation_id, created_at)` e não serve a esse range → varredura completa a cada tick de retenção (hora em hora).
- `users.email`: `findByEmail` (login da equipe, `prisma-users.ts:114-119`) sem índice (tabela pequena hoje; baixo custo de corrigir).
*Correção:* `@@index([crystalContactId])`, `@@index([createdAt])` em `Message`, e índice funcional `lower(email)` se a busca insensível a caixa continuar.

**M11 — Retenção não poda `health_events` nem `sessions`.**
`retention.ts:23-49` só apaga mensagens e `webhook_events`. `health_events` recebe uma linha por sonda por integração a cada intervalo do monitor **e** do laço de alertas (`alerts.start` → `integrations.check`, `server.ts:338`), para sempre; `sessions` guarda `ip` + `user_agent` de sessões expiradas/revogadas sem limite.
*Correção:* `deleteOlderThan` para `health_events` (ex.: 90 dias) e para sessões expiradas há mais de N dias, dentro do mesmo `tick`.

**M12 — `period` da cópia anônima casa com a auditoria `user.delete`.**
`anonymous-copy.ts:186` grava o mês da exclusão; `me.ts:178-181` grava `user.delete` com `actorId`/`targetId` = id do usuário e timestamp exato, em tabela sem FK. Com uma exclusão no mês (volume atual), quem tem o banco liga a cópia ao id excluído e, por `anon_ref`/finance e pelo próprio id em outras tabelas, a um conjunto de dados que a pessoa pediu para apagar. O comentário de `archive-types.ts:3-4` ("para não casar com o log de auditoria") não se cumpre.
*Correção:* não gravar `period` (ou gravar só o ano), ou só persistir a cópia quando houver ≥ k exclusões no período (k-anonimato), ou gravá-la com atraso aleatório.

**M13 — Dois alunos com o mesmo telefone: o segundo nunca consegue enviar e o erro é genérico.**
`chatwoot-channel.ts:137-153` + `schema.prisma:199` (`channelSourceId @unique`). O contato na inbox é só o telefone; o segundo cadastro com o mesmo número recebe o mesmo `source_id`, `setChannelLink` lança P2002, `messages.ts:180-199` loga `PrismaClientKnownRequestError` e devolve `CHANNEL_UNAVAILABLE` — toda vez. Além do bug, há mistura de memória da Crystal entre duas pessoas.
*Correção:* tratar P2002 explicitamente (código `CHANNEL_PHONE_IN_USE`, aviso ao suporte) e decidir se telefone compartilhado é permitido; se for, usar `identifier` por usuário e não por telefone.

**M14 — `forget` da Crystal é silencioso: falha some sem registro.**
`crystal.ts:139-151` engole qualquer erro; `me.ts:125-126,183-184` não grava se a Crystal confirmou. Para um pedido de exclusão LGPD não há evidência de que a memória externa foi apagada.
*Correção:* devolver `boolean`, gravar o resultado em `details` da auditoria e enfileirar nova tentativa (ou alertar a equipe) em caso de falha.

**M15 — Imagem Docker roda como root, com tag flutuante e TypeScript interpretado em produção.**
`Dockerfile:1` (`node:22-alpine`, tag móvel; a regra do repositório pede versão fixa), sem `USER node`, sem `HEALTHCHECK`; `package.json:8` `start: tsx src/server.ts` (compila a cada boot e leva `devDependencies` para a imagem).
*Correção:* fixar `node:22.x.y-alpine3.xx` (ou digest), `USER node` depois do install, `HEALTHCHECK` no `/healthz`; opcionalmente `tsc` para `dist/` + `pnpm prune --prod`.

**M16 — Hash de CPF enumerável por quem tiver `CPF_SALT`; `cpf_last4` em claro encolhe ainda mais o espaço.**
`lib/crypto.ts:8-10` (`sha256("cpf:salt:cpf")`, apoio) usado por `prisma-users.ts:22` e `schema.prisma:12-13`. Só existem ~10⁹ CPFs válidos; com o salt (único, global) um vazamento do banco + segredo reverte todos os hashes em minutos, e `cpf_last4` reduz cada busca a 10⁵ candidatos. Sem o salt o banco é seguro, então o desenho depende de guardar o segredo separado do dump.
*Correção:* trocar por HMAC-SHA256 com chave em cofre separado (mantém a busca exata) ou por KDF lenta de parâmetros fixos (`scrypt`/`argon2id`) se o custo de login permitir; reavaliar se `cpf_last4` precisa existir (a máscara pode vir da base do fornecedor).

**M17 — Não há nenhum teste contra o Postgres/Prisma.**
`test/helpers.ts:65` sempre usa `createMemoryRepos`. Toda a camada `db/prisma-*.ts` (cursores em SQL, `updateOwned` com P2025, `createIfAbsent` com `skipDuplicates`, `transaction` com timeout de 15 s, `upsert` do onboarding com `question: { set: null }`) e as migrações só são exercitadas pelo smoke manual (`10-smoke-prisma.log`). O drift de M8 e a ordem de M9 passaram justamente por isso.
*Correção:* um job de CI com Postgres (serviço ou testcontainers) que rode `migrate deploy`, `migrate diff --exit-code` e uma suíte pequena dos repos Prisma.

### 1.3 Baixo

**B1 — `redirect` seguido em clientes que mandam segredo e dado do aluno.**
`crystal.ts:158-172` (texto do aluno + chave), `crystal.ts:140-148` (`forget`), `directory.ts:60-70` (CPF + e-mail + chave), `onboarding-crystal.ts:29-34`. Os clientes Supabase e Chatwoot usam `redirect: "manual"`; estes não. Um 307/308 reenvia o corpo ao destino do redirect.
*Correção:* `redirect: "manual"` e tratar 3xx como indisponível.

**B2 — Corpo de resposta não consumido em erro/sucesso descartado.**
`crystal.ts:188-196` (status ≠ 2xx), `crystal.ts:140-148` (`forget`), `chatwoot-channel.ts:170-178` (erro vira `throw` sem `cancel`), `directory.ts:71-72,136`, `email.ts:31-33`. Em undici a conexão fica presa até o GC.
*Correção:* `await res.body?.cancel()` antes de lançar/retornar (como já faz `chatwoot-bot.ts:65`).

**B3 — Painel técnico descreve "diretório" e "crystal" só pelas variáveis antigas.**
`integrations.ts:103-113` ignora `SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` e `:91-102` ignora `CHAT_TRANSPORT=chatwoot`, enquanto `integration-probes.ts:215-227` os considera. Resultado: `configured: false` e aviso "só usuários provisionados localmente entram" com a base do Supabase ligada.
*Correção:* usar a mesma condição do `buildProbeBundle` em `describe`.

**B4 — O texto de erro da bolha vira mensagem "da Crystal" com `status: "done"`.**
`messages.ts:268-278` (`failPlaceholder`). Entra no histórico, na cópia anônima (`anonymous-copy.ts:173` só filtra `error`) e no resumo diário como fala da Crystal.
*Correção:* manter `status: "error"` e guardar o motivo em campo próprio (ou prefixo reconhecível) para o front mostrar.

**B5 — `hasPending` não é usado; comentário desatualizado.**
`messages.ts:246-249`. O webhook decide o push por `delivered.proactive` e pela chave `channel:recent` (`channel-webhook.ts:119-123`).
*Correção:* remover ou atualizar o comentário.

**B6 — `pickPending` com `echoId` que não casa cai na única bolha aberta.**
`messages.ts:251-256`. Resposta tardia à pergunta 1 (bolha já expirada) preenche a bolha da pergunta 2.
*Correção:* quando `echoId` vier e não casar, tratar como proativa.

**B7 — `BackupService.lastActive` em memória gera aviso repetido após reinício (e por réplica).**
`backup.ts:20,55-66`.
*Correção:* guardar o último estado notificado em `system_settings`.

**B8 — `MockEmailSender` em produção loga o e-mail do destinatário.**
`email.ts:41-44`. Só roda com `ALLOW_MOCKS` (a confirmar), mas o log já vai com PII.
*Correção:* `maskEmail(opts.to)`.

**B9 — Ordenação por `Number(id)` com ids que o schema permite como string.**
`chatwoot-channel.ts:148`: `NaN - NaN` deixa o `sort` indefinido.
*Correção:* comparar como string quando não for numérico, ou exigir número no schema.

**B10 — `decodeCursor` não limita `time`.**
`db/types.ts:62-69`: `new Date(1e20)` é `Invalid Date` e o Prisma lança (500) em qualquer listagem com cursor forjado.
*Correção:* rejeitar `time` fora de `[0, 8.64e15]`.

**B11 — Retenção apaga as linhas antes de apagar os arquivos; falha no `unlink` deixa mídia órfã para sempre.**
`retention.ts:32-41`.
*Correção:* apagar os arquivos primeiro (ou registrar os que falharam para nova tentativa).

**B12 — `messages.update` do Prisma lança P2025 se a mensagem sumir no meio do stream.**
`prisma-chat.ts:66-68` usa `update` (lança); `messages.ts:123,130,135,142` chamam sem `catch` (só `failPlaceholder` tem). O `run().catch` do hub transforma em `INTERNAL`, mas o aluno vê erro genérico se a retenção/purge correr durante a geração.
*Correção:* `updateMany` no repo (coerente com `users.update`/`tickets.update`).

**B13 — Duas fontes gravam `source: "meta"` com vocabulários diferentes.**
`health.ts:71-76` (`up/down/unknown`) e `integrations.ts:282-289` (`ok/degraded/down/skipped`), ambos lendo `latestBySource("meta")` como "anterior" → transições de alerta espúrias (`degraded`→`down`) e sondagem dupla à Graph API no mesmo minuto (`server.ts:331-338` inclui `"meta"` no laço de alertas).
*Correção:* uma só sonda da Meta (a do painel) alimentando o monitor, ou `source` distintos.

**B14 — Resposta pública da equipe em ticket fechado reabre sem aviso.**
`tickets.ts:280-286` (`closedAt: null`, `status: "waiting_user"`). A confirmar se é intencional.
*Correção:* se não for, devolver `closed` como em `addUserMessage`.

**B15 — `ticket_messages.author_id ON DELETE CASCADE` é armadilha para uma futura exclusão de membro da equipe.**
`schema.prisma:356`, `migrations/3_tickets:52`. Hoje nenhuma rota apaga usuário de equipe (`me.ts:160`), mas se vier a existir, as respostas do suporte somem dos tickets dos alunos.
*Correção:* `onDelete: SetNull` + `authorId String?` (ou `Restrict`).

**B16 — Rollback emulado em memória não cobre `settings` nem `health`.**
`memory-system.ts:84-90` só restaura `pushSubsStore`. Só afeta demo/testes.
*Correção:* incluir os três stores no `snapshot`.

**B17 — `user.crystalContactId!` no resumo diário.**
`daily-summary.ts:41`: aluno sem id de contato gera `crystal_contact_id: null` tipado como `string`.
*Correção:* validar antes (404/409) ou tipar como `string | null`.

**B18 — `deliver` do Web Push engole 401/403 (VAPID errado) sem log.**
`push.ts:110-115`.
*Correção:* `console.warn` com `statusCode` (sem endpoint).

**B19 — `errorCode` do FCM lido só em `details[0]`.**
`native-push.ts:148-149`. A API devolve vários `details` e o `FcmError` nem sempre é o primeiro.
*Correção:* `details.find((d) => d.errorCode)`.

**B20 — Regex com caracteres combinantes literais.**
`chatwoot-bot.ts:83` (`/[̀-ͯ]/g`) funciona, mas é invisível no editor; `onboarding-crystal.ts:73` usa `̀-ͯ`.
*Correção:* padronizar com escapes (ou `\p{M}` com `u`, como `anonymous-copy.ts:52`).

**B21 — Timeout único de 60 s cobre o streaming inteiro.**
`crystal.ts:171` (`withTimeout` sobre a resposta toda). Resposta longa > `CRYSTAL_API_TIMEOUT_MS` é cortada como "caiu no meio". A confirmar o valor em produção.
*Correção:* timeout de conexão/primeiro byte separado do de inatividade entre tokens.

**B22 — `listAllForUser` dentro da transação de 15 s.**
`anonymous-copy.ts:157` + `prisma.ts:19`. Titular com anos de conversa pode estourar o teto e abortar a exclusão inteira (com rollback correto, mas 500 para o aluno).
*Correção:* paginar/stream, ou montar a cópia antes da transação e só gravá-la dentro.

**B23 — Todos os usuários de teste têm o mesmo `crystalContactId: "contact-teste"`.**
`test/helpers.ts:156`. `findByCrystalContactId` devolve "o primeiro", o que mascara bugs de casamento de contato nos testes do webhook.
*Correção:* `contact-${cpfLast4}`.

**B24 — Esquema de assinatura `X-Chatwoot-Signature`/`X-Chatwoot-Timestamp`: a confirmar com o Chatwoot real.**
`chatwoot-channel.ts:198-218` (correto em si: HMAC sobre `timestamp.corpo`, janela de 300 s, comparação em tempo constante). O Chatwoot de fábrica não assina webhooks de inbox nem de agent bot com esses cabeçalhos; se não houver um proxy/n8n assinando no caminho, `routes/chatwoot-bot.ts:154` recusa tudo com 401.
*Correção:* confirmar na stack `atendimento.` quem assina; se ninguém, acrescentar a assinatura no proxy antes de ligar o robô.

**B25 — Opções do onboarding falam de relacionamento/dates; o produto é emagrecimento.**
`onboarding-crystal.ts:47-57` e `goalType: "reconquista"` em `anonymous-copy.test.ts:70`. A confirmar se é resquício ou se o enunciado desta revisão está desatualizado.

**B26 — `sessions` guarda e-mail/IP/UA e o desafio OTP guarda o e-mail em claro no Redis.**
`otp-login.ts:45-57` (TTL = `OTP_TTL_S`). Aceitável, mas vale constar no inventário LGPD do Redis.

### 1.4 Observações (sem ação obrigatória)

- **O1** `stream-hub.ts:112-121`: no modo chatwoot a carência de 30 s aborta um `AbortController` que ninguém escuta; inofensivo, mas `onAbort` nunca é configurado em `server.ts` (a confirmar) e o `stale` só é limpo no `finish`.
- **O2** `messages.ts:67-89`: `inMsg` e `outMsg` são dois `create` fora de transação; falha no segundo deixa a pergunta sem bolha (o front já lida com `status`).
- **O3** `suggestions.ts:70-99`: uma transação por item do lote; aceitável para o volume esperado.
- **O4** `error-reporter.ts:19-24`: `scrub` cobre CPF de 11 dígitos, OTP e e-mail; telefone de 10 dígitos e nomes passam. `beforeSend` já remove cabeçalhos/corpo, então o risco é só em mensagens de exceção.
- **O5** `prisma-system.ts:71-77` e `:94-113`: endpoint/token migram de dono no `upsert` (mesmo aparelho, novo login). Correto, mas vale lembrar que isso é o que torna `deleteByEndpoint(endpoint)` sem `userId` seguro.
- **O6** `prisma.ts:47-55`: transação aninhada reaproveita o `tx` (correto); isolamento padrão `READ COMMITTED` basta para os caminhos usados.
- **O7** `memory-chat.ts:37-49` lança `Error` genérico onde o Prisma lança P2002 (M13): as duas camadas divergem no tipo do erro, o que dificulta testar o tratamento.

---

## 2. O que está bem feito (resumo)

- **Cripto de campo** (`lib/field-crypto.ts`, confirmado): AES-256-GCM, IV aleatório de 96 bits por valor, tag verificada, chave de 32 bytes exigida em produção. Nenhum IV/nonce reutilizado em todo o escopo.
- **Webhook da inbox** (`chatwoot-channel.ts:198-218`): HMAC sobre `timestamp.corpo`, janela, formato validado por regex, `timingSafeEqual` com checagem de tamanho; dono do evento decidido só pelo vínculo local (`resolveOwner`), nunca pelo payload. `identifier_hash` do Chatwoot calculado certo.
- **Chatwoot bot client** (`chatwoot-bot.ts`): `redirect: "manual"`, timeout, corpo cancelado, token só em cabeçalho, conta conferida na rota.
- **Supabase directory**: CPF só no corpo, função RPC em vez de tabela, `service_role` só no servidor, `redirect: "manual"`, 4xx/5xx nunca viram "não encontrado".
- **Logs sem PII** nos serviços: só código, status HTTP e `err.name`; `MICROCOPY` para o aluno; corpo da Crystal nunca vaza.
- **Purge transacional** (`prontuario.purge` + `me.ts`): perfil, metas, progresso, insights, sugestões, onboarding, mensagens, conversas, push web e nativo, tickets e mensagens de ticket, financeiro anonimizado, sessões revogadas, usuário apagado, mídia no disco fora da transação e só após o commit; cópia anônima montada dentro da mesma transação. Smoke contra o Postgres confirma (`10-smoke-prisma.log`).
- **FKs coerentes** no schema: `Cascade` onde o dado é do aluno, `SetNull` para responsável/criador, sem FK em `audit_log`/`webhook_events`/`anonymous_conversations` de propósito. Índices compostos para todos os cursores keyset; `(source, created_at desc)` e `(outcome, received_at desc)` para os painéis.
- **Paginação keyset** consistente nas duas implementações (memória e Prisma), com desempate por id usando o mesmo comparador do cursor.
- **`updateOwned`/`deleteOwned`** atômicos (sem TOCTOU); `decidePending` como claim atômico; `createIfAbsent` com `skipDuplicates` para não abortar a transação.
- **Push nativo**: texto da conversa nunca vai pelo FCM/APNs (`AVISO_NATIVO_PRIVADO`), token OAuth com cache e folga, tokens mortos removidos.
- **Retenção**: coleta caminhos antes de apagar linhas, valor inválido/ausente não apaga nada, log do webhook sempre podado.
- **Testes de serviço** cobrem os contratos críticos: assinatura do webhook (positivo e 5 negativos), E.164, vínculo/reaproveitamento de conversa, `forget`, SSE/n8n/429/timeout da Crystal, Supabase (inclusive "base fora do ar ≠ não encontrado" e base autoritativa a cada login), redação (13 padrões + nomes + falsos positivos), exclusão com cópia anônima, retenção com mídia, alertas com cooldown, FCM com fetch fake.
- **Dockerfile**: `--frozen-lockfile`, schema copiado antes do `postinstall`, `.dockerignore` barra `.env*`; Prisma e client com versão pinada (6.19.3).

---

## 3. Lacunas de teste mais importantes (resumo de M17 + pontuais)

1. Camada Prisma e migrações sem teste automatizado (M17).
2. `anonymous-copy`: nenhum caso com nome em início de frase ou em minúsculas fora da lista (A2) — hoje passaria sem redigir.
3. `native-push`: `INVALID_ARGUMENT` por payload (M3) e timeout (M2).
4. `messages.ts`: `REPLY_TIMEOUT`, duas bolhas abertas com `echoId` divergente, resposta tardia depois do timeout (B6) — a confirmar se `routes/channel-webhook.test.ts` cobre.
5. `chatwoot-channel`: caminho de 404 → novo vínculo; P2002 de telefone repetido (M13).
6. `finance.update`: conteúdo de `notes` na auditoria (M5).
7. `retention`: falha de `unlink` (B11); ausência de poda de `health_events`/`sessions` (M11).
8. `stream-hub`: `push` após `done` ignorado; `run` rejeitado → `INTERNAL`.
9. `directory` HTTP legado: redirect (B1); `error-reporter.scrub`: telefone de 10 dígitos (O4).

---

## 4. Contagem

- **Arquivos lidos no escopo:** 91 (37 serviços, 35 db, 1 helper de teste, 1 schema, 14 migrações, 1 `migration_lock.toml`, Dockerfile, package.json).
- **Linhas lidas no escopo:** 10 082 (serviços 5 868 · db 3 130 · helpers 218 · schema 375 · migrações 432 · Dockerfile 19 · package.json 40).
- **Leituras de apoio fora do escopo:** 10 arquivos/trechos (listados no cabeçalho).
- **Achados:** crítico 0 · alto 2 · médio 17 · baixo 26 · observação 7.
