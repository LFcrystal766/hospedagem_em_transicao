-- =============================================================================
-- Memória completa pré-gerada: a "ficha" de cada aluno, pronta antes do primeiro acesso
-- (10/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só). Depende de app_telefone_chave.sql (app_tel_chave) e de
-- app_memoria_unica.sql (crystal_memoria_unica, app_memoria_ler, app_memoria_apagar),
-- os dois já aplicados. Se a conferência logo abaixo falhar, nada é criado.
--
-- Pedido do dono (10/10): "antes mesmo dos alunos chegarem ao app, você já consiga ter a
-- memória completa deles". A nossa Crystal (apps/crystal, na VPS) lê o histórico INTEIRO
-- do WhatsApp de cada aluno (tabela atual + arquivo), escreve uma ficha de até 4.000
-- caracteres e grava aqui, por customer_id. No turno, `app_memoria_ler` devolve a ficha e
-- a Crystal a usa já na primeira mensagem, sem espera. Quem conversou nos últimos 30 dias
-- vem primeiro na fila (pedido do dono, 10/10).
--
-- O que este arquivo cria (nenhuma linha das tabelas da agência, leticia_crystal_*, é
-- criada, mudada ou apagada: elas só aparecem em SELECT):
--   - tabela  public.crystal_memoria_ficha                 (create table if not exists);
--   - função  public.app_ficha_alvos()                     (interna: quem tem direito);
--   - função  public.app_ficha_fila(uuid, int)              (só leitura: quem falta);
--   - função  public.app_ficha_historico(uuid, timestamptz, int) (só leitura: uma página);
--   - função  public.app_ficha_gravar(...)                 (escreve SÓ na tabela nova);
--   - função  public.app_ficha_andamento()                 (só leitura: números do painel).
-- E reescreve duas funções NOSSAS (de app_memoria_unica.sql), sem mudar o que já faziam:
--   - app_memoria_ler: a mesma resposta + a chave nova `whatsapp_ficha`;
--   - app_memoria_apagar: apaga também a ficha (exclusão da conta, LGPD).
-- Rodar de novo é seguro: a tabela não é recriada (as fichas ficam) e as funções são
-- reescritas iguais. Tabela com o mesmo nome que não veio deste arquivo: para (JA_EXISTE).
--
-- Quem chama: só a nossa Crystal e a API do app (VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/<função>) com a service_role, que fica só na VPS. Todas as funções
-- são `security definer`, com execute só para service_role; a tabela não tem grant para
-- ninguém. Nada de texto de conversa vai para log: as funções só devolvem o que foi pedido.
--
-- ORDEM: app_telefone_chave.sql e app_memoria_unica.sql também escrevem app_memoria_ler.
-- Se algum deles for rodado de novo, rodar ESTE logo depois (senão a ficha some do turno).
--
-- Volta: `drop function public.app_ficha_fila(uuid, int), public.app_ficha_historico(uuid,
-- timestamptz, int), public.app_ficha_gravar(uuid, text, timestamptz, int, numeric, text,
-- text, text), public.app_ficha_andamento(), public.app_ficha_alvos();
-- drop table public.crystal_memoria_ficha;` e rodar de novo app_memoria_unica.sql (volta o
-- app_memoria_ler e o app_memoria_apagar de antes). A Crystal sem ficha responde como hoje.
-- =============================================================================

do $$
declare
  v_falta text;
begin
  select string_agg(format('%s.%s', x.tabela, x.coluna), ', ')
    into v_falta
    from (values
      ('leticia_crystal_active_accesses',        'customer_id'),
      ('leticia_crystal_active_accesses',        'phone_number'),
      ('leticia_crystal_active_accesses',        'subscription_status'),
      ('leticia_crystal_lead_management',        'id'),
      ('leticia_crystal_lead_management',        'phone_number'),
      ('leticia_crystal_lead_management',        'thread_id'),
      ('leticia_crystal_lead_management',        'updated_at'),
      ('leticia_crystal_lead_memories',          'lead_id'),
      ('leticia_crystal_lead_memories',          'content'),
      ('leticia_crystal_lead_memories',          'profile_data'),
      ('leticia_crystal_lead_memories',          'updated_at'),
      ('leticia_crystal_chat_histories',         'session_id'),
      ('leticia_crystal_chat_histories',         'message'),
      ('leticia_crystal_chat_histories',         'created_at'),
      ('leticia_crystal_chat_histories_archive', 'session_id'),
      ('leticia_crystal_chat_histories_archive', 'message'),
      ('leticia_crystal_chat_histories_archive', 'created_at'),
      ('crystal_compras',                        'id'),
      ('crystal_compras',                        'telefone'),
      ('crystal_compras',                        'status'),
      ('crystal_memoria_unica',                  'customer_id')
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

  if to_regprocedure('public.app_tel_chave(text)') is null then
    raise exception 'FALTA_TEL_CHAVE' using hint = 'aplicar antes app_telefone_chave.sql';
  end if;

  if to_regclass('public.crystal_memoria_ficha') is not null
     and coalesce(obj_description(to_regclass('public.crystal_memoria_ficha'), 'pg_class'), '')
         not like 'memoria-ficha %' then
    raise exception 'JA_EXISTE'
      using hint = 'public.crystal_memoria_ficha já existe e não veio deste arquivo; não mexer';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Tabela: uma linha por aluno (customer_id do app: o `crystalContactId`).
--   ficha       o texto que a Crystal lê no turno (null enquanto só houve erro);
--   ate         a data da última mensagem do WhatsApp que entrou na ficha (o cursor da
--               manutenção: na próxima rodada só entra o que veio depois);
--   estado      ok (ficha pronta), vazio (sem conversa no WhatsApp), erro (tentar de novo);
--   tentativas  erros seguidos; com 3, a fila deixa o aluno de lado até alguém zerar.
-- -----------------------------------------------------------------------------
create table if not exists public.crystal_memoria_ficha (
  customer_id  uuid        primary key,
  ficha        text,
  ate          timestamptz,
  mensagens    int         not null default 0,
  custo_usd    numeric(12, 6) not null default 0,
  modelo       text,
  estado       text        not null check (estado in ('ok', 'vazio', 'erro')),
  erro         text,
  tentativas   int         not null default 0,
  gerado_em    timestamptz not null default now(),
  versao       int         not null default 1,
  constraint crystal_memoria_ficha_tamanho check (ficha is null or char_length(ficha) <= 4000)
);

alter table public.crystal_memoria_ficha enable row level security;
revoke all on table public.crystal_memoria_ficha from public, anon, authenticated, service_role;

comment on table public.crystal_memoria_ficha is
  'memoria-ficha 10/10/2026: ficha do aluno gerada do histórico inteiro do WhatsApp. Só via app_ficha_* e app_memoria_* (crystal-em-casa/supabase/app_memoria_ficha.sql).';

-- -----------------------------------------------------------------------------
-- Interna: quem tem direito à ficha e por quais conversas do WhatsApp (thread_id).
-- Alunos da base antiga (acesso active ou pending) e os nossos compradores da Assiny
-- (crystal_compras, status active; o id da compra é o customer_id do app). Telefone
-- comparado pela chave país + DDD + 8 finais (app_tel_chave).
-- -----------------------------------------------------------------------------
create or replace function public.app_ficha_alvos()
returns table (customer_id uuid, session_id text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with tel as (
    select a.customer_id, public.app_tel_chave(a.phone_number) as chave
      from public.leticia_crystal_active_accesses a
     where a.customer_id is not null
       and a.subscription_status in ('active', 'pending')
       and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    union
    select k.id, public.app_tel_chave(k.telefone)
      from public.crystal_compras k
     where k.status = 'active'
       and length(regexp_replace(coalesce(k.telefone, ''), '\D', '', 'g')) >= 10
  ),
  alunos as (
    select distinct t.customer_id from tel t
  )
  select distinct al.customer_id, l.thread_id::text
    from alunos al
    left join tel t on t.customer_id = al.customer_id
    left join public.leticia_crystal_lead_management l
      on public.app_tel_chave(l.phone_number) = t.chave
     and l.thread_id is not null;
$$;

comment on function public.app_ficha_alvos() is
  'memoria-ficha 10/10/2026: interna. Alunos com direito à ficha e as conversas do WhatsApp de cada um.';

revoke all on function public.app_ficha_alvos() from public;
revoke all on function public.app_ficha_alvos() from anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Fila, em fatias: para os próximos `p_qtd` alunos (por customer_id, depois de `p_apos`),
-- a data da última mensagem no WhatsApp e se a ficha precisa ser feita agora:
--   - sem linha na tabela (nunca gerado), ou
--   - com mensagem nova depois de `ate` (manutenção), ou
--   - com erro e menos de 3 tentativas.
-- Em fatias porque a API REST corta cada pedido em 8 s e achar a última mensagem custa
-- uma leitura de índice por conversa (medido em 10/10: ~0,7 ms cada, ~10 mil conversas).
-- Quem chama (a API do app) junta as fatias, filtra pelos dias (o dono pediu os últimos
-- 30 primeiro) e ordena do mais recente para o mais antigo. A última mensagem vem da
-- tabela atual (índice session_id + created_at); quem só tem conversa no arquivo usa a
-- última do arquivo, pela ordem do id (o arquivo só tem índice session_id + id).
-- -----------------------------------------------------------------------------
create or replace function public.app_ficha_fila(p_apos uuid default null, p_qtd int default 1000)
returns table (customer_id uuid, ultima timestamptz, ate timestamptz, precisa boolean)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_qtd is null or p_qtd < 1 or p_qtd > 3000 then
    raise exception 'QTD_INVALIDA' using hint = 'p_qtd entre 1 e 3000';
  end if;

  return query
    with alvo as (
      select * from public.app_ficha_alvos()
    ),
    fatia as (
      select distinct a.customer_id
        from alvo a
       where p_apos is null or a.customer_id > p_apos
       order by a.customer_id
       limit p_qtd
    ),
    ult as (
      select
        a.customer_id,
        max(coalesce(
          (select h.created_at
             from public.leticia_crystal_chat_histories h
            where h.session_id = a.session_id
            order by h.created_at desc
            limit 1),
          (select x.created_at
             from public.leticia_crystal_chat_histories_archive x
            where x.session_id = a.session_id
            order by x.id desc
            limit 1)
        )) as m_ultima
      from fatia fa
      join alvo a on a.customer_id = fa.customer_id
      group by a.customer_id
    )
    select u.customer_id,
           u.m_ultima,
           f.ate,
           (   f.customer_id is null
            or (f.estado = 'erro' and f.tentativas < 3)
            or (f.estado <> 'erro' and u.m_ultima is not null and (f.ate is null or u.m_ultima > f.ate))
           ) as precisa
      from ult u
      left join public.crystal_memoria_ficha f on f.customer_id = u.customer_id
     order by u.customer_id;
end;
$$;

comment on function public.app_ficha_fila(uuid, int) is
  'memoria-ficha 10/10/2026: uma fatia de alunos (por customer_id) com a última mensagem no WhatsApp e se a ficha precisa ser feita. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- Histórico de um aluno, uma página por vez, da mais antiga para a mais nova, só o que
-- veio DEPOIS de `p_depois_de` (null: desde o começo). Tabela atual + arquivo, sem repetir.
-- Mensagens longas cortadas (aluno 800, Crystal 300 caracteres): o que importa da Crystal
-- é o assunto; do aluno, quase tudo cabe. A página nunca corta no meio de um mesmo
-- instante: se a última linha tem a data X, todas as de data X vêm juntas (o cursor da
-- próxima página é a data da última linha, sem perder empate).
-- -----------------------------------------------------------------------------
create or replace function public.app_ficha_historico(
  p_customer_id uuid,
  p_depois_de timestamptz default null,
  p_limite int default 2000
)
returns table (quando timestamptz, de text, texto text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_limite is null or p_limite < 1 or p_limite > 5000 then
    raise exception 'LIMITE_INVALIDO' using hint = 'p_limite entre 1 e 5000';
  end if;
  if p_customer_id is null then
    return;
  end if;

  return query
    with fio as (
      select distinct a.session_id
        from public.app_ficha_alvos() a
       where a.customer_id = p_customer_id
         and a.session_id is not null
    ),
    bruto as (
      select h.created_at, h.message
        from fio f
        join public.leticia_crystal_chat_histories h on h.session_id = f.session_id
       where h.created_at is not null
         and (p_depois_de is null or h.created_at > p_depois_de)
      union all
      select x.created_at, x.message
        from fio f
        join public.leticia_crystal_chat_histories_archive x on x.session_id = f.session_id
       where x.created_at is not null
         and (p_depois_de is null or x.created_at > p_depois_de)
    ),
    msg as (
      select distinct
        b.created_at as m_quando,
        case b.message->>'type' when 'human' then 'aluno' else 'crystal' end as m_de,
        nullif(btrim(coalesce(b.message->>'content', b.message->'data'->>'content')), '') as m_texto
      from bruto b
      where b.message->>'type' in ('human', 'ai')
    ),
    pagina as (
      select m.m_quando from msg m
       where m.m_texto is not null
       order by m.m_quando asc
       limit p_limite
    ),
    corte as (
      select max(p.m_quando) as ate from pagina p
    )
    select m.m_quando,
           m.m_de,
           left(m.m_texto, case m.m_de when 'aluno' then 800 else 300 end)
      from msg m, corte c
     where m.m_texto is not null
       and m.m_quando <= c.ate
     order by m.m_quando asc, m.m_de asc;
end;
$$;

comment on function public.app_ficha_historico(uuid, timestamptz, int) is
  'memoria-ficha 10/10/2026: uma página do histórico inteiro do WhatsApp de um aluno (atual + arquivo, sem repetir), da mais antiga para a mais nova. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- Grava o resultado de um aluno. ok/vazio: grava a ficha (vazio: sem texto), zera as
-- tentativas e soma o custo. erro: guarda só o código (sem texto de conversa), soma a
-- tentativa e NÃO apaga a ficha anterior (a Crystal segue usando a última boa).
-- -----------------------------------------------------------------------------
create or replace function public.app_ficha_gravar(
  p_customer_id uuid,
  p_ficha text,
  p_ate timestamptz,
  p_mensagens int,
  p_custo_usd numeric,
  p_modelo text,
  p_estado text,
  p_erro text default null
)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_ficha  text := nullif(btrim(coalesce(p_ficha, ''), E' \t\r\n'), '');
  v_custo  numeric := greatest(coalesce(p_custo_usd, 0), 0);
  v_versao int;
begin
  if p_customer_id is null then
    raise exception 'PESSOA_INVALIDA' using hint = 'p_customer_id é obrigatório';
  end if;
  if p_estado is null or p_estado not in ('ok', 'vazio', 'erro') then
    raise exception 'ESTADO_INVALIDO' using hint = 'p_estado: ok, vazio ou erro';
  end if;
  if p_estado = 'ok' and (v_ficha is null or char_length(v_ficha) > 4000) then
    raise exception 'FICHA_INVALIDA' using hint = 'ficha com 1 a 4000 caracteres';
  end if;
  if v_custo > 100 then
    raise exception 'CUSTO_INVALIDO' using hint = 'custo de um aluno acima de US$ 100';
  end if;

  if p_estado = 'erro' then
    insert into public.crystal_memoria_ficha as f
      (customer_id, estado, erro, tentativas, custo_usd, gerado_em)
    values (p_customer_id, 'erro', left(coalesce(p_erro, 'erro'), 80), 1, v_custo, now())
    on conflict (customer_id) do update
       set estado     = case when f.ficha is not null then f.estado else 'erro' end,
           erro       = left(coalesce(p_erro, 'erro'), 80),
           tentativas = f.tentativas + 1,
           custo_usd  = f.custo_usd + v_custo,
           gerado_em  = now()
    returning f.versao into v_versao;
    -- Com ficha anterior boa, o estado fica "ok": a fila só a pega de novo quando houver
    -- mensagem nova. Sem ficha, "erro" volta à fila até 3 tentativas.
    return json_build_object('versao', v_versao);
  end if;

  insert into public.crystal_memoria_ficha as f
    (customer_id, ficha, ate, mensagens, custo_usd, modelo, estado, erro, tentativas, gerado_em, versao)
  values (p_customer_id, case when p_estado = 'ok' then v_ficha end, p_ate,
          greatest(coalesce(p_mensagens, 0), 0), v_custo, left(p_modelo, 120), p_estado, null, 0, now(), 1)
  on conflict (customer_id) do update
     set ficha      = case when p_estado = 'ok' then v_ficha else f.ficha end,
         ate        = coalesce(p_ate, f.ate),
         mensagens  = f.mensagens + greatest(coalesce(p_mensagens, 0), 0),
         custo_usd  = f.custo_usd + v_custo,
         modelo     = coalesce(left(p_modelo, 120), f.modelo),
         estado     = case when p_estado = 'vazio' and f.ficha is not null then 'ok' else p_estado end,
         erro       = null,
         tentativas = 0,
         gerado_em  = now(),
         versao     = f.versao + 1
  returning f.versao into v_versao;

  return json_build_object('versao', v_versao);
end;
$$;

comment on function public.app_ficha_gravar(uuid, text, timestamptz, int, numeric, text, text, text) is
  'memoria-ficha 10/10/2026: grava a ficha (ou o erro, só o código) de um aluno em crystal_memoria_ficha. Só service_role.';

-- -----------------------------------------------------------------------------
-- Números do painel (Operação): quantos com ficha, vazios, com erro, custo somado, e o
-- tamanho da base. Sem nada de conversa.
-- -----------------------------------------------------------------------------
create or replace function public.app_ficha_andamento()
returns json
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select json_build_object(
    'alunos',        (select count(distinct a.customer_id) from public.app_ficha_alvos() a),
    'com_ficha',     count(*) filter (where f.estado = 'ok'),
    'vazios',        count(*) filter (where f.estado = 'vazio'),
    'erros',         count(*) filter (where f.estado = 'erro'),
    'erros_parados', count(*) filter (where f.estado = 'erro' and f.tentativas >= 3),
    'mensagens',     coalesce(sum(f.mensagens), 0),
    'custo_usd',     coalesce(sum(f.custo_usd), 0),
    'ultima_em',     max(f.gerado_em)
  )
  from public.crystal_memoria_ficha f;
$$;

comment on function public.app_ficha_andamento() is
  'memoria-ficha 10/10/2026: contagens e custo das fichas para o painel. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- app_memoria_ler: igual à de app_memoria_unica.sql + `whatsapp_ficha`.
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
  v_ficha  text;
  v_ate    timestamptz;
begin
  if p_customer_id is not null then
    with tel as (
      select distinct public.app_tel_chave(a.phone_number) as chave
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    ),
    leads as (
      select distinct l.id::text as lead_id
      from tel t
      join public.leticia_crystal_lead_management l
        on public.app_tel_chave(l.phone_number) = t.chave
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

    select f.ficha, f.ate
      into v_ficha, v_ate
      from public.crystal_memoria_ficha f
     where f.customer_id = p_customer_id
       and f.ficha is not null;
  end if;

  return json_build_object(
    'whatsapp_fatos',        v_fatos,
    'whatsapp_preferencias', v_prefs,
    'app_resumo',            v_resumo,
    'app_atualizado_em',     v_quando,
    'whatsapp_ficha',        v_ficha,
    'whatsapp_ficha_ate',    v_ate
  );
end;
$$;

comment on function public.app_memoria_ler(uuid) is
  'memoria-unica 08/10/2026 (ficha em 10/10): fatos e preferências da Crystal do WhatsApp, ficha pré-gerada e resumo do app, por cliente. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- app_memoria_apagar: igual à de app_memoria_unica.sql e apaga também a ficha (LGPD).
-- A resposta conta as duas tabelas.
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
  v_fichas   int := 0;
begin
  if p_customer_id is not null then
    delete from public.crystal_memoria_unica u
     where u.customer_id = p_customer_id;
    get diagnostics v_apagadas = row_count;
    delete from public.crystal_memoria_ficha f
     where f.customer_id = p_customer_id;
    get diagnostics v_fichas = row_count;
  end if;

  return json_build_object('apagadas', v_apagadas + v_fichas);
end;
$$;

comment on function public.app_memoria_apagar(uuid) is
  'memoria-unica 08/10/2026 (ficha em 10/10): apaga o resumo do app e a ficha de um cliente (exclusão da conta, LGPD). Só service_role.';

revoke all on function public.app_ficha_fila(uuid, int) from public;
revoke all on function public.app_ficha_fila(uuid, int) from anon, authenticated;
grant execute on function public.app_ficha_fila(uuid, int) to service_role;

revoke all on function public.app_ficha_historico(uuid, timestamptz, int) from public;
revoke all on function public.app_ficha_historico(uuid, timestamptz, int) from anon, authenticated;
grant execute on function public.app_ficha_historico(uuid, timestamptz, int) to service_role;

revoke all on function public.app_ficha_gravar(uuid, text, timestamptz, int, numeric, text, text, text) from public;
revoke all on function public.app_ficha_gravar(uuid, text, timestamptz, int, numeric, text, text, text) from anon, authenticated;
grant execute on function public.app_ficha_gravar(uuid, text, timestamptz, int, numeric, text, text, text) to service_role;

revoke all on function public.app_ficha_andamento() from public;
revoke all on function public.app_ficha_andamento() from anon, authenticated;
grant execute on function public.app_ficha_andamento() to service_role;

revoke all on function public.app_memoria_ler(uuid) from public;
revoke all on function public.app_memoria_ler(uuid) from anon, authenticated;
grant execute on function public.app_memoria_ler(uuid) to service_role;

revoke all on function public.app_memoria_apagar(uuid) from public;
revoke all on function public.app_memoria_apagar(uuid) from anon, authenticated;
grant execute on function public.app_memoria_apagar(uuid) to service_role;

notify pgrst, 'reload schema';
