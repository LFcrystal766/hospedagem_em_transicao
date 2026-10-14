-- =============================================================================
-- Trocar o e-mail de LOGIN de um aluno da base, pelo painel (pedido do dono, 14/10/2026)
-- =============================================================================
-- Rodar no SQL Editor do projeto "Crystal AI", o arquivo inteiro de uma vez. A API chama
-- esta função pela API REST (POST /rest/v1/rpc/app_aluno_trocar_email) com a chave
-- service_role, que fica só na VPS. Contrato do lado do app: crystal-web-chat
-- apps/api/src/services/base-alunos.ts (trocarEmailLogin) e PATCH /staff/alunos/:id.
--
-- Por que existe: no login só com e-mail (LOGIN_MODO=email) o app procura o e-mail em
-- app_verificar_login_email, que devolve `contact_id` = leticia_crystal_customers.id::text
-- (base antiga) ou crystal_compras.id::text (compras da Assiny). Esse id é a identidade da
-- conta no app (crystalContactId). Trocar o e-mail AQUI, mantendo o mesmo id, faz o próximo
-- login com o e-mail novo achar a MESMA conta. O suporte e o admin fazem isso pelo painel,
-- depois de conferir a identidade (CPF) com a pessoa.
--
-- Entrada : p_contact_id text (o id; uuid em texto), p_email_novo text.
-- Saída   : json
--   {"status":"trocado","origem":"base"|"compra"}
--   {"status":"email_em_uso"}   outro cadastro (base antiga ou compras) já tem esse e-mail
--   {"status":"nao_achado"}     nenhum cadastro com esse id
-- Formato de e-mail inválido: raise exception 'EMAIL_INVALIDO' (o PostgREST responde 400).
--
-- Regras:
--   - e-mail normalizado (lower/trim), no máximo 200 caracteres, formato conferido;
--   - base antiga primeiro, depois crystal_compras (a mesma ordem do login);
--   - recusa se OUTRO cadastro, em qualquer das duas tabelas, já tem o e-mail novo;
--   - atualiza `updated_at` (base antiga) só se a coluna existir, e `atualizado_em`
--     (crystal_compras);
--   - nada é registrado aqui: a auditoria fica no app (sem e-mail, só campos e origem).
--
-- O que NÃO muda: nome, telefone, CPF, status, lote, o id. Volta: rodar de novo com o e-mail
-- antigo (a função é a mesma), ou `drop function public.app_aluno_trocar_email(text, text);`.
-- =============================================================================

do $$
declare
  v_falta text;
begin
  select string_agg(format('%s.%s', x.tabela, x.coluna), ', ')
    into v_falta
    from (values
      ('leticia_crystal_customers', 'id'), ('leticia_crystal_customers', 'email'),
      ('crystal_compras', 'id'), ('crystal_compras', 'email'), ('crystal_compras', 'atualizado_em')
    ) as x(tabela, coluna)
   where not exists (
     select 1 from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = x.tabela and c.column_name = x.coluna
   );
  if v_falta is not null then
    raise exception 'ESQUEMA_DIFERENTE' using hint = 'não encontrei: ' || v_falta || ' (rodar app_compras.sql antes)';
  end if;
end;
$$;

create or replace function public.app_aluno_trocar_email(p_contact_id text, p_email_novo text)
returns json
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  v_email text := lower(trim(coalesce(p_email_novo, '')));
  v_id    uuid;
  v_tem_updated_at boolean;
begin
  if length(v_email) > 200 or v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'EMAIL_INVALIDO';
  end if;

  begin
    v_id := trim(coalesce(p_contact_id, ''))::uuid;
  exception when invalid_text_representation then
    return json_build_object('status', 'nao_achado');
  end;

  -- Base antiga.
  if exists (select 1 from public.leticia_crystal_customers c where c.id = v_id) then
    if exists (select 1 from public.leticia_crystal_customers o where o.id <> v_id and lower(trim(o.email)) = v_email)
       or exists (select 1 from public.crystal_compras k where k.email = v_email) then
      return json_build_object('status', 'email_em_uso');
    end if;
    select exists (
      select 1 from information_schema.columns
       where table_schema = 'public' and table_name = 'leticia_crystal_customers' and column_name = 'updated_at'
    ) into v_tem_updated_at;
    begin
      if v_tem_updated_at then
        execute 'update public.leticia_crystal_customers set email = $1, updated_at = now() where id = $2' using v_email, v_id;
      else
        update public.leticia_crystal_customers set email = v_email where id = v_id;
      end if;
    exception when unique_violation then
      return json_build_object('status', 'email_em_uso');
    end;
    return json_build_object('status', 'trocado', 'origem', 'base');
  end if;

  -- Compras da Assiny (nosso n8n).
  if exists (select 1 from public.crystal_compras k where k.id = v_id) then
    if exists (select 1 from public.crystal_compras k where k.id <> v_id and k.email = v_email)
       or exists (select 1 from public.leticia_crystal_customers o where lower(trim(o.email)) = v_email) then
      return json_build_object('status', 'email_em_uso');
    end if;
    begin
      update public.crystal_compras set email = v_email, atualizado_em = now() where id = v_id;
    exception when unique_violation then
      return json_build_object('status', 'email_em_uso');
    end;
    return json_build_object('status', 'trocado', 'origem', 'compra');
  end if;

  return json_build_object('status', 'nao_achado');
end;
$$;

revoke all on function public.app_aluno_trocar_email(text, text) from public;
revoke all on function public.app_aluno_trocar_email(text, text) from anon, authenticated;
grant execute on function public.app_aluno_trocar_email(text, text) to service_role;

notify pgrst, 'reload schema';

-- Conferências depois de criar (só contagens, nenhum dado de aluno):
--   select count(*) = 1 as funcao_existe
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public' and p.proname = 'app_aluno_trocar_email';          -- esperado: true
--   select has_function_privilege('service_role', 'public.app_aluno_trocar_email(text, text)', 'execute') as service_role,
--          has_function_privilege('anon', 'public.app_aluno_trocar_email(text, text)', 'execute') as anon,
--          has_function_privilege('authenticated', 'public.app_aluno_trocar_email(text, text)', 'execute') as authenticated;
--                                                                                 -- esperado: true, false, false
--   select (select count(*) from public.leticia_crystal_customers) as base_antiga,
--          (select count(*) from public.crystal_compras) as compras;               -- iguais às de antes
