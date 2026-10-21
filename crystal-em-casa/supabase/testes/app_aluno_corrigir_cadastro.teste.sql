-- Teste de app_aluno_corrigir_cadastro.sql (ver a ordem em base-falsa-cadastro.sql). Cada bloco falha com ASSERT se algo sair diferente.
-- Dados inventados. Roda como superusuário; o bloco 0 confere os privilégios.
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on

-- Cenário: A = base antiga com acesso ativo e telefone na tabela de acessos (o login ignora phone_from_gateway);
--          B = base antiga com assinatura ativa só no gateway (o login lê phone_from_gateway);
--          C = base antiga sem acesso nenhum; D = compra comum; E = outro cliente com CPF já usado.
insert into leticia_crystal_customers (id, email, full_name, phone_from_gateway, cpf) values
 ('aaaaaaaa-0000-0000-0000-000000000001', 'a@teste.invalid', 'Aluna A', '5511900000001', '11144477735'),
 ('bbbbbbbb-0000-0000-0000-000000000002', 'b@teste.invalid', 'Aluna B', '5521900000002', null),
 ('cccccccc-0000-0000-0000-000000000003', 'c@teste.invalid', 'Aluna C', null, null),
 ('eeeeeeee-0000-0000-0000-000000000005', 'e@teste.invalid', 'Aluna E', null, '39053344705');
insert into leticia_crystal_active_accesses (phone_number, customer_id, subscription_status) values
 ('5511911112222', 'aaaaaaaa-0000-0000-0000-000000000001', 'active');
insert into leticia_crystal_subscriptions (customer_id, status, updated_at, end_date) values
 ('bbbbbbbb-0000-0000-0000-000000000002', 'active', now(), now() + interval '30 days');
insert into crystal_compras (id, email, nome, telefone, status, transacao, assinatura) values
 ('dddddddd-0000-0000-0000-000000000004', 'd@teste.invalid', 'Compradora D', '+5531900000004', 'active', 'tx-d', null),
 ('ffffffff-0000-0000-0000-000000000006', 'f@teste.invalid', 'Compradora F', null, 'refunded', 'tx-f', null);
insert into crystal_compras_eventos (chave, evento, transacao, assinatura, acao) values
 ('tx-reemb:refunded_purchase', 'refunded_purchase', 'tx-reemb', null, 'bloquear'),
 ('as-cancel:subscription_canceled', 'subscription_canceled', null, 'as-cancelada', 'bloquear');

do $$
declare r json; t text;
begin
  -- 0. privilégios
  assert has_function_privilege('service_role', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute'), 'service_role executa';
  assert not has_function_privilege('anon', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute'), 'anon nao executa';
  assert not has_function_privilege('authenticated', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute'), 'authenticated nao executa';
  assert (select prosecdef from pg_proc where proname = 'app_aluno_corrigir_cadastro'), 'security definer';

  -- 1. corrigir nome da base antiga (espaços repetidos viram um); telefone não pedido -> telefone_no_login null
  r := public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{"nome":"  Aluna   Nova  C "}');
  assert r->>'status' = 'corrigido' and r->>'origem' = 'base' and (r->>'nome')::boolean and not (r->>'telefone')::boolean, 'nome base: ' || r::text;
  assert (r::jsonb)->'telefone_no_login' = 'null'::jsonb, 'telefone_no_login null sem telefone';
  assert (select full_name from leticia_crystal_customers where id = 'cccccccc-0000-0000-0000-000000000003') = 'Aluna Nova C', 'nome gravado';

  -- 2. telefone de B (login lê o gateway): efetivo, grava só dígitos
  r := public.app_aluno_corrigir_cadastro('corrigir', 'bbbbbbbb-0000-0000-0000-000000000002', '{"telefone":"+5548988504130"}');
  assert r->>'status' = 'corrigido' and (r->>'telefone_no_login')::boolean is true, 'B efetivo: ' || r::text;
  assert (select phone_from_gateway from leticia_crystal_customers where id = 'bbbbbbbb-0000-0000-0000-000000000002') = '5548988504130', 'digitos gravados';
  assert (select phone from app_verificar_login_email('b@teste.invalid')) = '+5548988504130', 'login devolve o novo';

  -- 3. telefone de A (login lê a tabela de acessos): NÃO efetivo, avisa
  r := public.app_aluno_corrigir_cadastro('corrigir', 'aaaaaaaa-0000-0000-0000-000000000001', '{"nome":"Aluna A2","telefone":"+5548988504131"}');
  assert (r->>'telefone_no_login')::boolean is false, 'A nao efetivo: ' || r::text;
  assert (select phone from app_verificar_login_email('a@teste.invalid')) = '+5511911112222', 'login segue com o numero dos acessos';
  assert (select full_name from leticia_crystal_customers where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 'Aluna A2', 'nome de A mudou junto';

  -- 4. número estrangeiro de 11 dígitos: o login poria +55, então não é efetivo
  r := public.app_aluno_corrigir_cadastro('corrigir', 'bbbbbbbb-0000-0000-0000-000000000002', '{"telefone":"+14155550123"}');
  assert (r->>'telefone_no_login')::boolean is false, 'estrangeiro nao efetivo: ' || r::text;

  -- 5. compra: nome e telefone em crystal_compras, e o login devolve o novo
  r := public.app_aluno_corrigir_cadastro('corrigir', 'dddddddd-0000-0000-0000-000000000004', '{"nome":"Compradora D2","telefone":"+5531988880000"}');
  assert r->>'origem' = 'compra' and (r->>'telefone_no_login')::boolean is true, 'compra: ' || r::text;
  assert (select nome || telefone from crystal_compras where id = 'dddddddd-0000-0000-0000-000000000004') = 'Compradora D2+5531988880000', 'compra gravada';

  -- 6. não achado: id que não existe e id que não é uuid
  assert (public.app_aluno_corrigir_cadastro('corrigir', '99999999-0000-0000-0000-000000000009', '{"nome":"X Y"}'))->>'status' = 'nao_achado', 'id inexistente';
  assert (public.app_aluno_corrigir_cadastro('corrigir', 'nao-e-uuid', '{"nome":"X Y"}'))->>'status' = 'nao_achado', 'id invalido';

  -- 7. validações
  begin perform public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{}'); assert false, 'devia recusar vazio';
  exception when others then get stacked diagnostics t = message_text; assert t = 'NADA_A_ALTERAR', 'vazio: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{"nome":"A"}'); assert false, 'devia recusar nome curto';
  exception when others then get stacked diagnostics t = message_text; assert t = 'NOME_INVALIDO', 'nome curto: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{"nome":123}'); assert false, 'devia recusar nome numero';
  exception when others then get stacked diagnostics t = message_text; assert t = 'NOME_INVALIDO', 'nome numero: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{"telefone":"48988504130"}'); assert false, 'devia recusar telefone sem +';
  exception when others then get stacked diagnostics t = message_text; assert t = 'TELEFONE_INVALIDO', 'telefone: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('corrigir', 'cccccccc-0000-0000-0000-000000000003', '{"telefone":null}'); assert false, 'devia recusar telefone nulo';
  exception when others then get stacked diagnostics t = message_text; assert t = 'TELEFONE_INVALIDO', 'telefone nulo: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('trocar', null, '{}'); assert false, 'devia recusar operacao';
  exception when others then get stacked diagnostics t = message_text; assert t = 'OPERACAO_INVALIDA', 'operacao: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('corrigir', null, '[]'); assert false, 'devia recusar dados que nao sao objeto';
  exception when others then get stacked diagnostics t = message_text; assert t = 'DADOS_INVALIDOS', 'dados: ' || t; end;

  -- 8. CPF: troca na base antiga (A tinha outro), só dígitos
  r := public.app_aluno_corrigir_cadastro('cpf', 'aaaaaaaa-0000-0000-0000-000000000001', '{"cpf":"529.982.247-25"}');
  assert r->>'origem' = 'base' and (r->>'gravado')::boolean, 'cpf base: ' || r::text;
  assert (select cpf from leticia_crystal_customers where id = 'aaaaaaaa-0000-0000-0000-000000000001') = '52998224725', 'cpf gravado em digitos';
  -- o mesmo CPF no mesmo cadastro é idempotente
  r := public.app_aluno_corrigir_cadastro('cpf', 'aaaaaaaa-0000-0000-0000-000000000001', '{"cpf":"52998224725"}');
  assert r->>'status' = 'corrigido', 'idempotente';
  -- cadastro sem CPF recebe
  r := public.app_aluno_corrigir_cadastro('cpf', 'cccccccc-0000-0000-0000-000000000003', '{"cpf":"11144477735"}');
  assert (r->>'gravado')::boolean, 'C recebe cpf (o de A foi liberado)';
  -- CPF de outro cadastro
  begin perform public.app_aluno_corrigir_cadastro('cpf', 'bbbbbbbb-0000-0000-0000-000000000002', '{"cpf":"39053344705"}'); assert false, 'devia recusar cpf em uso';
  exception when unique_violation then get stacked diagnostics t = message_text; assert t = 'CPF_EM_USO', 'cpf em uso: ' || t; end;
  -- CPF inválido (dígito verificador, todos iguais, curto, não-texto)
  foreach t in array array['{"cpf":"52998224726"}', '{"cpf":"11111111111"}', '{"cpf":"123"}', '{"cpf":52998224725}', '{}'] loop
    begin perform public.app_aluno_corrigir_cadastro('cpf', 'bbbbbbbb-0000-0000-0000-000000000002', t::jsonb); assert false, 'devia recusar ' || t;
    exception when others then
      declare m text; begin get stacked diagnostics m = message_text; assert m = 'CPF_INVALIDO', t || ': ' || m; end;
    end;
  end loop;
  assert (select cpf from leticia_crystal_customers where id = 'bbbbbbbb-0000-0000-0000-000000000002') is null, 'B segue sem cpf';
  -- compra: nada gravado na base, só avisa
  r := public.app_aluno_corrigir_cadastro('cpf', 'dddddddd-0000-0000-0000-000000000004', '{"cpf":"52998224725"}');
  assert r->>'origem' = 'compra' and not (r->>'gravado')::boolean, 'cpf compra: ' || r::text;
  assert public.app_aluno_corrigir_cadastro('cpf', '99999999-0000-0000-0000-000000000009', '{"cpf":"52998224725"}')->>'status' = 'nao_achado', 'cpf id inexistente';

  -- 9. liberação manual: cria a linha, o login a acha, o id volta como contact_id
  r := public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"  Novo.Comprador@Teste.INVALID ","nome":"Novo   Comprador","telefone":"+5548977770000","referencia":"tx-12345","referencia_tipo":"transacao"}');
  assert r->>'status' = 'liberado' and r->>'origem' = 'compra', 'liberado: ' || r::text;
  assert (select count(*) from crystal_compras where email = 'novo.comprador@teste.invalid' and status = 'active' and produto = 'Liberação manual'
            and nome = 'Novo Comprador' and telefone = '+5548977770000' and transacao = 'tx-12345' and assinatura is null and liberado_em is not null) = 1, 'linha criada';
  assert (select contact_id from app_verificar_login_email('novo.comprador@teste.invalid')) = r->>'contact_id', 'login acha a linha pelo e-mail';
  assert (select liberado from app_verificar_login_email('novo.comprador@teste.invalid')), 'liberado';
  -- por assinatura, sem telefone
  r := public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"outro@teste.invalid","nome":"Outro Comprador","referencia":"as-777","referencia_tipo":"assinatura"}');
  assert r->>'status' = 'liberado', 'assinatura: ' || r::text;
  assert (select transacao is null and assinatura = 'as-777' and telefone is null from crystal_compras where email = 'outro@teste.invalid'), 'referencia na coluna certa';
  -- sem referência, tipo padrão
  r := public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"sem.ref@teste.invalid","nome":"Sem Referencia"}');
  assert r->>'status' = 'liberado' and (select transacao is null and assinatura is null from crystal_compras where email = 'sem.ref@teste.invalid'), 'sem referencia';
  -- repetido: já existe ativa
  assert public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"novo.comprador@teste.invalid","nome":"Novo Comprador"}')::jsonb = '{"status":"ja_existe","situacao":"ativa"}'::jsonb, 'repetido ativa';
  -- reembolsada: não reabre
  assert public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"f@teste.invalid","nome":"Compradora F"}')::jsonb = '{"status":"ja_existe","situacao":"bloqueada"}'::jsonb, 'reembolsada';
  assert (select status from crystal_compras where email = 'f@teste.invalid') = 'refunded', 'F segue reembolsada';
  -- e-mail da base antiga (com caixa diferente)
  assert public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"C@Teste.Invalid","nome":"Aluna C"}')::jsonb = '{"status":"email_na_base"}'::jsonb, 'email na base';
  -- referência já reembolsada / cancelada
  assert public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"g@teste.invalid","nome":"Pessoa G","referencia":"tx-reemb"}')::jsonb = '{"status":"transacao_reembolsada"}'::jsonb, 'transacao reembolsada';
  assert public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"g@teste.invalid","nome":"Pessoa G","referencia":"as-cancelada","referencia_tipo":"assinatura"}')::jsonb = '{"status":"transacao_reembolsada"}'::jsonb, 'assinatura cancelada';
  assert not exists (select 1 from crystal_compras where email = 'g@teste.invalid'), 'nada criado nas recusas';
  -- validações
  begin perform public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"sem-arroba","nome":"Pessoa H"}'); assert false;
  exception when others then get stacked diagnostics t = message_text; assert t = 'EMAIL_INVALIDO', 'email: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"h@teste.invalid","nome":"H"}'); assert false;
  exception when others then get stacked diagnostics t = message_text; assert t = 'NOME_INVALIDO', 'nome: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"h@teste.invalid","nome":"Pessoa H","telefone":"123"}'); assert false;
  exception when others then get stacked diagnostics t = message_text; assert t = 'TELEFONE_INVALIDO', 'telefone: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"h@teste.invalid","nome":"Pessoa H","referencia":"tem espaco"}'); assert false;
  exception when others then get stacked diagnostics t = message_text; assert t = 'REFERENCIA_INVALIDA', 'referencia: ' || t; end;
  begin perform public.app_aluno_corrigir_cadastro('liberar_manual', null, '{"email":"h@teste.invalid","nome":"Pessoa H","referencia":"abc","referencia_tipo":"cartao"}'); assert false;
  exception when others then get stacked diagnostics t = message_text; assert t = 'REFERENCIA_INVALIDA', 'tipo: ' || t; end;
  assert not exists (select 1 from crystal_compras where email = 'h@teste.invalid'), 'nada criado nas validacoes';

  -- 10. a liberação manual depois vira compra comum se a Assiny confirmar a compra do mesmo e-mail
  r := public.app_compra_evento('{"event":"approved_purchase","data":{"client":{"email":"sem.ref@teste.invalid","full_name":"Sem Referencia"},"transaction":{"id":"tx-real"},"offer":{"product":{"id":"p1","name":"Crystal"}}}}'::jsonb);
  assert (select produto from crystal_compras where email = 'sem.ref@teste.invalid') = 'Crystal', 'compra real atualiza a linha';

  -- 11. nada da agência foi escrito
  assert (select count(*) from leticia_crystal_active_accesses) = 1, 'acessos da agencia intactos';
  assert (select phone_number from leticia_crystal_active_accesses) = '5511911112222', 'telefone dos acessos intacto';
end;
$$;

\echo 'OK: app_aluno_corrigir_cadastro passou em todos os blocos'
