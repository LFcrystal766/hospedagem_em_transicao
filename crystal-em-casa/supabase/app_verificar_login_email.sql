-- =============================================================================
-- Login do app da Crystal SÓ COM O E-MAIL da compra (decisão do dono em 07/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez. O app
-- chama esta função pela API REST (POST /rest/v1/rpc/app_verificar_login_email) com a
-- chave service_role, que fica só na VPS (bootstrap-vps.sh app-definir
-- SUPABASE_SERVICE_ROLE_KEY). Contrato do lado do app: crystal-web-chat
-- apps/api/src/services/directory.ts (SupabaseCustomerDirectory.verifyByEmail), com
-- LOGIN_MODO=email (padrão a partir de 07/10). A função antiga, app_verificar_login
-- (CPF + e-mail), continua existindo para LOGIN_MODO=cpf_email.
--
-- Por que só o e-mail: 1.708 cadastros da base não têm CPF (contagem de 05/10) e o
-- CPF é um dado semi-público; o que autentica de verdade é o CÓDIGO que o app manda
-- para o e-mail devolvido aqui. Por isso, neste modo, o app exige o código sempre.
--
-- Regras:
--   - entra quem tem o e-mail igual (minúsculas, sem espaços nas pontas) E um acesso
--     active ou pending na visão de acessos (o mesmo critério do atendimento no WhatsApp);
--   - devolve name, phone (WhatsApp do acesso, com "+"), contact_id (id do cliente na
--     base: é a identidade da conta no app) e liberado (lote, o app decide);
--   - mais de um cliente com o mesmo e-mail: fica o que tem acesso active antes de
--     pending, depois o mais antigo (created_at, id). Sempre o mesmo, login após login.
--   - o CPF não entra na conta: nem na busca nem no retorno.
-- =============================================================================

drop function if exists public.app_verificar_login_email(text);

create or replace function public.app_verificar_login_email(p_email text)
returns table (name text, phone text, contact_id text, liberado boolean)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    c.full_name::text as name,
    case
      when length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
        then '+' || regexp_replace(a.phone_number, '\D', '', 'g')
    end as phone,
    c.id::text as contact_id,
    coalesce(c.is_in_rollout, false) as liberado   -- lote já liberado? o app decide
  from public.leticia_crystal_customers c
  join lateral (
    select x.phone_number, x.subscription_status
      from public.leticia_crystal_active_accesses x
     where x.customer_id = c.id
       and x.subscription_status in ('active', 'pending')
     order by (x.subscription_status = 'active') desc, x.access_updated_at desc nulls last
     limit 1
  ) a on true
  where length(trim(coalesce(p_email, ''))) >= 3
    and lower(trim(c.email)) = lower(trim(coalesce(p_email, '')))
  -- E-mail repetido na base: acesso active antes de pending, depois o mais antigo.
  order by (a.subscription_status = 'active') desc, c.created_at asc, c.id asc
  limit 1;
$$;

-- Índice na mesma expressão da busca: o login não varre a tabela inteira.
create index if not exists leticia_crystal_customers_email_lower
  on public.leticia_crystal_customers ((lower(trim(email))));

revoke all on function public.app_verificar_login_email(text) from public;
revoke all on function public.app_verificar_login_email(text) from anon, authenticated;
grant execute on function public.app_verificar_login_email(text) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens, nenhum dado de aluna):
--   quantas alunas o app aceitaria hoje por e-mail (com ou sem CPF)
--     select count(distinct lower(trim(c.email))) from public.leticia_crystal_customers c
--      where exists (select 1 from public.leticia_crystal_active_accesses a
--                     where a.customer_id = c.id and a.subscription_status in ('active','pending'));
--   e-mails repetidos entre cadastros com acesso (a função escolhe um, sempre o mesmo)
--     select count(*) from (
--       select lower(trim(c.email)) e from public.leticia_crystal_customers c
--        where exists (select 1 from public.leticia_crystal_active_accesses a
--                       where a.customer_id = c.id and a.subscription_status in ('active','pending'))
--        group by 1 having count(*) > 1) r;
--   teste com a sua própria conta (resultado: uma linha com nome, +55..., id e liberado):
--     select * from public.app_verificar_login_email('seu@email');
--   a anon NÃO pode executar (tem que dar "permission denied"):
--     set role anon; select * from public.app_verificar_login_email('x@y.z'); reset role;
