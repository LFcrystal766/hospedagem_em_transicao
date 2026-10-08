-- =============================================================================
-- Silêncio no WhatsApp para quem usa o app (08/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só). Independente dos outros app_*.sql: não reusa nada deles. Se a
-- conferência de esquema logo abaixo falhar, nada é criado.
--
-- Quem chama: SÓ o servidor do app (apps/api, na VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/<função>) com a chave service_role, que fica só na VPS. A chave
-- anon (pública) nunca executa: as duas funções são `security definer`, com execute
-- revogado de public/anon/authenticated e concedido só a service_role.
-- Contrato do lado do app: crystal-web-chat apps/api/src/services/whatsapp-silencio.ts,
-- pelo mesmo cliente Supabase RPC de base-alunos/lotes. Nomes em env, opcionais:
-- SUPABASE_WHATSAPP_SILENCIAR_RPC (padrão app_whatsapp_silenciar) e
-- SUPABASE_WHATSAPP_ESTADO_RPC (padrão app_whatsapp_estado).
--
-- Decisão do dono em 08/10/2026: quem passa a usar o app deixa de receber resposta da
-- Crystal do WhatsApp (da agência, repositório crystal-ia). Só silêncio, sem mensagem
-- de redirecionamento. A chave do painel (op_whatsapp_silencio) começa desligada.
--
-- ESCRITA NUMA TABELA DA AGÊNCIA: é a ÚNICA escrita nossa numa tabela da agência além
-- de leticia_crystal_customers (lotes, CPF, e-mail). Só muda duas colunas de
-- leticia_crystal_lead_management: is_ai_enabled e updated_at (= now(), o mesmo que o
-- código da agência faz nos upserts dele). Nenhuma linha criada ou apagada, nenhuma
-- mudança de esquema. Avisar a agência (Tuan) antes de ligar.
--
-- Como a Crystal do WhatsApp decide (código crystal-ia, só leitura: ingest/leads.py e
-- pipeline.py): a cada mensagem ela faz upsert do lead, que NÃO mexe em is_ai_enabled,
-- e se is_ai_enabled for false (só false explícito; nulo = ligado) não responde e não
-- chama o modelo. Por isso:
--   - efeito IMEDIATO: a próxima mensagem no WhatsApp já fica sem resposta (não há
--     cache do lead no Redis);
--   - REVERSÍVEL: p_silenciar = false volta a ligar (is_ai_enabled = true);
--   - LIMITE: aluno que nunca escreveu no WhatsApp não tem linha de lead; a linha nasce
--     na primeira mensagem dele lá, com is_ai_enabled nulo (= ligado). A função não
--     cria lead. A API reaplica o silêncio no máximo 1 vez a cada 24 h por aluno
--     enquanto ele usa o app; a primeira resposta lá pode escapar até a próxima vez.
--
-- Caminho (o mesmo de app_historico_whatsapp): cliente → leticia_crystal_active_accesses
-- em QUALQUER status (o que importa é o telefone) → dígitos do WhatsApp (10+) = dígitos
-- de leticia_crystal_lead_management.phone_number. Dois acessos com o mesmo número em
-- formatos diferentes contam uma vez; dois leads do mesmo número mudam os dois. Telefone
-- diferente entre o cadastro e o WhatsApp (outro chip, falta do 9, falta do 55) não
-- casa e esse aluno NÃO é silenciado.
--
-- "Só onde muda": o estado efetivo é coalesce(is_ai_enabled, true), a regra da agência.
-- Silenciar grava false em quem está ligado (true ou nulo). Religar grava true só em
-- quem está false; nulo já está ligado e fica como está. Rodar duas vezes seguidas não
-- altera nada na segunda (leads = 0).
--
-- O que sai: só contagens. Nunca telefone, nome ou texto. O app não loga nada além de
-- userId e contagens; a auditoria (quem da equipe silenciou ou religou) fica no app.
--
-- Erros: `raise exception` com MENSAGEM = código fixo (LISTA_INVALIDA: lista nula, vazia,
-- só nulos ou com mais de 1000 ids; SILENCIAR_INVALIDO: p_silenciar nulo), `hint` com a
-- regra. Errcode padrão P0001 (PostgREST responde 400). Cliente desconhecido, sem
-- telefone ou sem lead NÃO é erro: conta zero.
--
-- Conferência geral, a qualquer hora (só número; inclui quem a agência silenciou à mão):
--   select count(*) filter (where is_ai_enabled is false) as silenciados, count(*) as leads
--     from public.leticia_crystal_lead_management;
--
-- Suposições sobre o esquema (código crystal-ia em 08/10; a conferência abaixo para o
-- arquivo se as duas colunas não existirem):
--   visão public.leticia_crystal_active_accesses a: customer_id uuid, phone_number text.
--   public.leticia_crystal_lead_management l: phone_id (único, id do LendChat),
--     phone_number text, is_ai_enabled boolean (pode ser nulo), updated_at timestamptz.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Conferência de esquema: sem is_ai_enabled boolean ou sem updated_at, o arquivo para
-- aqui e nenhuma função é criada.
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'leticia_crystal_lead_management'
       and column_name = 'is_ai_enabled' and data_type = 'boolean'
  ) then
    raise exception 'ESQUEMA_DIFERENTE'
      using hint = 'leticia_crystal_lead_management.is_ai_enabled (boolean) não encontrada';
  end if;
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'leticia_crystal_lead_management'
       and column_name = 'updated_at'
  ) then
    raise exception 'ESQUEMA_DIFERENTE'
      using hint = 'leticia_crystal_lead_management.updated_at não encontrada; tirar o updated_at = now() da função';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 1. Silenciar (p_silenciar = true) ou religar (false) a Crystal do WhatsApp para uma
--    lista de clientes. Devolve { clientes, leads }:
--      clientes = quantos ids da lista têm telefone válido (10+ dígitos) em algum acesso
--      leads    = linhas de lead alteradas agora (0 se já estavam no estado pedido)
-- -----------------------------------------------------------------------------
drop function if exists public.app_whatsapp_silenciar(uuid[], boolean);
create or replace function public.app_whatsapp_silenciar(
  p_customer_ids uuid[],
  p_silenciar boolean
)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_ids      uuid[];
  v_digitos  text[];
  v_clientes int := 0;
  v_leads    int := 0;
begin
  if p_silenciar is null then
    raise exception 'SILENCIAR_INVALIDO' using hint = 'p_silenciar true (silenciar) ou false (religar)';
  end if;

  select coalesce(array_agg(distinct u.id), '{}')
    into v_ids
    from unnest(coalesce(p_customer_ids, '{}')) as u(id)
   where u.id is not null;

  if cardinality(v_ids) = 0 or cardinality(p_customer_ids) > 1000 then
    raise exception 'LISTA_INVALIDA' using hint = 'de 1 a 1000 customer_ids';
  end if;

  select count(distinct t.customer_id), coalesce(array_agg(distinct t.digitos), '{}')
    into v_clientes, v_digitos
    from (
      select a.customer_id,
             regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos
        from public.leticia_crystal_active_accesses a
       where a.customer_id = any(v_ids)
    ) t
   where length(t.digitos) >= 10;

  if v_clientes > 0 then
    with feito as (
      update public.leticia_crystal_lead_management l
         set is_ai_enabled = not p_silenciar,
             updated_at = now()
       where regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = any(v_digitos)
         -- só onde o estado efetivo muda (nulo = ligado, a regra da agência)
         and coalesce(l.is_ai_enabled, true) = p_silenciar
      returning 1
    )
    select count(*) into v_leads from feito;
  end if;

  return json_build_object('clientes', v_clientes, 'leads', v_leads);
end;
$$;

-- -----------------------------------------------------------------------------
-- 2. Estado de um cliente, só leitura, para a tela da equipe conferir. Devolve
--    { leads, silenciados }: leads do(s) número(s) do cliente e quantos estão com
--    is_ai_enabled = false. Cliente nulo, desconhecido ou sem lead: zeros, sem erro.
-- -----------------------------------------------------------------------------
drop function if exists public.app_whatsapp_estado(uuid);
create or replace function public.app_whatsapp_estado(p_customer_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_leads       int := 0;
  v_silenciados int := 0;
begin
  if p_customer_id is not null then
    with tel as (
      select distinct
        regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    )
    select count(*), count(*) filter (where l.is_ai_enabled is false)
      into v_leads, v_silenciados
      from tel t
      join public.leticia_crystal_lead_management l
        on regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = t.digitos;
  end if;

  return json_build_object('leads', v_leads, 'silenciados', v_silenciados);
end;
$$;

-- -----------------------------------------------------------------------------
-- Permissões: só a service_role (o servidor) executa.
-- -----------------------------------------------------------------------------
revoke all on function public.app_whatsapp_silenciar(uuid[], boolean) from public;
revoke all on function public.app_whatsapp_silenciar(uuid[], boolean) from anon, authenticated;
grant execute on function public.app_whatsapp_silenciar(uuid[], boolean) to service_role;

revoke all on function public.app_whatsapp_estado(uuid) from public;
revoke all on function public.app_whatsapp_estado(uuid) from anon, authenticated;
grant execute on function public.app_whatsapp_estado(uuid) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens, nenhum dado de aluno na tela):
--   as funções existem e só service_role executa
--     select routine_name, grantee from information_schema.routine_privileges
--      where routine_schema = 'public' and routine_name like 'app_whatsapp_%' order by 1, 2;
--   quantos leads estão silenciados no total (antes de ligar a chave: só os da agência)
--     select count(*) filter (where is_ai_enabled is false) as silenciados, count(*) as leads
--       from public.leticia_crystal_lead_management;
--   estado de um aluno (só números)
--     select public.app_whatsapp_estado('<uuid de um cliente>');
--   cliente desconhecido conta zero, sem erro
--     select public.app_whatsapp_estado(gen_random_uuid());
--     select public.app_whatsapp_silenciar(array[gen_random_uuid()], true);
--   validação recusa (espera-se LISTA_INVALIDA)
--     select public.app_whatsapp_silenciar('{}'::uuid[], true);
--   a anon NÃO pode executar (tem que dar "permission denied")
--     set role anon; select public.app_whatsapp_estado(gen_random_uuid()); reset role;
--
-- Cada chamada lê a tabela de leads inteira comparando dígitos (como
-- app_historico_whatsapp). Se ficar lenta, um índice de expressão ajuda e não muda nada
-- para a agência; é tabela deles, combinar antes:
--   create index concurrently if not exists leticia_crystal_lead_management_digitos
--     on public.leticia_crystal_lead_management
--        ((regexp_replace(coalesce(phone_number, ''), '\D', '', 'g')));
