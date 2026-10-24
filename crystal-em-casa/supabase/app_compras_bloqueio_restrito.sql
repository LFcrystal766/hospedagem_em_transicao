-- Segurança 24/10/2026 (INT-06 da revisão): bloqueio por evento da Assiny só com compra conhecida. Substitui a função
-- app_compra_evento de app_compras.sql (o resto do arquivo não muda). Rodar inteiro no SQL Editor; idempotente.
-- Volta: rodar de novo o bloco "create or replace function public.app_compra_evento" de app_compras.sql.
-- Efeito: reembolso/cancelamento da Assiny para e-mail sem compra conhecida (nossa tabela ou base da agência com o
-- mesmo id de transação/assinatura) vira "ignorado_sem_compra_conhecida" em crystal_compras_eventos, em vez de criar
-- um pré-bloqueio para qualquer e-mail. A liberação continua igual.

create or replace function public.app_compra_evento(p_evento jsonb)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_evento     text := lower(btrim(coalesce(p_evento->>'event', '')));
  v_email      text := lower(btrim(coalesce(p_evento#>>'{data,client,email}', '')));
  v_nome       text := nullif(btrim(coalesce(p_evento#>>'{data,client,full_name}', '')), '');
  v_digitos    text := regexp_replace(coalesce(p_evento#>>'{data,client,phone}', ''), '\D', '', 'g');
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
    when v_evento = any (array['refunded_purchase', 'chargeback', 'chargedback_purchase',
                               'canceled_subscription', 'subscription_canceled']) then 'bloquear'
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
      (email, nome, telefone, status, produto_id, produto, oferta, transacao, assinatura, liberado_em)
    values
      (v_email, v_nome, v_telefone, 'active', v_produto_id, v_produto, v_oferta, v_tx, v_assinatura, now())
    on conflict (email) do update set
      nome          = coalesce(excluded.nome, c.nome),
      telefone      = coalesce(excluded.telefone, c.telefone),
      status        = 'active',
      produto_id    = coalesce(excluded.produto_id, c.produto_id),
      produto       = coalesce(excluded.produto, c.produto),
      oferta        = coalesce(excluded.oferta, c.oferta),
      transacao     = coalesce(excluded.transacao, c.transacao),
      assinatura    = coalesce(excluded.assinatura, c.assinatura),
      liberado_em   = case when c.status = 'active' then c.liberado_em else now() end,
      atualizado_em = now();

    return json_build_object('acao', 'liberado', 'novo', v_antes is distinct from 'active',
                             'evento', v_evento);
  end if;

  v_status := case
    when v_evento like '%charge%' then 'chargeback'
    when v_evento like '%cancel%' then 'canceled'
    else 'refunded'
  end;

  -- 24/10 (revisão de segurança, INT-06): um bloqueio só vale se a transação ou a assinatura do evento bate com uma
  -- compra conhecida desse e-mail: na nossa tabela (liberada pelo nosso n8n) ou na base da agência (compra de antes
  -- de 09/10). Um evento forjado com o token do n8n, sem o id real da compra da vítima, não bloqueia ninguém.
  -- Compra liberada à mão (transacao 'manual-…') não é derrubada por evento da Assiny: é decisão do dono.
  if not exists (
       select 1 from public.crystal_compras c
        where c.email = v_email
          and ((v_tx is not null and c.transacao = v_tx)
            or (v_assinatura is not null and c.assinatura = v_assinatura))
     )
     and not exists (
       select 1 from public.leticia_crystal_subscriptions s
        where lower(btrim(coalesce(s.raw_data#>>'{data,client,email}', ''))) = v_email
          and ((v_tx is not null and s.raw_data#>>'{data,transaction,id}' = v_tx)
            or (v_assinatura is not null and (s.raw_data#>>'{data,offer,subscription,id}' = v_assinatura
                                             or s.external_id::text = v_assinatura)))
     ) then
    update public.crystal_compras_eventos set acao = 'ignorado_sem_compra_conhecida' where chave = v_chave;
    return json_build_object('acao', 'ignorado', 'motivo', 'sem_compra_conhecida', 'evento', v_evento, 'novo', false);
  end if;

  insert into public.crystal_compras as c
    (email, nome, telefone, status, produto_id, produto, oferta, transacao, assinatura, bloqueado_em)
  values
    (v_email, v_nome, v_telefone, v_status, v_produto_id, v_produto, v_oferta, v_tx, v_assinatura, now())
  on conflict (email) do update set
    status        = excluded.status,
    bloqueado_em  = now(),
    atualizado_em = now()
  where c.transacao = excluded.transacao
     or (excluded.assinatura is not null and c.assinatura = excluded.assinatura);
  get diagnostics v_linhas = row_count;

  if v_linhas = 0 then
    update public.crystal_compras_eventos set acao = 'ignorado_outra_compra' where chave = v_chave;
    return json_build_object('acao', 'ignorado', 'motivo', 'outra_compra', 'evento', v_evento, 'novo', false);
  end if;
  return json_build_object('acao', 'bloqueado', 'evento', v_evento, 'novo', false);
end;
$$;

revoke all on function public.app_compra_evento(jsonb) from public, anon, authenticated;
grant execute on function public.app_compra_evento(jsonb) to service_role;

-- conferência: a função existe, é security definer e só service_role executa
select p.prosecdef as security_definer,
       has_function_privilege('anon', p.oid, 'execute') as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       has_function_privilege('service_role', p.oid, 'execute') as service_role
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname = 'app_compra_evento';
