# Ensaio das migrações do painel novo (onda 4), 12/10/2026

Sessão T3. Postgres 16.15 local (Ubuntu), Node 22.22, pnpm 9.15.9, Prisma 6.19.3. Worktrees do app em
`otimizacao/publicar-10-10` (`5a5b198`) e `painel/base` (`03cff13`). Dados fictícios: seed de demonstração
da API (`DEMO_SEED=1`, `DEMO_JOURNEY=1`) e volume sintético por SQL. Nada tocado na VPS, no Supabase nem no app.
Leitura e conclusões em `crystal-em-casa/painel-novo/README.md`.

## Ensaio A (estado do sha-5a5b198 → painel novo)

```
tempo migrate deploy (0_init..e3_26): 2.06 s        Database schema is up to date!
seed: users 5004 (disabled 294) · messages 50016 · tickets 400 · ticket_messages 1200 · system_settings 6 · audit_log 20200 · 36 MB

migrate status ANTES (painel/base puro):  "The migration from the database are not found locally in prisma/migrations: e3_26_avisos_programados"  (exit 0)
migrate deploy (pa01..pa14): 9 aplicadas, 2.80 s
  e3_26 0.01 · pa01_26 0.01 · pa03_01 0.04 · pa06_01 0.05 · pa07_01 0.02 · pa07_02 0.01 · pa12_26 0.25 · pa13_01 0.67 · pa13_02 0.01 · pa14_01 0.01  (s, por _prisma_migrations)
migrate status DEPOIS: 35 migrations found · Database schema is up to date!

backfill 1ª vez: {"total":20200,"preenchidas":20200,"ok":true,"conferidas":20200,"quebra":null}  30.2 s
backfill 2ª vez: {"total":20200,"preenchidas":0,"ok":true,"conferidas":20200,"quebra":null}       2.4 s
SQL: total 20200 · sem_hash 0 · prev_null 1 · prev_distintos 20199 · max_seq 20200 · seq_duplicado 0 · audit_log_seq_seq last_value 20201

pa03_01 disabled_reason: manual 94 · preblock 100 · refund 100 · ativos_com_motivo 0
pa12_26 first_staff_reply_at: 400 de 400, todos na mensagem pública (não na interna)
pa01_26: 6 chaves com version 1, updated_at preenchido, updated_by nulo

migrate diff (migrações painel/base x schema.prisma, shadow db): só finance_entries (DROP/ADD FK, TIMESTAMP(3) em 4 colunas), diferença anterior à onda 1
```

## Testes de Postgres do próprio app (banco recém-migrado)

```
✓ src/db/pa03-backfill.pg.test.ts (1 test)
✓ src/db/notices.pg.test.ts (3 tests)
✓ src/db/audit-chain.pg.test.ts (5 tests)
Test Files 3 passed · Tests 9 passed · 2.57 s
```

## Ensaio B (banco vazio)

```
35 migrações aplicadas em 2.49 s · Database schema is up to date!
backfill: {"total":0,"preenchidas":0,"ok":true,"conferidas":0,"quebra":null}
```

## Ensaio C (ordem errada: API nova grava ANTES do backfill)

```
API nova (log): {"msg":"auditoria: cabeça da cadeia sem hash; rode o audit:backfill","code":"AUDIT_CHAIN_SEM_BACKFILL"}
backfill: {"total":20201,"preenchidas":20200,"ok":false,"quebra":{"seq":20201,"reason":"prev_hash"}}  exit 1
backfill de novo: preenchidas 0, mesma quebra  exit 1
Ordem certa (ensaio A, API nova grava DEPOIS): {"ok":true,"conferidas":20201,"quebra":null}
```

## Imagem antiga sobre o banco novo (volta só de imagem)

```
prisma (5a5b198) migrate deploy: No pending migrations to apply.  exit 0
prisma (5a5b198) migrate status: 27 migrations found · Database schema is up to date!  exit 0
cliente Prisma antigo: {"auditoria_gravada":true,"settings":6,"messages":50016,"users":5004}; linha gravada com seq 20202 e hash nulo
ida de novo, backfill: {"total":20202,"preenchidas":1,"ok":true}
```

## Volta por SQL (volta-migracoes.sql) e ida de novo

```
volta: exit 0, 0.12 s · pa_restantes 0 · tabelas_novas 0 · audit_log 20202 · users 5004
imagem antiga migrate status: Database schema is up to date!
migrate diff ensaio_a (voltado) x ensaio_a_base (antes): -- This is an empty migration.
ida de novo: 9 aplicadas · backfill {"total":20202,"preenchidas":20202,"ok":true} · status up to date
```

## Branch reconciliada simulada (painel/base + e3_26 + migração que apaga scheduled_notices)

```
deploy sobre o estado sha-5a5b198: 10 aplicadas (pa01..pa14 + pa15_01_simulacao_drop_scheduled_notices) · status up to date · scheduled_notices apagada: t
volta-scheduled-notices.sql: CREATE TABLE · CREATE INDEX · migracoes_da_t1_tiradas 1 (pa15_01_simulacao_drop_scheduled_notices)
volta-migracoes.sql: exit 0
imagem antiga migrate status: up to date · migrate diff contra o estado de antes: vazio
```

## bootstrap-vps.sh

`bash -n` e `shellcheck -S warning` (0.11.0) limpos com os três comandos novos. Não rodados na VPS.
sha256 do arquivo neste commit: ver `publicar-prd.md`, seção da onda 4.
