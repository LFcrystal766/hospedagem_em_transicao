-- Segurança 24/10/2026 (achado INT-14 da revisão + advisors do Supabase). Rodar no SQL Editor do projeto
-- hwbllqepvhddakszqdbk, inteiro. Idempotente: pode rodar de novo.
--
-- O que faz:
--  1. Tira das tabelas da agência (leticia_crystal_*) e das nossas (crystal_*) toda leitura/escrita dos papéis
--     `anon` e `authenticated`: políticas de RLS e grants. O app só usa `service_role`, pelas funções app_*.
--     Antes: qualquer usuário autenticado do Supabase Auth lia nome, e-mail, CPF, telefone e as conversas do WhatsApp.
--  2. Revoga das funções SECURITY DEFINER da agência (get_crystal_*, leticia_crystal_get_user_stats, rls_auto_enable)
--     o EXECUTE de public/anon/authenticated: hoje qualquer pessoa com a chave pública chama via /rest/v1/rpc.
--  3. Fixa search_path nas funções que o app usa e que estavam "mutable" (crystal_hybrid_search etc.).
--  4. No fim, mostra o que sobrou para conferir (tem que dar 0 política e 0 grant para anon/authenticated).
--
-- Efeito colateral conhecido: o painel antigo da agência (se alguém ainda entra nele pelo Supabase Auth) para de ler
-- essas tabelas. A agência saiu em 09/10. Para voltar: as políticas antigas eram `authenticated_select USING (true)`.

begin;

-- 1. políticas e grants de anon/authenticated nas tabelas de alunos e nossas
do $$
declare r record;
begin
  for r in
    select p.schemaname, p.tablename, p.policyname
      from pg_policies p
     where p.schemaname = 'public'
       and (p.tablename like 'leticia\_crystal\_%' or p.tablename like 'crystal\_%')
       and (p.roles::text[] && array['anon', 'authenticated', 'public'])
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;

  for r in
    select c.relname
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm')
       and (c.relname like 'leticia\_crystal\_%' or c.relname like 'crystal\_%')
  loop
    execute format('revoke all on table public.%I from anon, authenticated', r.relname);
  end loop;
end $$;

-- 2. funções da agência expostas a quem não está logado
do $$
declare r record;
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prosecdef
       and (p.proname like 'get\_crystal\_%' or p.proname like 'leticia\_crystal\_get\_%' or p.proname = 'rls_auto_enable')
  loop
    execute format('revoke execute on function public.%I(%s) from public, anon, authenticated', r.proname, r.args);
  end loop;
end $$;

-- 3. search_path fixo nas funções que o app usa (advisor "function_search_path_mutable")
do $$
declare r record;
begin
  for r in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('crystal_hybrid_search', 'match_leticia_crystal_vector_store', 'crystal_valida_telefone',
                         'crystal_cpf_valido', 'crystal_phone_id', 'lc_set_updated_at', 'update_updated_at_column')
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
  loop
    execute format('alter function public.%I(%s) set search_path = public, pg_temp', r.proname, r.args);
  end loop;
end $$;

commit;

-- 4. conferência: tudo tem que dar 0
select 'politicas_anon_auth_restantes' as o, count(*) as n from pg_policies
 where schemaname = 'public' and (tablename like 'leticia\_crystal\_%' or tablename like 'crystal\_%')
   and (roles::text[] && array['anon', 'authenticated', 'public'])
union all
select 'grants_anon_auth_restantes', count(*) from information_schema.role_table_grants
 where table_schema = 'public' and grantee in ('anon', 'authenticated')
   and (table_name like 'leticia\_crystal\_%' or table_name like 'crystal\_%')
union all
select 'funcoes_agencia_executaveis_por_anon', count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prosecdef
   and (p.proname like 'get\_crystal\_%' or p.proname like 'leticia\_crystal\_get\_%' or p.proname = 'rls_auto_enable')
   and has_function_privilege('anon', p.oid, 'execute')
union all
select 'funcoes_app_ainda_com_service_role', count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like 'app\_%' and has_function_privilege('service_role', p.oid, 'execute');
