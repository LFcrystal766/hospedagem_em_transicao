-- =============================================================================
-- Operação pelo painel: lotes de acesso e exportação (07/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só), DEPOIS de app_equipe_alunos.sql (reusa app_equipe_resumo_aluno).
--
-- Quem chama: SÓ o servidor do app (apps/api, na VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/<função>) com a chave service_role, que fica só na VPS. A chave
-- anon (pública) nunca executa nada daqui: cada função é `security definer`, com
-- execute revogado de public/anon/authenticated e concedido só a service_role.
-- Contrato do lado do app: crystal-web-chat apps/api/src/routes/staff-operacao.ts
-- (área `operacao`, só papel admin), cliente SupabaseBaseAlunos. Nomes das funções
-- em env, opcionais, com padrão igual ao nome daqui: SUPABASE_EQUIPE_LOTE_RESUMO_RPC,
-- SUPABASE_EQUIPE_LIBERAR_LOTE_RPC, SUPABASE_EQUIPE_LIBERAR_LISTA_RPC,
-- SUPABASE_EQUIPE_EXPORTAR_RPC.
--
-- Decisão do dono em 07/10/2026: o lote deixa de ser `update ... set is_in_rollout`
-- à mão no SQL Editor e passa para a tela /equipe/operacao:
--   resumo (total, liberados, ativos sem liberar, liberados hoje) → app_equipe_lote_resumo
--   liberar os N mais ativos dos últimos D dias                   → app_equipe_liberar_lote
--   liberar uma lista de e-mails                                  → app_equipe_liberar_lista
--   CSV (sem CPF, liberados, não liberados, ativos 30d)           → app_equipe_exportar
--
-- "Ativo" = mandou mensagem (type = human) para a Crystal do WhatsApp nos últimos N
-- dias. É a mesma conta do "top 500" de 06/10: cliente → acesso active|pending →
-- WhatsApp do acesso (só dígitos) = WhatsApp do lead (só dígitos) → thread do lead
-- = session_id do histórico. Fica numa função interna, app_equipe_atividade(dias),
-- usada pelas três que precisam dela, para a conta ser uma só.
--
-- Dados que saem: nome, e-mail, WhatsApp, SE tem CPF (nunca o CPF), lote e contagem
-- de mensagens. Nunca o texto das mensagens, nunca o CPF.
--
-- Auditoria: fica NO APP (audit_log da API: quem da equipe liberou quanto, com que
-- parâmetros; sem e-mail de aluno). Aqui nada é registrado.
--
-- Erros: `raise exception` com MENSAGEM = código fixo que o app traduz
-- (QUANTIDADE_INVALIDA, DIAS_INVALIDOS, LISTA_VAZIA, LISTA_GRANDE, TIPO_INVALIDO),
-- com `hint` dizendo a faixa aceita. Errcode padrão P0001 (PostgREST responde 400).
--
-- ÚNICA MUDANÇA DE ESQUEMA: a coluna leticia_crystal_customers.app_liberado_em
-- (timestamptz, nula), carimbo de quando o app liberou. Sem ela não há como contar
-- "liberados hoje" (is_in_rollout é só true/false). Escolha: a coluna é OBRIGATÓRIA e
-- é criada logo abaixo com `add column if not exists` (idempotente, nula, não mexe em
-- linha nenhuma, nenhum índice). Checar a coluna em tempo de execução via
-- information_schema exigiria SQL dinâmico em três funções para poupar um `alter`
-- trivial: mais código, mais pontos de falha, e o painel mostraria "null" sem explicar.
-- Se o `alter` falhar (dono da tabela é outro papel), o arquivo inteiro falha antes de
-- criar função alguma: nada fica pela metade. Avisar a agência (Tuan) que a coluna
-- existe; é nossa, só as funções app_equipe_* escrevem nela.
--
-- app_equipe_liberar (individual, em app_equipe_alunos.sql) é redefinida no fim deste
-- arquivo com a MESMA assinatura e o mesmo corpo, só acrescentando o carimbo. Sem isso,
-- liberar um aluno pela tela de Alunos não contaria em "liberados hoje".
--
-- Suposições sobre o esquema (conferidas em 05-07/10, confirmar se algo mudou):
--   public.leticia_crystal_customers c: id uuid, full_name, email, cpf (texto, pode
--     ser nulo/vazio), is_in_rollout boolean (null = fora do lote), created_at.
--   visão public.leticia_crystal_active_accesses a: customer_id, phone_number,
--     subscription_status, access_updated_at.
--   public.leticia_crystal_lead_management l: thread_id uuid, phone_number text.
--   public.leticia_crystal_chat_histories h: session_id (texto ou uuid; comparado
--     como texto), message jsonb (message->>'type' = 'human' | 'ai'), created_at
--     timestamptz.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Carimbo de liberação (ver cabeçalho).
-- -----------------------------------------------------------------------------
alter table public.leticia_crystal_customers
  add column if not exists app_liberado_em timestamptz;
comment on column public.leticia_crystal_customers.app_liberado_em is
  'Quando o app da Crystal liberou o acesso (lote, lista ou painel). Gravado só pelas funções app_equipe_*. Nulo = liberado antes do carimbo existir, ou nunca.';

-- -----------------------------------------------------------------------------
-- Interno: mensagens humanas por cliente nos últimos p_dias dias. Só clientes com
-- acesso active|pending e WhatsApp com 10+ dígitos entram (os outros não têm como
-- casar com o lead). Dedup antes de contar: dois acessos com o mesmo número, ou dois
-- leads com a mesma thread, não contam a mensagem duas vezes. Sem grant para ninguém
-- (as funções abaixo são security definer e rodam como o dono, que já pode).
-- -----------------------------------------------------------------------------
-- 08/10 (noite): reescrita por desempenho. Em produção a versão anterior levava 39 s no
-- "Crystal AI" (1 milhão de mensagens) e o PostgREST cortava por tempo (HTTP 500 no painel).
-- Agora: (1) `set enable_nestloop = off` força o cruzamento dos telefones por hash (sem isso,
-- com estatística ruim, o banco comparava 11 mil x 11 mil telefones um a um); (2) a contagem
-- por conversa sai só do índice (session_id, created_at), sem ler o texto das mensagens.
-- Por isso `mensagens` passa a contar as mensagens da conversa (aluno e Crystal), não só as do
-- aluno: serve para ordenar o lote e dizer quem esteve ativo. O tipo de session_id (texto ou
-- uuid) é lido na hora, para a comparação usar o índice nos dois casos.
drop function if exists public.app_equipe_atividade(int);
create or replace function public.app_equipe_atividade(p_dias int)
returns table (customer_id uuid, mensagens int, ultima timestamptz)
language plpgsql
stable
security definer
set search_path = public, pg_temp
set enable_nestloop = off
as $$
declare
  v_tipo  text;
  v_cmp   text;
  v_desde timestamptz := now() - make_interval(days => greatest(coalesce(p_dias, 30), 1));
begin
  select c.data_type into v_tipo
    from information_schema.columns c
   where c.table_schema = 'public'
     and c.table_name = 'leticia_crystal_chat_histories'
     and c.column_name = 'session_id';
  v_cmp := case when v_tipo = 'uuid' then 'h.session_id = f.thread_id'
                else 'h.session_id = f.thread_id::text' end;

  return query execute format($q$
    with tel as (
      select distinct a.customer_id,
             regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos
        from public.leticia_crystal_active_accesses a
       where a.subscription_status in ('active', 'pending')
         and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    ),
    fio as (
      select distinct t.customer_id, l.thread_id
        from tel t
        join public.leticia_crystal_lead_management l
          on regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = t.digitos
       where l.thread_id is not null
    ),
    por_fio as (
      select f.customer_id, x.n, x.ultima
        from fio f
        cross join lateral (
          select count(*)::int as n, max(h.created_at) as ultima
            from public.leticia_crystal_chat_histories h
           where %s
             and h.created_at >= $1
        ) x
       where x.n > 0
    )
    select p.customer_id, sum(p.n)::int, max(p.ultima)
      from por_fio p
     group by p.customer_id
  $q$, v_cmp) using v_desde;
end;
$$;

revoke all on function public.app_equipe_atividade(int) from public;
revoke all on function public.app_equipe_atividade(int) from anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 1. Resumo dos lotes. total/liberados/nao_liberados contam a base inteira (com ou
--    sem acesso ativo, igual às contagens que o time já acompanha: 1.459 / 9.514 em
--    06/10). ativos_30d_nao_liberados: quem mandou mensagem nos últimos 30 dias e
--    ainda não foi liberado (só tem acesso, por construção). liberados_hoje: carimbo
--    de hoje no horário de Brasília.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_lote_resumo();
create or replace function public.app_equipe_lote_resumo()
returns json
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select json_build_object(
    'total',          count(*),
    'liberados',      count(*) filter (where coalesce(c.is_in_rollout, false)),
    'nao_liberados',  count(*) filter (where not coalesce(c.is_in_rollout, false)),
    'ativos_30d_nao_liberados', (
      select count(*)
        from public.app_equipe_atividade(30) atv
        join public.leticia_crystal_customers x on x.id = atv.customer_id
       where not coalesce(x.is_in_rollout, false)
    ),
    'liberados_hoje', count(*) filter (
      where coalesce(c.is_in_rollout, false)
        and (c.app_liberado_em at time zone 'America/Sao_Paulo')::date
          = (now() at time zone 'America/Sao_Paulo')::date
    )
  )
  from public.leticia_crystal_customers c;
$$;

-- -----------------------------------------------------------------------------
-- 2. Liberar lote: os p_quantidade clientes ainda não liberados, com acesso
--    active|pending, mais ativos nos últimos p_dias dias. Ordem: mensagens desc,
--    última mensagem desc, id. Quem não tem mensagem nenhuma entra por último (por
--    id), para o lote sempre completar a quantidade enquanto houver gente.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_liberar_lote(int, int);
create or replace function public.app_equipe_liberar_lote(p_quantidade int, p_dias int)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_liberados int := 0;
begin
  if p_quantidade is null or p_quantidade < 1 or p_quantidade > 2000 then
    raise exception 'QUANTIDADE_INVALIDA' using hint = 'p_quantidade entre 1 e 2000';
  end if;
  if p_dias is null or p_dias < 1 or p_dias > 365 then
    raise exception 'DIAS_INVALIDOS' using hint = 'p_dias entre 1 e 365';
  end if;

  with alvo as (
    select c.id
      from public.leticia_crystal_customers c
      left join public.app_equipe_atividade(p_dias) atv on atv.customer_id = c.id
     where not coalesce(c.is_in_rollout, false)
       and exists (
         select 1 from public.leticia_crystal_active_accesses a
          where a.customer_id = c.id
            and a.subscription_status in ('active', 'pending')
       )
     order by coalesce(atv.mensagens, 0) desc, atv.ultima desc nulls last, c.id asc
     limit p_quantidade
  ),
  feito as (
    update public.leticia_crystal_customers c
       set is_in_rollout = true,
           app_liberado_em = now()
      from alvo
     where c.id = alvo.id
    returning c.id
  )
  select count(*) into v_liberados from feito;

  return json_build_object('liberados', v_liberados);
end;
$$;

-- -----------------------------------------------------------------------------
-- 3. Liberar por lista de e-mails: casa por lower(trim(email)) (índice
--    leticia_crystal_customers_email_lower, de app_verificar_login_email.sql).
--    Sem filtro de acesso: a lista é escolha explícita do dono. E-mail repetido na
--    base libera todos os cadastros com ele. Devolve liberados (quem virou agora),
--    ja_liberados (estava na lista e já era liberado; informativo) e
--    nao_encontrados (sem cadastro, já normalizados). Entrada: até 2000, vazios e
--    repetidos descartados antes de contar.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_liberar_lista(text[]);
create or replace function public.app_equipe_liberar_lista(p_emails text[])
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_emails        text[];
  v_liberados     int := 0;
  v_ja_liberados  int := 0;
  v_nao_encontrados text[];
begin
  select coalesce(array_agg(distinct e), '{}')
    into v_emails
    from unnest(coalesce(p_emails, '{}')) as e0(e_bruto)
    cross join lateral (select lower(trim(e_bruto)) as e) n
   where length(n.e) >= 3 and position('@' in n.e) > 1;

  if coalesce(array_length(v_emails, 1), 0) = 0 then
    raise exception 'LISTA_VAZIA' using hint = 'nenhum e-mail válido na lista';
  end if;
  if array_length(v_emails, 1) > 2000 then
    raise exception 'LISTA_GRANDE' using hint = 'até 2000 e-mails por vez';
  end if;

  select count(*) into v_ja_liberados
    from public.leticia_crystal_customers c
   where lower(trim(c.email)) = any(v_emails)
     and coalesce(c.is_in_rollout, false);

  with feito as (
    update public.leticia_crystal_customers c
       set is_in_rollout = true,
           app_liberado_em = now()
     where lower(trim(c.email)) = any(v_emails)
       and not coalesce(c.is_in_rollout, false)
    returning c.id
  )
  select count(*) into v_liberados from feito;

  select coalesce(array_agg(e order by e), '{}')
    into v_nao_encontrados
    from unnest(v_emails) as u(e)
   where not exists (
     select 1 from public.leticia_crystal_customers c where lower(trim(c.email)) = u.e
   );

  return json_build_object(
    'liberados', v_liberados,
    'ja_liberados', v_ja_liberados,
    'nao_encontrados', to_json(v_nao_encontrados)
  );
end;
$$;

-- -----------------------------------------------------------------------------
-- 4. Exportar (CSV montado no app). Tipos:
--      sem_cpf        com acesso active|pending e sem CPF de 11 dígitos
--      liberados      is_in_rollout = true (com ou sem acesso)
--      nao_liberados  com acesso active|pending e ainda não liberado
--      ativos_30d     com mensagem humana nos últimos 30 dias
--    whatsapp = '+' || dígitos do acesso (active antes de pending, o mais recente),
--    nulo se não houver. Ordem: mensagens_30d desc, nome.
-- -----------------------------------------------------------------------------
drop function if exists public.app_equipe_exportar(text);
create or replace function public.app_equipe_exportar(p_tipo text)
returns table (
  customer_id text,
  nome text,
  email text,
  whatsapp text,
  tem_cpf boolean,
  liberado boolean,
  mensagens_30d int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_tipo text := lower(trim(coalesce(p_tipo, '')));
begin
  if v_tipo not in ('sem_cpf', 'liberados', 'nao_liberados', 'ativos_30d') then
    raise exception 'TIPO_INVALIDO' using hint = 'sem_cpf | liberados | nao_liberados | ativos_30d';
  end if;

  return query
    with base as (
      select
        c.id,
        c.full_name::text as nome,
        c.email::text as email,
        case
          when length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
            then '+' || regexp_replace(a.phone_number, '\D', '', 'g')
        end as whatsapp,
        length(regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g')) = 11 as tem_cpf,
        coalesce(c.is_in_rollout, false) as liberado,
        a.customer_id is not null as com_acesso,
        coalesce(atv.mensagens, 0) as mensagens_30d
      from public.leticia_crystal_customers c
      left join lateral (
        select x.customer_id, x.phone_number
          from public.leticia_crystal_active_accesses x
         where x.customer_id = c.id
           and x.subscription_status in ('active', 'pending')
         order by (x.subscription_status = 'active') desc, x.access_updated_at desc nulls last
         limit 1
      ) a on true
      left join public.app_equipe_atividade(30) atv on atv.customer_id = c.id
    )
    select b.id::text, b.nome, b.email, b.whatsapp, b.tem_cpf, b.liberado, b.mensagens_30d
      from base b
     where case v_tipo
             when 'sem_cpf'       then b.com_acesso and not b.tem_cpf
             when 'liberados'     then b.liberado
             when 'nao_liberados' then b.com_acesso and not b.liberado
             when 'ativos_30d'    then b.mensagens_30d > 0
           end
     order by b.mensagens_30d desc, b.nome asc nulls last, b.id asc;
end;
$$;

-- -----------------------------------------------------------------------------
-- 5. app_equipe_liberar (individual, de app_equipe_alunos.sql): mesma assinatura e
--    corpo, acrescentando só o carimbo (liberar grava now(); tirar do lote limpa).
--    `create or replace` sem drop: mantém o grant que já existe; repetido abaixo
--    por segurança.
-- -----------------------------------------------------------------------------
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
     set is_in_rollout = coalesce(p_liberado, false),
         app_liberado_em = case when coalesce(p_liberado, false) then now() end
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
revoke all on function public.app_equipe_lote_resumo() from public;
revoke all on function public.app_equipe_lote_resumo() from anon, authenticated;
grant execute on function public.app_equipe_lote_resumo() to service_role;

revoke all on function public.app_equipe_liberar_lote(int, int) from public;
revoke all on function public.app_equipe_liberar_lote(int, int) from anon, authenticated;
grant execute on function public.app_equipe_liberar_lote(int, int) to service_role;

revoke all on function public.app_equipe_liberar_lista(text[]) from public;
revoke all on function public.app_equipe_liberar_lista(text[]) from anon, authenticated;
grant execute on function public.app_equipe_liberar_lista(text[]) to service_role;

revoke all on function public.app_equipe_exportar(text) from public;
revoke all on function public.app_equipe_exportar(text) from anon, authenticated;
grant execute on function public.app_equipe_exportar(text) to service_role;

revoke all on function public.app_equipe_liberar(uuid, boolean) from public;
revoke all on function public.app_equipe_liberar(uuid, boolean) from anon, authenticated;
grant execute on function public.app_equipe_liberar(uuid, boolean) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens, nenhum dado de aluno):
--   a coluna existe
--     select column_name, data_type from information_schema.columns
--      where table_schema = 'public' and table_name = 'leticia_crystal_customers'
--        and column_name = 'app_liberado_em';
--   as funções existem e só service_role executa (app_equipe_atividade: ninguém)
--     select routine_name, grantee from information_schema.routine_privileges
--      where routine_schema = 'public' and routine_name like 'app_equipe_%' order by 1, 2;
--   o resumo responde (liberados_hoje = 0 logo depois de criar)
--     select public.app_equipe_lote_resumo();
--   a conta de atividade bate com o "top 500" de 06/10 (só números)
--     select count(*), sum(mensagens) from public.app_equipe_atividade(30);
--   validação recusa (espera-se QUANTIDADE_INVALIDA)
--     select public.app_equipe_liberar_lote(0, 30);
--   exportação só conta linhas, sem imprimir
--     select count(*) from public.app_equipe_exportar('sem_cpf');
--   a anon NÃO pode executar (tem que dar "permission denied")
--     set role anon; select public.app_equipe_lote_resumo(); reset role;
--
-- Se a conta de atividade ficar lenta (histórico grande), um índice ajuda e não muda
-- nada para a agência; combinar antes, é tabela deles:
--   create index concurrently if not exists leticia_crystal_chat_histories_created_at
--     on public.leticia_crystal_chat_histories (created_at);
