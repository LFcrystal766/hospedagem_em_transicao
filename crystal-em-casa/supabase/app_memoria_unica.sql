-- =============================================================================
-- Memória única: a Crystal do app lê o que a Crystal do WhatsApp sabe da pessoa, e o
-- resumo do app fica guardado no Supabase (08/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só). Independente dos outros app_*.sql: não reusa nada deles. Se a
-- conferência logo abaixo falhar, nada é criado.
--
-- REGRA DO DONO (08/10): "não alterar absolutamente nada do que temos". Por isso este
-- arquivo SÓ CRIA quatro objetos novos e não toca em mais nada:
--   - tabela  public.crystal_memoria_unica          (create table if not exists);
--   - função  public.app_memoria_ler(uuid)          (só leitura);
--   - função  public.app_memoria_gravar(uuid, text) (escreve SÓ na tabela nova);
--   - função  public.app_memoria_apagar(uuid)       (apaga SÓ na tabela nova; LGPD).
-- Nenhum alter, drop, grant ou revoke em objeto que já existia; nenhuma linha das
-- tabelas da agência (leticia_crystal_*) é criada, mudada ou apagada: elas só aparecem
-- em SELECT. Todo alter/comment/revoke/grant abaixo é sobre os quatro objetos novos. Sem
-- chave estrangeira para a tabela de clientes de propósito: uma FK cria gatilhos na
-- tabela referenciada, e essa é da agência. Rodar de novo é seguro: a tabela não é
-- recriada (os dados ficam) e as funções são reescritas iguais. Se já existir uma
-- tabela ou função com esses nomes que NÃO veio deste arquivo, ele para (JA_EXISTE)
-- antes de mexer em qualquer coisa.
--
-- Quem chama: ler e gravar, SÓ a nossa Crystal (apps/crystal, na VPS), pela API REST do
-- Supabase (POST /rest/v1/rpc/<função>) com a chave service_role, que fica só na VPS (a
-- mesma SUPABASE_URL e a mesma chave da busca na base). Apagar, SÓ a API do app (apps/api,
-- na mesma VPS), do mesmo jeito, com a SUPABASE_URL e a service_role do api.env. As três
-- funções são `security definer`, com execute revogado de public/anon/authenticated e
-- concedido só a service_role. A tabela não tem grant para ninguém além do dono: só se
-- chega a ela pelas funções. Nomes em env, opcionais: no crystal.env,
-- SUPABASE_MEMORIA_LER_RPC (padrão app_memoria_ler) e SUPABASE_MEMORIA_GRAVAR_RPC (padrão
-- app_memoria_gravar); no api.env, SUPABASE_MEMORIA_APAGAR_RPC (padrão app_memoria_apagar).
-- Ler e gravar ficam atrás da chave op_memoria_unica (Operação, seção Crystal), que nasce
-- desligada; desligada, o app não chama nenhuma das duas e o pedido à Crystal fica igual ao
-- de hoje. Apagar NÃO depende da chave: a exclusão da conta pelo aluno sempre chama (a
-- linha pode ser de quando a chave esteve ligada).
--
-- Para quê: uma memória só por pessoa entre as duas Crystals, sem mexer na da agência.
--   - Ler (início do turno no app, com cache de 10 min por pessoa): o que a Crystal do
--     WhatsApp anotou (leticia_crystal_lead_memories.content e
--     profile_data->'known_preferences') e o último resumo do app.
--   - Gravar (quando o app regrava o resumo do contato): o resumo vai para a tabela
--     NOVA, nunca para a da agência.
--   - Apagar (LGPD, quando o aluno exclui a conta no app): some a linha dele da tabela
--     NOVA. O que a Crystal do WhatsApp anotou é da agência e não é tocado aqui.
--
-- Caminho (o mesmo de app_historico_whatsapp): cliente (customer_id =
-- crystalContactId do usuário do app) → leticia_crystal_active_accesses em QUALQUER
-- status (o que importa é o telefone) → dígitos do WhatsApp (10+) = dígitos de
-- leticia_crystal_lead_management.phone_number → leticia_crystal_lead_memories por
-- lead_id = id do lead, comparados como TEXTO (o tipo das duas colunas não está
-- confirmado). Dois acessos com o mesmo número contam uma vez; dois leads (dois
-- números) somam as duas memórias, a de updated_at mais recente por último. Telefone
-- diferente entre o cadastro e o WhatsApp (outro chip, sem o 9, sem o 55) não casa.
--
-- O que sai de app_memoria_ler (json, sempre as quatro chaves):
--   whatsapp_fatos         text | null   content de todos os leads da pessoa, separados
--                                        por uma linha em branco, cortado nos ÚLTIMOS 4000
--                                        caracteres (o fim é o mais novo: a Crystal da
--                                        agência anota acrescentando no fim);
--   whatsapp_preferencias  json array    known_preferences de todos os leads, sem repetir,
--                                        na mesma ordem; [] quando não há;
--   app_resumo             text | null   último resumo gravado pelo app;
--   app_atualizado_em      timestamptz | null.
-- Pessoa nula ou desconhecida, sem telefone, sem lead ou lead sem memória NÃO é erro:
-- fatos nulo e preferências [] (o resumo do app vem se existir).
--
-- O que sai de app_memoria_gravar: { versao } (1 na primeira gravação, +1 a cada outra).
--
-- O que sai de app_memoria_apagar: { apagadas } (1 se havia linha da pessoa, 0 se não
-- havia). Pessoa nula ou desconhecida NÃO é erro: 0. Rodar de novo dá 0.
--
-- TEXTO DE ALUNO: as duas funções carregam texto pessoal (fatos, preferências, resumo).
-- Por isso só a service_role executa, e o app nunca grava esse texto em log.
--
-- Erros (só em app_memoria_gravar): `raise exception` com MENSAGEM = código fixo,
-- `hint` com a regra. Errcode padrão P0001 (PostgREST responde 400).
--   PESSOA_INVALIDA  p_customer_id nulo;
--   RESUMO_INVALIDO  resumo nulo, vazio, só espaço ou com mais de 4000 caracteres
--                    (contados depois de tirar espaços e quebras das pontas).
--
-- Volta: desligar a chave op_memoria_unica. A tabela e as funções podem ficar (ninguém
-- mais lê nem grava; apagar continua servindo à exclusão de conta). Apagar de vez só se o
-- dono pedir, e só estes quatro:
--   drop function if exists public.app_memoria_apagar(uuid);
--   drop function if exists public.app_memoria_gravar(uuid, text);
--   drop function if exists public.app_memoria_ler(uuid);
--   drop table if exists public.crystal_memoria_unica;
--
-- Suposições sobre o esquema (código crystal-ia em 08/10: graph/agent.py,
-- graph/tools/factory.py, memory/summarize.py; a conferência abaixo para o arquivo se
-- faltar alguma coluna):
--   visão public.leticia_crystal_active_accesses a: customer_id uuid, phone_number text.
--   public.leticia_crystal_lead_management l: id (tipo não confirmado), phone_number text.
--   public.leticia_crystal_lead_memories m: lead_id (um por lead; o mesmo valor de l.id),
--     content text, profile_data jsonb ({"known_preferences": ["...", ...], ...}),
--     updated_at timestamptz.
--
-- -----------------------------------------------------------------------------
-- Para o Tuan (NADA disto é aplicado aqui nem no lado dele; é um trecho pronto, se a
-- agência quiser que a Crystal do WhatsApp também leia o que veio do app). Um SELECT na
-- tabela nova pelo telefone do lead, no estilo do _load_memory (asyncpg), com
-- $1 = lead["phone_number"]:
--
--   SELECT u.app_resumo, u.app_atualizado_em
--     FROM public.crystal_memoria_unica u
--    WHERE u.customer_id IN (
--          SELECT a.customer_id
--            FROM public.leticia_crystal_active_accesses a
--           WHERE regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')
--               = regexp_replace(coalesce($1, ''), '\D', '', 'g')
--             AND length(regexp_replace(coalesce($1, ''), '\D', '', 'g')) >= 10)
--    ORDER BY u.app_atualizado_em DESC
--    LIMIT 1;
--
-- Onde o texto entra no prompt dele é decisão dele (por exemplo, junto do lead_profile).
-- A tabela tem RLS ligado sem política e nenhum grant: lê quem é dono dela (o usuário
-- postgres, que é provavelmente o da DATABASE_URL do pooler que a Crystal do WhatsApp
-- usa). Se a conexão dele for com outro usuário, combinar antes um `grant select` só
-- nesta tabela.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Conferência (só leitura de catálogo; nada é criado se falhar):
--   ESQUEMA_DIFERENTE  falta alguma coluna da agência que as funções leem;
--   JA_EXISTE          já há tabela ou função com estes nomes que não veio deste
--                      arquivo (a marca é o comentário 'memoria-unica ...').
-- -----------------------------------------------------------------------------
do $$
declare
  v_falta text;
begin
  select string_agg(format('%s.%s', x.tabela, x.coluna), ', ')
    into v_falta
    from (values
      ('leticia_crystal_active_accesses', 'customer_id'),
      ('leticia_crystal_active_accesses', 'phone_number'),
      ('leticia_crystal_lead_management', 'id'),
      ('leticia_crystal_lead_management', 'phone_number'),
      ('leticia_crystal_lead_memories',   'lead_id'),
      ('leticia_crystal_lead_memories',   'content'),
      ('leticia_crystal_lead_memories',   'profile_data'),
      ('leticia_crystal_lead_memories',   'updated_at')
    ) as x(tabela, coluna)
   where not exists (
     select 1 from information_schema.columns c
      where c.table_schema = 'public'
        and c.table_name = x.tabela
        and c.column_name = x.coluna
   );
  if v_falta is not null then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'não encontrei: ' || v_falta;
  end if;

  if to_regclass('public.crystal_memoria_unica') is not null
     and coalesce(obj_description(to_regclass('public.crystal_memoria_unica'), 'pg_class'), '')
         not like 'memoria-unica %' then
    raise exception 'JA_EXISTE'
      using hint = 'public.crystal_memoria_unica já existe e não veio deste arquivo; não mexer';
  end if;

  if exists (
    select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('app_memoria_ler', 'app_memoria_gravar', 'app_memoria_apagar')
       and coalesce(obj_description(p.oid, 'pg_proc'), '') not like 'memoria-unica %'
  ) then
    raise exception 'JA_EXISTE'
      using hint = 'app_memoria_ler, app_memoria_gravar ou app_memoria_apagar já existe e não veio deste arquivo; não mexer';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- 1. Tabela nova: o resumo do app, um por cliente. RLS ligado e sem política; nenhum
--    grant (o padrão do Supabase dá tudo a anon/authenticated/service_role em tabela
--    nova do public, por isso o revoke). Só as funções abaixo chegam nela.
-- -----------------------------------------------------------------------------
create table if not exists public.crystal_memoria_unica (
  customer_id       uuid        primary key,
  app_resumo        text        not null,
  app_atualizado_em timestamptz not null default now(),
  versao            int         not null default 1
);

alter table public.crystal_memoria_unica enable row level security;
revoke all on table public.crystal_memoria_unica from public, anon, authenticated, service_role;

comment on table public.crystal_memoria_unica is
  'memoria-unica 08/10/2026: resumo da Crystal do app por cliente. Só via app_memoria_ler/app_memoria_gravar/app_memoria_apagar (crystal-em-casa/supabase/app_memoria_unica.sql).';

-- -----------------------------------------------------------------------------
-- 2. Ler a memória de uma pessoa. Só leitura (stable). Ver o formato no cabeçalho.
-- -----------------------------------------------------------------------------
create or replace function public.app_memoria_ler(p_customer_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_fatos  text;
  v_prefs  jsonb := '[]'::jsonb;
  v_resumo text;
  v_quando timestamptz;
begin
  if p_customer_id is not null then
    with tel as (
      select distinct
        regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    ),
    leads as (
      select distinct l.id::text as lead_id
      from tel t
      join public.leticia_crystal_lead_management l
        on regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = t.digitos
      where l.id is not null
    ),
    mem as (
      select
        d.lead_id,
        nullif(btrim(m.content::text, E' \t\r\n'), '') as fatos,
        m.profile_data::jsonb as perfil,
        m.updated_at as quando
      from leads d
      join public.leticia_crystal_lead_memories m
        on m.lead_id::text = d.lead_id
    ),
    pref as (
      select e.valor, min(e.ordem) as ordem
      from (
        select
          btrim(x.elem #>> '{}', E' \t\r\n') as valor,
          row_number() over (order by mm.quando asc nulls first, mm.lead_id, x.n) as ordem
        from mem mm
        cross join lateral jsonb_array_elements(
          case when jsonb_typeof(mm.perfil -> 'known_preferences') = 'array'
               then mm.perfil -> 'known_preferences'
               else '[]'::jsonb
          end
        ) with ordinality as x(elem, n)
        where jsonb_typeof(x.elem) = 'string'
      ) e
      where e.valor <> ''
      group by e.valor
    )
    select
      (select string_agg(mm.fatos, E'\n\n' order by mm.quando asc nulls first, mm.lead_id)
         from mem mm
        where mm.fatos is not null),
      coalesce((select jsonb_agg(to_jsonb(p.valor) order by p.ordem) from pref p), '[]'::jsonb)
    into v_fatos, v_prefs;

    if char_length(v_fatos) > 4000 then
      v_fatos := right(v_fatos, 4000);
    end if;

    select u.app_resumo, u.app_atualizado_em
      into v_resumo, v_quando
      from public.crystal_memoria_unica u
     where u.customer_id = p_customer_id;
  end if;

  return json_build_object(
    'whatsapp_fatos',        v_fatos,
    'whatsapp_preferencias', v_prefs,
    'app_resumo',            v_resumo,
    'app_atualizado_em',     v_quando
  );
end;
$$;

comment on function public.app_memoria_ler(uuid) is
  'memoria-unica 08/10/2026: fatos e preferências da Crystal do WhatsApp + resumo do app, por cliente. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- 3. Gravar o resumo do app de uma pessoa. Upsert SÓ na tabela nova; versao + 1.
-- -----------------------------------------------------------------------------
create or replace function public.app_memoria_gravar(p_customer_id uuid, p_resumo text)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_resumo text := btrim(p_resumo, E' \t\r\n');
  v_versao int;
begin
  if p_customer_id is null then
    raise exception 'PESSOA_INVALIDA' using hint = 'p_customer_id é obrigatório (uuid do cliente)';
  end if;
  if v_resumo is null or v_resumo = '' or char_length(v_resumo) > 4000 then
    raise exception 'RESUMO_INVALIDO'
      using hint = 'p_resumo com 1 a 4000 caracteres, sem contar espaços e quebras das pontas';
  end if;

  insert into public.crystal_memoria_unica as u (customer_id, app_resumo, app_atualizado_em, versao)
  values (p_customer_id, v_resumo, now(), 1)
  on conflict (customer_id) do update
     set app_resumo        = excluded.app_resumo,
         app_atualizado_em = now(),
         versao            = u.versao + 1
  returning u.versao into v_versao;

  return json_build_object('versao', v_versao);
end;
$$;

comment on function public.app_memoria_gravar(uuid, text) is
  'memoria-unica 08/10/2026: grava o resumo do app em crystal_memoria_unica (upsert, versao + 1). Só service_role.';

-- -----------------------------------------------------------------------------
-- Permissões das duas funções novas: só a service_role (o servidor) executa.
-- -----------------------------------------------------------------------------
revoke all on function public.app_memoria_ler(uuid) from public;
revoke all on function public.app_memoria_ler(uuid) from anon, authenticated;
grant execute on function public.app_memoria_ler(uuid) to service_role;

revoke all on function public.app_memoria_gravar(uuid, text) from public;
revoke all on function public.app_memoria_gravar(uuid, text) from anon, authenticated;
grant execute on function public.app_memoria_gravar(uuid, text) to service_role;

-- -----------------------------------------------------------------------------
-- 4. Apagar o resumo do app de uma pessoa (LGPD: o aluno exclui a conta no app). Delete
--    SÓ na tabela nova, só a linha dessa pessoa; nada nas tabelas da agência. Pessoa
--    nula ou sem linha não é erro: { apagadas: 0 }. Só service_role executa.
-- -----------------------------------------------------------------------------
create or replace function public.app_memoria_apagar(p_customer_id uuid)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_apagadas int := 0;
begin
  if p_customer_id is not null then
    delete from public.crystal_memoria_unica u
     where u.customer_id = p_customer_id;
    get diagnostics v_apagadas = row_count;
  end if;

  return json_build_object('apagadas', v_apagadas);
end;
$$;

comment on function public.app_memoria_apagar(uuid) is
  'memoria-unica 08/10/2026: apaga o resumo do app de um cliente em crystal_memoria_unica (exclusão da conta, LGPD). Só service_role.';

revoke all on function public.app_memoria_apagar(uuid) from public;
revoke all on function public.app_memoria_apagar(uuid) from anon, authenticated;
grant execute on function public.app_memoria_apagar(uuid) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só números e nomes, nenhum texto de aluno na tela):
--   as funções existem e só service_role executa (mais o dono, postgres)
--     select routine_name, grantee from information_schema.routine_privileges
--      where routine_schema = 'public' and routine_name like 'app_memoria_%' order by 1, 2;
--   a tabela não tem grant para anon/authenticated/service_role (espera-se zero linhas)
--     select grantee, privilege_type from information_schema.role_table_grants
--      where table_schema = 'public' and table_name = 'crystal_memoria_unica'
--        and grantee in ('anon', 'authenticated', 'service_role');
--   um aluno com memória no WhatsApp (só tamanhos)
--     select char_length(r->>'whatsapp_fatos') as fatos,
--            json_array_length(r->'whatsapp_preferencias') as prefs,
--            r->>'app_atualizado_em' as app_em
--       from (select public.app_memoria_ler('<uuid de um cliente>') as r) s;
--   cliente desconhecido não é erro (fatos nulo, prefs 0)
--     select char_length(r->>'whatsapp_fatos'), json_array_length(r->'whatsapp_preferencias')
--       from (select public.app_memoria_ler(gen_random_uuid()) as r) s;
--   validação recusa (espera-se RESUMO_INVALIDO; nada é gravado)
--     select public.app_memoria_gravar(gen_random_uuid(), '');
--   apagar cliente desconhecido ou nulo não é erro (espera-se {"apagadas" : 0} nas duas)
--     select public.app_memoria_apagar(gen_random_uuid()), public.app_memoria_apagar(null);
--   a anon NÃO pode executar (tem que dar "permission denied")
--     set role anon; select public.app_memoria_ler(gen_random_uuid()); reset role;
--   quantos resumos do app já foram guardados
--     select count(*), max(versao), max(app_atualizado_em) from public.crystal_memoria_unica;
--
-- Cada leitura compara dígitos na tabela de leads inteira (como app_historico_whatsapp)
-- e casa lead_id como texto; com cache de 10 min no app isso basta. Se ficar lenta, o
-- índice sugerido em app_whatsapp_silencio.sql ajuda e é tabela da agência: NÃO criar
-- sem combinar (regra deste arquivo: nada muda do que já existe).
