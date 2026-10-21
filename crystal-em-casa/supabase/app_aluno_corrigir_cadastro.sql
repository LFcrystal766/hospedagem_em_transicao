-- =============================================================================
-- Autonomia do suporte na ficha do aluno: corrigir nome, WhatsApp e CPF da base e liberar
-- à mão quem comprou e não está na base (pedido do dono, 21/10/2026)
-- =============================================================================
-- NÃO APLICADO. Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez,
-- DEPOIS de conferir a seção "Antes de rodar" no fim. A API chama esta função pela API REST
-- (POST /rest/v1/rpc/app_aluno_corrigir_cadastro) com a chave service_role, que fica só na VPS.
-- Contrato do lado do app: crystal-web-chat apps/api/src/services/base-alunos.ts
-- (corrigirCadastro, corrigirCpf, liberarManual) e apps/api/src/routes/staff-alunos-cadastro.ts.
-- Variável de ambiente do app (opcional, tem padrão): SUPABASE_ALUNO_CORRIGIR_CADASTRO_RPC.
--
-- UMA função, três operações (mesma busca do aluno, mesma conferência de esquema, um grant só):
--
--   p_operacao = 'corrigir'         p_contact_id = id do aluno (crystalContactId da conta no app)
--     p_dados: { "nome": "...", "telefone": "+5548988504130" }   (só as chaves presentes mudam)
--     -> {"status":"corrigido","origem":"base"|"compra","nome":bool,"telefone":bool,
--         "telefone_no_login": true|false|null}
--        {"status":"nao_achado"}
--     base antiga   : leticia_crystal_customers.full_name e .phone_from_gateway (só dígitos)
--     compra        : crystal_compras.nome e .telefone ("+" e dígitos, como o app_compra_evento grava)
--     `telefone_no_login`: depois de gravar, a função pergunta ao próprio app_verificar_login_email (a
--     função de login da produção) qual número o login vai devolver para este e-mail. false = o login
--     ainda lê OUTRO número (hoje, para a base antiga, o login lê primeiro
--     leticia_crystal_active_accesses.phone_number, a tabela de acessos da agência, e só depois
--     phone_from_gateway; e ele põe +55 em número de 10 ou 11 dígitos que não começa por 55). Aí o app
--     avisa a pessoa do suporte e NÃO muda o WhatsApp da conta (o próximo login o desfaria). null = o
--     telefone não foi pedido.
--
--   p_operacao = 'cpf'              p_contact_id = id do aluno
--     p_dados: { "cpf": "39053344705" }   (com ou sem pontuação; 11 dígitos, dígitos verificadores certos)
--     -> {"status":"corrigido","origem":"base","gravado":true}     base antiga: leticia_crystal_customers.cpf
--        {"status":"corrigido","origem":"compra","gravado":false}  compra não guarda CPF: só o app muda
--        {"status":"nao_achado"}
--     Recusas (raise exception, o PostgREST responde 400 ou 409): CPF_INVALIDO, CPF_EM_USO (outro
--     cadastro da base antiga já tem esse CPF). Diferente de app_equipe_definir_cpf, que só preenche CPF
--     vazio (CPF_JA_INFORMADO), esta TROCA o CPF; o painel só chama depois do código do e-mail.
--     Por que a mesma função e não outra: é uma coluna só da base antiga, a busca do aluno é a mesma, e a
--     operação é uma entrada própria (nunca vai junto com nome e telefone), com recusas próprias. Mesma
--     superfície, um grant, e a diferença de risco está no app (reautenticação), não aqui.
--
--   p_operacao = 'liberar_manual'   p_contact_id = null
--     p_dados: { "email": "...", "nome": "...", "telefone": "+55..." (opcional),
--                "referencia": "<nº da transação ou da assinatura>" (opcional),
--                "referencia_tipo": "transacao" | "assinatura" (padrão transacao) }
--     -> {"status":"liberado","contact_id":"<uuid>","origem":"compra"}
--        {"status":"ja_existe","situacao":"ativa"|"bloqueada"}   o e-mail já tem linha em crystal_compras
--        {"status":"email_na_base"}                             o e-mail é de um cadastro da base antiga
--        {"status":"transacao_reembolsada"}                     a referência já tem reembolso/cancelamento
--     Cria UMA linha em crystal_compras: status active, produto 'Liberação manual', transacao ou
--     assinatura = a referência (se vier), liberado_em = agora. O login só com e-mail
--     (app_verificar_login_email) acha essa linha como qualquer compra ativa e devolve o id dela como
--     contact_id; o app já cria a conta ligada a esse id. Nada de produto_id: a lista
--     crystal_compras_produtos só filtra eventos da Assiny. O PRAZO não mora aqui (crystal_compras não
--     tem coluna de prazo e o login não olharia): mora na conta do app ("Acesso até"), que o login e a
--     renovação de sessão conferem.
--     Se a mesma pessoa comprar de verdade depois (evento da Assiny com o mesmo e-mail), o app_compra_evento
--     atualiza esta linha (produto, transação) e ela vira uma compra comum. Se a referência bate com a
--     transação do reembolso do MESMO e-mail, o reembolso bloqueia a linha; reembolso em outro e-mail não
--     alcança esta linha (o corte dos acessos reembolsados é o do app, por e-mail).
--
-- Regras comuns:
--   - security definer, search_path fixo; só service_role executa (public, anon e authenticated revogados);
--   - nome: 2 a 120 caracteres, espaços repetidos viram um, sem caractere de controle (NOME_INVALIDO);
--   - telefone: E.164 (+, depois 8 a 15 dígitos, o primeiro de 1 a 9) (TELEFONE_INVALIDO);
--   - e-mail: lower/trim, até 200, formato conferido (EMAIL_INVALIDO); referência: 3 a 80 de A-Z a-z 0-9 . _ : -
--     (REFERENCIA_INVALIDA); nada a mudar em 'corrigir' (NADA_A_ALTERAR); outra operação (OPERACAO_INVALIDA);
--   - atualiza `updated_at` da base antiga só se a coluna existir, e `atualizado_em` de crystal_compras;
--   - nada é registrado aqui: a auditoria fica no app (audit_log), só com ids, nomes dos campos e o motivo.
--
-- O que NÃO muda: o id, o e-mail, o status, o lote (is_in_rollout), as assinaturas e a tabela de acessos da
-- agência (leticia_crystal_active_accesses) nunca são escritos aqui.
--
-- Volta (no fim do arquivo): apagar a função; desfazer uma liberação manual; desfazer uma correção.
-- =============================================================================

do $$
declare
  v_falta text;
begin
  select string_agg(format('%s.%s', x.tabela, x.coluna), ', ')
    into v_falta
    from (values
      ('leticia_crystal_customers', 'id'), ('leticia_crystal_customers', 'email'),
      ('leticia_crystal_customers', 'full_name'), ('leticia_crystal_customers', 'phone_from_gateway'),
      ('leticia_crystal_customers', 'cpf'),
      ('crystal_compras', 'id'), ('crystal_compras', 'email'), ('crystal_compras', 'nome'),
      ('crystal_compras', 'telefone'), ('crystal_compras', 'status'), ('crystal_compras', 'produto'),
      ('crystal_compras', 'transacao'), ('crystal_compras', 'assinatura'), ('crystal_compras', 'liberado_em'),
      ('crystal_compras', 'atualizado_em'),
      ('crystal_compras_eventos', 'transacao'), ('crystal_compras_eventos', 'assinatura'),
      ('crystal_compras_eventos', 'acao')
    ) as x(tabela, coluna)
   where not exists (
     select 1 from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = x.tabela and c.column_name = x.coluna
   );
  if v_falta is not null then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'não encontrei: ' || v_falta || ' (rodar app_compras.sql antes)';
  end if;
  if to_regprocedure('public.app_verificar_login_email(text)') is null then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'falta public.app_verificar_login_email(text) (rodar app_compras.sql antes)';
  end if;
end;
$$;

create or replace function public.app_aluno_corrigir_cadastro(
  p_operacao   text,
  p_contact_id text  default null,
  p_dados      jsonb default '{}'::jsonb
)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_op      text  := lower(btrim(coalesce(p_operacao, '')));
  v_dados   jsonb := coalesce(p_dados, '{}'::jsonb);
  v_id      uuid;
  v_email   text;
  v_nome    text;
  v_tel     text;
  v_cpf     text;
  v_ref     text;
  v_tipo    text;
  v_status  text;
  v_novo    uuid;
  v_login_tel text;
  v_achou_login boolean;
  v_origem  text;
  v_tem_nome boolean;
  v_tem_tel  boolean;
  v_tem_updated_at boolean;
  v_soma    int;
  v_resto   int;
  i         int;
  v_sets    text;
begin
  if jsonb_typeof(v_dados) is distinct from 'object' then
    raise exception 'DADOS_INVALIDOS';
  end if;

  -- ---------------------------------------------------------------------------
  -- liberar_manual: comprador fora da base
  -- ---------------------------------------------------------------------------
  if v_op = 'liberar_manual' then
    v_email := lower(btrim(coalesce(v_dados->>'email', '')));
    if length(v_email) > 200 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception 'EMAIL_INVALIDO';
    end if;
    v_nome := regexp_replace(btrim(coalesce(v_dados->>'nome', '')), '\s+', ' ', 'g');
    if jsonb_typeof(v_dados->'nome') is distinct from 'string'
       or length(v_nome) not between 2 and 120 or v_nome ~ '[[:cntrl:]]' then
      raise exception 'NOME_INVALIDO';
    end if;
    if v_dados ? 'telefone' and jsonb_typeof(v_dados->'telefone') <> 'null' then
      v_tel := btrim(coalesce(v_dados->>'telefone', ''));
      if jsonb_typeof(v_dados->'telefone') <> 'string' or v_tel !~ '^\+[1-9][0-9]{7,14}$' then
        raise exception 'TELEFONE_INVALIDO';
      end if;
    end if;
    v_ref := nullif(btrim(coalesce(v_dados->>'referencia', '')), '');
    v_tipo := coalesce(nullif(btrim(coalesce(v_dados->>'referencia_tipo', '')), ''), 'transacao');
    if v_tipo not in ('transacao', 'assinatura') or (v_ref is not null and v_ref !~ '^[A-Za-z0-9._:-]{3,80}$') then
      raise exception 'REFERENCIA_INVALIDA';
    end if;

    -- Cadastro da base antiga com esse e-mail (a mesma comparação do login): outro caminho, na aba Base de alunos.
    if exists (select 1 from public.leticia_crystal_customers c where lower(btrim(c.email)) = v_email) then
      return json_build_object('status', 'email_na_base');
    end if;
    -- Já tem linha em crystal_compras: ativa (entra sozinho) ou bloqueada (reembolso, cancelamento): não se reabre à mão.
    select k.status into v_status from public.crystal_compras k where k.email = v_email;
    if found then
      return json_build_object('status', 'ja_existe', 'situacao', case when v_status = 'active' then 'ativa' else 'bloqueada' end);
    end if;
    -- A mesma regra do app_compra_evento: referência que já teve reembolso ou cancelamento não libera.
    if v_ref is not null and exists (
      select 1 from public.crystal_compras_eventos e
       where e.acao = 'bloquear'
         and case when v_tipo = 'transacao' then e.transacao else e.assinatura end = v_ref
    ) then
      return json_build_object('status', 'transacao_reembolsada');
    end if;

    begin
      insert into public.crystal_compras as k
        (email, nome, telefone, status, produto, transacao, assinatura, liberado_em)
      values
        (v_email, v_nome, v_tel, 'active', 'Liberação manual',
         case when v_tipo = 'transacao' then v_ref end,
         case when v_tipo = 'assinatura' then v_ref end,
         now())
      returning k.id into v_novo;
    exception when unique_violation then
      return json_build_object('status', 'ja_existe', 'situacao', 'ativa');
    end;
    return json_build_object('status', 'liberado', 'contact_id', v_novo::text, 'origem', 'compra');
  end if;

  if v_op not in ('corrigir', 'cpf') then
    raise exception 'OPERACAO_INVALIDA';
  end if;

  -- ---------------------------------------------------------------------------
  -- corrigir e cpf: o aluno pelo id (base antiga primeiro, depois compras: a mesma ordem do login)
  -- ---------------------------------------------------------------------------
  begin
    v_id := btrim(coalesce(p_contact_id, ''))::uuid;
  exception when invalid_text_representation then
    return json_build_object('status', 'nao_achado');
  end;

  if v_op = 'corrigir' then
    v_tem_nome := v_dados ? 'nome';
    v_tem_tel := v_dados ? 'telefone';
    if not (v_tem_nome or v_tem_tel) then
      raise exception 'NADA_A_ALTERAR';
    end if;
    if v_tem_nome then
      v_nome := regexp_replace(btrim(coalesce(v_dados->>'nome', '')), '\s+', ' ', 'g');
      if jsonb_typeof(v_dados->'nome') is distinct from 'string'
         or length(v_nome) not between 2 and 120 or v_nome ~ '[[:cntrl:]]' then
        raise exception 'NOME_INVALIDO';
      end if;
    end if;
    if v_tem_tel then
      v_tel := btrim(coalesce(v_dados->>'telefone', ''));
      if jsonb_typeof(v_dados->'telefone') is distinct from 'string' or v_tel !~ '^\+[1-9][0-9]{7,14}$' then
        raise exception 'TELEFONE_INVALIDO';
      end if;
    end if;

    select c.email into v_email from public.leticia_crystal_customers c where c.id = v_id;
    if found then
      v_origem := 'base';
      select exists (
        select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'leticia_crystal_customers' and column_name = 'updated_at'
      ) into v_tem_updated_at;
      -- Só as colunas pedidas; o número vai só em dígitos, como o login o espera (ele põe o + e o 55).
      v_sets := concat_ws(', ',
        case when v_tem_nome then 'full_name = $2' end,
        case when v_tem_tel then 'phone_from_gateway = $3' end,
        case when v_tem_updated_at then 'updated_at = now()' end);
      execute format('update public.leticia_crystal_customers set %s where id = $1', v_sets)
        using v_id, v_nome, substr(v_tel, 2);
    else
      select k.email into v_email from public.crystal_compras k where k.id = v_id;
      if not found then
        return json_build_object('status', 'nao_achado');
      end if;
      v_origem := 'compra';
      update public.crystal_compras k
         set nome = case when v_tem_nome then v_nome else k.nome end,
             telefone = case when v_tem_tel then v_tel else k.telefone end,
             atualizado_em = now()
       where k.id = v_id;
    end if;

    if v_tem_tel then
      -- O que o login vai devolver para este e-mail DEPOIS da gravação (a função de login da produção).
      select l.phone into v_login_tel from public.app_verificar_login_email(v_email) l limit 1;
      v_achou_login := found;
      return json_build_object('status', 'corrigido', 'origem', v_origem, 'nome', v_tem_nome, 'telefone', true,
                               'telefone_no_login', (not v_achou_login) or v_login_tel is not distinct from v_tel);
    end if;
    return json_build_object('status', 'corrigido', 'origem', v_origem, 'nome', v_tem_nome, 'telefone', false,
                             'telefone_no_login', null);
  end if;

  -- cpf
  v_cpf := regexp_replace(coalesce(v_dados->>'cpf', ''), '\D', '', 'g');
  -- A mesma validação do app (packages/shared/src/cpf.ts): 11 dígitos, não todos iguais, os dois verificadores.
  if jsonb_typeof(v_dados->'cpf') is distinct from 'string' or length(v_cpf) <> 11 or v_cpf ~ '^(\d)\1{10}$' then
    raise exception 'CPF_INVALIDO';
  end if;
  v_soma := 0;
  for i in 1..9 loop
    v_soma := v_soma + substr(v_cpf, i, 1)::int * (11 - i);
  end loop;
  v_resto := (v_soma * 10) % 11;
  if v_resto = 10 then v_resto := 0; end if;
  if v_resto <> substr(v_cpf, 10, 1)::int then
    raise exception 'CPF_INVALIDO';
  end if;
  v_soma := 0;
  for i in 1..10 loop
    v_soma := v_soma + substr(v_cpf, i, 1)::int * (12 - i);
  end loop;
  v_resto := (v_soma * 10) % 11;
  if v_resto = 10 then v_resto := 0; end if;
  if v_resto <> substr(v_cpf, 11, 1)::int then
    raise exception 'CPF_INVALIDO';
  end if;

  if exists (select 1 from public.leticia_crystal_customers c where c.id = v_id) then
    if exists (
      select 1 from public.leticia_crystal_customers o
       where o.id <> v_id and regexp_replace(coalesce(o.cpf::text, ''), '\D', '', 'g') = v_cpf
    ) then
      raise exception 'CPF_EM_USO' using errcode = 'unique_violation';
    end if;
    select exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'leticia_crystal_customers' and column_name = 'updated_at'
    ) into v_tem_updated_at;
    begin
      if v_tem_updated_at then
        execute 'update public.leticia_crystal_customers set cpf = $1, updated_at = now() where id = $2' using v_cpf, v_id;
      else
        update public.leticia_crystal_customers c set cpf = v_cpf where c.id = v_id;
      end if;
    exception when unique_violation then
      -- uq_customers_cpf: alguém gravou o mesmo CPF entre a conferência e o update.
      raise exception 'CPF_EM_USO' using errcode = 'unique_violation';
    end;
    return json_build_object('status', 'corrigido', 'origem', 'base', 'gravado', true);
  end if;

  if exists (select 1 from public.crystal_compras k where k.id = v_id) then
    return json_build_object('status', 'corrigido', 'origem', 'compra', 'gravado', false);
  end if;

  return json_build_object('status', 'nao_achado');
end;
$$;

comment on function public.app_aluno_corrigir_cadastro(text, text, jsonb) is
  'painel 21/10/2026: corrige nome, WhatsApp e CPF de aluno da base e libera à mão comprador fora da base. Só service_role.';

revoke all on function public.app_aluno_corrigir_cadastro(text, text, jsonb) from public;
revoke all on function public.app_aluno_corrigir_cadastro(text, text, jsonb) from anon, authenticated;
grant execute on function public.app_aluno_corrigir_cadastro(text, text, jsonb) to service_role;

notify pgrst, 'reload schema';

-- =============================================================================
-- Antes de rodar (só leitura, nenhum dado de aluno sai)
-- =============================================================================
--   1. As colunas existem (o bloco do começo do arquivo já recusa se faltar alguma). Para ver o tipo de
--      phone_from_gateway e de cpf (a função grava texto):
--        select column_name, data_type from information_schema.columns
--         where table_schema = 'public' and table_name = 'leticia_crystal_customers'
--           and column_name in ('phone_from_gateway', 'cpf', 'updated_at');
--   2. Quem fornece o número no login (explica o `telefone_no_login`). Quantos alunos com acesso ativo ou
--      pendente têm a linha de acessos da agência COM telefone, e portanto NÃO mudam de número só por
--      phone_from_gateway:
--        select count(*) from public.leticia_crystal_customers c
--         where exists (select 1 from public.leticia_crystal_active_accesses a
--                        where a.customer_id = c.id and a.subscription_status in ('active', 'pending')
--                          and length(regexp_replace(coalesce(a.phone_number, ''), '\D', '', 'g')) >= 10);
--   3. leticia_crystal_active_accesses é tabela ou visão? (se for tabela, a agência/n8n ainda a atualiza)
--        select table_type from information_schema.tables
--         where table_schema = 'public' and table_name = 'leticia_crystal_active_accesses';
--
-- =============================================================================
-- Conferências depois de criar (só contagens e booleanos, nenhum dado de aluno)
-- =============================================================================
--   select count(*) = 1 as funcao_existe
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'app_aluno_corrigir_cadastro';                       -- esperado: true
--   select has_function_privilege('service_role', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute') as service_role,
--          has_function_privilege('anon', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute') as anon,
--          has_function_privilege('authenticated', 'public.app_aluno_corrigir_cadastro(text, text, jsonb)', 'execute') as authenticated;
--                                                                                                    -- esperado: true, false, false
--   select p.prosecdef as security_definer from pg_proc p
--    where p.proname = 'app_aluno_corrigir_cadastro';                                                 -- esperado: true
--   -- Recusas que não gravam nada (esperado: o erro de cada linha, nenhuma linha alterada):
--   select public.app_aluno_corrigir_cadastro('cpf', '00000000-0000-0000-0000-000000000000', '{"cpf":"111.111.111-11"}'); -- CPF_INVALIDO
--   select public.app_aluno_corrigir_cadastro('corrigir', '00000000-0000-0000-0000-000000000000', '{}');                  -- NADA_A_ALTERAR
--   select public.app_aluno_corrigir_cadastro('cpf', '00000000-0000-0000-0000-000000000000', '{"cpf":"39053344705"}');    -- {"status":"nao_achado"}
--   select public.app_aluno_corrigir_cadastro('x', null, '{}');                                                           -- OPERACAO_INVALIDA
--   -- Contagens iguais às de antes (a conferência acima não grava nada):
--   select (select count(*) from public.leticia_crystal_customers) as base_antiga,
--          (select count(*) from public.crystal_compras) as compras;
--
-- =============================================================================
-- Volta
-- =============================================================================
--   Tirar a função (o painel passa a responder 503 só nessas três ações; o resto da ficha continua):
--     drop function if exists public.app_aluno_corrigir_cadastro(text, text, jsonb);
--
--   Desfazer UMA liberação manual (o aluno deixa de entrar na hora do próximo login; desligar a conta no
--   painel corta também a sessão aberta). A linha fica com o histórico, só bloqueada (sem dado novo):
--     update public.crystal_compras
--        set status = 'canceled', bloqueado_em = now(), atualizado_em = now()
--      where email = '<e-mail>' and produto = 'Liberação manual';
--   Conferir quantas liberações manuais existem e quantas seguem ativas (só contagens):
--     select status, count(*) from public.crystal_compras where produto = 'Liberação manual' group by 1;
--
--   Desfazer UMA correção: o painel corrige de novo com o valor anterior (a função é a mesma); a auditoria do
--   app guarda quem corrigiu o quê e quando (só nomes de campos), nunca o valor.
-- =============================================================================
