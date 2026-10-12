# Painel novo da equipe (onda 4): ensaio das migrações e volta

Preparação da publicação do painel novo (`painel/base` + `otimizacao/publicar-10-10`, que a
sessão T1 junta em `painel/onda4`). Tudo aqui foi feito num Postgres 16 local em 12/10/2026,
com dados fictícios (seed de demonstração da API + volume sintético). **Nada foi feito na VPS,
no Supabase nem no app.** O roteiro para o dono está em `../publicar-prd.md`, seção
"Publicação do painel novo (onda 4)".

## O que o painel novo faz no banco

9 migrações do Prisma, todas aditivas, mais um passo fora do Prisma:

| Migração | O que faz | Tempo no ensaio |
|---|---|---|
| `pa01_26_system_settings_meta` | `system_settings` ganha `updated_at`, `updated_by`, `version` | 0,01 s |
| `pa03_01_alunos` | colunas em `users` (última atividade, desligamento, conta local), tabela `student_notes`, preenche o motivo de quem já está desligado a partir da auditoria | 0,04 s |
| `pa06_01_notices` | tabelas `notices`, `notice_deliveries`, `notice_templates`; botão da bolha em `messages` | 0,05 s |
| `pa07_01_notice_schedule` | `notices.send_date` e índice do agendador | 0,02 s |
| `pa07_02_notice_updated_by` | `notices.updated_by` | 0,01 s |
| `pa12_26_metricas` | colunas de uso do modelo em `messages`, `tickets.first_staff_reply_at` (preenchido pelo histórico), tabela `metrics_daily`, 5 índices | 0,25 s |
| `pa13_01_audit_chain` | `audit_log.seq` (identidade, numerada em `created_at, id`), `prev_hash`, `hash` (nulos), 2 índices | 0,67 s (20 mil linhas) |
| `pa13_02_auth_events` | tabela `auth_events` | 0,01 s |
| `pa14_01_data_requests` | tabela `data_requests` (pedidos do titular LGPD) | 0,01 s |
| **`audit:backfill`** (Node, fora do Prisma) | calcula a cadeia de hash das linhas antigas da auditoria, numa transação só | **30 s para 20.200 linhas** (1,5 s por mil); 2ª rodada 2,4 s |

A T1 ainda vai acrescentar uma migração que **apaga `scheduled_notices`** (avisos programados
de 10/10, substituídos pelas Mensagens agendadas). Ela entra depois das 9; o nome ainda não
existe. `volta-scheduled-notices.sql` cobre essa volta.

## O ensaio (12/10, Postgres 16.15 local)

**Ensaio A, o caminho que a produção vai viver.** Banco vazio → 27 migrações até `e3_26`
(estado do `sha-5a5b198`, 2,1 s) → API `sha-5a5b198` subiu uma vez com `DEMO_SEED=1` e
`DEMO_JOURNEY=1` (4 contas de demonstração, conversa da Ana) → volume sintético parecido com
produção: 5.004 alunos (294 desligados), 50.016 mensagens, 400 pedidos de suporte com 1.200
mensagens, 6 chaves `op_*`, 20.200 linhas de auditoria sem cadeia (como as de hoje), 36 MB.
Depois:

1. `prisma migrate deploy` das 9 `pa*`: **2,8 s**, todas aplicadas; `migrate status`:
   "Database schema is up to date!".
2. `audit:backfill` (1ª vez): 20.200 linhas preenchidas, cadeia conferida, `ok: true`, 30 s.
3. `audit:backfill` (2ª vez): 0 preenchidas, `ok: true`, 2,4 s. **Idempotente.**
4. Conferências por SQL: 0 linhas sem hash, 1 `prev_hash` nulo (a primeira), 20.199 `prev_hash`
   distintos, `seq` sem buraco nem repetição, sequência da identidade em 20.201.
5. `pa03_01` preencheu o motivo dos 294 desligados (100 `preblock`, 100 `refund`, 94 `manual`),
   nenhum ativo tocado; `pa12_26` preencheu a primeira resposta do suporte nos 400 pedidos (a
   mensagem pública, não a interna); `pa01_26` deu `version = 1` e `updated_at` às 6 chaves.
6. Os três testes de Postgres do próprio app (`audit-chain.pg.test.ts`, `pa03-backfill.pg.test.ts`,
   `notices.pg.test.ts`) passaram num banco recém-migrado (9 testes).
7. `prisma migrate diff` entre as migrações de `painel/base` e o `schema.prisma`: só a
   diferença antiga de `finance_entries` (tipos de data e FKs), que já existia antes da onda 1.

**Ensaio B, a partir do zero.** Banco vazio → as 35 migrações de uma vez: 2,5 s, status limpo;
`audit:backfill` sem linhas: `total 0, ok true`.

**Ensaio C, a ordem errada (por isso a API tem de estar parada).** Depois das 9 migrações, a API
nova gravou UMA linha de auditoria antes do backfill (ela até avisa no log:
`AUDIT_CHAIN_SEM_BACKFILL`). O backfill preencheu as 20.200 antigas e saiu com código 1:
`quebra: seq 20201, motivo prev_hash`. Rodar o backfill de novo não conserta (0 preenchidas,
mesma quebra). A linha nova nasceu apontando para "nada" porque a cabeça ainda não tinha hash.
**Ordem obrigatória: API parada → migração + backfill → API nova.** Na ordem certa (ensaio A,
depois a API nova gravou), a cadeia segue íntegra.

**Branch reconciliada simulada.** `painel/base` + `e3_26` + uma migração de simulação que apaga
`scheduled_notices`, aplicada sobre o estado do `sha-5a5b198`: 10 aplicadas, status limpo. Se a
branch da T1 **esquecer a pasta `e3_26_avisos_programados`**, o `migrate status` da imagem nova
reclama "The migration from the database are not found locally: e3_26_avisos_programados"
(o deploy ainda passa). A pasta tem de ficar.

## A volta (testada)

Volta de imagem só, `app-subir sha-5a5b198`: a imagem antiga **convive** com as tabelas e colunas
novas. Ensaiado: `migrate deploy` da antiga responde "No pending migrations", `migrate status`
"up to date", e o cliente Prisma antigo grava auditoria e lê `system_settings`, `messages` e
`users` normalmente. As linhas de auditoria que a antiga gravar ficam sem hash no fim da trilha;
numa nova ida o backfill as preenche (ensaiado: 1 preenchida, `ok: true`). Exceção: se a
migração da T1 já tiver apagado `scheduled_notices`, a aba "Programados" da antiga quebra: rodar
`volta-scheduled-notices.sql` antes (tabela volta vazia).

Volta de banco, `volta-migracoes.sql` (ordem inversa, uma transação, 0,12 s): depois dele,
`migrate status` da imagem `sha-5a5b198` dá "up to date" e `prisma migrate diff` entre o banco
voltado e a cópia de antes das migrações é **vazio** (esquema idêntico). Ida de novo depois da
volta: 9 aplicadas e backfill `ok: true` (20.202 preenchidas). Os dois arquivos juntos
(`volta-scheduled-notices.sql` + `volta-migracoes.sql`) também foram testados sobre a branch
reconciliada simulada: status limpo e diff vazio.

**O que se perde ao voltar o banco** (está no topo do `volta-migracoes.sql`): mensagens da equipe,
fila, abertura e clique, modelos e agendamentos; pedidos do titular LGPD; notas internas sobre
alunos; tentativas de entrada e métricas consolidadas; a cadeia de hash (as linhas da auditoria
ficam); motivo e data do desligamento, prazo da conta local, última atividade; uso do modelo por
mensagem; primeira resposta do suporte; quem/quando/versão das chaves. Antes de qualquer volta,
**cancelar os envios agendados** no painel (a versão antiga não os conhece).

## Variáveis de ambiente

Comparação de `apps/api/src/env.ts` entre `74092e0` (produção) e `painel/base`, mais
`apps/crystal` e as `NEXT_PUBLIC_*` do web:

- **Nenhuma variável nova e nenhum padrão mudou** no painel novo. As chaves ao vivo (A11) ficam
  em `system_settings`, no mecanismo que a Operação já usa (banco, depois env, depois padrão).
- `painel/base` nasceu de `c320aa0` e por isso **não tem** três variáveis que `74092e0` trouxe,
  todas opcionais com padrão: `SUPABASE_MEMORIA_APAGAR_RPC` (API) e `SUPABASE_MEMORIA_LER_RPC`,
  `SUPABASE_MEMORIA_GRAVAR_RPC` (Crystal). A junção da T1 sobre `otimizacao/publicar-10-10` as
  traz de volta; conferir no `env.ts` da `painel/onda4`. Nenhuma está no `.externos` da VPS (não
  passam pelo `app-definir`), então nada muda lá.
- `app-definir` não precisa de nada novo. O `api.env` de hoje passa no boot da imagem nova (o
  `app-subir` já confere isso antes do deploy, `app_env_preflight`).
- O PRD cita `APP_VERSION` chegando à Crystal e ao web: é argumento de build do `imagens-vps`,
  não variável da VPS.

## CI do app (pré-requisito, nada mudado aqui)

- `.github/workflows/ci.yml` roda em push para `main`, `claude/gracious-shannon-6x9l5j`,
  `otimizacao/**` e em **pull request**. `imagens-vps.yml` roda em push para
  `claude/gracious-shannon-6x9l5j` e `otimizacao/etapa-*`, em tag `v*` e por **disparo manual**
  (`workflow_dispatch`). As imagens `sha-5a5b198` saíram por disparo manual (run 65, 10/10).
- Nenhum workflow nunca rodou para `painel/**` (zero runs do `ci.yml` em `painel/base`).
- Para a imagem do painel novo sair: a T1 inclui `painel/**` nos dois workflows, **ou** abre um
  PR de `painel/onda4` (dispara o `ci.yml`) e dispara o `imagens-vps` à mão nessa branch, como em
  10/10. Sem isso não existe `sha-<tag>` para o `app-subir`.

## Arquivos

| Arquivo | O que é |
|---|---|
| `volta-migracoes.sql` | volta das 9 migrações, ordem inversa, uma transação; tira as 9 do `_prisma_migrations` |
| `volta-scheduled-notices.sql` | recria `scheduled_notices` (vazia) e tira a migração da T1 do `_prisma_migrations` |
| `../bootstrap-vps.sh` | comandos novos `app-api-parar`, `app-auditoria-backfill TAG`, `app-painel-conferir` |
| `../publicar-prd.md` | roteiro "Publicação do painel novo (onda 4)" |
| `../../auditorias/2026-10-12/ensaio-painel-novo.md` | saídas brutas do ensaio |

Os três comandos novos do `bootstrap-vps.sh` passaram em `bash -n` e `shellcheck -S warning`,
mas **não rodaram na VPS** (esta sessão não toca nela). O backfill roda num serviço temporário do
Swarm (`crystal_app_backfill`) porque a rede `app_interno` da stack não aceita `docker run`.
