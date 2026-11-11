-- login-cpf 11/11/2026 (pedido do dono): login do app com e-mail + CPF.
--
-- Regra do dono: "quem tem CPF vem com CPF; os novos usuários têm que vir com CPF; os que não têm vêm com
-- código e, quando entrar, cadastra o CPF". Este arquivo é a parte do Supabase:
--
-- 1) Segredo no Vault (`crystal_cpf_marca`, gerado aqui dentro, nunca sai do banco) e a função
--    `app_cpf_marca(cpf)`: HMAC-SHA256 do CPF com esse segredo. O CPF em claro não fica guardado.
-- 2) `crystal_compras.cpf_marca`: o n8n passa a mandar `data.client.document` e o `app_compra_evento` guarda só a
--    marca. Compra que chega sem CPF segue como antes (a coluna fica nula).
-- 3) `app_verificar_login_email_cpf(p_email, p_cpf)`: o mesmo resultado de `app_verificar_login_email(p_email)`
--    mais `cpf_confere`:
--      true  = há CPF guardado para esse e-mail (base antiga ou compra nova) e o digitado bate;
--      false = há CPF guardado e o digitado não bate;
--      null  = não há CPF guardado para esse e-mail (ou o digitado não tem 11 dígitos).
--    A API do app usa esse valor só para decidir entre sessão direta e código por e-mail; a resposta à tela é a
--    mesma para "não bate" e "sem CPF" (sem oráculo).
--
-- Só acrescenta: `app_verificar_login_email` não muda (a versão do app no ar continua chamando ela).
-- Rodar inteiro, uma vez; é idempotente.

-- 1) Segredo e marca ----------------------------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'crystal_cpf_marca') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'crystal_cpf_marca',
      'login-cpf 11/11/2026: segredo da marca HMAC do CPF (crystal_compras.cpf_marca). Nunca muda: trocar invalida as marcas.'
    );
  end if;
end $$;

create or replace function public.app_cpf_marca(p_cpf text)
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case
    when length(x.d) = 11 then encode(
      extensions.hmac(x.d, (select s.decrypted_secret from vault.decrypted_secrets s where s.name = 'crystal_cpf_marca'), 'sha256'),
      'hex')
  end
  from (select regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g') as d) x;
$$;
revoke all on function public.app_cpf_marca(text) from public, anon, authenticated;
comment on function public.app_cpf_marca(text) is
  'login-cpf 11/11/2026: HMAC-SHA256 do CPF (só dígitos, 11) com o segredo crystal_cpf_marca do Vault. Só para as funções do app.';

-- 2) Marca do CPF nas compras novas ---------------------------------------------------------------------------------
alter table public.crystal_compras add column if not exists cpf_marca text;
comment on column public.crystal_compras.cpf_marca is
  'login-cpf 11/11/2026: HMAC-SHA256 do CPF do comprador (app_cpf_marca). O CPF em claro não fica guardado.';

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
$function$;

-- 3) Login com e-mail + CPF ---------------------------------------------------------------------------------------
create or replace function public.app_verificar_login_email_cpf(p_email text, p_cpf text)
returns table (name text, phone text, contact_id text, liberado boolean, cpf_confere boolean)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with pedido as (
    select lower(trim(coalesce(p_email, ''))) as e,
           regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g') as d
  ),
  -- Todo CPF guardado para esse e-mail: base antiga (em claro, como sempre esteve) e compras novas (só a marca).
  fontes as (
    select regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g') = p.d as bate
      from public.leticia_crystal_customers c, pedido p
     where length(p.e) >= 3
       and lower(trim(c.email)) = p.e
       and length(regexp_replace(coalesce(c.cpf::text, ''), '\D', '', 'g')) = 11
    union all
    select k.cpf_marca = public.app_cpf_marca(p.d)
      from public.crystal_compras k, pedido p
     where length(p.e) >= 3
       and k.email = p.e
       and k.cpf_marca is not null
  ),
  confere as (
    select case
      when (select length(p.d) from pedido p) <> 11 then null
      when count(*) = 0 then null
      else coalesce(bool_or(f.bate), false)
    end as v
    from fontes f
  )
  select v.name, v.phone, v.contact_id, v.liberado, (select c.v from confere c)
    from public.app_verificar_login_email(p_email) v;
$$;
revoke all on function public.app_verificar_login_email_cpf(text, text) from public, anon, authenticated;
grant execute on function public.app_verificar_login_email_cpf(text, text) to service_role;
comment on function public.app_verificar_login_email_cpf(text, text) is
  'login-cpf 11/11/2026: app_verificar_login_email + cpf_confere (true bate, false não bate, null sem CPF guardado).';
