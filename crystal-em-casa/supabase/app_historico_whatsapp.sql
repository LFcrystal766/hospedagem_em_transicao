-- =============================================================================
-- Memória de chegada: histórico do WhatsApp para a Crystal do app (08/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez (uma
-- transação só). Independente dos outros app_*.sql: não reusa nada deles.
--
-- Quem chama: SÓ o servidor do app (apps/api, na VPS), pela API REST do Supabase
-- (POST /rest/v1/rpc/app_historico_whatsapp) com a chave service_role, que fica só
-- na VPS. A chave anon (pública) nunca executa: a função é `security definer`, com
-- execute revogado de public/anon/authenticated e concedido só a service_role.
-- Contrato do lado do app: crystal-web-chat apps/api/src/services/memoria-chegada.ts,
-- pelo mesmo cliente Supabase RPC de base-alunos/lotes. Nome da função em env,
-- opcional: SUPABASE_HISTORICO_WHATSAPP_RPC (padrão app_historico_whatsapp).
--
-- Para quê: a Crystal do app nasce sem memória; o aluno que conversou meses com a
-- Crystal do WhatsApp (da agência, histórico neste Supabase) chega e ela não lembra
-- de nada. O app chama esta função UMA vez por aluno (primeiro login ou primeira
-- mensagem), leva as últimas mensagens para a memória da nossa Crystal e gera o
-- resumo. Depois disso o app é a fonte; nada volta para o WhatsApp.
--
-- O que sai: data, quem falou ('aluno' | 'crystal') e o TEXTO da mensagem. É a única
-- função app_* que devolve texto de conversa; por isso só a service_role executa, e o
-- app nunca grava esse texto em log, auditoria nem resposta de equipe (só contagens).
--
-- Caminho (o mesmo de app_equipe_atividade, em app_equipe_lotes.sql, repetido aqui
-- porque ela é interna, sem grant, e filtra status): cliente →
-- leticia_crystal_active_accesses em QUALQUER status (o que importa é o telefone; um
-- acesso cancelado ainda aponta a conversa certa) → dígitos do WhatsApp (10+) =
-- dígitos de leticia_crystal_lead_management.phone_number → thread_id::text =
-- session_id::text do histórico. Dedupe: dois acessos com o mesmo número, ou dois
-- leads com a mesma thread, não repetem mensagem. Dois leads do mesmo número com
-- threads diferentes somam as duas conversas.
--
-- Filtros: só message->>'type' in ('human', 'ai'); 'system', 'tool' e o resto caem.
-- texto = coalesce(message->>'content', message->'data'->>'content'), os dois formatos
-- que o LangChain grava; vazio ou nulo cai. created_at nulo cai (o app exige data).
-- Devolve só as ÚLTIMAS p_limite mensagens (1..500, padrão 200), do mais antigo para
-- o mais novo, prontas para entrar na memória na ordem em que aconteceram.
--
-- Erros: `raise exception` com MENSAGEM = código fixo que o app traduz
-- (LIMITE_INVALIDO), `hint` com a faixa. Errcode padrão P0001 (PostgREST responde 400).
-- Cliente desconhecido, sem telefone, sem lead ou sem mensagem NÃO é erro: zero linhas
-- (o app marca "importado com 0" e não tenta de novo).
--
-- Nenhuma mudança de esquema. Só leitura (stable). Avisar a agência (Tuan) que esta
-- função lê leticia_crystal_chat_histories.
--
-- Suposições sobre o esquema (as mesmas de app_equipe_lotes.sql, 05-07/10; confirmar
-- com o Tuan o formato do `message`):
--   visão public.leticia_crystal_active_accesses a: customer_id uuid, phone_number
--     text, subscription_status text (não filtrado aqui).
--   public.leticia_crystal_lead_management l: thread_id uuid, phone_number text.
--   public.leticia_crystal_chat_histories h: session_id (texto ou uuid; comparado
--     como texto), message jsonb (type 'human' | 'ai'; content direto ou em
--     data.content), created_at timestamptz.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Últimas p_limite mensagens do WhatsApp de um cliente, do mais antigo para o mais
-- novo. Em caso de created_at igual, a ordem entre essas mensagens é indefinida.
-- -----------------------------------------------------------------------------
drop function if exists public.app_historico_whatsapp(uuid, int);
create or replace function public.app_historico_whatsapp(
  p_customer_id uuid,
  p_limite int default 200
)
returns table (quando timestamptz, de text, texto text)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if p_limite is null or p_limite < 1 or p_limite > 500 then
    raise exception 'LIMITE_INVALIDO' using hint = 'p_limite entre 1 e 500';
  end if;
  if p_customer_id is null then
    return;
  end if;

  return query
    with tel as (
      select distinct
        regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    ),
    fio as (
      select distinct l.thread_id::text as session_id
      from tel t
      join public.leticia_crystal_lead_management l
        on regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = t.digitos
      where l.thread_id is not null
    ),
    msg as (
      select
        h.created_at as quando,
        case h.message->>'type'
          when 'human' then 'aluno'
          when 'ai'    then 'crystal'
        end as de,
        nullif(btrim(coalesce(h.message->>'content', h.message->'data'->>'content')), '') as texto
      from fio f
      join public.leticia_crystal_chat_histories h
        on h.session_id::text = f.session_id
      where h.message->>'type' in ('human', 'ai')
        and h.created_at is not null
    ),
    ultimas as (
      select m.quando, m.de, m.texto
      from msg m
      where m.texto is not null
      order by m.quando desc
      limit p_limite
    )
    select u.quando, u.de, u.texto
    from ultimas u
    order by u.quando asc;
end;
$$;

-- -----------------------------------------------------------------------------
-- Permissões: só a service_role (o servidor) executa.
-- -----------------------------------------------------------------------------
revoke all on function public.app_historico_whatsapp(uuid, int) from public;
revoke all on function public.app_historico_whatsapp(uuid, int) from anon, authenticated;
grant execute on function public.app_historico_whatsapp(uuid, int) to service_role;

-- Se o app der 404 na função logo depois de criar, o cache do PostgREST não viu ainda:
--   notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens, nenhum texto de aluno na tela):
--   a função existe e só service_role executa
--     select routine_name, grantee from information_schema.routine_privileges
--      where routine_schema = 'public' and routine_name = 'app_historico_whatsapp' order by 2;
--   um aluno com conversa devolve linhas, o mais antigo primeiro (só números e datas)
--     select count(*), min(quando), max(quando), count(*) filter (where de = 'aluno')
--       from public.app_historico_whatsapp('<uuid de um cliente>', 200);
--   quem não tem telefone ou lead devolve zero linhas, sem erro
--     select count(*) from public.app_historico_whatsapp(gen_random_uuid(), 200);
--   validação recusa (espera-se LIMITE_INVALIDO)
--     select count(*) from public.app_historico_whatsapp(gen_random_uuid(), 0);
--   a anon NÃO pode executar (tem que dar "permission denied")
--     set role anon; select count(*) from public.app_historico_whatsapp(gen_random_uuid(), 10); reset role;
--
-- Se ficar lenta (histórico grande), o índice sugerido em app_equipe_lotes.sql não ajuda
-- aqui; o que ajuda é um em session_id, e é tabela da agência, combinar antes:
--   create index concurrently if not exists leticia_crystal_chat_histories_session_id
--     on public.leticia_crystal_chat_histories (session_id);
