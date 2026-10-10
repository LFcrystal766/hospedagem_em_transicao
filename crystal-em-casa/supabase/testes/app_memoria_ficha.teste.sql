-- Teste de app_memoria_ficha.sql (base-falsa.sql + app_memoria_unica.sql + app_telefone_chave.sql + app_memoria_ficha.sql antes).
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
insert into leticia_crystal_active_accesses (phone_number, customer_id, subscription_status) values
 ('+55 (11) 98765-4321','aaaaaaaa-0000-0000-0000-000000000001','active'),
 ('5521987650000','bbbbbbbb-0000-0000-0000-000000000002','pending'),
 ('5531999990000','cccccccc-0000-0000-0000-000000000003','active'),
 ('5541988880000','eeeeeeee-0000-0000-0000-000000000005','canceled');
insert into crystal_compras (id, email, telefone, status) values ('dddddddd-0000-0000-0000-000000000004','d@x','+55 51 97777-0000','active');
insert into leticia_crystal_lead_management (phone_number, thread_id) values
 ('551187654321','11111111-0000-0000-0000-000000000001'),
 ('5521987650000','22222222-0000-0000-0000-000000000002'),
 ('5551977770000','44444444-0000-0000-0000-000000000004'),
 ('5541988880000','55555555-0000-0000-0000-000000000005');
insert into leticia_crystal_lead_memories select id, 'fatos do '||phone_number, '{"known_preferences":["gosta de audio"]}', now() from leticia_crystal_lead_management where thread_id='11111111-0000-0000-0000-000000000001';
-- A: arquivo antigo, atual recente, um repetido nos dois, empate de data, mensagem longa
insert into leticia_crystal_chat_histories_archive (session_id, message, created_at) values
 ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"oi antigo"}', now()-interval '200 days'),
 ('11111111-0000-0000-0000-000000000001','{"type":"ai","content":"resposta antiga"}', now()-interval '199 days'),
 ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"repetida"}', '2026-09-01 10:00+00');
insert into leticia_crystal_chat_histories (session_id, message, created_at) values
 ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"repetida"}', '2026-09-01 10:00+00'),
 ('11111111-0000-0000-0000-000000000001','{"type":"ai","data":{"content":"empate ai"}}', '2026-09-02 10:00+00'),
 ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"empate aluno"}', '2026-09-02 10:00+00'),
 ('11111111-0000-0000-0000-000000000001', jsonb_build_object('type','human','content',repeat('x',1000)), now()-interval '5 days'),
 ('11111111-0000-0000-0000-000000000001', jsonb_build_object('type','ai','content',repeat('y',1000)), now()-interval '5 days'+interval '1 minute'),
 ('11111111-0000-0000-0000-000000000001','{"type":"system","content":"nao entra"}', now()-interval '4 days'),
 ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"   "}', now()-interval '4 days'),
 ('22222222-0000-0000-0000-000000000002','{"type":"human","content":"B fala"}', now()-interval '60 days'),
 ('44444444-0000-0000-0000-000000000004','{"type":"human","content":"D fala"}', now()-interval '2 days'),
 ('55555555-0000-0000-0000-000000000005','{"type":"human","content":"E cancelado"}', now()-interval '1 days');

\echo '--- 1 fila: todos precisam, E fora (esperado a,b,c,d todos t; c sem ultima)'
select left(customer_id::text,1), precisa, ultima is null from app_ficha_fila(null, 1000);
\echo '--- 2 fatias de 2 (esperado a,b depois c,d)'
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 2);
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila('bbbbbbbb-0000-0000-0000-000000000002', 2);
\echo '--- 3 historico A pagina 3 (esperado: oi antigo, resposta antiga, repetida)'
select de, texto from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', null, 3);
\echo '--- 4 proxima pagina limite 1 a partir de 2026-09-01 10:00 (esperado as 2 do empate, aluno primeiro)'
select de, texto from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', '2026-09-01 10:00+00', 1);
\echo '--- 5 tamanhos cortados (esperado aluno 800, crystal 300)'
select de, length(texto) from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', '2026-09-03', 100);
\echo '--- 6 total A (esperado 7)'
select count(*) from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', null, 5000);
\echo '--- 7 D pela compra (esperado D fala)'
select texto from app_ficha_historico('dddddddd-0000-0000-0000-000000000004', null, 10);
\echo '--- 8 E cancelado (esperado nada)'
select count(*) from app_ficha_historico('eeeeeeee-0000-0000-0000-000000000005', null, 10);
\echo '--- 9a gravar A com ate = ultima lida no historico: a mensagem de sistema depois dela faz A voltar (por isso a Crystal grava o maior entre os dois)'
select app_ficha_gravar('aaaaaaaa-0000-0000-0000-000000000001','Ficha da A', (select max(quando) from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', null, 5000)), 7, 0.012, 'g/flash', 'ok');
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 1000) where precisa;
\echo '--- 9b gravar A com ate = ultima da fila: fila tira A (esperado b,c,d)'
select app_ficha_gravar('aaaaaaaa-0000-0000-0000-000000000001','Ficha da A', (select ultima from app_ficha_fila(null, 1000) where customer_id='aaaaaaaa-0000-0000-0000-000000000001'), 0, 0, 'g/flash', 'ok');
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 1000) where precisa;
\echo '--- 10 mensagem nova da A: volta a fila; historico depois de ate so traz a nova'
insert into leticia_crystal_chat_histories (session_id, message, created_at) values ('11111111-0000-0000-0000-000000000001','{"type":"human","content":"nova"}', now());
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 1000) where precisa and ate is not null;
select texto from app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', (select ate from crystal_memoria_ficha where customer_id='aaaaaaaa-0000-0000-0000-000000000001'), 100);
\echo '--- 11 erro na A com ficha: continua ok e com ficha; tentativas 1'
select app_ficha_gravar('aaaaaaaa-0000-0000-0000-000000000001',null,null,0,0.001,null,'erro','limite');
select estado, ficha, tentativas, custo_usd from crystal_memoria_ficha where customer_id='aaaaaaaa-0000-0000-0000-000000000001';
\echo '--- 12 B com 3 erros sai da fila'
select app_ficha_gravar('bbbbbbbb-0000-0000-0000-000000000002',null,null,0,0,null,'erro','x') from generate_series(1,3);
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 1000) where precisa;
\echo '--- 13 C vazio sem custo: sai da fila'
select app_ficha_gravar('cccccccc-0000-0000-0000-000000000003',null,null,0,0,'-','vazio');
select string_agg(left(customer_id::text,1), ',') from app_ficha_fila(null, 1000) where precisa;
\echo '--- 14 memoria_ler A traz ficha e fatos'
select app_memoria_ler('aaaaaaaa-0000-0000-0000-000000000001')::jsonb - 'whatsapp_ficha_ate';
\echo '--- 15 andamento'
select app_ficha_andamento()::jsonb - 'ultima_em';
\echo '--- 16 validacoes (esperado 4 erros)'
do $$ begin
  begin perform app_ficha_gravar('aaaaaaaa-0000-0000-0000-000000000001', repeat('z',4001), now(),1,0,'m','ok'); raise notice 'FALHOU'; exception when others then raise notice 'ok: %', sqlerrm; end;
  begin perform app_ficha_gravar('aaaaaaaa-0000-0000-0000-000000000001', 'x', now(),1,0,'m','outro'); raise notice 'FALHOU'; exception when others then raise notice 'ok: %', sqlerrm; end;
  begin perform app_ficha_fila(null, 0); raise notice 'FALHOU'; exception when others then raise notice 'ok: %', sqlerrm; end;
  begin perform app_ficha_historico('aaaaaaaa-0000-0000-0000-000000000001', null, 6000); raise notice 'FALHOU'; exception when others then raise notice 'ok: %', sqlerrm; end;
end $$;
\echo '--- 17 permissoes'
set role service_role;
select count(*) >= 0 from app_ficha_fila(null, 5);
do $$ begin
  begin perform 1 from crystal_memoria_ficha; raise notice 'FALHOU tabela'; exception when insufficient_privilege then raise notice 'ok: tabela fechada'; end;
  begin perform 1 from app_ficha_alvos(); raise notice 'FALHOU alvos'; exception when insufficient_privilege then raise notice 'ok: alvos fechada'; end;
end $$;
reset role;
set role anon;
do $$ begin
  begin perform app_ficha_fila(null, 5); raise notice 'FALHOU anon'; exception when insufficient_privilege then raise notice 'ok: anon barrado'; end;
  begin perform app_memoria_ler('aaaaaaaa-0000-0000-0000-000000000001'); raise notice 'FALHOU anon ler'; exception when insufficient_privilege then raise notice 'ok: anon barrado ler'; end;
end $$;
reset role;
\echo '--- 18 apagar (LGPD)'
select app_memoria_apagar('aaaaaaaa-0000-0000-0000-000000000001');
select count(*) from crystal_memoria_ficha where customer_id='aaaaaaaa-0000-0000-0000-000000000001';
