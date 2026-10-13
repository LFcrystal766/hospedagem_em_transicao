-- Volta das 9 migrações do painel novo (onda 4) no banco do app (crystal_web_chat).
--
-- Quando usar: só se a volta de imagem (app-subir sha-5a5b198) não bastar. A imagem
-- antiga convive com estas tabelas e colunas a mais (ensaiado em 12/10): a volta de
-- imagem sozinha é a primeira opção. Este arquivo apaga o que o painel novo criou.
--
-- O QUE SE PERDE (ler antes de rodar):
--   * Mensagens da equipe (notices), fila de entrega, abertura e clique (notice_deliveries),
--     modelos de mensagem (notice_templates), agendamentos (send_date, scheduled_at).
--   * Pedidos do titular LGPD (data_requests): exportar, apagar dados, excluir conta.
--   * Notas internas da equipe sobre alunos (student_notes).
--   * Tentativas de entrada (auth_events) e as métricas consolidadas (metrics_daily).
--   * Cadeia de hash da auditoria (seq, prev_hash, hash). As linhas da auditoria FICAM;
--     só a prova de integridade sai. Aplicar o painel novo de novo refaz a cadeia (backfill).
--   * Em users: motivo, observação e data do desligamento, prazo e motivo da conta local,
--     última atividade e última mensagem. Em messages: uso do modelo e botão da bolha.
--     Em tickets: primeira resposta do suporte. Em system_settings: quem/quando/versão.
--
-- Como rodar (na VPS, com a API PARADA e o backup feito):
--   pg=$(docker ps -q -f name=crystal_app_app_postgres | head -1)
--   docker exec -i "$pg" psql -U crystal -d crystal_web_chat -v ON_ERROR_STOP=1 < volta-migracoes.sql
-- Tudo numa transação só (BEGIN/COMMIT aqui dentro; não passar -1): ou volta inteiro, ou nada muda.
-- Ensaiado em 12/10/2026 num Postgres 16 local: depois dele, `prisma migrate status` da
-- imagem sha-5a5b198 responde "Database schema is up to date!" e o esquema fica igual ao
-- de antes (migrate diff vazio). Ver README.md nesta pasta.

\set ON_ERROR_STOP on
BEGIN;

-- Ordem inversa da aplicação.

-- pa14_01_data_requests
DROP TABLE IF EXISTS "data_requests";

-- pa13_02_auth_events
DROP TABLE IF EXISTS "auth_events";

-- pa13_01_audit_chain (apagar a coluna seq apaga a sequência da identidade junto)
DROP INDEX IF EXISTS "audit_log_actor_id_created_at_idx";
DROP INDEX IF EXISTS "audit_log_action_created_at_idx";
DROP INDEX IF EXISTS "audit_log_seq_key";
ALTER TABLE "audit_log"
  DROP COLUMN IF EXISTS "hash",
  DROP COLUMN IF EXISTS "prev_hash",
  DROP COLUMN IF EXISTS "seq";
-- A âncora da poda da retenção só faz sentido com a cadeia.
DELETE FROM "system_settings" WHERE "key" = 'audit_chain_anchor';

-- pa12_26_metricas
DROP INDEX IF EXISTS "users_role_status_created_at_idx";
DROP INDEX IF EXISTS "tickets_created_at_idx";
DROP INDEX IF EXISTS "messages_direction_status_created_at_idx";
-- "messages_created_at_idx" fica (13/10): ele é da e3_27 (correção do painel, sha-3773e2e), que a versão de volta
-- conhece; a pa12_26 só o cria se faltar. Tirar o índice deixaria o painel lento de novo.
DROP INDEX IF EXISTS "finance_entries_access_until_idx";
DROP TABLE IF EXISTS "metrics_daily";
ALTER TABLE "tickets" DROP COLUMN IF EXISTS "first_staff_reply_at";
ALTER TABLE "messages"
  DROP COLUMN IF EXISTS "completed_at",
  DROP COLUMN IF EXISTS "error_code",
  DROP COLUMN IF EXISTS "model",
  DROP COLUMN IF EXISTS "risk_detected",
  DROP COLUMN IF EXISTS "tokens_in",
  DROP COLUMN IF EXISTS "tokens_out",
  DROP COLUMN IF EXISTS "written_at";

-- pa07_02_notice_updated_by e pa07_01_notice_schedule (a tabela notices sai inteira abaixo)
DROP INDEX IF EXISTS "notices_status_scheduled_at_idx";

-- pa06_01_notices
DROP INDEX IF EXISTS "messages_notice_id_idx";
ALTER TABLE "messages"
  DROP COLUMN IF EXISTS "notice_id",
  DROP COLUMN IF EXISTS "action_label",
  DROP COLUMN IF EXISTS "action_url";
DROP TABLE IF EXISTS "notice_templates";
DROP TABLE IF EXISTS "notice_deliveries";
DROP TABLE IF EXISTS "notices";

-- pa03_01_alunos
DROP TABLE IF EXISTS "student_notes";
DROP INDEX IF EXISTS "users_role_status_last_seen_at_idx";
ALTER TABLE "users"
  DROP COLUMN IF EXISTS "last_seen_at",
  DROP COLUMN IF EXISTS "last_message_at",
  DROP COLUMN IF EXISTS "disabled_reason",
  DROP COLUMN IF EXISTS "disabled_note_enc",
  DROP COLUMN IF EXISTS "disabled_at",
  DROP COLUMN IF EXISTS "local_until",
  DROP COLUMN IF EXISTS "local_reason";

-- pa01_26_system_settings_meta
ALTER TABLE "system_settings"
  DROP COLUMN IF EXISTS "updated_at",
  DROP COLUMN IF EXISTS "updated_by",
  DROP COLUMN IF EXISTS "version";

-- O Prisma deixa de ver as 9 como aplicadas (senão `migrate status` da imagem antiga
-- reclama de "migration not found locally" e a próxima ida não as reaplica).
DELETE FROM "_prisma_migrations" WHERE "migration_name" IN (
  'pa01_26_system_settings_meta', 'pa03_01_alunos', 'pa06_01_notices',
  'pa07_01_notice_schedule', 'pa07_02_notice_updated_by', 'pa12_26_metricas',
  'pa13_01_audit_chain', 'pa13_02_auth_events', 'pa14_01_data_requests'
);

COMMIT;

-- Conferir (só números):
--   select count(*) from _prisma_migrations where migration_name like 'pa%';   -- 0
--   select count(*) from information_schema.tables where table_name in
--     ('notices','notice_deliveries','notice_templates','student_notes','data_requests',
--      'auth_events','metrics_daily');                                         -- 0
