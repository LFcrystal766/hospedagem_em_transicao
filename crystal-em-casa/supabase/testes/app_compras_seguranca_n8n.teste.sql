-- Teste de app_compras_seguranca_n8n.sql (ordem em base-falsa-compras.sql). Cada bloco falha com ASSERT se algo sair
-- diferente. Dados inventados. Roda como superusuário; o bloco 0 confere os privilégios.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on

insert into crystal_compras_produtos (produto_id, nome) values ('prod-a', 'Crystal A'), ('prod-b', 'Crystal B');
-- compra da época da agência: só na tabela de assinaturas, com o corpo cru da Assiny
insert into leticia_crystal_subscriptions (external_id, raw_data) values
 ('as-antiga', '{"data":{"client":{"email":"Antiga@teste.invalid"},"transaction":{"id":"tx-antiga"},"offer":{"subscription":{"id":"as-antiga"}}}}');

create or replace function pg_temp.ev(p_evento text, p_email text, p_tx text, p_produto text default 'prod-a', p_extra jsonb default '{}')
returns json language sql as $$
  select public.app_compra_evento(jsonb_build_object('event', p_evento, 'data', jsonb_build_object(
    'client', jsonb_build_object('email', p_email, 'full_name', 'Pessoa Teste', 'first_name', 'Pessoa', 'phone', '+55 (11) 98765-4321', 'document', '00000000000'),
    'transaction', jsonb_build_object('id', p_tx, 'status', 'paid', 'created_at', now()::text, 'updated_at', now()::text),
    'offer', jsonb_build_object('id', 'of-1', 'name', 'Oferta', 'product', jsonb_build_object('id', p_produto, 'name', 'Produto ' || p_produto),
                                'subscription', jsonb_build_object('id', 'as-' || p_tx)),
    'metadata', jsonb_build_object('ip', '203.0.113.9')) || p_extra));
$$;

do $$
declare r json; j json; falhou boolean;
begin
  -- 0. privilégios
  assert (select prosecdef from pg_proc where proname = 'app_compra_evento'), 'app_compra_evento security definer';
  assert (select prosecdef from pg_proc where proname = 'app_compras_conciliacao'), 'conciliacao security definer';
  assert has_function_privilege('service_role', 'public.app_compra_evento(jsonb)', 'execute'), 'service_role executa';
  assert has_function_privilege('n8n_compras', 'public.app_compra_evento(jsonb)', 'execute'), 'n8n_compras executa';
  assert has_function_privilege('n8n_compras', 'public.app_compras_conciliacao(int,int,int)', 'execute'), 'n8n_compras concilia';
  assert not has_function_privilege('anon', 'public.app_compra_evento(jsonb)', 'execute'), 'anon nao executa';
  assert not has_function_privilege('authenticated', 'public.app_compras_conciliacao(int,int,int)', 'execute'), 'authenticated nao concilia';
  assert not has_table_privilege('n8n_compras', 'public.crystal_compras', 'select'), 'n8n_compras nao le crystal_compras';
  assert not has_table_privilege('n8n_compras', 'public.crystal_compras_eventos', 'insert'), 'n8n_compras nao escreve eventos';
  assert pg_has_role('authenticator', 'n8n_compras', 'member'), 'authenticator e membro de n8n_compras';

  -- 1. compra aprovada libera; o reenvio é repetido e diz o que o original fez
  r := pg_temp.ev('approved_purchase', 'A@teste.invalid', 'tx-a');
  assert r->>'acao' = 'liberado' and (r->>'novo')::boolean, 'liberado novo: ' || r::text;
  assert (select telefone from crystal_compras where email = 'a@teste.invalid') = '+5511987654321', 'telefone E.164';
  r := pg_temp.ev('approved_purchase', 'a@teste.invalid', 'tx-a');
  assert r->>'acao' = 'repetido' and r->>'anterior' = 'liberar', 'repetido liberar: ' || r::text;

  -- 2. reembolso forjado (e-mail sem compra conhecida) não bloqueia ninguém e fica registrado
  r := pg_temp.ev('refunded_purchase', 'vitima@teste.invalid', 'tx-forjada');
  assert r->>'acao' = 'ignorado' and r->>'motivo' = 'sem_compra_conhecida', 'forjado: ' || r::text;
  assert not exists (select 1 from crystal_compras where email = 'vitima@teste.invalid'), 'vitima sem linha';
  assert (select acao from crystal_compras_eventos where chave = 'tx-forjada:refunded_purchase') = 'ignorado_sem_compra_conhecida', 'evento forjado registrado';
  -- reembolso com e-mail de compradora real mas transação de outra pessoa: também não bloqueia
  r := pg_temp.ev('refunded_purchase', 'a@teste.invalid', 'tx-de-outra');
  assert r->>'acao' = 'ignorado' and r->>'motivo' = 'sem_compra_conhecida', 'tx alheia: ' || r::text;
  assert (select status from crystal_compras where email = 'a@teste.invalid') = 'active', 'A continua ativa';

  -- 3. reembolso da compra conhecida bloqueia; o reenvio diz "anterior = bloquear" (o n8n repassa de novo à API)
  r := pg_temp.ev('refunded_purchase', 'a@teste.invalid', 'tx-a');
  assert r->>'acao' = 'bloqueado', 'bloqueado: ' || r::text;
  assert (select status from crystal_compras where email = 'a@teste.invalid') = 'refunded', 'status refunded';
  r := pg_temp.ev('refunded_purchase', 'a@teste.invalid', 'tx-a');
  assert r->>'acao' = 'repetido' and r->>'anterior' = 'bloquear', 'repetido bloquear: ' || r::text;
  r := pg_temp.ev('approved_purchase', 'z@teste.invalid', 'tx-a');
  assert r->>'acao' = 'repetido', 'mesma tx+evento e repetido mesmo com outro e-mail: ' || r::text;

  -- 4. charged_back (nome da documentação da Assiny) bloqueia compra da época da agência, casando pela transação
  --    gravada no corpo cru da assinatura (a tabela da agência)
  r := public.app_compra_evento('{"event":"charged_back","data":{"client":{"email":"antiga@teste.invalid"},"transaction":{"id":"tx-antiga"},"offer":{"product":{"id":"prod-a"},"subscription":{"id":"as-antiga"}}}}');
  assert r->>'acao' = 'bloqueado', 'chargeback agencia: ' || r::text;
  assert (select status from crystal_compras where email = 'antiga@teste.invalid') = 'chargeback', 'status chargeback';

  -- 5. evento desconhecido fica registrado sem dado pessoal
  r := pg_temp.ev('pix_generated', 'c@teste.invalid', 'tx-pix');
  assert r->>'acao' = 'ignorado' and r->>'motivo' = 'evento', 'desconhecido: ' || r::text;
  assert (select acao from crystal_compras_eventos where chave = 'tx-pix:pix_generated') = 'ignorado_evento', 'ignorado_evento gravado';
  assert not exists (select 1 from crystal_compras where email = 'c@teste.invalid'), 'desconhecido nao cria linha';
  assert (select count(*) from crystal_compras_eventos e where e.chave = 'tx-pix:pix_generated' and e::text ilike '%teste.invalid%') = 0, 'sem e-mail no evento';

  -- 6. produto fora da lista: ignorado produto (o n8n repassa ao app como pacote de imagens)
  r := pg_temp.ev('approved_purchase', 'c@teste.invalid', 'tx-img', 'prod-img');
  assert r->>'acao' = 'ignorado' and r->>'motivo' = 'produto', 'produto fora: ' || r::text;

  -- 7. limites: transação longa ou com caractere estranho é recusada; nome longo é cortado
  falhou := false;
  begin
    r := pg_temp.ev('approved_purchase', 'd@teste.invalid', repeat('x', 81));
  exception when others then falhou := sqlerrm like '%EVENTO_INVALIDO%';
  end;
  assert falhou, 'tx de 81 recusada';
  falhou := false;
  begin
    r := pg_temp.ev('approved_purchase', 'd@teste.invalid', 'tx com espaço');
  exception when others then falhou := sqlerrm like '%EVENTO_INVALIDO%';
  end;
  assert falhou, 'tx com espaço recusada';
  falhou := false;
  begin
    r := public.app_compra_evento('{"event":"approved_purchase","data":{"client":{"email":"sem-arroba"},"transaction":{"id":"tx-e"}}}');
  exception when others then falhou := sqlerrm like '%EMAIL_INVALIDO%';
  end;
  assert falhou, 'e-mail invalido recusado';
  r := public.app_compra_evento(jsonb_build_object('event', 'approved_purchase', 'data', jsonb_build_object(
         'client', jsonb_build_object('email', 'longo@teste.invalid', 'full_name', repeat('N', 200)),
         'transaction', jsonb_build_object('id', 'tx-longo'), 'offer', jsonb_build_object('product', jsonb_build_object('id', 'prod-a')))));
  assert r->>'acao' = 'liberado', 'nome longo libera: ' || r::text;
  assert length((select nome from crystal_compras where email = 'longo@teste.invalid')) = 120, 'nome cortado em 120';

  -- 8. conciliação: contagens, desconhecidos, bloqueios da janela, alerta por volume
  j := public.app_compras_conciliacao(23);
  assert (j->>'liberados')::int = 2, 'liberados=2: ' || j::text;   -- tx-a, tx-longo
  assert (j->>'bloqueados')::int = 2, 'bloqueados=2: ' || j::text; -- tx-a (refund), tx-antiga (chargeback)
  assert (j->'eventos_desconhecidos')::text like '%pix_generated%', 'desconhecido listado';
  assert not (j->>'alerta')::boolean, 'sem alerta com os limites padrao';
  assert json_array_length(j->'bloqueios') = 2, 'dois bloqueios na janela: ' || (j->'bloqueios')::text;
  assert exists (select 1 from json_array_elements(j->'bloqueios') b
                  where b->>'email' = 'a@teste.invalid' and b->>'transacao' = 'tx-a' and b->>'evento' = 'refunded_purchase' and b->>'status' = 'refunded'),
         'bloqueio de A com evento: ' || (j->'bloqueios')::text;
  assert exists (select 1 from json_array_elements(j->'bloqueios') b
                  where b->>'email' = 'antiga@teste.invalid' and b->>'evento' = 'charged_back' and b->>'status' = 'chargeback'),
         'bloqueio da antiga com evento: ' || (j->'bloqueios')::text;
  j := public.app_compras_conciliacao(23, 100, 1);
  assert (j->>'alerta')::boolean and (j->'motivos_alerta')::text like '%bloqueios_acima_de_1%', 'alerta por bloqueios: ' || j::text;
  falhou := false;
  begin
    j := public.app_compras_conciliacao(0);
  exception when others then falhou := sqlerrm like '%JANELA_INVALIDA%';
  end;
  assert falhou, 'janela 0 recusada';

  -- 10. recompra depois do reembolso religa a linha (a conta do app desligada fica para o suporte, como antes)
  r := pg_temp.ev('approved_purchase', 'a@teste.invalid', 'tx-a2', 'prod-b');
  assert r->>'acao' = 'liberado' and (r->>'novo')::boolean, 'recompra libera: ' || r::text;
  assert (select status from crystal_compras where email = 'a@teste.invalid') = 'active', 'A ativa de novo';
  j := public.app_compras_conciliacao(23);
  assert json_array_length(j->'bloqueios') = 1, 'A religada sai dos bloqueios: ' || (j->'bloqueios')::text;
end $$;

-- 9. como n8n_compras: executa a função (security definer), mas não lê tabela
set role n8n_compras;
select (public.app_compra_evento('{"event":"teste_credenciais"}'))->>'acao' = 'ignorado' as n8n_executa;
do $$
declare n int; negado boolean := false;
begin
  begin
    select count(*) into n from public.crystal_compras;
  exception when insufficient_privilege then negado := true;
  end;
  assert negado, 'n8n_compras nao pode ler crystal_compras';
end $$;
reset role;
select 'ok: app_compras_seguranca_n8n' as resultado;
