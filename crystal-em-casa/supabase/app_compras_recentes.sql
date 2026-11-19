-- =============================================================================
-- app_compras_recentes (19/11/2026): compras ativas liberadas numa janela de tempo, para a mensagem
-- pós-compra do app ("2 horas depois da compra, a Crystal manda o formulário").
--
-- Uso pelo app (service_role):
--   select * from app_compras_recentes(p_desde := now() - interval '7 days', p_ate := now() - interval '2 hours');
-- Devolve: contact_id (o id da linha de crystal_compras, o mesmo que o login devolve como contact_id para quem só
-- existe ali), email (minúsculo, para casar com a conta do app de quem também está na base antiga) e comprado_em
-- (liberado_em; sem ele, criado_em). Só status 'active'. No máximo 2000 linhas, das mais antigas para as mais novas.
--
-- Só leitura; security definer com search_path fixo; só service_role executa.
-- Volta: drop function if exists public.app_compras_recentes(timestamptz, timestamptz);
-- =============================================================================
create or replace function public.app_compras_recentes(p_desde timestamptz, p_ate timestamptz)
returns table (contact_id text, email text, comprado_em timestamptz)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select k.id::text, lower(btrim(k.email)), coalesce(k.liberado_em, k.criado_em)
    from public.crystal_compras k
   where k.status = 'active'
     and p_desde is not null and p_ate is not null
     and coalesce(k.liberado_em, k.criado_em) >= p_desde
     and coalesce(k.liberado_em, k.criado_em) < p_ate
   order by 3, 1
   limit 2000;
$function$;

revoke all on function public.app_compras_recentes(timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.app_compras_recentes(timestamptz, timestamptz) to service_role;
