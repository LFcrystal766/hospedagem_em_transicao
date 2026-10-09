-- =============================================================================
-- Telefone pela CHAVE país + DDD + 8 últimos dígitos (09/10/2026)
-- =============================================================================
-- Achado em 09/10: o WhatsApp guarda muitos números brasileiros SEM o nono dígito
-- (55 DD XXXXXXXX, 12 dígitos), e o cadastro da compra tem COM o 9 (55 DD 9XXXXXXXX, 13).
-- As funções comparavam o número inteiro e não achavam a conversa: um aluno com 746
-- mensagens no WhatsApp aparecia "sem histórico" no app.
--
-- app_tel_chave(texto): só dígitos; brasileiro com ou sem 55, com ou sem o 9 → '55' + DDD
-- + 8 últimos. Outro formato: os dígitos como vieram (igual a antes).
-- As funções abaixo passam a comparar pela chave dos dois lados (cadastro e WhatsApp):
--   app_historico_whatsapp, app_memoria_ler, app_whatsapp_estado, app_whatsapp_silenciar,
--   app_whatsapp_silenciar_telefones. Mesmas assinaturas, retornos e permissões.
-- Só leitura nas tabelas da agência, exceto o silêncio (a mesma escrita de antes, em
-- is_ai_enabled/updated_at), que passa a achar também os números sem o 9.
-- Desfazer: rodar de novo app_historico_whatsapp.sql, app_memoria_unica.sql (só a função
-- app_memoria_ler), app_whatsapp_silencio.sql e app_whatsapp_silenciar_telefones.sql.
-- =============================================================================

create or replace function public.app_tel_chave(p_telefone text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when x.d ~ '^55[1-9][0-9]9?[0-9]{8}$' then left(x.d, 4) || right(x.d, 8)
    when x.d ~ '^[1-9][0-9]9?[0-9]{8}$'   then '55' || left(x.d, 2) || right(x.d, 8)
    else x.d
  end
  from (select regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g') as d) x
$$;
revoke all on function public.app_tel_chave(text) from public;
revoke all on function public.app_tel_chave(text) from anon, authenticated;
grant execute on function public.app_tel_chave(text) to service_role;

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
      select distinct public.app_tel_chave(a.phone_number) as chave
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    ),
    fio as (
      select distinct l.thread_id::text as session_id
      from tel t
      join public.leticia_crystal_lead_management l
        on public.app_tel_chave(l.phone_number) = t.chave
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
  end if;

  return json_build_object(
    'whatsapp_fatos',        v_fatos,
    'whatsapp_preferencias', v_prefs,
    'app_resumo',            v_resumo,
    'app_atualizado_em',     v_quando
  );
end;
$$;

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
      select distinct public.app_tel_chave(a.phone_number) as chave
      from public.leticia_crystal_active_accesses a
      where a.customer_id = p_customer_id
        and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
    )
    select count(*), count(*) filter (where l.is_ai_enabled is false)
      into v_leads, v_silenciados
      from tel t
      join public.leticia_crystal_lead_management l
        on public.app_tel_chave(l.phone_number) = t.chave;
  end if;

  return json_build_object('leads', v_leads, 'silenciados', v_silenciados);
end;
$$;

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
  v_chaves   text[];
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

  select count(distinct t.customer_id), coalesce(array_agg(distinct t.chave), '{}')
    into v_clientes, v_chaves
    from (
      select a.customer_id,
             regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g') as digitos,
             public.app_tel_chave(a.phone_number) as chave
        from public.leticia_crystal_active_accesses a
       where a.customer_id = any(v_ids)
    ) t
   where length(t.digitos) >= 10;

  if v_clientes > 0 then
    with feito as (
      update public.leticia_crystal_lead_management l
         set is_ai_enabled = not p_silenciar,
             updated_at = now()
       where public.app_tel_chave(l.phone_number) = any(v_chaves)
         and coalesce(l.is_ai_enabled, true) = p_silenciar
      returning 1
    )
    select count(*) into v_leads from feito;
  end if;

  return json_build_object('clientes', v_clientes, 'leads', v_leads);
end;
$$;

create or replace function public.app_whatsapp_silenciar_telefones(
  p_telefones text[],
  p_silenciar boolean
)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_chaves  text[];
  v_achados int := 0;
  v_leads   int := 0;
begin
  if p_silenciar is null then
    raise exception 'SILENCIAR_INVALIDO' using hint = 'p_silenciar true (silenciar) ou false (religar)';
  end if;
  if cardinality(p_telefones) > 1000 then
    raise exception 'LISTA_INVALIDA' using hint = 'até 1000 telefones por chamada';
  end if;

  select coalesce(array_agg(distinct public.app_tel_chave(x.t)), '{}')
    into v_chaves
    from unnest(coalesce(p_telefones, '{}')) as x(t)
   where length(regexp_replace(coalesce(x.t, ''), '\D', '', 'g')) >= 10;

  if cardinality(v_chaves) = 0 then
    raise exception 'LISTA_INVALIDA' using hint = 'nenhum telefone com 10 ou mais dígitos';
  end if;

  select count(*) into v_achados
    from public.leticia_crystal_lead_management l
   where public.app_tel_chave(l.phone_number) = any(v_chaves);

  with feito as (
    update public.leticia_crystal_lead_management l
       set is_ai_enabled = not p_silenciar,
           updated_at = now()
     where public.app_tel_chave(l.phone_number) = any(v_chaves)
       and coalesce(l.is_ai_enabled, true) = p_silenciar
    returning 1
  )
  select count(*) into v_leads from feito;

  return json_build_object('telefones', cardinality(v_chaves), 'achados', v_achados, 'leads', v_leads);
end;
$$;

notify pgrst, 'reload schema';
