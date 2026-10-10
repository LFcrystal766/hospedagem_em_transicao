-- Esquema falso das tabelas da agência (só as colunas usadas), para testar os app_*.sql num Postgres local:
-- sudo -u postgres psql -f testes/base-falsa.sql, depois os .sql na ordem, depois o teste.
drop database if exists ficha_teste;
create database ficha_teste;
\c ficha_teste
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role; end if;
end $$;
create table leticia_crystal_active_accesses (access_id uuid default gen_random_uuid(), phone_number text, customer_id uuid, subscription_status text, access_updated_at timestamptz);
create table leticia_crystal_lead_management (id bigserial primary key, phone_number varchar, thread_id uuid, updated_at timestamptz);
create table leticia_crystal_lead_memories (lead_id bigint, content text, profile_data jsonb, updated_at timestamptz);
create table leticia_crystal_chat_histories (id serial, session_id varchar, message jsonb, created_at timestamptz, is_summarized boolean);
create table leticia_crystal_chat_histories_archive (id bigserial, session_id varchar, message jsonb, created_at timestamptz, is_summarized boolean, archived_at timestamptz);
create table crystal_compras (id uuid default gen_random_uuid() primary key, email text, nome text, telefone text, status text);
