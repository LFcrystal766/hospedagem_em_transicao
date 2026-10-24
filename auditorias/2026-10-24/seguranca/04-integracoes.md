# Revisão de segurança 24/10/2026 · 04 · Webhooks, integrações e a cadeia de compra

Só leitura. Código revisado: `LFcrystal766/crystal-web-chat` no commit `fe6dbd7` (o que está no ar), o fluxo do n8n
`crystal-em-casa/n8n/compra-assiny.json`, as funções do Supabase em `crystal-em-casa/supabase/*.sql` e os roteiros da
VPS. Nenhum serviço de produção foi chamado e não houve acesso a banco: o que está escrito sobre o Supabase vem dos
arquivos SQL do repositório, não do estado real (os pontos "a confirmar" dizem como conferir). Nenhum segredo nem
dado de aluno aparece aqui.

Prova executável (um arquivo de teste novo, não altera nada do app):
`apps/api/src/seguranca-webhooks.test.ts`, rodado com `pnpm --filter @crystal/api exec vitest run src/seguranca-webhooks.test.ts`
(o filtro `api` não acha o pacote, que se chama `@crystal/api`). Os testes marcados `it.fails` descrevem o
comportamento DESEJADO e falham hoje: são a prova dos achados INT-02, INT-03 e INT-05. Quando a correção entrar, eles
passam a ser `it`. Os demais confirmam o que está certo.

## Em linguagem simples (para o dono)

A cadeia é: a aluna paga na **Assiny** → a Assiny avisa o **nosso n8n** → o n8n grava no **Supabase** (`app_compra_evento`) →
o n8n manda e-mail de boas-vindas (**Resend**) e, no reembolso, pede à **API do app** para desligar a conta
(`/webhooks/reembolso`); pacote de imagens vai para `/webhooks/imagens`. Por fora disso, o **Chatwoot** chama a API
(`/webhooks/chatwoot-bot` e `/webhooks/chatwoot`) e a API chama Supabase, Resend, ActiveDev, FCM e OpenRouter.

O que encontrei, do mais sério para o menos:

1. **Quem tiver o token que a Assiny usa manda no acesso de todo mundo** (INT-06). O n8n confia em tudo que vem no
   corpo do aviso da Assiny, protegido só por uma senha fixa num cabeçalho. Quem souber essa senha (ela fica na
   Assiny, no n8n e num arquivo da VPS) consegue: criar acesso grátis para qualquer e-mail (basta copiar o id de um
   produto da Crystal, que aparece em qualquer recibo) e mandar o e-mail "Seu acesso está liberado" com texto que ele
   escolher, saindo do remetente oficial; ou **bloquear qualquer aluna** mandando um "reembolso" com o e-mail dela
   (a função do Supabase grava a aluna como reembolsada mesmo sem compra nossa, e o login passa a recusar). A Assiny
   não assina os avisos, então a defesa é conferir a compra na própria Assiny antes de liberar, e restringir de onde
   o aviso pode vir.
2. **Um segredo só abre duas portas, e um aviso antigo pode ser reaproveitado** (INT-01, INT-02). O mesmo segredo
   serve para desligar alunas e para dar crédito de imagens. Ele é fixo (não tem data nem assinatura), então um
   pedido capturado pode ser reenviado para sempre; a API só ignora o reenvio por 30 dias. Se a equipe religar uma
   aluna depois de um reembolso indevido, o mesmo aviso reenviado 31 dias depois a desliga de novo (teste INT-02).
3. **Reembolso que não chega ao app deixa a aluna dentro por até 90 dias** (INT-09). O n8n responde "ok" à Assiny
   antes de avisar a API. Se a API estiver reiniciando (um deploy leva mais que os 6 segundos de tentativas), o
   bloqueio no Supabase acontece, mas a conta do app continua ativa e a sessão dela renova por 90 dias sem olhar a
   base de novo. Não existe nenhuma rotina que compare as duas pontas depois.
4. **O "pré-bloqueio" pode trancar a aluna errada** (INT-03). Quando um reembolso vem com CPF que nunca entrou e o
   e-mail de uma aluna que existe, a API desliga a aluna e ainda cria uma segunda conta "Aluno", desligada, com o
   mesmo e-mail. Depois que a equipe religa a aluna, o login (que procura a conta pelo e-mail, sem ordem definida)
   pode cair na conta fantasma e responder "acesso desligado" sem explicação (teste INT-03).
5. **O n8n guarda chaves fortes demais e dados pessoais demais** (INT-07, INT-08). O n8n tem a chave mestra do
   Supabase (`service_role`, que lê a base inteira da agência com CPF e telefone), a chave do Resend (que também vai
   para o Chatwoot) e o segredo do reembolso, quando só precisa executar uma função. E cada aviso da Assiny (CPF,
   e-mail, telefone, nome, IP) fica gravado 14 dias no histórico de execuções do n8n.
6. **Crédito de imagens em ordem invertida** (INT-05). Se o estorno chegar antes da compra (ou a Assiny reenviar a
   compra depois do estorno), o pacote é creditado mesmo assim (teste INT-05). Dinheiro pequeno, mas é bug.
7. **A confirmar com urgência no Supabase** (INT-14): se o RLS das tabelas da agência (`leticia_crystal_*`) estiver
   desligado, a chave pública `anon` lê CPF, e-mail e telefone de ~11 mil alunas e a base de conhecimento inteira.
   O repositório não guarda essa conferência; o item traz o SQL de um minuto para fechar a dúvida.

O que está bem feito aparece no fim: o Chatwoot é assinado com HMAC e janela de 5 minutos, nenhum endereço de
integração é editável pelo painel (sem SSRF), as funções do Supabase são `security definer` com `search_path` fixo
e execute só para `service_role`, o telefone da aluna não é editável por ela, links de banner e de aviso só aceitam
`https://` ou caminho do app, e o push só fala com os serviços conhecidos.

## Tabela técnica

Gravidade: **Alta** (dá acesso, bloqueia pessoas ou expõe dado pessoal com uma condição plausível), **Média** (precisa de
um segredo ou de uma coincidência, ou amplia muito o estrago de outra falha), **Baixa** (bug real de impacto pequeno
ou superfície desnecessária), **Info** (propriedade do desenho que a equipe precisa conhecer).

| id | gravidade | arquivo:linha | cenário | prova | correção proposta |
|---|---|---|---|---|---|
| INT-06 | **Alta** | `crystal-em-casa/n8n/compra-assiny.json` (nó "Assiny": `authentication: headerAuth`; nó "Registrar no Supabase": `jsonBody = { p_evento: $json.body }`; nó "E-mail de boas-vindas": `first_name` entra no texto); `supabase/app_compras.sql:139-147,194-221,229-246`; `app_verificar_login_email.producao-20261016.sql` (CTE `bloqueio`) | A Assiny não assina o aviso; a única defesa é um token fixo num cabeçalho (`x-crystal-token`) mais um sufixo secreto no caminho. Com o token, (a) `approved_purchase` forjado com o id de um produto da lista (público em recibos/checkout) cria linha ativa em `crystal_compras` para qualquer e-mail → login liberado; (b) o e-mail de boas-vindas sai do remetente oficial com `first_name` controlado pelo atacante; (c) `refunded_purchase` forjado para o e-mail de uma aluna da base antiga cria linha bloqueada (`c.transacao is null` casa a linha nova) → a função de login em produção devolve `liberado = false` (CTE `bloqueio`, linhas 18-27 e 97) e a API responde 403 enquanto `op_rollout_gate` estiver `on` (ver INT-21); o n8n ainda chama `/webhooks/reembolso`, desligando a conta do app | Leitura do fluxo e da função. O corpo não é validado além de `event` e e-mail; nome, telefone e transação entram sem limite de tamanho | (1) Confirmar a transação na API da Assiny (GET pela `transaction.id`) antes de `liberar`/`bloquear`: o n8n só repassa ao Supabase o que a Assiny confirmar; (2) se a Assiny publicar IPs de saída, restringir `webhook.crystalnowpp.com.br/webhook/assiny-compras*` a eles no Traefik; (3) sanear `first_name` (só letras, 60 caracteres) e não usar texto do evento no e-mail; (4) limitar `nome`/`telefone`/`transacao` na função (`length`); (5) alerta por e-mail quando houver mais de N `liberado` ou `bloqueado` por hora; (6) rotacionar o token (o script `--novo-token` já existe) |
| INT-14 | **Alta se confirmado** (a confirmar) | `supabase/app_conhecimento_editar.sql:129-134,536` (só revoga ESCRITA; leitura fica); `supabase/app_verificar_login.sql:82-86` (conferência de RLS só comentada); `auditorias/2026-10-13/onda5-alma.md:108-110` | A chave `anon` do Supabase é pública por natureza. Se `leticia_crystal_customers`, `leticia_crystal_active_accesses`, `leticia_crystal_lead_memories`, `leticia_crystal_chat_histories*` ou `leticia_crystal_hybrid_search` estiverem com RLS desligado e grants padrão, qualquer pessoa com a `anon` lê CPF, e-mail, telefone, memória e histórico de conversa de ~11 mil alunas, e a base de conhecimento inteira pelo PostgREST | O repositório não tem registro do estado do RLS dessas tabelas; o arquivo da onda 5 fecha só a escrita direta | Rodar no SQL Editor: `select tablename, rowsecurity from pg_tables where schemaname='public' and tablename like 'leticia_crystal_%' order by 1;` e `select table_name, grantee, privilege_type from information_schema.role_table_grants where table_schema='public' and table_name like 'leticia_crystal_%' and grantee in ('anon','authenticated') order by 1,2,3;`. Para cada tabela com `rowsecurity = false` ou grant para `anon`/`authenticated`: `alter table ... enable row level security` (sem política = ninguém além do dono e da `service_role`) e `revoke all on table ... from anon, authenticated`. Antes, confirmar que a Edge Function `crystal_hybrid_search` e o sistema da agência usam a `service_role` (se usarem `anon`, param) |
| INT-01 | Média | `apps/api/src/app.ts:198-202`; `routes/imagens-webhook.ts:17-18,38`; `routes/refund-webhook.ts:27-33,115-120,176` | `REFUND_WEBHOOK_SECRET` abre as duas rotas. É Bearer fixo, sem data nem assinatura do corpo. Quem o tiver (n8n, `.externos`, log de proxy, captura) pode: desligar qualquer aluna por e-mail ou CPF; creditar pacotes de imagens a qualquer e-mail (ou deixar pendente para quem entrar com ele); criar contas desligadas sem limite (INT-04); e usar a resposta (`matched`, `result`) como oráculo de "este e-mail/CPF tem conta?" | Teste INT-01 (o mesmo Bearer credita e corta); INT-06 do arquivo mostra o 401 idêntico | Segredos distintos por rota (`REFUND_WEBHOOK_SECRET` e `IMAGENS_WEBHOOK_SECRET`); assinatura HMAC do corpo + `x-timestamp` com janela de 5 min, como já se faz no Chatwoot (`verifyInboxWebhook`); no Traefik, as rotas `/webhooks/reembolso` e `/webhooks/imagens` de `api.` só para o IP público da própria VPS (o n8n roda nela); resposta sem `result`/`matched` detalhados (basta `ok`) |
| INT-02 | Média | `routes/refund-webhook.ts:21,163-168` (dedup em Redis com TTL de 30 dias); `n8n` guarda o corpo por 14 dias (`stacks-exemplo/04-n8n-editor.yaml:121-128`) | Sem data no pedido, um evento capturado vale para sempre; o dedup só segura 30 dias. Aluna reembolsada por engano, religada pela equipe, é desligada de novo por um reenvio (Assiny, operador do n8n ou atacante com o corpo) depois do prazo. A tabela `crystal_compras_eventos` do Supabase, ao contrário, lembra para sempre | Teste INT-02 (`it.fails`): depois de apagar a marca, o replay responde `disabled` e a conta volta a `disabled` | Guardar `transaction.id + event` processados numa tabela do Postgres do app (como `webhook_events`), sem TTL; ou exigir `x-timestamp` assinado e recusar fora da janela; e não desligar de novo uma conta cujo `disabledAt`/religamento é posterior ao evento (comparar com `transaction.updated_at` do corpo) |
| INT-03 | Média | `routes/refund-webhook.ts:214-239` (pré-bloqueio copia `quem.email`), `:288-290` (pré-bloqueia mesmo quando o e-mail achou outra conta); `db/prisma-users.ts:164-169` (`findFirst` sem `orderBy`); `routes/auth.ts:264,287-289`; `prisma/schema.prisma` (`User.email` sem `@unique`) | Reembolso com CPF que nunca entrou + e-mail de aluna existente: a aluna é desligada e nasce uma segunda conta "Aluno", desligada, com o mesmo e-mail. Quando a equipe religa a aluna (reembolso de outro produto, erro de digitação na Assiny), o login só com e-mail faz `findByEmail` e pode cair na conta fantasma → `ACCOUNT_DISABLED` sem causa visível no painel. Também polui a lista de alunos | Teste INT-03: duas contas com o mesmo e-mail, ambas desligadas; o `it.fails` mostra que a fantasma continua depois do religamento | Não copiar o e-mail para a conta de pré-bloqueio quando `matchedBy === "email"` (a aluna já foi tratada); `findByEmail` com ordem definida (ativa antes de desligada, com `crystalContactId` antes de sem); no painel, mostrar as contas duplicadas por e-mail na ficha da aluna |
| INT-07 | Média | `crystal-em-casa/n8n/compra-assiny-credenciais.py:324-328` (lê `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY` e `REFUND_WEBHOOK_SECRET` de `.externos`); `bootstrap-vps.sh` função `cw_gerar_env` (a mesma chave do Resend vai para o SMTP do Chatwoot) | O n8n só precisa executar `app_compra_evento`, mas guarda a `service_role`, que lê e escreve toda a base da agência (CPF, telefone, memória, histórico). Um nó Code malicioso, um pacote comunitário ou um operador do editor do n8n herda tudo. A chave do Resend que manda os códigos de login está em três sistemas (API, n8n, Chatwoot): vazou um, todos os três e-mails oficiais podem ser forjados | Leitura dos roteiros; o script já oferece `--supabase-proprio` e `--resend-proprio` mas o padrão é reaproveitar | Papel próprio no Postgres do Supabase (`create role n8n_compras nologin; grant n8n_compras to authenticator; grant execute on function app_compra_evento(jsonb) to n8n_compras;`) e um JWT assinado com o segredo JWT do projeto com `role: n8n_compras` para o n8n (o PostgREST honra a claim); uma chave do Resend por sistema (API, n8n, Chatwoot), cada uma restrita ao domínio remetente; revogar da `service_role` tudo que o n8n não usa |
| INT-08 | Média | `stacks-exemplo/04-n8n-editor.yaml:121-128` e `05-n8n-webhook.yaml:116-123` (`EXECUTIONS_DATA_MAX_AGE=336` h); `compra-assiny.json` (fluxo sem "não guardar execuções bem-sucedidas"); `auditorias/2026-10-23/diag-n8n-compras.sql` (lê `execution_data` com regex) | Cada aviso da Assiny (CPF em `client.document`, e-mail, nome, telefone, `metadata` com IP e user agent) fica 14 dias no banco do n8n, legível por qualquer usuário do editor e pelos backups do n8n. É cópia de dado pessoal sem finalidade depois do processamento (LGPD, minimização) | Leitura da configuração | No fluxo, "Settings → Save successful executions: Do not save" (manter só as com erro) ou um nó Set logo após o webhook que descarta `data.client.document` e `data.metadata` antes de qualquer outro nó (a função só usa event, e-mail, nome, telefone, transação e oferta); reduzir `EXECUTIONS_DATA_MAX_AGE` para 48 h |
| INT-09 | Média | `compra-assiny.json`: ordem "Registrar no Supabase" → "Responder à Assiny" → IFs → "Desligar no app (reembolso)" (`retryOnFail: 3`, `waitBetweenTries: 2000`); `apps/api/src/routes/auth.ts:54-70,92-117` (a renovação não consulta a base); `env.ts:239-241` (`REFRESH_TTL_S` = 90 dias); `services/directory.ts:38-44` (`authoritative` só no login) | O 200 para a Assiny sai antes do corte no app. Se a API estiver fora por mais de ~6 s (deploy com `start_period: 90s`, reinício), o Supabase fica bloqueado mas a conta do app segue ativa; a sessão renova por até 90 dias sem reconferir a base. Não há reconciliação entre `crystal_compras.status` e `users.status` | Leitura do fluxo; o diagnóstico de 23/10 já mostra execuções com erro | (a) Rotina diária na API: para cada aluna ativa com `crystalContactId`, se a base diz bloqueada (nova função só leitura `app_compras_bloqueadas_desde(timestamptz)`), desligar com motivo `refund`; (b) `/auth/refresh` reconsulta a base no máximo 1 vez por dia por conta; (c) no n8n, "Error Workflow" que avisa por e-mail e re-enfileira; `waitBetweenTries` maior (o máximo do n8n é 5 s, por isso a rotina do item a é a defesa real) |
| INT-04 | Baixa | `routes/refund-webhook.ts:106-113` (limite só para segredo errado), `:256-259` | Com o segredo, cada evento com um CPF válido novo cria uma conta `disabled` (CPF hash único; e-mail livre). Nenhum teto, nenhum alerta: 10⁹ CPFs válidos possíveis → poluição do banco, da lista de alunos e das métricas | Teste INT-04: cinco eventos, cinco contas | Limite por IP também para pedidos válidos (ex.: 60/min) e teto diário de pré-bloqueios com alerta à equipe; considerar não criar conta no pré-bloqueio e sim gravar o hash do CPF numa tabela `cpf_bloqueado` consultada no login |
| INT-05 | Baixa | `services/imagens-compra.ts:85-99` (`creditar` só olha `compra:<tx>`), `:127-138` e `:139-144` (`estornar` devolve sem gravar `estorno:<tx>` quando apaga pendente ou não há o que tirar); `db/prisma-imagens.ts:64-70,89-92` | Estorno antes da compra (ou retry da compra depois do estorno) credita o pacote: o pendente apagado leva junto a única marca `compra:<tx>`, e o estorno "vazio" não deixa marca nenhuma. A Assiny reenvia e entrega fora de ordem (o incidente de 23/10 é da mesma família: evento aprovado depois de recusado) | Testes INT-05 (`it.fails`, dois cenários): `creditado` e `pendente` depois do estorno; o login do e-mail recebe 30 imagens | `estornar` sempre grava um lançamento/marca `estorno:<tx>` (delta 0 quando não há o que tirar) e `creditar` recusa quando existe `estorno:<tx>`; ao apagar o pendente, manter a marca `compra:<tx>` (linha "consumida") |
| INT-11 | Baixa | `apps/api/src/app.ts:193`; `routes/webhooks.ts:94-194` | `POST /webhooks/crystal` (n8n antigo → app) fica sempre no ar, assinado com `WEBHOOK_SECRET`. Hoje a Crystal é interna (`app_crystal`) e nada legítimo bate ali. Quem tiver o segredo escreve mensagens "da Crystal", insights e sugestões para qualquer aluna pelo `crystal_contact_id` (uuid da base) | Leitura | Registrar a rota só com `WEBHOOK_CRYSTAL_ENABLED=1` (ou remover); enquanto existir, restringir no Traefik ao IP da VPS |
| INT-12 | Baixa | `services/chatwoot-channel.ts:209` (identificador do contato = telefone, senão `app:<id>`); `routes/chatwoot-bot.ts:429` (chave da memória = telefone do `sender`); `:173-182` (`findAllByPhone`); `routes/staff-alunos.ts:333-340` (equipe muda o telefone) | A identidade no Chatwoot e a chave da memória da Crystal é o número de telefone. Duas alunas com o mesmo número na base (mãe e filha, número reaproveitado) ou uma correção de telefone pela equipe para um número que já é de outra aluna fazem o `POST /contacts {identifier}` devolver o contato existente: as duas conversam na mesma conversa e a Crystal mistura as memórias (inclusive o histórico importado do WhatsApp). A aluna não edita o próprio telefone (bom), mas a equipe edita | Leitura | Para a inbox do app, usar sempre `app:<userId>` como `identifier` (único e estável) e guardar o telefone como atributo do contato; na correção de telefone pela equipe, recusar número já usado por outra aluna ativa (409) |
| INT-16 | Baixa | `supabase/app_compras.sql:159-167` (evento desconhecido devolve `ignorado` sem gravar), `:169-172` (sem limite de tamanho em nome/telefone/transação) | Nomes de evento novos da Assiny (a família "aprovado depois de recusado") não deixam rastro no Supabase; só aparecem nos 14 dias de execuções do n8n. O dono descobre tarde que alunas pagaram e não entraram | Leitura; diagnóstico de 23/10 precisou vasculhar `execution_data` | Gravar `('sem-transacao-…'|tx) || ':' || evento` em `crystal_compras_eventos` com `acao = 'ignorado_evento'` (sem dado pessoal) e um painel/alerta de eventos desconhecidos; limitar `v_nome` (120), `v_telefone` (E.164) e `v_tx` (80) |
| INT-17 | Baixa | `compra-assiny.json` nó "E-mail de boas-vindas (Resend)" (`Idempotency-Key` por transação; texto com `first_name` e o e-mail do comprador) | O e-mail é texto puro (sem HTML), então não há injeção de HTML; mas o nome entra sem filtro e o destinatário é o que veio no corpo. Junto com INT-06 vira envio de texto arbitrário pelo remetente oficial para qualquer caixa | Leitura | Depende de INT-06; além disso, só o primeiro nome (letras, até 60) e nunca o e-mail dentro do texto |
| INT-18 | Baixa | `services/activedev.ts:11-16,131-138`; `env.ts:283-296,494-500` | O token do ActiveDev vai no CAMINHO da URL: fica nos logs de acesso do ActiveDev/Mautic e de qualquer proxy no meio. O código já evita logar a URL; `https` é exigido; redirecionamento não é seguido; a resposta é validada. Vai e-mail, nome e telefone só de quem se inscreveu num evento (mínimo necessário) | Leitura | Pedir ao ActiveDev que aceite o token em cabeçalho (`Authorization`) e mudar o cliente quando aceitar; rotacionar o token ao trocar |
| INT-13 | Info | `routes/refund-webhook.ts:176`; `routes/imagens-webhook.ts:82` | A resposta diz `matched`/`result`: quem tem o segredo confirma se um CPF/e-mail tem conta (oráculo). Só com o segredo | Teste INT-01 | Ver INT-01 (resposta mínima) |
| INT-19 | Info | `routes/auth.ts:311-316` (404 `LOGIN_NOT_FOUND` × 200 com `masked_email`); `supabase/app_verificar_login_email.sql` | A função do Supabase devolve nome, telefone e id só à `service_role` (certo). O oráculo de "este e-mail é aluna?" fica na API (`/auth/login`), limitado a 50 por IP/15 min e 5 por e-mail. É da dimensão de autenticação; registrado aqui porque passa pela função | Leitura; `auditorias/2026-10-16/verificacao-login.md` | Resposta igual (200 "se o e-mail existir, o código chega") para achado e não achado, se o produto aceitar |
| INT-21 | Info (a confirmar) | `app_verificar_login_email.producao-20261016.sql:18-27,97` (`liberado = t.liberado and not b.bloqueado`); `apps/api/src/routes/auth.ts:318-321` (`liberado === false` só barra com `op_rollout_gate` = `on`); `services/operacao-config.ts:35-36` | O bloqueio pela nossa tabela chega ao app disfarçado de "fora do lote": vira 403 `LOGIN_NOT_RELEASED` ("seu acesso está sendo liberado em lotes"), e só enquanto a chave `op_rollout_gate` estiver `on`. Se alguém a desligar no painel ("fim dos lotes", `ROLLOUT_GATE=off` em `publicar-prd.md:255`), a aluna reembolsada cuja conta do app não foi desligada (INT-09) entra de novo | Leitura; o estado atual da chave não está no repositório | Conferir no painel (Operação) que `op_rollout_gate` está `on` e anotar aqui; melhor: a função devolver uma coluna própria `bloqueado` e a API responder `ACCOUNT_DISABLED`/`LOGIN_INACTIVE`, independente do portão de lotes |
| INT-20 | Info | `CLAUDE.md` (regra `api.` cinza); `app.ts:36-48,115`; `env.ts:384-395` | Os limites por IP (inclusive o balde de assinatura inválida, 30/min) dependem de `TRUST_PROXY=1` com o Traefik em modo host. Se `api.` virar laranja no Cloudflare sem ajustar `TRUST_PROXY` para os IPs do Cloudflare, o IP visto será o do Cloudflare: 30 pedidos ruins de qualquer pessoa bloqueiam o webhook para o n8n e o Chatwoot | Leitura | Manter `api.` cinza (regra já escrita); se um dia for laranja, `TRUST_PROXY` = lista de CIDRs do Cloudflare, nunca `true` |

## Detalhes e caminhos de abuso conferidos (sem achado)

- **`app_aluno_trocar_email` (14/10)**: não dá para tomar a conta de outra aluna trocando o e-mail de A para o e-mail de
  B. A função recusa `email_em_uso` olhando as duas tabelas (`leticia_crystal_customers` com `id <> v_id` e
  `crystal_compras`, linhas 78-81 e 100-103) e trata `unique_violation`; a API confere antes se outra conta do app usa
  o e-mail (`staff-alunos.ts:73-76,317-318`) e, depois da troca, derruba todas as sessões. `search_path` fixo,
  `security definer`, execute só `service_role` (117-119). Formato de e-mail e tamanho conferidos.
- **`app_aluno_corrigir_cadastro` (21/10, "NÃO APLICADO" no cabeçalho)**: `corrigir` só muda nome/telefone com validação
  (E.164, 2 a 120 caracteres, sem controle); `cpf` valida dígitos verificadores e recusa `CPF_EM_USO` antes e no
  `unique_violation`; `liberar_manual` recusa e-mail da base antiga, linha existente e referência reembolsada. Quem
  chama precisa de papel `admin`/`support`, motivo sem dado pessoal e, no CPF, reautenticação. Risco residual é de
  negócio: `support` libera acesso sem compra (com prazo e auditoria), decisão explícita do dono.
- **`app_verificar_login_email`**: a versão em produção (cópia de 16/10) difere da do repositório (fim dos lotes,
  `leticia_crystal_subscriptions`, bloqueio pela nossa tabela). Manter a cópia fiel atualizada no repositório a cada
  mudança, senão a "volta" documentada (`rodar o .sql de novo`) regride o login.
- **`app_conhecimento_*`**: escrita na tabela da agência só pelas funções, histórico imutável por gatilho, trava
  `pg_advisory_xact_lock`, validação de tamanhos e do embedding; execute só `service_role`. A leitura direta pela `anon`
  é o ponto de INT-14.
- **`app_equipe_lotes` / `app_equipe_alunos` / `app_whatsapp_*` / `app_memoria_*` / `app_ficha_*` / `app_historico_*`**:
  todas `security definer` com `set search_path = public, pg_temp` (ou `public, extensions`), parâmetros com faixas
  (`p_limite 1..500`, `p_qtd 1..3000`, listas até 1000/2000), execute revogado de `public/anon/authenticated` e
  concedido só a `service_role`; funções internas (`app_equipe_atividade`, `app_equipe_resumo_aluno`, `app_ficha_alvos`)
  sem grant para ninguém. Tabelas novas (`crystal_*`) com RLS ligado e `revoke all`.
- **Chatwoot**: `verifyInboxWebhook` exige `x-chatwoot-signature` e `x-chatwoot-timestamp`, HMAC-SHA256 de
  `"<ts>.<corpo cru>"`, janela de ±300 s, comparação em tempo constante, segredo vazio recusa tudo
  (`chatwoot-channel.ts:274-289`). O robô confere `account.id`, só responde em conversa `pending`, ignora nota privada e
  mensagens `outgoing`, dedup por id de mensagem (8 dias) gravado só depois de aceitar na fila e liberado se a tarefa
  falhar. O webhook da inbox decide o dono SÓ pelo vínculo gravado (`source_id` + id da conversa), nunca pelo payload.
  O token do robô só alcança mensagem e status; `redirect: "manual"` em toda chamada de saída. O Chatwoot só aceita
  webhook em endereço público (proteção SSRF dele), por isso `api.` público, de propósito.
- **ActiveDev**: URL e token só por env (nenhuma chave do painel tem `url`, `secret`, `token` ou `senha` no nome,
  garantido por `apps/api/src/services/settings.test.ts:82`); `https` obrigatório em produção; `redirect: "manual"`; resposta validada com Zod;
  log só com ids e HTTP; a fila para em 401/404 em vez de martelar.
- **Resend (API)**: destinatário sempre o e-mail da conta ou da base, nunca do pedido; HTML dos avisos de login e de
  risco com `escapeHtml`; o código OTP é só dígitos; falha de envio vai ao log sem destinatário. O e-mail de risco
  (`aviso-risco.ts`) leva nome, WhatsApp e e-mail da aluna para `EQUIPE_EMAIL` (necessário ao propósito).
- **Push**: `isAllowedWebPushEndpoint` só `https` em FCM/Apple/Mozilla/WNS (sem SSRF por endpoint); VAPID e conta de
  serviço FCM só por env; o corpo privado vira aviso genérico; tokens nativos removidos quando inválidos.
- **Banners e avisos**: `bannerLinkSchema`/`isValidNoticeUrl` só `https://` ou `/caminho`; `javascript:`, `data:`,
  `http://`, `//` e credencial na URL são recusados (teste em `banners.test.ts`). Imagem refeita pelo `sharp` (sem EXIF),
  nome conferido por regex antes de tocar o disco. Link para qualquer host `https` é decisão de produto (admin).
- **`/webhooks/crystal`**: HMAC do corpo cru, janela de `sent_at` ±5 min, nonce por `event_id` com TTL 3× a janela,
  nonce liberado se nada persistiu, 202 sem oráculo para contato desconhecido. Só a superfície desnecessária (INT-11).
- **Segredos de produção**: `assertProductionSecrets` barra `TRUST_PROXY` vazio ou `true`, exige `https` para Supabase,
  ActiveDev e Chatwoot, e tamanho/entropia mínimos para `REFUND_WEBHOOK_SECRET`, `WEBHOOK_SECRET` e `OTP_PEPPER`.

## O que está certo

- Autenticação dos webhooks da API em tempo constante (`safeEqualSecret` compara SHA-256 de tamanho fixo), 401 idêntico
  para segredo errado, ausente ou sem `Bearer`, e rota inexistente (404) sem o segredo (testes INT-06 do arquivo).
- Log e auditoria dos webhooks sem CPF, e-mail, nome, telefone nem `metadata` da Assiny: só nome do evento, hash curto
  da transação, resultado e `matched_by` (teste INT-06c).
- Corte de acesso numa função única (`disableAccount`): status, revogação de todas as sessões, remoção das inscrições
  de push e auditoria na mesma transação.
- Idempotência do crédito de imagens pelo caminho normal: `external_id` único no banco, trava por aluno
  (`comTrava`), estorno nunca deixa saldo negativo.
- `crystal_compras_produtos` preenchida com os 7 produtos que liberam o app e o pacote de imagens fora dela
  (`publicar-prd.md:693,742`); `crystal_compras_eventos` lembra transação+evento para sempre; liberação de transação
  já bloqueada é ignorada; reembolso de uma compra antiga não derruba uma nova.
- Nenhuma URL de integração editável pelo painel; `redirect: "manual"` em todas as chamadas de saída; prazos
  (`AbortSignal.timeout`) em tudo.
- A aluna não edita o próprio telefone nem o e-mail (as rotas `/me` não têm esses campos); a equipe edita com
  auditoria, e a troca de e-mail derruba as sessões.
- Segredo do webhook de reembolso gerado e validado na VPS (32 bytes, 10 caracteres distintos), nunca em arquivo do
  repositório; o script do n8n nunca imprime chave.

## Como conferir e corrigir (ordem sugerida)

1. **Hoje**: rodar as duas consultas de INT-14 no SQL Editor. Se alguma tabela `leticia_crystal_*` estiver com
   `rowsecurity = false` ou com grant para `anon`/`authenticated`, fechar no mesmo dia. No painel, confirmar que
   `op_rollout_gate` está `on` (INT-21).
2. **Esta semana**: INT-09 (rotina de reconciliação na API) e INT-02/INT-03 (dedup permanente; não copiar o e-mail no
   pré-bloqueio; `findByEmail` com ordem). As três mexem só no app (`sha` novo), sem SQL.
3. **Esta semana**: INT-06 (confirmar a transação na Assiny antes de liberar/bloquear; sanear o e-mail de boas-vindas)
   e INT-08 (não guardar execuções bem-sucedidas no n8n). Só no n8n.
4. **Próximas duas semanas**: INT-01 (segredos distintos + HMAC com data) e INT-07 (papel próprio no Supabase para o
   n8n, chaves do Resend separadas). Exigem trocar credenciais em dois lugares cada: fazer em hora calma, com a
   volta anotada.
5. **Quando der**: INT-05, INT-04, INT-11, INT-12, INT-16, INT-17, INT-18.

Depois de cada correção do app, rodar `pnpm --filter @crystal/api exec vitest run src/seguranca-webhooks.test.ts`: o
`it.fails` correspondente passa a falhar (porque agora o comportamento desejado acontece) e deve virar `it`.
