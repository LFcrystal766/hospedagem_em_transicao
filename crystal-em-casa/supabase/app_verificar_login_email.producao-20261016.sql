-- =============================================================================
-- CÓPIA FIEL da função de login como está NA PRODUÇÃO em 16/10/2026 (lida com pg_get_functiondef).
-- Ela é mais nova que a de app_compras.sql/app_verificar_login_email.sql deste repositório: em 11/10 ("fim dos
-- lotes") passou a liberar todo mundo com assinatura ativa ou pendente (is_in_rollout não conta mais), a ler também
-- leticia_crystal_subscriptions e a bloquear quem foi reembolsado pela nossa tabela. Não rodar sem necessidade:
-- serve de referência e de volta. Ver auditorias/2026-10-16/verificacao-login.md.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.app_verificar_login_email(p_email text)
 RETURNS TABLE(name text, phone text, contact_id text, liberado boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with pedido as (
    select lower(trim(coalesce(p_email, ''))) as e
  ),
  -- bloqueio do nosso fluxo (Assiny → n8n → crystal_compras): vence qualquer outra fonte
  bloqueio as (
    select
      exists (
        select 1 from public.crystal_compras k, pedido p
         where k.email = p.e and k.bloqueado_em is not null and k.status <> 'active'
      )
      and not exists (
        select 1 from public.crystal_compras k, pedido p
         where k.email = p.e and k.status = 'active'
      ) as bloqueado
  ),
  antiga as (
    select
      c.full_name::text as name,
      a.phone,
      c.id::text as contact_id,
      true as liberado,  -- compra válida = liberado (11/10: fim dos lotes)
      1 as origem,
      a.fonte,
      (a.st = 'active') as ativo,
      c.created_at::timestamptz as criado,
      c.id::text as desempate
    from public.leticia_crystal_customers c
    join lateral (
      select v.phone, v.st, v.fonte
        from (
          select
            case
              when length(regexp_replace(coalesce(x.phone_number, ''), '\D', '', 'g')) >= 10
                then '+' || regexp_replace(x.phone_number, '\D', '', 'g')
            end as phone,
            x.subscription_status as st,
            0 as fonte,
            x.access_updated_at as ts
          from public.leticia_crystal_active_accesses x
          where x.customer_id = c.id
            and x.subscription_status in ('active', 'pending')
          union all
          select
            case
              when length(g.d) between 10 and 11 and g.d not like '55%' then '+55' || g.d
              when length(g.d) >= 12 then '+' || g.d
            end,
            s.status,
            1,
            s.updated_at
          from public.leticia_crystal_subscriptions s
          cross join lateral (
            select regexp_replace(coalesce(c.phone_from_gateway, ''), '\D', '', 'g') as d
          ) g
          where s.customer_id = c.id
            and s.status in ('active', 'pending')
            and (s.end_date is null or s.end_date > now())
        ) v
       order by v.fonte, (v.st = 'active') desc, v.ts desc nulls last
       limit 1
    ) a on true
    cross join pedido p
    where length(p.e) >= 3
      and lower(trim(c.email)) = p.e
  ),
  nossa as (
    select k.nome, k.telefone, k.id::text, true, 2, 0, true, k.criado_em::timestamptz, k.id::text
      from public.crystal_compras k
      cross join pedido p
     where length(p.e) >= 3
       and k.email = p.e
       and k.status = 'active'
  ),
  -- reembolsado que não está em lugar nenhum mais: ainda devolve a linha, só que bloqueada
  reembolsada as (
    select k.nome, k.telefone, k.id::text, false, 3, 0, false, k.criado_em::timestamptz, k.id::text
      from public.crystal_compras k
      cross join pedido p
     where length(p.e) >= 3
       and k.email = p.e
       and k.bloqueado_em is not null
       and k.status <> 'active'
  )
  select t.name, t.phone, t.contact_id, (t.liberado and not b.bloqueado) as liberado
    from (select * from antiga union all select * from nossa union all select * from reembolsada) t
    cross join bloqueio b
   order by t.fonte, t.origem, t.ativo desc, t.criado asc, t.desempate asc
   limit 1;
$function$;
