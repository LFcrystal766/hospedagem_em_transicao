-- =============================================================================
-- Base de conhecimento editável pelo painel: histórico dos trechos e funções de escrita
-- (onda 5, 13/10/2026). Cópia de docs/supabase/app_conhecimento.sql do app (teste lá, em docs/supabase/testes/)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma transação
-- só: begin no topo, commit no fim). Se a conferência logo abaixo falhar, nada é criado.
--
-- Pedido do dono (13/10): ver e editar a "inteligência" da Crystal pelo painel. Uma das três
-- partes é a base de conhecimento, a tabela da agência `leticia_crystal_hybrid_search` (27
-- linhas em 13/10), que a Edge Function `crystal_hybrid_search` busca a cada turno pela RPC
-- `public.crystal_hybrid_search(...)`. O painel passa a criar, editar, apagar e restaurar
-- trechos, sempre com histórico e sem apagar de verdade: o trecho apagado sai da tabela viva
-- (é o único jeito de sair da busca sem mexer na RPC da agência) e fica inteiro, com texto e
-- embedding, no histórico, que só aceita acréscimo (nem update, nem delete, nem truncate).
--
-- O que este arquivo cria (a RPC crystal_hybrid_search, a Edge Function e as outras funções
-- da agência NÃO mudam):
--   - tabela  public.crystal_conhecimento_versoes        (histórico; create table if not exists);
--   - semente: uma versão `semente` por linha viva que ainda não tem versão (rodar de novo não
--     duplica);
--   - função  public.app_conhecimento_listar()           (só leitura: trechos vivos e apagados);
--   - função  public.app_conhecimento_historico(bigint)  (só leitura: versões de um trecho);
--   - função  public.app_conhecimento_gravar(...)        (cria ou edita um trecho, com versão);
--   - função  public.app_conhecimento_apagar(...)        (guarda a versão `apagar` com texto e
--     embedding e só então tira a linha da tabela viva: a busca deixa de achar);
--   - função  public.app_conhecimento_restaurar(...)     (devolve a linha com o MESMO id);
--   - gatilho no histórico: update, delete e truncate param (HISTORICO_SO_ACRESCENTA);
--   - fecha a escrita direta na tabela viva para anon e authenticated (revoke de insert, update,
--     delete e truncate; a leitura fica) e confere no fim: sobrou escrita por outro caminho
--     (papel herdado, grant em coluna), o arquivo para com PERMISSAO_ABERTA e nada fica.
-- Escreve na tabela da agência só por essas funções: insert, update e delete de UMA linha por
-- chamada, sempre com a versão no histórico antes.
--
-- Quem chama: só a nossa Crystal (apps/crystal, na VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/<função>) com a service_role, que fica só no crystal.env. O embedding do
-- trecho é gerado pela Crystal (openai/text-embedding-3-small, 1536 dimensões, o mesmo da Edge
-- Function) ANTES de chamar a função, e chega como texto '[n,n,...]'. Todas as funções são
-- `security definer`, `set search_path = public, extensions`, com execute só para service_role;
-- a tabela de histórico não tem grant para ninguém.
--
-- ATENÇÃO, antes de aplicar:
--   1) A conferência mostra (NOTICE) se a coluna `fts` é gerada pelo banco. Se NÃO for, as
--      funções calculam `fts` com to_tsvector('portuguese', content). Conferir antes que a
--      agência usa mesmo a configuração 'portuguese' (ver a definição da crystal_hybrid_search
--      ou de algum trigger); se for outra, trocar as duas ocorrências de 'portuguese' abaixo.
--   2) Sem agência desde 09/10, mas ainda pode existir algum processo da agência que reescreve
--      a leticia_crystal_hybrid_search (n8n antigo). Conferir antes de ligar a edição. Se ele
--      escrevia com a chave anon ou com um usuário logado, para de funcionar (é a brecha que
--      este arquivo fecha); com a service_role, segue como estava.
--
-- ORDEM: depois de app_memoria_ficha.sql (não depende dele; só para manter a ordem dos
-- arquivos). Junto com a imagem nova da Crystal (as rotas /v1/conhecimento respondem 503 sem
-- as funções). Rodar de novo é seguro: a tabela não é recriada e as funções são reescritas
-- iguais. Tabela de histórico com o mesmo nome que não veio deste arquivo: para (JA_EXISTE).
--
-- Volta: só as funções saem; a tabela de histórico FICA (é onde estão o texto e o embedding de
-- todo trecho apagado; sem ela, eles se perdem para sempre). Nunca dar drop nela.
--   drop function public.app_conhecimento_listar(), public.app_conhecimento_historico(bigint),
--     public.app_conhecimento_gravar(bigint, text, text, text, jsonb, text, text, text, text, bigint),
--     public.app_conhecimento_apagar(bigint, text, text, text, bigint),
--     public.app_conhecimento_restaurar(bigint, text, text, text),
--     public.app_conhecimento_tipo_id(), public.app_conhecimento_fts_gerada(),
--     public.app_conhecimento_conferir_tabela_viva();
-- As linhas vivas da leticia_crystal_hybrid_search ficam como estão (com as edições feitas), e a
-- escrita direta de anon e authenticated continua fechada (reabrir é decisão à parte, que pede
-- RLS conferido antes).
-- =============================================================================

begin;

set local search_path = public, extensions;

do $$
declare
  v_falta text;
  v_tipo_embedding text;
  v_fts_gerada boolean;
  v_id_identidade "char";
  v_id_default text;
  v_obrigatorias text;
begin
  -- A tabela da agência e as colunas que o painel usa.
  select string_agg(x.coluna, ', ')
    into v_falta
    from (values ('id'), ('content'), ('category'), ('content_type'), ('metadata'), ('fts'), ('embedding')) as x(coluna)
   where not exists (
     select 1 from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = 'leticia_crystal_hybrid_search' and c.column_name = x.coluna
   );
  if v_falta is not null then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'leticia_crystal_hybrid_search sem: ' || v_falta;
  end if;

  if not exists (select 1 from pg_extension where extname = 'vector') then
    raise exception 'SEM_VECTOR' using hint = 'a extensão vector (pgvector) não está instalada';
  end if;

  select format_type(a.atttypid, a.atttypmod)
    into v_tipo_embedding
    from pg_attribute a
   where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass and a.attname = 'embedding' and not a.attisdropped;
  if v_tipo_embedding not like '%vector(1536)' then
    raise exception 'EMBEDDING_DIFERENTE' using hint = 'embedding é ' || coalesce(v_tipo_embedding, '?') || ', esperado vector(1536)';
  end if;

  -- Coluna obrigatória que o painel não conhece: o insert falharia. Melhor parar aqui.
  select string_agg(a.attname, ', ')
    into v_obrigatorias
    from pg_attribute a
    left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
   where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass
     and a.attnum > 0 and not a.attisdropped and a.attnotnull
     and d.adbin is null and a.attidentity = '' and a.attgenerated = ''
     and a.attname not in ('id', 'content', 'category', 'content_type', 'metadata', 'fts', 'embedding');
  if v_obrigatorias is not null then
    raise exception 'COLUNA_OBRIGATORIA' using hint = 'colunas obrigatórias sem padrão: ' || v_obrigatorias;
  end if;

  select a.attgenerated = 's'
    into v_fts_gerada
    from pg_attribute a
   where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass and a.attname = 'fts';
  select a.attidentity, pg_get_expr(d.adbin, d.adrelid)
    into v_id_identidade, v_id_default
    from pg_attribute a
    left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
   where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass and a.attname = 'id';

  raise notice 'tabela viva: rls %, anon escreve direto: %, authenticated escreve direto: % (antes deste arquivo; ele fecha)',
    (select case when c.relrowsecurity then 'ligado' else 'DESLIGADO' end from pg_class c where c.oid = 'public.leticia_crystal_hybrid_search'::regclass),
    has_table_privilege('anon', 'public.leticia_crystal_hybrid_search', 'insert, update, delete, truncate')
      or has_any_column_privilege('anon', 'public.leticia_crystal_hybrid_search', 'insert, update'),
    has_table_privilege('authenticated', 'public.leticia_crystal_hybrid_search', 'insert, update, delete, truncate')
      or has_any_column_privilege('authenticated', 'public.leticia_crystal_hybrid_search', 'insert, update');
  raise notice 'fts: %', case when v_fts_gerada then 'gerada pelo banco (nada a calcular)'
                              else 'NÃO é gerada: as funções calculam to_tsvector(''portuguese'', content); confirmar a configuração' end;
  raise notice 'id: %', case v_id_identidade when 'a' then 'identity always (restaurar usa overriding system value)'
                                              when 'd' then 'identity by default'
                                              else coalesce('default ' || v_id_default, 'sem default (criar usa max(id) + 1)') end;

  if to_regclass('public.crystal_conhecimento_versoes') is not null
     and coalesce(obj_description(to_regclass('public.crystal_conhecimento_versoes'), 'pg_class'), '')
         not like 'conhecimento-versoes %' then
    raise exception 'JA_EXISTE'
      using hint = 'public.crystal_conhecimento_versoes já existe e não veio deste arquivo; não mexer';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Histórico: uma linha por mudança, nunca alterada nem apagada. `apagar` guarda o texto e o
-- embedding do trecho que saiu da tabela viva (é de onde o restaurar tira).
-- -----------------------------------------------------------------------------
create table if not exists public.crystal_conhecimento_versoes (
  versao_id    bigserial   primary key,
  trecho_id    bigint      not null,
  acao         text        not null check (acao in ('semente', 'criar', 'editar', 'apagar', 'restaurar')),
  content      text        not null,
  category     text,
  content_type text,
  metadata     jsonb       not null default '{}'::jsonb,
  embedding    vector(1536),
  autor_id     text,
  autor_nome   text,
  nota         text,
  em           timestamptz not null default now()
);

create index if not exists crystal_conhecimento_versoes_trecho
  on public.crystal_conhecimento_versoes (trecho_id, versao_id desc);

alter table public.crystal_conhecimento_versoes enable row level security;
revoke all on table public.crystal_conhecimento_versoes from public, anon, authenticated, service_role;
revoke all on sequence public.crystal_conhecimento_versoes_versao_id_seq from public, anon, authenticated, service_role;

comment on table public.crystal_conhecimento_versoes is
  'conhecimento-versoes 13/10/2026: histórico dos trechos da leticia_crystal_hybrid_search editados pelo painel. Só via app_conhecimento_* (crystal-em-casa/supabase/app_conhecimento_editar.sql).';

-- Só acrescenta: update, delete e truncate param, de quem for (o histórico é de onde o trecho
-- apagado volta; mudar ou apagar uma linha dele perde o trecho).
create or replace function public.app_conhecimento_versoes_imutavel()
returns trigger
language plpgsql
set search_path = public, extensions
as $$
begin
  raise exception 'HISTORICO_SO_ACRESCENTA'
    using hint = 'crystal_conhecimento_versoes só aceita insert (docs/supabase/app_conhecimento.sql)';
end;
$$;
revoke all on function public.app_conhecimento_versoes_imutavel() from public, anon, authenticated, service_role;

create or replace trigger crystal_conhecimento_versoes_so_acrescenta
  before update or delete on public.crystal_conhecimento_versoes
  for each row execute function public.app_conhecimento_versoes_imutavel();
create or replace trigger crystal_conhecimento_versoes_sem_truncate
  before truncate on public.crystal_conhecimento_versoes
  for each statement execute function public.app_conhecimento_versoes_imutavel();

-- Semente: uma versão por linha viva sem histórico (as 27 de 13/10). Rodar de novo não duplica.
insert into public.crystal_conhecimento_versoes (trecho_id, acao, content, category, content_type, metadata, embedding)
select l.id, 'semente', l.content, l.category, l.content_type, coalesce(l.metadata, '{}'::jsonb), l.embedding
  from public.leticia_crystal_hybrid_search l
 where not exists (select 1 from public.crystal_conhecimento_versoes v where v.trecho_id = l.id)
 order by l.id;

-- -----------------------------------------------------------------------------
-- Internas: como a tabela da agência foi criada (lidas a cada chamada; custam um índice).
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_fts_gerada()
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce((select a.attgenerated = 's' from pg_attribute a
                    where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass and a.attname = 'fts'), false);
$$;

-- 'a' identity always, 'd' identity by default, 's' serial/default, '' sem default.
create or replace function public.app_conhecimento_tipo_id()
returns text
language sql
stable
security definer
set search_path = public, extensions
as $$
  select case when a.attidentity <> '' then a.attidentity::text when d.adbin is not null then 's' else '' end
    from pg_attribute a
    left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
   where a.attrelid = 'public.leticia_crystal_hybrid_search'::regclass and a.attname = 'id';
$$;

revoke all on function public.app_conhecimento_fts_gerada() from public, anon, authenticated, service_role;
revoke all on function public.app_conhecimento_tipo_id() from public, anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Listar: trechos vivos (com a última versão, para a trava otimista) e apagados (a última
-- versão é `apagar` e a linha não está viva). Sem o embedding: ele nunca sai daqui.
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_listar()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  with ult as (
    select distinct on (v.trecho_id) v.*
      from public.crystal_conhecimento_versoes v
     order by v.trecho_id, v.versao_id desc
  )
  select jsonb_build_object(
    'itens', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', l.id, 'content', l.content, 'category', l.category, 'content_type', l.content_type,
               'metadata', coalesce(l.metadata, '{}'::jsonb), 'versao_id', u.versao_id, 'atualizado_em', u.em,
               'autor_id', u.autor_id, 'autor_nome', u.autor_nome) order by l.id)
        from public.leticia_crystal_hybrid_search l
        left join ult u on u.trecho_id = l.id), '[]'::jsonb),
    'apagados', coalesce((
      select jsonb_agg(jsonb_build_object(
               'trecho_id', u.trecho_id, 'versao_id', u.versao_id, 'category', u.category, 'em', u.em,
               'autor_id', u.autor_id, 'autor_nome', u.autor_nome) order by u.em desc)
        from ult u
       where u.acao = 'apagar'
         and not exists (select 1 from public.leticia_crystal_hybrid_search l where l.id = u.trecho_id)), '[]'::jsonb)
  );
$$;

comment on function public.app_conhecimento_listar() is
  'conhecimento-versoes 13/10/2026: trechos vivos e apagados, sem embedding. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- Histórico de um trecho, da versão mais nova para a mais antiga (sem embedding).
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_historico(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_vivo boolean;
  v_versoes jsonb;
begin
  v_vivo := exists (select 1 from public.leticia_crystal_hybrid_search l where l.id = p_id);
  select jsonb_agg(jsonb_build_object(
           'versao_id', v.versao_id, 'trecho_id', v.trecho_id, 'acao', v.acao, 'content', v.content,
           'category', v.category, 'content_type', v.content_type, 'metadata', v.metadata,
           'autor_id', v.autor_id, 'autor_nome', v.autor_nome, 'nota', v.nota, 'em', v.em) order by v.versao_id desc)
    into v_versoes
    from public.crystal_conhecimento_versoes v
   where v.trecho_id = p_id;
  if v_versoes is null and not v_vivo then
    raise exception 'NAO_ENCONTRADO';
  end if;
  return jsonb_build_object('trecho_id', p_id, 'apagado', not v_vivo, 'versoes', coalesce(v_versoes, '[]'::jsonb));
end;
$$;

comment on function public.app_conhecimento_historico(bigint) is
  'conhecimento-versoes 13/10/2026: versões de um trecho, da mais nova para a mais antiga. Só leitura; só service_role.';

-- -----------------------------------------------------------------------------
-- Gravar: p_id null cria; senão edita. p_versao_esperada é a última versao_id que o painel
-- leu (null = trecho sem versão); diferente da atual: CONFLITO. Limites conferidos aqui
-- também (o painel e a Crystal já conferem): content de 20 a 4.000 caracteres, content_type
-- na lista, categoria em minúsculas, metadata objeto até 2.000 caracteres, nota até 300,
-- embedding com 1536 números. Devolve o trecho como o listar.
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_gravar(
  p_id bigint,
  p_content text,
  p_category text,
  p_content_type text,
  p_metadata jsonb,
  p_embedding text,
  p_autor_id text,
  p_autor_nome text,
  p_nota text,
  p_versao_esperada bigint
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_content text := btrim(coalesce(p_content, ''));
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_embedding vector(1536);
  v_id bigint;
  v_ultima bigint;
  v_versao bigint;
  v_em timestamptz;
  v_tipo_id text;
begin
  if char_length(v_content) < 20 or char_length(v_content) > 4000
     or p_content_type is null or p_content_type not in ('regra', 'exemplo', 'diretriz', 'estagio')
     or p_category is null or p_category !~ '^[a-z][a-z0-9_]{1,39}$'
     or jsonb_typeof(v_metadata) <> 'object' or char_length(v_metadata::text) > 2000
     or char_length(coalesce(p_nota, '')) > 300
     or char_length(coalesce(p_autor_id, '')) > 100 or char_length(coalesce(p_autor_nome, '')) > 120
     or p_embedding is null then
    raise exception 'INVALIDO';
  end if;
  begin
    v_embedding := p_embedding::vector(1536);
  exception when others then
    raise exception 'INVALIDO';
  end;

  -- Uma escrita na base por vez (criar, editar, apagar, restaurar).
  perform pg_advisory_xact_lock(hashtext('crystal_conhecimento'));

  if p_id is null then
    v_tipo_id := public.app_conhecimento_tipo_id();
    if v_tipo_id = '' then
      select coalesce(max(l.id), 0) + 1 into v_id from public.leticia_crystal_hybrid_search l;
      v_id := greatest(v_id, coalesce((select max(v.trecho_id) + 1 from public.crystal_conhecimento_versoes v), 1));
      insert into public.leticia_crystal_hybrid_search (id, content, category, content_type, metadata, embedding)
      values (v_id, v_content, p_category, p_content_type, v_metadata, v_embedding);
    else
      insert into public.leticia_crystal_hybrid_search (content, category, content_type, metadata, embedding)
      values (v_content, p_category, p_content_type, v_metadata, v_embedding)
      returning id into v_id;
    end if;
  else
    v_id := p_id;
    perform 1 from public.leticia_crystal_hybrid_search l where l.id = v_id for update;
    if not found then
      raise exception 'NAO_ENCONTRADO';
    end if;
    select max(v.versao_id) into v_ultima from public.crystal_conhecimento_versoes v where v.trecho_id = v_id;
    if v_ultima is distinct from p_versao_esperada then
      raise exception 'CONFLITO';
    end if;
    update public.leticia_crystal_hybrid_search
       set content = v_content, category = p_category, content_type = p_content_type, metadata = v_metadata, embedding = v_embedding
     where id = v_id;
  end if;

  if not public.app_conhecimento_fts_gerada() then
    update public.leticia_crystal_hybrid_search set fts = to_tsvector('portuguese', content) where id = v_id;
  end if;

  insert into public.crystal_conhecimento_versoes (trecho_id, acao, content, category, content_type, metadata, embedding, autor_id, autor_nome, nota)
  values (v_id, case when p_id is null then 'criar' else 'editar' end, v_content, p_category, p_content_type, v_metadata, v_embedding,
          p_autor_id, p_autor_nome, nullif(btrim(coalesce(p_nota, '')), ''))
  returning versao_id, em into v_versao, v_em;

  return jsonb_build_object(
    'id', v_id, 'content', v_content, 'category', p_category, 'content_type', p_content_type, 'metadata', v_metadata,
    'versao_id', v_versao, 'atualizado_em', v_em, 'autor_id', p_autor_id, 'autor_nome', p_autor_nome);
end;
$$;

comment on function public.app_conhecimento_gravar(bigint, text, text, text, jsonb, text, text, text, text, bigint) is
  'conhecimento-versoes 13/10/2026: cria (p_id null) ou edita um trecho, com versão no histórico e trava otimista. Só service_role.';

-- -----------------------------------------------------------------------------
-- Apagar: grava a versão `apagar` com texto E embedding (é de onde o restaurar tira) e só
-- então tira a linha da tabela viva. A busca (Edge Function e RPC) deixa de achar o trecho
-- sem mudar nada nela.
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_apagar(
  p_id bigint,
  p_autor_id text,
  p_autor_nome text,
  p_nota text,
  p_versao_esperada bigint
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v_ultima bigint;
  v_versao bigint;
begin
  if char_length(coalesce(p_nota, '')) > 300 or char_length(btrim(coalesce(p_nota, ''))) < 3 then
    raise exception 'INVALIDO';
  end if;
  perform pg_advisory_xact_lock(hashtext('crystal_conhecimento'));
  perform 1 from public.leticia_crystal_hybrid_search l where l.id = p_id for update;
  if not found then
    raise exception 'NAO_ENCONTRADO';
  end if;
  select max(v.versao_id) into v_ultima from public.crystal_conhecimento_versoes v where v.trecho_id = p_id;
  if v_ultima is distinct from p_versao_esperada then
    raise exception 'CONFLITO';
  end if;

  insert into public.crystal_conhecimento_versoes (trecho_id, acao, content, category, content_type, metadata, embedding, autor_id, autor_nome, nota)
  select l.id, 'apagar', l.content, l.category, l.content_type, coalesce(l.metadata, '{}'::jsonb), l.embedding, p_autor_id, p_autor_nome, btrim(p_nota)
    from public.leticia_crystal_hybrid_search l
   where l.id = p_id
  returning versao_id into v_versao;

  delete from public.leticia_crystal_hybrid_search where id = p_id;

  return jsonb_build_object('trecho_id', p_id, 'versao_id', v_versao);
end;
$$;

comment on function public.app_conhecimento_apagar(bigint, text, text, text, bigint) is
  'conhecimento-versoes 13/10/2026: tira o trecho da busca guardando texto e embedding no histórico. Só service_role.';

-- -----------------------------------------------------------------------------
-- Restaurar: a versão escolhida (de um trecho apagado) volta a ser a linha viva, com o MESMO
-- id. Trecho vivo com esse id: CONFLITO (para voltar um texto antigo de um trecho vivo, o
-- painel edita).
-- -----------------------------------------------------------------------------
create or replace function public.app_conhecimento_restaurar(
  p_versao_id bigint,
  p_autor_id text,
  p_autor_nome text,
  p_nota text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public, extensions
as $$
declare
  v public.crystal_conhecimento_versoes%rowtype;
  v_versao bigint;
  v_em timestamptz;
begin
  if char_length(coalesce(p_nota, '')) > 300 or char_length(btrim(coalesce(p_nota, ''))) < 3 then
    raise exception 'INVALIDO';
  end if;
  perform pg_advisory_xact_lock(hashtext('crystal_conhecimento'));
  select * into v from public.crystal_conhecimento_versoes x where x.versao_id = p_versao_id;
  if not found then
    raise exception 'NAO_ENCONTRADO';
  end if;
  if exists (select 1 from public.leticia_crystal_hybrid_search l where l.id = v.trecho_id) then
    raise exception 'CONFLITO';
  end if;

  if public.app_conhecimento_tipo_id() = 'a' then
    insert into public.leticia_crystal_hybrid_search (id, content, category, content_type, metadata, embedding)
    overriding system value
    values (v.trecho_id, v.content, v.category, v.content_type, v.metadata, v.embedding);
  else
    insert into public.leticia_crystal_hybrid_search (id, content, category, content_type, metadata, embedding)
    values (v.trecho_id, v.content, v.category, v.content_type, v.metadata, v.embedding);
  end if;

  if not public.app_conhecimento_fts_gerada() then
    update public.leticia_crystal_hybrid_search set fts = to_tsvector('portuguese', content) where id = v.trecho_id;
  end if;

  insert into public.crystal_conhecimento_versoes (trecho_id, acao, content, category, content_type, metadata, embedding, autor_id, autor_nome, nota)
  values (v.trecho_id, 'restaurar', v.content, v.category, v.content_type, v.metadata, v.embedding, p_autor_id, p_autor_nome, btrim(p_nota))
  returning versao_id, em into v_versao, v_em;

  return jsonb_build_object(
    'id', v.trecho_id, 'content', v.content, 'category', v.category, 'content_type', v.content_type, 'metadata', v.metadata,
    'versao_id', v_versao, 'atualizado_em', v_em, 'autor_id', p_autor_id, 'autor_nome', p_autor_nome);
end;
$$;

comment on function public.app_conhecimento_restaurar(bigint, text, text, text) is
  'conhecimento-versoes 13/10/2026: devolve à busca um trecho apagado, com o mesmo id. Só service_role.';

-- -----------------------------------------------------------------------------
-- Permissões: execute só para a service_role (a Crystal na VPS).
-- -----------------------------------------------------------------------------
revoke all on function public.app_conhecimento_listar() from public, anon, authenticated;
grant execute on function public.app_conhecimento_listar() to service_role;

revoke all on function public.app_conhecimento_historico(bigint) from public, anon, authenticated;
grant execute on function public.app_conhecimento_historico(bigint) to service_role;

revoke all on function public.app_conhecimento_gravar(bigint, text, text, text, jsonb, text, text, text, text, bigint) from public, anon, authenticated;
grant execute on function public.app_conhecimento_gravar(bigint, text, text, text, jsonb, text, text, text, text, bigint) to service_role;

revoke all on function public.app_conhecimento_apagar(bigint, text, text, text, bigint) from public, anon, authenticated;
grant execute on function public.app_conhecimento_apagar(bigint, text, text, text, bigint) to service_role;

revoke all on function public.app_conhecimento_restaurar(bigint, text, text, text) from public, anon, authenticated;
grant execute on function public.app_conhecimento_restaurar(bigint, text, text, text) to service_role;

-- A tabela viva da agência: com os grants padrão do Supabase, anon e authenticated escrevem
-- direto pelo PostgREST se o RLS estiver desligado (sem histórico e sem auditoria). A escrita
-- passa a ser só pelas funções acima; a leitura fica como está (a busca da agência pode usar).
revoke insert, update, delete, truncate on table public.leticia_crystal_hybrid_search from public, anon, authenticated;

-- Confere que anon e authenticated não escrevem na tabela viva por caminho nenhum (grant na
-- tabela, em coluna, por PUBLIC ou por papel herdado). Sobrou: PERMISSAO_ABERTA.
create or replace function public.app_conhecimento_conferir_tabela_viva()
returns void
language plpgsql
stable
set search_path = public, extensions
as $$
declare
  v_papel text;
begin
  foreach v_papel in array array['anon', 'authenticated'] loop
    if has_table_privilege(v_papel, 'public.leticia_crystal_hybrid_search', 'insert, update, delete, truncate')
       or has_any_column_privilege(v_papel, 'public.leticia_crystal_hybrid_search', 'insert, update') then
      raise exception 'PERMISSAO_ABERTA'
        using hint = v_papel || ' ainda escreve direto na leticia_crystal_hybrid_search (papel herdado ou grant que o revoke não alcança)';
    end if;
  end loop;
end;
$$;
revoke all on function public.app_conhecimento_conferir_tabela_viva() from public, anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Conferência no fim (uma linha): tudo precisa dar o esperado antes do commit.
--   vivos = semente (na primeira execução, as 27 linhas);
--   anon_executa e authenticated_executa = false; service_role_executa = true;
--   historico_aberto = false (ninguém além do dono lê a tabela de histórico);
--   tabela_viva_fechada = true (anon e authenticated não escrevem direto na tabela da agência).
-- -----------------------------------------------------------------------------
do $$
declare
  v_sem_versao int;
begin
  select count(*) into v_sem_versao
    from public.leticia_crystal_hybrid_search l
   where not exists (select 1 from public.crystal_conhecimento_versoes v where v.trecho_id = l.id);
  if v_sem_versao > 0 then
    raise exception 'SEMENTE_INCOMPLETA' using hint = v_sem_versao || ' trechos vivos sem versão';
  end if;
  if has_function_privilege('anon', 'public.app_conhecimento_gravar(bigint, text, text, text, jsonb, text, text, text, text, bigint)', 'execute')
     or has_function_privilege('authenticated', 'public.app_conhecimento_apagar(bigint, text, text, text, bigint)', 'execute')
     or has_table_privilege('anon', 'public.crystal_conhecimento_versoes', 'select')
     or has_table_privilege('authenticated', 'public.crystal_conhecimento_versoes', 'select') then
    raise exception 'PERMISSAO_ABERTA';
  end if;
  perform public.app_conhecimento_conferir_tabela_viva();
end;
$$;

select
  (select count(*) from public.leticia_crystal_hybrid_search)                                   as vivos,
  (select count(*) from public.crystal_conhecimento_versoes where acao = 'semente')              as semente,
  public.app_conhecimento_fts_gerada()                                                           as fts_gerada,
  public.app_conhecimento_tipo_id()                                                              as tipo_id,
  has_function_privilege('anon', 'public.app_conhecimento_listar()', 'execute')                  as anon_executa,
  has_function_privilege('authenticated', 'public.app_conhecimento_listar()', 'execute')         as authenticated_executa,
  has_function_privilege('service_role', 'public.app_conhecimento_listar()', 'execute')          as service_role_executa,
  has_table_privilege('service_role', 'public.crystal_conhecimento_versoes', 'select')           as historico_aberto,
  not (has_table_privilege('anon', 'public.leticia_crystal_hybrid_search', 'insert, update, delete, truncate')
       or has_table_privilege('authenticated', 'public.leticia_crystal_hybrid_search', 'insert, update, delete, truncate')) as tabela_viva_fechada;

notify pgrst, 'reload schema';

commit;
