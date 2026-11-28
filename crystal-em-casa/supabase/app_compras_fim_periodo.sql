-- =============================================================================
-- Cancelou a renovação: o acesso vai até o fim do período pago, salvo se renovar (26/11/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez, DEPOIS de
-- app_compras_cancelamento.sql. Pedido do dono (26/11): "pode fazer o corte no fim do período pago desde
-- que não tenha renovado". APLICADO em 26–27/11 (migrações compras_fim_do_periodo_pago e
-- compra_evento_assinatura_antiga_nao_pega_compra_nova). Este arquivo foi refeito em 28/11 a partir do que está
-- no banco (a primeira cópia se perdeu num reinício do contêiner antes do commit).
--
-- Como fica:
--   - Cancelamento (subscription_canceled / canceled_subscription):
--     - grava em crystal_compras `status = 'canceled'` e `acesso_ate` (o fim do período pago);
--     - NÃO bloqueia na hora nem chama o app (o n8n recebe 'cancelamento' e só responde à Assiny).
--   - Renovação ou compra nova ('liberar'): volta a `active` e zera `acesso_ate`. Quem renovou não é cortado.
--   - Login (app_verificar_login_email):
--     - até `acesso_ate`, entra normalmente;
--     - depois dele, a linha vem com `liberado = false`, igual a um reembolso.
--     - O app recusa o login e, na conferência diária da sessão, derruba quem estava dentro. Isso só vale
--       com o "Portão de lotes" LIGADO no painel (`op_rollout_gate = on`).
--   - Reembolso e chargeback: nada muda. Bloqueiam na hora e o app desliga a conta.
--
-- 27/11/2026: reembolso ou cancelamento de uma assinatura antiga não pega mais a compra NOVA e diferente do mesmo
-- e-mail.
--   - O caso: a assinatura "Botão Dourado" reembolsada em 24/11 bloqueou o Combo da Black comprado em 19/11.
--   - A regra: a assinatura só casa quando a compra atual da linha foi liberada por ela mesma.
--
-- Fim do período pago (função app_compras_fim_periodo). Vale a MAIOR destas datas, para nunca cortar antes da hora:
--   - última liberação (compra aprovada ou renovação) registrada para a assinatura ou transação + o período;
--   - `liberado_em` da compra + o período;
--   - base antiga: `end_date`, `next_billing_date`, `start_date` + 1 ano e a data do cadastro do cliente + 1 ano;
--   - período: 1 mês se a oferta diz MENSAL; 1 ano em qualquer outro caso (as ofertas de hoje são anuais).
--   - Sem nenhuma dessas datas: agora + o período.
--
-- Uma vez só, no fim: preenche `acesso_ate` nas compras canceladas que não estão bloqueadas (as 166
-- desbloqueadas em 26/11). Resultado em 27/11: de 24/02/2027 a 06/10/2027.
--
-- Volta: rodar de novo app_compras_cancelamento.sql e app_verificar_login_email.sql. A coluna `acesso_ate`
-- pode ficar: sem as funções novas, ninguém a lê.
-- =============================================================================

alter table public.crystal_compras add column if not exists acesso_ate timestamptz;
comment on column public.crystal_compras.acesso_ate is
  'Fim do período pago de uma assinatura cancelada (26/11/2026). Depois dele o login responde liberado = false, salvo renovação (que zera a coluna).';

create or replace function public.app_compras_fim_periodo(p_email text, p_oferta text, p_assinatura text, p_tx text)
returns timestamptz
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  with periodo as (
    select case when coalesce(p_oferta, '') ilike '%mensal%' then interval '1 month' else interval '1 year' end as p
  ),
  datas as (
    select max(e.recebido_em) + (select p from periodo) as d
      from public.crystal_compras_eventos e
     where e.acao = 'liberar'
       and ((p_assinatura is not null and e.assinatura = p_assinatura) or (p_tx is not null and e.transacao = p_tx))
    union all
    select k.liberado_em + (select p from periodo)
      from public.crystal_compras k where k.email = lower(btrim(p_email))
    union all
    select greatest(s.end_date, s.next_billing_date, s.start_date + interval '1 year', c.created_at + interval '1 year')
      from public.leticia_crystal_customers c
      left join public.leticia_crystal_subscriptions s on s.customer_id = c.id
     where lower(btrim(c.email)) = lower(btrim(p_email))
  )
  select coalesce(max(d), now() + (select p from periodo)) from datas;
$function$;

revoke all on function public.app_compras_fim_periodo(text, text, text, text) from public, anon, authenticated;
grant execute on function public.app_compras_fim_periodo(text, text, text, text) to service_role;

create or replace function public.app_compra_evento(p_evento jsonb)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_evento     text := lower(btrim(coalesce(p_evento->>'event', '')));
  v_email      text := lower(btrim(coalesce(p_evento#>>'{data,client,email}', '')));
  v_nome       text := nullif(btrim(coalesce(p_evento#>>'{data,client,full_name}', '')), '');
  v_digitos    text := regexp_replace(coalesce(p_evento#>>'{data,client,phone}', ''), '\D', '', 'g');
  -- login-cpf 11/11/2026: só a marca do CPF; o documento em claro não é gravado em lugar nenhum.
  v_cpf_marca  text := public.app_cpf_marca(p_evento#>>'{data,client,document}');
  v_tx         text := nullif(btrim(coalesce(p_evento#>>'{data,transaction,id}', '')), '');
  v_assinatura text := nullif(btrim(coalesce(p_evento#>>'{data,offer,subscription,id}', '')), '');
  v_produto_id text := nullif(btrim(coalesce(p_evento#>>'{data,offer,product,id}', '')), '');
  v_produto    text := nullif(btrim(coalesce(p_evento#>>'{data,offer,product,name}', '')), '');
  v_oferta     text := nullif(btrim(coalesce(p_evento#>>'{data,offer,name}', '')), '');
  v_telefone   text;
  v_tipo       text;
  v_status     text;
  v_chave      text;
  v_antes      text;
  v_linhas     int;
  v_fim        timestamptz;
begin
  if p_evento is null or jsonb_typeof(p_evento) <> 'object' or v_evento = '' then
    raise exception 'EVENTO_INVALIDO' using hint = 'corpo da Assiny com "event"';
  end if;

  v_tipo := case
    when v_evento = any (array['approved_purchase', 'purchase_approved',
                               'subscription_renewed', 'renewed_subscription']) then 'liberar'
    when v_evento = any (array['refunded_purchase', 'chargeback', 'chargedback_purchase']) then 'bloquear'
    -- 26/11/2026: cancelar a renovação não é reembolso; o acesso vai até o fim do período pago.
    when v_evento = any (array['canceled_subscription', 'subscription_canceled']) then 'cancelamento'
  end;
  if v_tipo is null then
    return json_build_object('acao', 'ignorado', 'motivo', 'evento', 'evento', v_evento, 'novo', false);
  end if;

  if length(v_email) > 200 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'EMAIL_INVALIDO' using hint = 'data.client.email ausente ou fora do formato';
  end if;
  v_telefone := case when length(v_digitos) between 10 and 15 then '+' || v_digitos end;

  if exists (select 1 from public.crystal_compras_produtos)
     and not exists (select 1 from public.crystal_compras_produtos p where p.produto_id = v_produto_id) then
    insert into public.crystal_compras_eventos (chave, evento, transacao, assinatura, produto_id, produto, acao)
    values (coalesce(v_tx, 'sem-transacao-' || md5(p_evento::text)) || ':' || v_evento,
            v_evento, v_tx, v_assinatura, v_produto_id, v_produto, 'ignorado_produto')
    on conflict (chave) do nothing;
    return json_build_object('acao', 'ignorado', 'motivo', 'produto', 'evento', v_evento, 'novo', false);
  end if;

  v_chave := coalesce(v_tx, 'sem-transacao-' || md5(p_evento::text)) || ':' || v_evento;
  insert into public.crystal_compras_eventos (chave, evento, transacao, assinatura, produto_id, produto, acao)
  values (v_chave, v_evento, v_tx, v_assinatura, v_produto_id, v_produto, v_tipo)
  on conflict (chave) do nothing;
  get diagnostics v_linhas = row_count;

  -- Cancelamento: guarda o fim do período pago e mais nada. Nunca 'repetido', que o n8n manda desligar.
  if v_tipo = 'cancelamento' then
    if v_linhas > 0 then
      v_fim := public.app_compras_fim_periodo(v_email, v_oferta, v_assinatura, v_tx);
      insert into public.crystal_compras as c
        (email, nome, telefone, status, produto_id, produto, oferta, transacao, assinatura, acesso_ate)
      values
        (v_email, v_nome, v_telefone, 'canceled', v_produto_id, v_produto, v_oferta, v_tx, v_assinatura, v_fim)
      on conflict (email) do update set
        status        = 'canceled',
        acesso_ate    = excluded.acesso_ate,
        atualizado_em = now()
      where c.status in ('active', 'canceled')
        and (c.transacao is null
          or c.transacao = excluded.transacao
          or (excluded.assinatura is not null and c.assinatura = excluded.assinatura
              -- 27/11: a compra atual da linha é OUTRA (ex.: combo avulso depois da assinatura): não mexe
              and not exists (select 1 from public.crystal_compras_eventos e2
                               where e2.transacao = c.transacao and e2.acao = 'liberar'
                                 and e2.assinatura is distinct from excluded.assinatura)));
    end if;
    return json_build_object('acao', 'cancelamento', 'evento', v_evento, 'novo', false);
  end if;

  if v_linhas = 0 then
    return json_build_object('acao', 'repetido', 'evento', v_evento, 'novo', false);
  end if;

  select c.status into v_antes from public.crystal_compras c where c.email = v_email for update;

  if v_tipo = 'liberar' then
    if v_tx is not null and exists (
      select 1 from public.crystal_compras_eventos e
       where e.transacao = v_tx and e.acao = 'bloquear'
    ) then
      update public.crystal_compras_eventos set acao = 'ignorado_ja_bloqueada' where chave = v_chave;
      return json_build_object('acao', 'ignorado', 'motivo', 'transacao_ja_bloqueada', 'evento', v_evento, 'novo', false);
    end if;

    insert into public.crystal_compras as c
      (email, nome, telefone, status, produto_id, produto, oferta, transacao, assinatura, liberado_em, cpf_marca)
    values
      (v_email, v_nome, v_telefone, 'active', v_produto_id, v_produto, v_oferta, v_tx, v_assinatura, now(), v_cpf_marca)
    on conflict (email) do update set
      nome          = coalesce(excluded.nome, c.nome),
      telefone      = coalesce(excluded.telefone, c.telefone),
      status        = 'active',
      produto_id    = coalesce(excluded.produto_id, c.produto_id),
      produto       = coalesce(excluded.produto, c.produto),
      oferta        = coalesce(excluded.oferta, c.oferta),
      transacao     = coalesce(excluded.transacao, c.transacao),
      assinatura    = coalesce(excluded.assinatura, c.assinatura),
      cpf_marca     = coalesce(excluded.cpf_marca, c.cpf_marca),
      liberado_em   = case when c.status = 'active' then c.liberado_em else now() end,
      acesso_ate    = null,   -- 26/11: renovou ou comprou de novo, sem corte
      atualizado_em = now();

    return json_build_object('acao', 'liberado', 'novo', v_antes is distinct from 'active',
                             'evento', v_evento);
  end if;

  v_status := case
    when v_evento like '%charge%' then 'chargeback'
    else 'refunded'
  end;

  insert into public.crystal_compras as c
    (email, nome, telefone, status, produto_id, produto, oferta, transacao, assinatura, bloqueado_em)
  values
    (v_email, v_nome, v_telefone, v_status, v_produto_id, v_produto, v_oferta, v_tx, v_assinatura, now())
  on conflict (email) do update set
    status        = excluded.status,
    bloqueado_em  = now(),
    atualizado_em = now()
  where c.transacao is null
     or c.transacao = excluded.transacao
     or (excluded.assinatura is not null and c.assinatura = excluded.assinatura
         -- 27/11 (caso do combo da Black): reembolso da assinatura antiga não bloqueia uma compra nova diferente
         and not exists (select 1 from public.crystal_compras_eventos e2
                          where e2.transacao = c.transacao and e2.acao = 'liberar'
                            and e2.assinatura is distinct from excluded.assinatura));
  get diagnostics v_linhas = row_count;

  if v_linhas = 0 then
    update public.crystal_compras_eventos set acao = 'ignorado_outra_compra' where chave = v_chave;
    return json_build_object('acao', 'ignorado', 'motivo', 'outra_compra', 'evento', v_evento, 'novo', false);
  end if;
  return json_build_object('acao', 'bloqueado', 'evento', v_evento, 'novo', false);
end;
$function$;

revoke all on function public.app_compra_evento(jsonb) from public, anon, authenticated;
grant execute on function public.app_compra_evento(jsonb) to service_role;

create or replace function public.app_verificar_login_email(p_email text)
returns table(name text, phone text, contact_id text, liberado boolean)
language sql
stable security definer
set search_path to 'public', 'pg_temp'
as $function$
  with pedido as (
    select lower(trim(coalesce(p_email, ''))) as e
  ),
  -- bloqueio do nosso fluxo (Assiny → n8n → crystal_compras): vence qualquer outra fonte.
  -- 26/11/2026: também a assinatura cancelada depois do fim do período pago (acesso_ate).
  bloqueio as (
    select
      exists (
        select 1 from public.crystal_compras k, pedido p
         where k.email = p.e
           and ((k.bloqueado_em is not null and k.status <> 'active')
             or (k.status = 'canceled' and k.acesso_ate is not null and k.acesso_ate <= now()))
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
       and (k.status = 'active'
         -- 26/11/2026: cancelou a renovação, mas o período pago ainda não acabou.
         or (k.status = 'canceled' and k.bloqueado_em is null and k.acesso_ate > now()))
  ),
  -- reembolsado (ou cancelado com o período pago vencido) que não está em lugar nenhum mais:
  -- ainda devolve a linha, só que bloqueada
  reembolsada as (
    select k.nome, k.telefone, k.id::text, false, 3, 0, false, k.criado_em::timestamptz, k.id::text
      from public.crystal_compras k
      cross join pedido p
     where length(p.e) >= 3
       and k.email = p.e
       and ((k.bloqueado_em is not null and k.status <> 'active')
         or (k.status = 'canceled' and k.acesso_ate is not null and k.acesso_ate <= now()))
  )
  select t.name, t.phone, t.contact_id, (t.liberado and not b.bloqueado) as liberado
    from (select * from antiga union all select * from nossa union all select * from reembolsada) t
    cross join bloqueio b
   order by t.fonte, t.origem, t.ativo desc, t.criado asc, t.desempate asc
   limit 1;
$function$;

-- Uma vez só (26/11/2026): o fim do período pago das compras canceladas que não estão bloqueadas.
update public.crystal_compras k
   set acesso_ate = public.app_compras_fim_periodo(k.email, k.oferta, k.assinatura, k.transacao),
       atualizado_em = now()
 where k.status = 'canceled'
   and k.bloqueado_em is null
   and k.acesso_ate is null;
