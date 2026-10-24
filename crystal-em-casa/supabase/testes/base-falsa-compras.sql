-- Esquema falso mínimo para testar app_compras.sql + app_compras_seguranca_n8n.sql num Postgres LOCAL (nunca no
-- Supabase de verdade). Ordem (a partir de crystal-em-casa/supabase/):
--   sudo -u postgres psql -f testes/base-falsa-compras.sql
--   sudo -u postgres psql -d compras_teste -v ON_ERROR_STOP=1 -f app_compras.sql
--   sudo -u postgres psql -d compras_teste -v ON_ERROR_STOP=1 -f app_compras_seguranca_n8n.sql
--   sudo -u postgres psql -d compras_teste -v ON_ERROR_STOP=1 -f testes/app_compras_seguranca_n8n.teste.sql
-- Só dados inventados (e-mails .invalid, ids "tx-…"). Os papéis anon/authenticated/service_role/authenticator imitam
-- os do Supabase.
drop database if exists compras_teste;
create database compras_teste;
\c compras_teste
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
  if not exists (select 1 from pg_roles where rolname='authenticator') then create role authenticator noinherit login password 'x'; end if;
  if exists (select 1 from pg_roles where rolname='n8n_compras') then
    -- sobra de um teste anterior: tira as dependências que impediriam o drop e recria limpo
    execute 'drop owned by n8n_compras';
    execute 'drop role n8n_compras';
  end if;
end $$;
create table leticia_crystal_customers (
  id uuid primary key default gen_random_uuid(),
  email text,
  full_name text,
  is_in_rollout boolean,
  created_at timestamptz default now()
);
create table leticia_crystal_active_accesses (access_id uuid default gen_random_uuid(), phone_number text, customer_id uuid,
  subscription_status text, access_updated_at timestamptz);
create table leticia_crystal_subscriptions (id uuid default gen_random_uuid(), customer_id uuid, status text,
  updated_at timestamptz, end_date timestamptz, external_id text, raw_data jsonb);
