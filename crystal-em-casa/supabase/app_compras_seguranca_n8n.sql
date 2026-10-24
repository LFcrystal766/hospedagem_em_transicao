-- =============================================================================
-- Segurança 24/10/2026 · fluxo do n8n (INT-06, INT-07, INT-09, INT-16): app_compra_evento v3,
-- app_compras_conciliacao e o papel n8n_compras
-- =============================================================================
-- Substitui a função app_compra_evento de app_compras.sql E de app_compras_bloqueio_restrito.sql (este arquivo contém
-- tudo o que o bloqueio restrito faz; não precisa rodar os dois). Rodar inteiro no SQL Editor do projeto "Crystal AI";
-- idempotente. Nenhuma tabela muda. Volta: rodar de novo o bloco "create or replace function
-- public.app_compra_evento" de app_compras.sql (ou de app_compras_bloqueio_restrito.sql); as funções e o papel novos
-- podem ficar.
--
-- O que muda em app_compra_evento:
--  1. Bloqueio só com compra conhecida (o mesmo de app_compras_bloqueio_restrito.sql): reembolso, chargeback ou
--     cancelamento para e-mail cuja transação/assinatura não casa com uma compra nossa nem com uma da agência vira
--     'ignorado_sem_compra_conhecida'. Um aviso forjado com o token do n8n, sem o id real da compra, não bloqueia ninguém.
--  2. Evento repetido devolve também "anterior" (liberar | bloquear | ignorado_*): o n8n repassa de novo um bloqueio à
--     API do app quando a Assiny reenvia o aviso depois de uma falha nossa (INT-09). A API ignora o que já processou.
--  3. Evento de nome desconhecido fica registrado em crystal_compras_eventos com acao = 'ignorado_evento' (nome do
--     evento, transação e produto; nenhum dado pessoal), em vez de sumir (INT-16).
--  4. Limites de tamanho: transação, assinatura e ids de produto/oferta até 80 caracteres (acima disso o evento é
--     recusado com EVENTO_INVALIDO); nome, produto e oferta cortados em 120; telefone só com 10 a 15 dígitos.
--  5. 'charged_back' entra na lista de bloqueio: é o nome técnico do chargeback na documentação da Assiny
--     (docs.assiny.com/webhooks/payloads/chargeback). Os nomes antigos continuam aceitos.
--
-- Funções e papel novos:
--  - app_compras_conciliacao(p_horas, p_max_liberados, p_max_bloqueados): só leitura, para a rotina do n8n duas vezes
--    por dia (crystal-em-casa/n8n/compra-assiny-conciliacao.json): contagens por ação e evento na janela, eventos
--    desconhecidos, alerta por volume e a lista dos bloqueios da janela (e-mail, transação, status, evento, data), que
--    o n8n reenvia à API do app (/webhooks/reembolso); a API dispensa o que já fez e corta o que ficou para trás.
--  - Papel n8n_compras (INT-07): só executa as duas funções acima; não lê nem escreve tabela nenhuma. O n8n entra na
--    API do Supabase com um JWT desse papel (claim "role": "n8n_compras") em vez da service_role; ver
--    compra-assiny-credenciais.py --supabase-papel. Se o projeto não tiver o papel authenticator (Postgres local de
--    teste), o grant para ele é pulado.
-- =============================================================================

do $$
begin
  if to_regclass('public.crystal_compras') is null or to_regclass('public.crystal_compras_eventos') is null
     or to_regclass('public.crystal_compras_produtos') is null then
    raise exception 'FALTA_BASE' using hint = 'rodar app_compras.sql antes';
  end if;
  if to_regclass('public.leticia_crystal_subscriptions') is not null and not exists (
       select 1 from information_schema.columns
        where table_schema = 'public' and table_name = 'leticia_crystal_subscriptions' and column_name = 'raw_data') then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'leticia_crystal_subscriptions sem raw_data; conferir antes de rodar';
  end if;
end;
$$;

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
  v_nome       text := nullif(left(btrim(coalesce(p_evento#>>'{data,client,full_name}', '')), 120), '');
  v_digitos    text := regexp_replace(coalesce(p_evento#>>'{data,client,phone}', ''), '\D', '', 'g');
  v_tx         text := nullif(btrim(coalesce(p_evento#>>'{data,transaction,id}', '')), '');
  v_assinatura text := nullif(btrim(coalesce(p_evento#>>'{data,offer,subscription,id}', '')), '');
  v_produto_id text := nullif(btrim(coalesce(p_evento#>>'{data,offer,product,id}', '')), '');
  v_produto    text := nullif(left(btrim(coalesce(p_evento#>>'{data,offer,product,name}', '')), 120), '');
  v_oferta     text := nullif(left(btrim(coalesce(p_evento#>>'{data,offer,name}', '')), 120), '');
  v_telefone   text;
  v_tipo       text;
  v_status     text;
  v_chave      text;
  v_antes      text;
  v_anterior   text;
  v_linhas     int;
begin
  if p_evento is null or jsonb_typeof(p_evento) <> 'object' or v_evento = '' or length(v_evento) > 64
     or v_evento !~ '^[a-z0-9_.:-]+$' then
    raise exception 'EVENTO_INVALIDO' using hint = 'corpo da Assiny com "event" (minúsculas, até 64 caracteres)';
  end if;
  if length(v_tx) > 80 or length(v_assinatura) > 80 or length(v_produto_id) > 80
     or v_tx !~ '^[A-Za-z0-9][A-Za-z0-9._:-]*$' then
    raise exception 'EVENTO_INVALIDO' using hint = 'transação, assinatura ou produto fora do formato (até 80 caracteres)';
  end if;

  v_tipo := case
    when v_evento = any (array['approved_purchase', 'purchase_approved',
                               'subscription_renewed', 'renewed_subscription']) then 'liberar'
    when v_evento = any (array['refunded_purchase', 'chargeback', 'charged_back', 'chargedback_purchase',
                               'canceled_subscription', 'subscription_canceled']) then 'bloquear'
  end;
  v_chave := coalesce(v_tx, 'sem-transacao-' || md5(p_evento::text)) || ':' || v_evento;

  if v_tipo is null then
    -- INT-16: nome de evento que não conhecemos fica registrado (sem dado pessoal), para a conciliação mostrar.
    insert into public.crystal_compras_eventos (chave, evento, transacao, assinatura, produto_id, produto, acao)
    values (v_chave, v_evento, v_tx, v_assinatura, v_produto_id, v_produto, 'ignorado_evento')
    on conflict (chave) do nothing;
    return json_build_object('acao', 'ignorado', 'motivo', 'evento', 'evento', v_evento, 'novo', false);
  end if;

  if length(v_email) > 200 or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'EMAIL_INVALIDO' using hint = 'data.client.email ausente ou fora do formato';
  end if;
  v_telefone := case when length(v_digitos) between 10 and 15 then '+' || v_digitos end;

  if exists (select 1 from public.crystal_compras_produtos)
     and not exists (select 1 from public.crystal_compras_produtos p where p.produto_id = v_produto_id) then
    insert into public.crystal_compras_eventos (chave, evento, transacao, assinatura, produto_id, produto, acao)
    values (v_chave, v_evento, v_tx, v_assinatura, v_produto_id, v_produto, 'ignorado_produto')
    on conflict (chave) do nothing;
    return json_build_object('acao', 'ignorado', 'motivo', 'produto', 'evento', v_evento, 'novo', false);
  end if;

  insert into public.crystal_compras_eventos (chave, evento, transacao, assinatura, produto_id, produto, acao)
  values (v_chave, v_evento, v_tx, v_assinatura, v_produto_id, v_produto, v_tipo)
  on conflict (chave) do nothing;
  get diagnostics v_linhas = row_count;
  if v_linhas = 0 then
    -- INT-09: o reenvio diz o que o original fez, para o n8n repassar de novo um bloqueio que não chegou à API.
    select e.acao into v_anterior from public.crystal_compras_eventos e where e.chave = v_chave;
    return json_build_object('acao', 'repetido', 'anterior', v_anterior, 'evento', v_evento, 'novo', false);
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

  -- INT-06: um bloqueio só vale se a transação ou a assinatura do evento bate com uma compra conhecida desse e-mail:
  -- na nossa tabela (liberada pelo nosso n8n) ou na base da agência (compra de antes de 09/10). Um evento forjado com
  -- o token do n8n, sem o id real da compra da vítima, não bloqueia ninguém. Compra liberada à mão (transacao
  -- 'manual-…') não é derrubada por evento da Assiny: é decisão do dono.
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

comment on function public.app_compra_evento(jsonb) is
  'crystal-compras 24/10/2026 (v3): evento da Assiny → libera ou bloqueia em crystal_compras. Bloqueio só com compra conhecida; repetido traz "anterior"; evento desconhecido registrado. Só service_role e n8n_compras.';

revoke all on function public.app_compra_evento(jsonb) from public, anon, authenticated;
grant execute on function public.app_compra_evento(jsonb) to service_role;

-- -----------------------------------------------------------------------------
-- Conciliação (INT-09 c, INT-16, INT-06 item 5): o que aconteceu na janela e os bloqueios para reenviar à API do app.
-- Só leitura. O e-mail dos bloqueados sai daqui só para o n8n repassar à API; o resumo por e-mail à equipe não leva
-- dado pessoal (é o nó "Montar resumo" do fluxo que decide o que vai no texto).
-- -----------------------------------------------------------------------------
create or replace function public.app_compras_conciliacao(p_horas int default 23,
                                                          p_max_liberados int default 100,
                                                          p_max_bloqueados int default 20)
returns json
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_desde        timestamptz;
  v_resumo       json;
  v_desconhecidos json;
  v_bloqueios    json;
  v_liberados    int;
  v_bloqueados   int;
  v_motivos      text[] := '{}';
begin
  if p_horas is null or p_horas < 1 or p_horas > 168 then
    raise exception 'JANELA_INVALIDA' using hint = 'p_horas entre 1 e 168';
  end if;
  v_desde := now() - make_interval(hours => p_horas);

  select coalesce(json_agg(json_build_object('acao', s.acao, 'evento', s.evento, 'quantidade', s.n)
                           order by s.acao, s.evento), '[]')
    into v_resumo
    from (select e.acao, e.evento, count(*) as n
            from public.crystal_compras_eventos e
           where e.recebido_em >= v_desde
           group by 1, 2) s;

  select coalesce(json_agg(distinct e.evento), '[]')
    into v_desconhecidos
    from public.crystal_compras_eventos e
   where e.recebido_em >= v_desde and e.acao = 'ignorado_evento';

  select count(*) filter (where e.acao = 'liberar'), count(*) filter (where e.acao = 'bloquear')
    into v_liberados, v_bloqueados
    from public.crystal_compras_eventos e
   where e.recebido_em >= v_desde;
  if v_liberados > coalesce(p_max_liberados, 100) then
    v_motivos := v_motivos || format('liberacoes_acima_de_%s', coalesce(p_max_liberados, 100));
  end if;
  if v_bloqueados > coalesce(p_max_bloqueados, 20) then
    v_motivos := v_motivos || format('bloqueios_acima_de_%s', coalesce(p_max_bloqueados, 20));
  end if;

  select coalesce(json_agg(json_build_object(
           'email', c.email,
           'transacao', c.transacao,
           'assinatura', c.assinatura,
           'status', c.status,
           'evento', (select e.evento from public.crystal_compras_eventos e
                       where e.acao = 'bloquear'
                         and ((c.transacao is not null and e.transacao = c.transacao)
                           or (c.assinatura is not null and e.assinatura = c.assinatura))
                       order by e.recebido_em desc limit 1),
           'bloqueado_em', c.bloqueado_em) order by c.bloqueado_em), '[]')
    into v_bloqueios
    from public.crystal_compras c
   where c.status <> 'active' and c.bloqueado_em is not null and c.bloqueado_em >= v_desde;

  return json_build_object(
    'janela_horas', p_horas,
    'desde', v_desde,
    'resumo', v_resumo,
    'eventos_desconhecidos', v_desconhecidos,
    'liberados', v_liberados,
    'bloqueados', v_bloqueados,
    'alerta', cardinality(v_motivos) > 0,
    'motivos_alerta', to_json(v_motivos),
    'bloqueios', v_bloqueios);
end;
$$;

comment on function public.app_compras_conciliacao(int, int, int) is
  'crystal-compras 24/10/2026: resumo da janela (contagens, eventos desconhecidos, alerta) e bloqueios para o n8n reenviar à API do app. Só leitura; só service_role e n8n_compras.';

revoke all on function public.app_compras_conciliacao(int, int, int) from public, anon, authenticated;
grant execute on function public.app_compras_conciliacao(int, int, int) to service_role;

-- -----------------------------------------------------------------------------
-- Papel do n8n (INT-07): executa só as duas funções acima. O PostgREST troca para ele quando o JWT traz
-- "role": "n8n_compras" (o JWT é assinado com o segredo JWT do projeto; compra-assiny-credenciais.py --supabase-papel
-- gera e testa). Precisa ser membro de authenticator para o PostgREST poder trocar.
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'n8n_compras') then
    create role n8n_compras nologin;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticator') then
    execute 'grant n8n_compras to authenticator';
  end if;
end;
$$;
grant usage on schema public to n8n_compras;
grant execute on function public.app_compra_evento(jsonb) to n8n_compras;
grant execute on function public.app_compras_conciliacao(int, int, int) to n8n_compras;
revoke all on all tables in schema public from n8n_compras;
revoke all on all sequences in schema public from n8n_compras;

notify pgrst, 'reload schema';

-- Conferência: as duas funções são security definer; anon/authenticated não executam; service_role e n8n_compras
-- executam; n8n_compras não lê crystal_compras.
select p.proname,
       p.prosecdef as security_definer,
       has_function_privilege('anon', p.oid, 'execute') as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
       has_function_privilege('service_role', p.oid, 'execute') as service_role,
       has_function_privilege('n8n_compras', p.oid, 'execute') as n8n_compras
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('app_compra_evento', 'app_compras_conciliacao')
 order by 1;
select has_table_privilege('n8n_compras', 'public.crystal_compras', 'select') as n8n_le_crystal_compras;
