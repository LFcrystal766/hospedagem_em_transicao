-- =============================================================================
-- Cancelamento de assinatura não desliga mais o cliente (26/11/2026, pedido do dono)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez.
--
-- O problema (achado em 26/11): "muita gente sendo desligada automaticamente do app".
--   - A Assiny manda `subscription_canceled` quando a assinatura ANUAL é cancelada. É o cliente que desliga
--     a renovação, sem pedir o dinheiro de volta.
--   - O `app_compra_evento` tratava isso como reembolso: gravava a linha bloqueada em crystal_compras, e o
--     n8n chamava /webhooks/reembolso, que desliga a conta no app.
--   - Como o bloqueio de crystal_compras vence a base antiga no login, o cliente perdia o acesso no meio do
--     ano que já pagou.
--   - De 15/10 a 25/11 foram 166 clientes da base antiga, todos com assinatura válida lá e sem nenhum
--     reembolso: anual R$ 297 (checkouts 01, 02 e 03) e recuperação R$ 247.
--
-- O que muda:
--   1. subscription_canceled / canceled_subscription: só ficam registrados em crystal_compras_eventos
--      (acao 'cancelamento'). Não bloqueiam a compra nem chamam o app.
--      - A resposta ao n8n é {"acao":"cancelamento"}. Nenhuma regra do nó "Destino" bate, então ele cai na
--        saída "nada" e só responde à Assiny.
--      - Evento repetido também devolve 'cancelamento', NUNCA 'repetido', porque 'repetido' vai para
--        "Desligar no app".
--   2. Reembolso e chargeback (refunded_purchase, chargeback, chargedback_purchase) continuam bloqueando
--      como antes.
--   3. Uma vez só, no fim do arquivo: desbloqueia as compras bloqueadas SÓ por cancelamento. Condições:
--      sem reembolso nem chargeback na mesma transação ou assinatura, e com assinatura válida na base antiga.
--      - O `bloqueado_em` volta a null e o status fica 'canceled', como histórico.
--      - Com o `bloqueado_em` null, a linha não pesa mais no app_verificar_login_email.
--
-- O que NÃO muda: a função de login, os produtos aceitos, a liberação por compra aprovada.
-- As contas que o app JÁ desligou voltam pela VPS (roteiro em crystal-em-casa/religar-cancelamentos.md).
--
-- Pendência (proposta ao dono): cortar o acesso no fim do período pago. Por exemplo, 1 ano depois da compra
-- no plano anual, quando a assinatura foi cancelada. Hoje, quem cancela a renovação continua com acesso.
--
-- Volta: rodar de novo app_compras.sql (a versão anterior da função). Os desbloqueios não voltam sozinhos:
-- a lista fica em crystal_compras_eventos (acao 'bloquear', evento de cancelamento).
-- =============================================================================

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
begin
  if p_evento is null or jsonb_typeof(p_evento) <> 'object' or v_evento = '' then
    raise exception 'EVENTO_INVALIDO' using hint = 'corpo da Assiny com "event"';
  end if;

  v_tipo := case
    when v_evento = any (array['approved_purchase', 'purchase_approved',
                               'subscription_renewed', 'renewed_subscription']) then 'liberar'
    when v_evento = any (array['refunded_purchase', 'chargeback', 'chargedback_purchase']) then 'bloquear'
    -- 26/11/2026: cancelar a renovação não é reembolso; só registra.
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

  -- Cancelamento: registrado (ou já registrado) e mais nada. Nunca 'repetido', que o n8n manda desligar.
  if v_tipo = 'cancelamento' then
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
     or (excluded.assinatura is not null and c.assinatura = excluded.assinatura);
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

-- Uma vez só (26/11/2026): desbloqueia quem foi bloqueado SÓ por cancelamento e tem assinatura válida na base.
update public.crystal_compras k
   set bloqueado_em = null,
       atualizado_em = now()
 where k.status = 'canceled'
   and k.bloqueado_em is not null
   and not exists (
     select 1 from public.crystal_compras_eventos e
      where e.evento in ('refunded_purchase', 'chargeback', 'chargedback_purchase')
        and ((k.transacao is not null and e.transacao = k.transacao)
          or (k.assinatura is not null and e.assinatura = k.assinatura)))
   and exists (
     select 1 from public.leticia_crystal_subscriptions s
       join public.leticia_crystal_customers c on c.id = s.customer_id
      where lower(btrim(c.email)) = k.email
        and s.status in ('active', 'pending')
        and (s.end_date is null or s.end_date > now()));
