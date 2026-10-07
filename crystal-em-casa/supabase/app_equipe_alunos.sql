-- =============================================================================
-- Painel da equipe corrige a base de alunos (07/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só). Complementa docs/supabase/app_verificar_login.sql.
--
-- Quem chama: SÓ o servidor do app (apps/api, na VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/<função>) com a chave service_role, que fica só na VPS. A chave
-- anon (pública) nunca executa nada daqui: cada função é `security definer`, com
-- execute revogado de public/anon/authenticated e concedido só a service_role.
-- Contrato do lado do app: crystal-web-chat apps/api/src/services/base-alunos.ts.
--
-- Decisão do dono em 07/10/2026: a Bia (papel suporte) precisa corrigir, pelo painel
-- e sem SQL, o cadastro de alunos NA BASE (não só a conta do app):
--   (a) e-mail diferente do da compra      → app_equipe_corrigir_email
--   (b) aluno sem CPF na base              → app_equipe_definir_cpf
--   (c) liberar para o app (is_in_rollout) → app_equipe_liberar
--   busca para achar o cadastro            → app_equipe_buscar_aluno
--
-- Dados que saem: nome, e-mail, SE tem CPF (nunca o CPF), lote, status do acesso e
-- WhatsApp. O CPF nunca volta: a Bia só confere pelo que o aluno informa.
--
-- Auditoria: fica NO APP (tabela audit_log da API: quem da equipe fez o quê, em qual
-- customer_id, sem CPF nem e-mail). Aqui nada é registrado.
--
-- Erros: cada recusa sai como `raise exception` cuja MENSAGEM é um código fixo que o
-- app traduz para a pessoa (ALUNO_NAO_ENCONTRADO, EMAIL_INVALIDO, EMAIL_EM_USO,
-- CPF_INVALIDO, CPF_JA_INFORMADO, CPF_EM_USO). Conflito usa errcode unique_violation
-- (o PostgREST responde 409); validação usa o padrão P0001 (400). Qualquer outro
-- erro (função ausente, chave recusada, banco fora) o app trata como indisponível.
--
-- Suposições sobre a tabela public.leticia_crystal_customers (conferidas em 05/10):
--   id uuid, full_name, email, cpf (texto; comparado sempre só em dígitos, como no
--   login), is_in_rollout boolean (null = fora do lote), created_at. CPF gravado só
--   em dígitos. Se a tabela tiver `updated_at`, acrescentar `updated_at = now()`
--   nos três updates. O índice único uq_customers_cpf barra CPF repetido; a função
--   confere antes e ainda trata a violação, se chegar lá.
-- =============================================================================

-- Resumo de um aluno, o mesmo nas quatro funções. Interno: sem grant para ninguém
-- (as funções abaixo são security definer e rodam como o dono, que já pode).
drop function if exists public.app_equipe_resumo_aluno(uuid);
create or replace function public.app_equipe_resumo_aluno(p_customer_id uuid)
returns table (
  customer_id uuid,
  full_name text,
  email text,
  tem_cpf boolean,
  liberado boolean,
  acesso text,
  whatsapp text
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    c.id as customer_id,
    c.full_name::text as full_name,
    c.email::text as email,
    length(regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g')) = 11 as tem_cpf,
    coalesce(c.is_in_rollout, false) as liberado,
    coalesce(a.subscription_status::text, 'nenhum') as acesso,
    case
      when length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
        then '+' || regexp_replace(a.phone_number, '\D', '', 'g')
    end as whatsapp
  from public.leticia_crystal_customers c
  left join lateral (
    select x.subscription_status, x.phone_number
      from public.leticia_crystal_active_accesses x
     where x.customer_id = c.id
       and x.subscription_status in ('active', 'pending')
     order by (x.subscription_status = 'active') desc, x.access_updated_at desc nulls last
     limit 1
  ) a on true
  where c.id = p_customer_id;
$$;

revoke all on function public.app_equipe_resumo_aluno(uuid) from public;
revoke all on function public.app_equipe_resumo_aluno(uuid) from anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 1. Busca: por CPF (só dígitos, 11, igual ao login) OU por e-mail (contém, sem
--    caixa). Até 20 linhas. Nenhum dos dois → nenhuma linha.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_buscar_aluno(text, text);
create or replace function public.app_equipe_buscar_aluno(p_cpf text, p_email text)
returns table (
  customer_id uuid,
  full_name text,
  email text,
  tem_cpf boolean,
  liberado boolean,
  acesso text,
  whatsapp text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_cpf   text := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if length(v_cpf) = 11 then
    return query
      select r.*
        from public.leticia_crystal_customers c
        cross join lateral public.app_equipe_resumo_aluno(c.id) r
       where regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g') = v_cpf
       order by c.created_at asc, c.id asc
       limit 20;
  elsif length(v_email) >= 2 then
    -- `%` e `_` digitados são texto, não curinga.
    v_email := replace(replace(replace(v_email, '\', '\\'), '%', '\%'), '_', '\_');
    return query
      select r.*
        from public.leticia_crystal_customers c
        cross join lateral public.app_equipe_resumo_aluno(c.id) r
       where lower(trim(c.email)) like '%' || v_email || '%' escape '\'
       order by c.created_at asc, c.id asc
       limit 20;
  end if;
  return;
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Corrigir e-mail: formato conferido, gravado lower/trim; recusa se OUTRO
--    cliente já tiver esse e-mail. Devolve o resumo.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_corrigir_email(uuid, text);
create or replace function public.app_equipe_corrigir_email(p_customer_id uuid, p_email text)
returns table (
  customer_id uuid,
  full_name text,
  email text,
  tem_cpf boolean,
  liberado boolean,
  acesso text,
  whatsapp text
)
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
begin
  if not exists (select 1 from public.leticia_crystal_customers c where c.id = p_customer_id) then
    raise exception 'ALUNO_NAO_ENCONTRADO' using errcode = 'no_data_found';
  end if;
  if length(v_email) > 200 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'EMAIL_INVALIDO';
  end if;
  if exists (
    select 1 from public.leticia_crystal_customers o
     where o.id <> p_customer_id and lower(trim(o.email)) = v_email
  ) then
    raise exception 'EMAIL_EM_USO' using errcode = 'unique_violation';
  end if;

  update public.leticia_crystal_customers c
     set email = v_email
   where c.id = p_customer_id;

  return query select * from public.app_equipe_resumo_aluno(p_customer_id);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Informar CPF: só quando o atual está vazio; 11 dígitos com dígitos
--    verificadores certos; recusa se outro cliente já tiver esse CPF.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_definir_cpf(uuid, text);
create or replace function public.app_equipe_definir_cpf(p_customer_id uuid, p_cpf text)
returns table (
  customer_id uuid,
  full_name text,
  email text,
  tem_cpf boolean,
  liberado boolean,
  acesso text,
  whatsapp text
)
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_cpf    text := regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g');
  v_atual  text;
  v_soma   int;
  v_resto  int;
  i        int;
begin
  -- Validação igual à do app (packages/shared/src/cpf.ts): 11 dígitos, não todos
  -- iguais, e os dois dígitos verificadores.
  if length(v_cpf) <> 11 or v_cpf ~ '^(\d)\1{10}$' then
    raise exception 'CPF_INVALIDO';
  end if;
  v_soma := 0;
  for i in 1..9 loop
    v_soma := v_soma + substr(v_cpf, i, 1)::int * (11 - i);
  end loop;
  v_resto := (v_soma * 10) % 11;
  if v_resto = 10 then v_resto := 0; end if;
  if v_resto <> substr(v_cpf, 10, 1)::int then
    raise exception 'CPF_INVALIDO';
  end if;
  v_soma := 0;
  for i in 1..10 loop
    v_soma := v_soma + substr(v_cpf, i, 1)::int * (12 - i);
  end loop;
  v_resto := (v_soma * 10) % 11;
  if v_resto = 10 then v_resto := 0; end if;
  if v_resto <> substr(v_cpf, 11, 1)::int then
    raise exception 'CPF_INVALIDO';
  end if;

  select regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g')
    into v_atual
    from public.leticia_crystal_customers c
   where c.id = p_customer_id;
  if not found then
    raise exception 'ALUNO_NAO_ENCONTRADO' using errcode = 'no_data_found';
  end if;
  if length(v_atual) > 0 then
    raise exception 'CPF_JA_INFORMADO' using errcode = 'unique_violation';
  end if;

  if exists (
    select 1 from public.leticia_crystal_customers o
     where o.id <> p_customer_id
       and regexp_replace(coalesce(o.cpf::text, ''), '\D', '', 'g') = v_cpf
  ) then
    raise exception 'CPF_EM_USO' using errcode = 'unique_violation';
  end if;

  begin
    update public.leticia_crystal_customers c
       set cpf = v_cpf
     where c.id = p_customer_id;
  exception
    when unique_violation then
      -- uq_customers_cpf: alguém gravou o mesmo CPF entre a conferência e o update.
      raise exception 'CPF_EM_USO' using errcode = 'unique_violation';
  end;

  return query select * from public.app_equipe_resumo_aluno(p_customer_id);
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Liberar para o app (lote): grava is_in_rollout. false tira do lote.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_liberar(uuid, boolean);
create or replace function public.app_equipe_liberar(p_customer_id uuid, p_liberado boolean)
returns table (
  customer_id uuid,
  full_name text,
  email text,
  tem_cpf boolean,
  liberado boolean,
  acesso text,
  whatsapp text
)
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
begin
  update public.leticia_crystal_customers c
     set is_in_rollout = coalesce(p_liberado, false)
   where c.id = p_customer_id;
  if not found then
    raise exception 'ALUNO_NAO_ENCONTRADO' using errcode = 'no_data_found';
  end if;
  return query select * from public.app_equipe_resumo_aluno(p_customer_id);
end;
$$;

-- -----------------------------------------------------------------------------
-- Permissões: só a service_role (o servidor) executa.
-- -----------------------------------------------------------------------------
revoke all on function public.app_equipe_buscar_aluno(text, text) from public;
revoke all on function public.app_equipe_buscar_aluno(text, text) from anon, authenticated;
grant execute on function public.app_equipe_buscar_aluno(text, text) to service_role;

revoke all on function public.app_equipe_corrigir_email(uuid, text) from public;
revoke all on function public.app_equipe_corrigir_email(uuid, text) from anon, authenticated;
grant execute on function public.app_equipe_corrigir_email(uuid, text) to service_role;

revoke all on function public.app_equipe_definir_cpf(uuid, text) from public;
revoke all on function public.app_equipe_definir_cpf(uuid, text) from anon, authenticated;
grant execute on function public.app_equipe_definir_cpf(uuid, text) to service_role;

revoke all on function public.app_equipe_liberar(uuid, boolean) from public;
revoke all on function public.app_equipe_liberar(uuid, boolean) from anon, authenticated;
grant execute on function public.app_equipe_liberar(uuid, boolean) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (nenhum dado de aluno sai):
--   as quatro funções existem e só service_role executa
--     select p.proname, p.prosecdef, pg_get_function_identity_arguments(p.oid)
--       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--      where n.nspname = 'public' and p.proname like 'app_equipe_%' order by 1;
--     select routine_name, grantee from information_schema.routine_privileges
--      where routine_schema = 'public' and routine_name like 'app_equipe_%' order by 1, 2;
--   a busca com um e-mail que não existe devolve zero linhas
--     select count(*) from public.app_equipe_buscar_aluno(null, 'ninguem@exemplo.invalido');
--   CPF inválido é recusado (espera-se o erro CPF_INVALIDO)
--     select * from public.app_equipe_definir_cpf('00000000-0000-0000-0000-000000000000', '111.111.111-11');
