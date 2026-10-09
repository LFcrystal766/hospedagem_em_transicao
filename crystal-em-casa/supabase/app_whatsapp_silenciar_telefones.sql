-- =============================================================================
-- Silêncio no WhatsApp por TELEFONE (09/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez. Irmã de
-- app_whatsapp_silenciar (app_whatsapp_silencio.sql), que recebe customer_ids: esta recebe
-- telefones, para silenciar quem foi marcado com uma etiqueta no LendChat e recebeu a
-- comunicação de mudança para o app, tenha ou não conta no app ainda.
--
-- Quem chama: crystal-em-casa/silenciar-por-etiqueta.py, na VPS, com a service_role que
-- fica só lá (/root/crystal/app/.externos). Execute só para service_role.
--
-- O que muda: SÓ leticia_crystal_lead_management.is_ai_enabled (e updated_at = now()),
-- nos leads cujo telefone (só dígitos) está na lista. A Crystal do WhatsApp não responde a
-- lead com is_ai_enabled = false (lê a cada mensagem). Nenhuma linha criada ou apagada.
-- Reversível: p_silenciar = false religa. Rodar duas vezes não muda nada na segunda.
--
-- Erros: SILENCIAR_INVALIDO (p_silenciar nulo), LISTA_INVALIDA (nenhum telefone com 10+
-- dígitos, ou mais de 1000 itens). Sai só contagem: telefones válidos, leads achados e
-- leads que mudaram. Nunca telefone.
--
-- Religar todo mundo que esta função silenciou não tem atalho: rodar o script de novo com
-- "religar" e a mesma etiqueta.
-- =============================================================================

do $$
begin
  if not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'leticia_crystal_lead_management'
       and column_name = 'is_ai_enabled' and data_type = 'boolean'
  ) or not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'leticia_crystal_lead_management'
       and column_name = 'updated_at'
  ) then
    raise exception 'ESQUEMA_DIFERENTE'
      using hint = 'leticia_crystal_lead_management.is_ai_enabled (boolean) ou updated_at não encontrada';
  end if;
end;
$$;

drop function if exists public.app_whatsapp_silenciar_telefones(text[], boolean);
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
  v_digitos text[];
  v_achados int := 0;
  v_leads   int := 0;
begin
  if p_silenciar is null then
    raise exception 'SILENCIAR_INVALIDO' using hint = 'p_silenciar true (silenciar) ou false (religar)';
  end if;
  if cardinality(p_telefones) > 1000 then
    raise exception 'LISTA_INVALIDA' using hint = 'até 1000 telefones por chamada';
  end if;

  select coalesce(array_agg(distinct x.d), '{}')
    into v_digitos
    from (
      select regexp_replace(coalesce(t, ''), '\D', '', 'g') as d
        from unnest(coalesce(p_telefones, '{}')) as u(t)
    ) x
   where length(x.d) >= 10;

  if cardinality(v_digitos) = 0 then
    raise exception 'LISTA_INVALIDA' using hint = 'nenhum telefone com 10 ou mais dígitos';
  end if;

  select count(*) into v_achados
    from public.leticia_crystal_lead_management l
   where regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = any(v_digitos);

  with feito as (
    update public.leticia_crystal_lead_management l
       set is_ai_enabled = not p_silenciar,
           updated_at = now()
     where regexp_replace(coalesce(l.phone_number, ''), '\D', '', 'g') = any(v_digitos)
       and coalesce(l.is_ai_enabled, true) = p_silenciar
    returning 1
  )
  select count(*) into v_leads from feito;

  return json_build_object('telefones', cardinality(v_digitos), 'achados', v_achados, 'leads', v_leads);
end;
$$;

revoke all on function public.app_whatsapp_silenciar_telefones(text[], boolean) from public;
revoke all on function public.app_whatsapp_silenciar_telefones(text[], boolean) from anon, authenticated;
grant execute on function public.app_whatsapp_silenciar_telefones(text[], boolean) to service_role;

notify pgrst, 'reload schema';
