-- Volta da migração da onda 4 que APAGA a tabela scheduled_notices (os avisos programados
-- da publicação de 10/10, substituídos pelas Mensagens agendadas do painel novo).
--
-- Rodar só se for voltar a produção para sha-5a5b198 DEPOIS de o painel novo ter subido:
-- a imagem sha-5a5b198 procura a tabela scheduled_notices e a aba "Programados" quebra sem ela.
-- O QUE SE PERDE: os avisos programados que existiam em 10/10 (a tabela volta VAZIA; a
-- migração da T1 apaga as linhas junto). Anotar os avisos pendentes antes da onda 4.
--
-- Rodar ANTES de volta-migracoes.sql (ou depois; são independentes), API parada:
--   docker exec -i "$pg" psql -U crystal -d crystal_web_chat -v ON_ERROR_STOP=1 < volta-scheduled-notices.sql
-- (transação já está no arquivo; não passar -1)
-- O nome da migração da T1 ainda não existe: o DELETE abaixo acha pelo trecho
-- "scheduled_notices" e mostra quantas linhas tirou (tem que ser 1). Conferir o nome na
-- branch painel/onda4 (apps/api/prisma/migrations/) e, se for outro, ajustar o LIKE.

\set ON_ERROR_STOP on
BEGIN;

CREATE TABLE IF NOT EXISTS "scheduled_notices" (
    "id"            TEXT         NOT NULL,
    "title"         TEXT         NOT NULL,
    "body"          TEXT         NOT NULL,
    "url"           TEXT         NOT NULL,
    "send_at"       TIMESTAMP(3) NOT NULL,
    "status"        TEXT         NOT NULL DEFAULT 'scheduled',
    "created_by_id" TEXT,
    "updated_by_id" TEXT,
    "created_at"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at"    TIMESTAMP(3) NOT NULL,
    "claimed_at"    TIMESTAMP(3),
    "finished_at"   TIMESTAMP(3),
    "students"      INTEGER,
    "devices"       INTEGER,
    "delivered"     INTEGER,
    "fail_reason"   TEXT,
    CONSTRAINT "scheduled_notices_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "scheduled_notices_status_send_at_idx" ON "scheduled_notices"("status", "send_at");

-- Tira do Prisma a migração que apagou a tabela (não a e3_26, que a criou e continua valendo).
WITH apagadas AS (
  DELETE FROM "_prisma_migrations"
  WHERE "migration_name" LIKE '%scheduled_notices%'
    AND "migration_name" <> 'e3_26_avisos_programados'
  RETURNING "migration_name"
)
SELECT count(*) AS migracoes_da_t1_tiradas, string_agg("migration_name", ', ') AS nomes FROM apagadas;

COMMIT;
