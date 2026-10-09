-- =============================================================================
-- Histórico do WhatsApp também do ARQUIVO (09/10/2026)
-- =============================================================================
-- Achado em 09/10: o sistema da agência move mensagens antigas de
-- leticia_crystal_chat_histories para leticia_crystal_chat_histories_archive (~4,7 milhões
-- de linhas, jan a out/2026). app_historico_whatsapp só lia a tabela atual: para 1.415
-- alunos, parte das 3 semanas que o app importa (contadas da ÚLTIMA mensagem do aluno) já
-- estava no arquivo e ficava de fora.
--
-- Esta versão lê as duas tabelas, só leitura, com o telefone pela chave (app_tel_chave,
-- app_telefone_chave.sql) e devolve as últimas p_limite mensagens da pessoa, sem repetir
-- (a mesma mensagem nas duas tabelas conta uma vez). Mesma assinatura, retorno e permissões.
-- Cada tabela é lida pelo índice da sessão, no máximo p_limite linhas por conversa.
-- Desfazer: rodar app_telefone_chave.sql de novo (volta a versão só da tabela atual).
-- =============================================================================

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
    bruto as (
      select r.created_at, r.message
      from fio f
      cross join lateral (
        select h.created_at, h.message
          from public.leticia_crystal_chat_histories h
         where h.session_id::text = f.session_id
           and h.created_at is not null
         order by h.created_at desc
         limit p_limite
      ) r
      union all
      select r.created_at, r.message
      from fio f
      cross join lateral (
        select x.created_at, x.message
          from public.leticia_crystal_chat_histories_archive x
         where x.session_id = f.session_id
           and x.created_at is not null
         order by x.id desc
         limit p_limite
      ) r
    ),
    msg as (
      select distinct
        b.created_at as quando,
        case b.message->>'type'
          when 'human' then 'aluno'
          when 'ai'    then 'crystal'
        end as de,
        nullif(btrim(coalesce(b.message->>'content', b.message->'data'->>'content')), '') as texto
      from bruto b
      where b.message->>'type' in ('human', 'ai')
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

notify pgrst, 'reload schema';
