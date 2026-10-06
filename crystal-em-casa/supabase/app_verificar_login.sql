-- =============================================================================
-- Login do app da Crystal no Supabase "Crystal AI" (05/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto. O app chama esta função pela API REST
-- (POST /rest/v1/rpc/app_verificar_login) com a chave service_role, que fica só
-- na VPS (bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY). Contrato do
-- lado do app: crystal-web-chat apps/api/src/services/directory.ts.
--
-- Base conferida em 05/10 (só contagens, nenhum dado de aluna):
--   leticia_crystal_customers: 10.955 cadastros, 9.247 com CPF (todos distintos),
--     1.708 sem CPF, 0 sem e-mail, 1.458 com is_in_rollout.
--   leticia_crystal_active_accesses (visão): 8.259 active + 1.386 pending, nenhum
--     vencido. phone_number já em formato internacional só com dígitos (55 + DDD +
--     número, com ou sem o 9; alguns de outros países), então só ganha o "+".
--
-- Regras:
--   - entra quem tem CPF + e-mail iguais na base E um acesso active ou pending
--     na visão de acessos (o mesmo critério do atendimento no WhatsApp hoje);
--   - o WhatsApp devolvido é o do acesso (o mesmo que a Crystal já conhece);
--   - aluna SEM CPF na base não entra pelo app (ver nota no fim).
--
-- Liberação em lotes (decisão do time em 06/10/2026): a divulgação do app sai em
-- lotes decrescentes, cerca de 500 alunas por dia, começando pelas top users. Quem
-- já foi liberada tem is_in_rollout = true em leticia_crystal_customers (1.458 em
-- 05/10); o time vira a flag por SQL, lote a lote. A função NÃO filtra por ela:
-- devolve a coluna `liberado` (= coalesce(is_in_rollout, false)) e o app decide.
-- Aluna encontrada e com acesso, mas liberado = false, recebe 403 LOGIN_NOT_RELEASED
-- ("seu acesso está sendo liberado em lotes"), sem criar conta nem mandar código.
-- A variável ROLLOUT_GATE da API (on, padrão | off) ignora liberado = false e abre
-- para todas sem mexer aqui. Função antiga, sem a coluna: o app trata como liberada.
-- =============================================================================

-- A coluna `liberado` muda o tipo de retorno, e o Postgres não aceita isso num
-- "create or replace": derruba a função antiga antes (os grants são refeitos abaixo).
-- Entre o drop e o grant o app responde 503 por um instante; rodar o arquivo inteiro
-- de uma vez, numa transação só (o SQL Editor faz isso).
drop function if exists public.app_verificar_login(text, text);

create or replace function public.app_verificar_login(p_cpf text, p_email text)
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
    select x.phone_number
      from public.leticia_crystal_active_accesses x
     where x.customer_id = c.id
       and x.subscription_status in ('active', 'pending')
     order by (x.subscription_status = 'active') desc, x.access_updated_at desc nulls last
     limit 1
  ) a on true
  where length(regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g')) = 11
    and regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g')
          = regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g')
    and lower(trim(c.email)) = lower(trim(coalesce(p_email, '')))
  order by c.created_at asc, c.id asc   -- se houver cadastro repetido, sempre o mesmo
  limit 1;
$$;

-- Índice na mesma expressão da busca: o login não varre a tabela inteira.
create index if not exists leticia_crystal_customers_cpf_digitos
  on public.leticia_crystal_customers ((regexp_replace(coalesce(cpf::text, ''), '\D', '', 'g')));

revoke all on function public.app_verificar_login(text, text) from public;
revoke all on function public.app_verificar_login(text, text) from anon, authenticated;
grant execute on function public.app_verificar_login(text, text) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens):
--   RLS ligado nas tabelas com dado de aluna (rowsecurity tem que ser true; se false,
--   a chave anon, que é pública, lê a tabela com CPF):
--     select tablename, rowsecurity from pg_tables
--      where schemaname = 'public' and tablename like 'leticia_crystal_%' order by 1;
--   quantas alunas o app aceitaria hoje
--     select count(*) from public.leticia_crystal_customers c
--      where length(regexp_replace(coalesce(c.cpf,''),'\D','','g')) = 11
--        and exists (select 1 from public.leticia_crystal_active_accesses a
--                     where a.customer_id = c.id and a.subscription_status in ('active','pending'));
--   quantas alunas com acesso ficam de fora por falta de CPF
--     select count(*) from public.leticia_crystal_customers c
--      where coalesce(c.cpf,'') = ''
--        and exists (select 1 from public.leticia_crystal_active_accesses a
--                     where a.customer_id = c.id and a.subscription_status in ('active','pending'));
--   quantas alunas já estão liberadas (lote) e quantas ainda esperam
--     select coalesce(is_in_rollout, false) as liberado, count(*)
--       from public.leticia_crystal_customers group by 1;
--   teste com a sua própria conta (resultado: uma linha com nome, +55..., id e liberado):
--     select * from public.app_verificar_login('SEU CPF', 'seu@email');
--
-- Nota sobre quem não tem CPF: aceitar só o e-mail NÃO é seguro com o app atual.
-- A conta do app é identificada pelo CPF digitado; uma aluna sem CPF poderia
-- digitar o CPF de outra pessoa e, como o e-mail dela bateria, o app trocaria o
-- e-mail da conta já existente e entregaria a conversa da outra. O caminho certo é
-- completar o CPF dessas cadastros a partir da Assiny (gateway_customer_id) e, só
-- se sobrar alguém, fazer uma mudança no app com teste para esse caso.
