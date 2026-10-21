-- Esquema falso mínimo para testar app_aluno_corrigir_cadastro.sql num Postgres LOCAL (nunca no Supabase de verdade).
-- Ordem (a partir de crystal-em-casa/supabase/):
--   sudo -u postgres psql -f testes/base-falsa-cadastro.sql
--   sudo -u postgres psql -d cadastro_teste -v ON_ERROR_STOP=1 -f app_compras.sql
--   sudo -u postgres psql -d cadastro_teste -v ON_ERROR_STOP=1 -f app_verificar_login_email.producao-20261016.sql   (a função de login como está na produção)
--   sudo -u postgres psql -d cadastro_teste -v ON_ERROR_STOP=1 -f app_aluno_corrigir_cadastro.sql
--   sudo -u postgres psql -d cadastro_teste -v ON_ERROR_STOP=1 -f testes/app_aluno_corrigir_cadastro.teste.sql
-- Só dados inventados (e-mails .invalid, CPFs de teste, telefones 555).
drop database if exists cadastro_teste;
create database cadastro_teste;
\c cadastro_teste
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;
create table leticia_crystal_customers (
  id uuid primary key default gen_random_uuid(),
  email text,
  full_name text,
  phone_from_gateway text,
  cpf text,
  is_in_rollout boolean,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create unique index uq_customers_cpf on leticia_crystal_customers (cpf);
create table leticia_crystal_active_accesses (access_id uuid default gen_random_uuid(), phone_number text, customer_id uuid, subscription_status text, access_updated_at timestamptz);
create table leticia_crystal_subscriptions (id uuid default gen_random_uuid(), customer_id uuid, status text, updated_at timestamptz, end_date timestamptz);
