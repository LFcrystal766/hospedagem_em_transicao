-- =============================================================================
-- Compra direta: comprou na Assiny, já entra no app (09/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez. Independe da
-- agência: a compra passa a ser registrada numa tabela NOSSA (crystal_compras), e o login
-- do app aceita quem está nela com status active, já liberado (sem lote).
--
-- Caminho: Assiny (webhook) → nosso n8n (crystal-em-casa/n8n/compra-assiny.json) →
-- POST /rest/v1/rpc/app_compra_evento { p_evento: <corpo da Assiny como veio> } com a chave
-- secreta própria do n8n. Toda a regra mora aqui (testada em Postgres); o n8n só repassa.
--
-- O que cria (só acréscimo; nada da agência é escrito):
--   crystal_compras           uma linha por e-mail de comprador: nome, telefone, status,
--                             produto, transação e assinatura da Assiny. O id (uuid) vira a
--                             identidade da conta no app (contact_id) para quem não está na
--                             base antiga.
--   crystal_compras_eventos   um registro por (transação, evento): reenvio da Assiny vira
--                             "repetido" e nada muda. Sem e-mail, nome nem telefone.
--   crystal_compras_produtos  lista de produtos que liberam o app. VAZIA = qualquer produto
--                             libera. Preencher com os ids dos produtos da Crystal (consulta
--                             no fim do arquivo mostra os ids que já chegaram).
--   app_compra_evento(jsonb)  recebe o evento e devolve { acao, novo, motivo, evento }:
--                             liberado | bloqueado | ignorado | repetido. "novo" = acabou de
--                             ganhar acesso (o n8n manda o e-mail de boas-vindas só então).
-- O que MUDA: app_verificar_login_email (mesma assinatura e retorno). Antes de tudo procura
-- na base antiga, igual a hoje (quem já usa o app mantém a mesma conta); sem acesso lá,
-- procura em crystal_compras com status active, liberado = true.
--
-- Eventos (minúsculas; confira os nomes na tela de webhooks da Assiny e acrescente aqui se
-- vier outro): liberam approved_purchase, purchase_approved, subscription_renewed,
-- renewed_subscription; bloqueiam refunded_purchase, chargeback, chargedback_purchase,
-- canceled_subscription, subscription_canceled (os mesmos do webhook de reembolso da API).
-- Outro evento: "ignorado", nada muda. Compra pendente (boleto, pix gerado) não libera.
--
-- Regras de bloqueio: a linha do e-mail só é bloqueada quando o reembolso é da mesma
-- transação ou da mesma assinatura que liberou (reembolso de uma compra antiga não derruba
-- uma compra nova). E-mail sem linha (comprador da época da agência): grava a linha já
-- bloqueada e devolve "bloqueado", para o n8n repassar à API (/webhooks/reembolso), que
-- desliga a conta do app. Liberação de uma transação já reembolsada não religa.
-- Recompra depois de reembolso: a linha volta a active, mas a conta do app desligada pela
-- API continua desligada até o suporte reativar no painel (Alunos > reativar).
--
-- Desfazer: (1) desligar o fluxo no n8n; (2) rodar crystal-em-casa/supabase/
-- app_verificar_login_email.sql de novo (volta o login só pela base antiga). As tabelas
-- novas podem ficar.
-- =============================================================================

do $$
begin
  if to_regprocedure('public.app_verificar_login_email(text)') is null then
    raise exception 'ESQUEMA_DIFERENTE'
      using hint = 'app_verificar_login_email(text) não existe: aplicar app_verificar_login_email.sql antes';
  end if;
  if to_regclass('public.crystal_compras') is not null
     and coalesce(obj_description(to_regclass('public.crystal_compras'), 'pg_class'), '') not like 'crystal-compras %' then
    raise exception 'JA_EXISTE' using hint = 'public.crystal_compras já existe e não veio deste arquivo; não mexer';
  end if;
end;
$$;

create table if not exists public.crystal_compras (
  id            uuid        primary key default gen_random_uuid(),
  email         text        not null unique,
  nome          text,
  telefone      text,
  status        text        not null check (status in ('active', 'refunded', 'chargeback', 'canceled')),
  produto_id    text,
  produto       text,
  oferta        text,
  transacao     text,
  assinatura    text,
  liberado_em   timestamptz,
  bloqueado_em  timestamptz,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table public.crystal_compras enable row level security;
revoke all on table public.crystal_compras from public, anon, authenticated, service_role;
comment on table public.crystal_compras is
  'crystal-compras 09/10/2026: compradores da Assiny registrados pelo nosso n8n. Só via app_compra_evento e app_verificar_login_email.';

create table if not exists public.crystal_compras_eventos (
  chave       text        primary key,
  evento      text        not null,
  transacao   text,
  assinatura  text,
  produto_id  text,
  produto     text,
  acao        text        not null,
  recebido_em timestamptz not null default now()
);
create index if not exists crystal_compras_eventos_transacao on public.crystal_compras_eventos (transacao);
alter table public.crystal_compras_eventos enable row level security;
revoke all on table public.crystal_compras_eventos from public, anon, authenticated, service_role;
comment on table public.crystal_compras_eventos is
  'crystal-compras 09/10/2026: um registro por (transação, evento) da Assiny. Sem dado pessoal.';

create table if not exists public.crystal_compras_produtos (
  produto_id text        primary key,
  nome       text,
  criado_em  timestamptz not null default now()
);
alter table public.crystal_compras_produtos enable row level security;
revoke all on table public.crystal_compras_produtos from public, anon, authenticated, service_role;
comment on table public.crystal_compras_produtos is
  'crystal-compras 09/10/2026: produtos da Assiny que liberam o app. Vazia = qualquer produto.';

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
$$;

comment on function public.app_compra_evento(jsonb) is
  'crystal-compras 09/10/2026: evento da Assiny (corpo inteiro) → libera ou bloqueia em crystal_compras. Só service_role.';

revoke all on function public.app_compra_evento(jsonb) from public;
revoke all on function public.app_compra_evento(jsonb) from anon, authenticated;
grant execute on function public.app_compra_evento(jsonb) to service_role;

-- Login por e-mail: base antiga primeiro (igual a hoje), depois crystal_compras.
create or replace function public.app_verificar_login_email(p_email text)
returns table (name text, phone text, contact_id text, liberado boolean)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with pedido as (
    select lower(trim(coalesce(p_email, ''))) as e
  ),
  antiga as (
    select
      c.full_name::text as name,
      case
        when length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10
          then '+' || regexp_replace(a.phone_number, '\D', '', 'g')
      end as phone,
      c.id::text as contact_id,
      coalesce(c.is_in_rollout, false) as liberado,
      1 as origem,
      (a.subscription_status = 'active') as ativo,
      c.created_at::timestamptz as criado,
      c.id::text as desempate
    from public.leticia_crystal_customers c
    join lateral (
      select x.phone_number, x.subscription_status
        from public.leticia_crystal_active_accesses x
       where x.customer_id = c.id
         and x.subscription_status in ('active', 'pending')
       order by (x.subscription_status = 'active') desc, x.access_updated_at desc nulls last
       limit 1
    ) a on true
    cross join pedido p
    where length(p.e) >= 3
      and lower(trim(c.email)) = p.e
  ),
  nossa as (
    select k.nome, k.telefone, k.id::text, true, 2, true, k.criado_em::timestamptz, k.id::text
      from public.crystal_compras k
      cross join pedido p
     where length(p.e) >= 3
       and k.email = p.e
       and k.status = 'active'
  )
  select t.name, t.phone, t.contact_id, t.liberado
    from (select * from antiga union all select * from nossa) t
   order by t.origem, t.ativo desc, t.criado asc, t.desempate asc
   limit 1;
$$;

revoke all on function public.app_verificar_login_email(text) from public;
revoke all on function public.app_verificar_login_email(text) from anon, authenticated;
grant execute on function public.app_verificar_login_email(text) to service_role;

notify pgrst, 'reload schema';

-- Conferências (só contagens e ids de produto, nenhum dado pessoal):
--   select status, count(*) from public.crystal_compras group by 1;
--   select evento, acao, count(*) from public.crystal_compras_eventos group by 1, 2 order by 1, 2;
--   produtos que já chegaram (para preencher a lista):
--     select produto_id, produto, count(*) from public.crystal_compras_eventos group by 1, 2 order by 3 desc;
--   travar a liberação só nos produtos da Crystal:
--     insert into public.crystal_compras_produtos (produto_id, nome) values ('<id>', '<nome>');
