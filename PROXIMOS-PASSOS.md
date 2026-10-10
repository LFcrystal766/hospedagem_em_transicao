# Próximos passos — atualizado em 28/09/2026

Tudo que dá pra fazer por API é da sessão do Claude. Abaixo, só o que depende
de você, na ordem, com o tempo estimado.

## Funções SQL aplicadas no Supabase "Crystal AI" (08/10)

- `app_historico_whatsapp.sql`: aplicada; grants conferidos (só postgres e service_role).
- `app_equipe_lotes.sql`: aplicada à noite (a primeira tentativa falhou por colar só um pedaço;
  a versão sem comentários, testada em Postgres, passou). Liga a seção Lotes da Operação.
- `app_whatsapp_silencio.sql`: entregue para aplicar em 09/10 (versão sem comentários, testada), para ligar o silêncio.
- `app_memoria_unica.sql`: aplicada em 09/10 (chave "Memória única" ligada).
- `app_telefone_chave.sql` (09/10): APLICADA pelo conector do Supabase. Histórico, memória e silêncio comparam o
  telefone pela chave país + DDD + 8 últimos (o WhatsApp guarda muitos números sem o nono dígito). Antes: 9.268
  dos 9.641 alunos com acesso achavam a conversa; agora 9.635 (+367). Caso que revelou: aluno com 746 mensagens
  no WhatsApp aparecia sem histórico. Para quem já tinha conta e foi marcado "sem histórico": Alunos > Importar agora.
  Conferência dos 35 alunos do app em 09/10: 22 já importados com mensagens; 3 marcados "sem histórico" que agora
  têm histórico foram reimportados (marca apagada, entra na próxima mensagem); 1 continua sem histórico; 9 ainda não
  importados com histórico esperando; 0 erros.
- `app_historico_arquivo.sql` (09/10): APLICADA pelo conector (migração `app_historico_arquivo_20261009`). A agência
  move mensagens antigas para `leticia_crystal_chat_histories_archive` (~4,7 milhões de linhas); o histórico só lia a
  tabela atual e, para 1.415 alunos, parte das 3 semanas importadas estava no arquivo. Agora lê as duas, sem repetir.
  Conferido: aluno com arquivo passou a devolver 220 mensagens (antes só as da tabela atual).
  Prontidão da base em 09/10: 9.643 alunos com acesso, todos com e-mail válido e telefone; 9.637 com conversa achada
  no WhatsApp; 8.542 com mensagens; 6.747 com anotações da Crystal; 4 e-mails repetidos. Nada a pré-importar: cada
  um recebe memória e histórico na primeira mensagem no app. Os 22 já importados antes da correção podem ser
  reimportados (Alunos > Importar agora, ou o reset em lote na VPS) para pegar a parte que estava no arquivo.
- `app_compras.sql` (09/10): APLICADA em 09/10. Login por e-mail conferido na VPS (`app_verificar_login_email`
  HTTP 200). Compra direta pela Assiny via nosso n8n: falta ligar (chaves, n8n, Assiny).
  10/10: credenciais do n8n por `crystal-em-casa/n8n/compra-assiny-credenciais.py` na VPS: FEITO e
  testado de ponta a ponta no n8n de produção (sem token 403; com token 200; compra de teste liberou e
  mandou boas-vindas; reembolso de teste bloqueou e repassou à API). O token da Assiny apareceu no chat;
  o dono decidiu NÃO trocar (10/10, risco aceito: com o token, dá para forjar compra ou reembolso).
  Trocar quando quiser: `--novo-token --mostrar-token --sem-teste-completo` e o valor novo na Assiny. Falta: o
  webhook na Assiny e tirar o da agência. Linhas de teste (2 em crystal_compras, 4 em eventos, e-mails
  `delivered+teste-n8n-*@resend.dev`, reembolsadas) ficam até o DELETE no SQL Editor (o conector pede
  confirmação para apagar e não chega a tempo). Sobrou no Supabase a função de teste
  `zz_teste_cabecalho_20261009` (sem permissão para ninguém; o DROP pelo conector pede confirmação):
  apagar no SQL Editor com `drop function public.zz_teste_cabecalho_20261009();`.
  ACHADO 09/10: `app_verificar_login_email` NÃO existia no Supabase (só a `app_verificar_login` antiga, de CPF,
  sem a coluna liberado) e o `bootstrap-vps.sh` da VPS é anterior a 07/10 (não grava LOGIN_MODO). Com o padrão
  do app (LOGIN_MODO=email), login de quem não tinha sessão dava 404 na base. O `app_compras.sql` cria a função.
  Nas 48 h antes da correção, nenhum login foi barrado por isso (0 DIRECTORY_UNAVAILABLE no log).
  Roteiro em `crystal-em-casa/publicar-prd.md`, seção "Compra direta pela Assiny".
- Memória do WhatsApp em lote rodada em 08/10: 27 alunos do app, 10 importados, 1 sem
  histórico, 16 pulados (sem conversa ainda; recebem na primeira mensagem), 0 falhas.
  Custo por importação entre US$ 0,02 e 0,05.

## Memória completa ANTES do primeiro acesso (proposta de 10/10, esperando decisão do dono)

Pedido do dono: a memória completa de cada aluno pronta no app antes de ele chegar.

Como está hoje (lido no código do app, `sha-74092e0`):
- Na 1ª mensagem no app, o robô importa só os últimos 7 dias do WhatsApp (até 500 mensagens) para a
  memória da nossa Crystal (Postgres da VPS, por telefone) e gera um resumo de no máximo 1.000 caracteres.
  O aluno espera até 8 s; passou disso, a 1ª resposta sai sem memória.
- Em todo turno, com `op_memoria_unica`, a Crystal lê no Supabase, por customer_id, as anotações da Crystal
  do WhatsApp (`lead_memories`, 6.747 alunos). Isso já está pronto antes do acesso, mas é curto e não cobre
  quem não tem anotação.

Volume medido em 10/10 (amostra de 5%, só leitura): 9.709 conversas de alunos, ~5,5 milhões de mensagens,
~3,1 bilhões de caracteres (~800 milhões de tokens). Cortando cada mensagem longa (aluno 800, Crystal 300
caracteres) cai para ~400 milhões de tokens.

Desenho proposto: tabela nova `crystal_memoria_whatsapp` (por customer_id: memória de até 4.000 caracteres,
até que mensagem já entrou, custo). Gerada pela nossa Crystal (a chave do OpenRouter fica só lá), em lotes
disparados pela Operação, com teto de gasto, retomável e andamento no painel. `app_memoria_ler` passa a
devolver essa memória e a Crystal a usa já na 1ª mensagem, sem espera. Manutenção: rodada diária só com
as mensagens novas de cada aluno (barato) e quem entra pela Assiny (`crystal_compras`) entra na fila.
Piloto de 20 alunos (com e sem memória) antes do lote inteiro.

Decisões do dono: modelo (custo), alcance (histórico inteiro ou últimos 12 meses), teto de gasto e
recarga do OpenRouter (saldo de US$ 25,41 em 09/10 não cobre).

## Migração final do site (proposta de 09/10, esperando decisão)

Conferido em 09/10: o DNS está no Cloudflare (cinza), mas o site, o e-mail `mail.` e o `leticiafelisberto.com`
(NS na AZAN, e-mail no Google) continuam no servidor da AZAN. O contato do Registro.br ainda é
`admin@leticiafelisberto.com`. A conta Hostinger só tem a VPS: nenhum plano de hospedagem de site.

Proposta:
1. Site num plano de hospedagem Hostinger Premium (catálogo em 09/10: R$ 45,99/mês, ou R$ 179,88 no 1º ano e
   R$ 467,88 na renovação), em São Paulo. Não na VPS: o WordPress é a peça mais atacada e ficaria ao lado dos
   segredos do app, e o cache LiteSpeed de que o site depende vem pronto na hospedagem.
2. Pular o "Cloudflare na frente da AZAN" (depende do chamado #RAI-374885): ir direto de AZAN cinza para
   Hostinger laranja. O certificado de borda já está ativo; na origem, Origin CA importado no hPanel.
   `cloudflare-degrau2.sh preparar --aplicar` antes (só age com laranja). Volta: A de novo na AZAN, cinza.
3. Antes de cancelar: e-mail `@crystalnowpp` migrado, zona do `leticiafelisberto.com` no Cloudflare (mantendo o
   MX do Google), contato do Registro.br numa caixa fora da AZAN, backup final, 15 dias estáveis.
   Pagar a fatura de 14/10; cancelar antes da de 14/11.

## Sem agência a partir de 09/10

Decisão do dono: "não tem mais nada com o Tuan, tudo é pra ser nosso agora". Nada mais é
combinado com ele. O que ainda roda do lado dele usa a chave service_role vazada e a senha do
banco do Crystal AI: a Crystal do WhatsApp (no LendChat, da agência) e o n8n dele (cadastro de
comprador novo e reembolso). Desligar a chave legada e trocar a senha PARA os dois na hora. O app
não depende deles.

Ordem:
1. Já, sem quebrar nada: tirar a agência da organização do Supabase (Team), criar a secret key
   `app-vps` e trocar na VPS (FEITO em 09/10: `app-definir` + `app-subir sha-74092e0`, HTTP 200) (`app-definir SUPABASE_SERVICE_ROLE_KEY` + `app-subir sha-74092e0`),
   revisar os acessos dele nas outras contas (Assiny, Hostinger, Cloudflare, GitHub, OpenRouter,
   n8n, Chatwoot, Portainer, Resend, Bitwarden).
2. Nosso fluxo de compra e reembolso no nosso n8n (pendente: estrutura das tabelas, print do
   webhook da Assiny, o que o comprador recebe depois de pagar).
3. WhatsApp ENCERRADO (decisão do dono em 09/10: "tirar o webhook do whatsapp e mandar direto pro
   app sempre a partir de agora"). Todo mundo no app: desligar o portão de lotes (Operação,
   "Liberação em lotes"), tirar o webhook da Crystal no LendChat (conta `crystal`) e deixar uma
   resposta automática apontando para o app, avisar a base por e-mail. O histórico e a memória
   do WhatsApp já chegam ao app (memória de chegada e memória única) e ficam congelados no corte.
   Na transição em levas, o silêncio no WhatsApp (`app_whatsapp_silencio.sql`) desliga a Crystal do
   WhatsApp para quem já usa o app (decisão de 09/10: aplicar e ligar; versão sem comentários testada).
4. Corte: desligar as chaves legadas (Settings > API Keys > Legacy > Disable JWT-based API keys),
   trocar a senha do banco, tirar o webhook dele da Assiny.

## Abrir o app para a base inteira (09/10): o que segura

`app-custo 24` em 09/10: US$ 0,90 em 24 h, 106 turnos, US$ 0,0085 por turno (resumo incluído),
projeção de US$ 27 em 30 dias com 38 alunos (cerca de US$ 0,71 por aluno por mês). Conta do
OpenRouter: comprados US$ 6.320, usados US$ 6.294,59, **saldo US$ 25,41**, e a chave da Crystal
**sem limite mensal**. A conta é dividida com a chave antiga da Crystal do WhatsApp (agência), que
gasta quase tudo. Antes de desligar a fila de lotes: crédito + recarga automática, limite mensal na
chave da Crystal, plano pago do Resend (o gratuito manda 100 e-mails por dia) e a contagem de
alunos com acesso ativo. A chave do WhatsApp sai junto com o corte (também vazou na stack do Tuan).
Contagem em 09/10: 8.350 active + 1.306 pending = 9.656 podem entrar. Conferência na VPS em 09/10:
**`op_rollout_gate = off` (fila já desligada)** com o saldo ainda em US$ 25 e sem limite; silêncio ligado
mas falhando com HTTP 404 (8 vezes em 2 h: SQL do silêncio ainda não estava no Supabase).
Depois do SQL e do botão "aplicar a quem já usa" (09/10): 25 alunos, 23 conversas silenciadas. Dos 34
alunos do app ligados à base, 32 têm conversa no WhatsApp: 23 silenciados, 9 ainda respondendo (os 9
que entraram no app mas ainda não mandaram mensagem; silenciam sozinhos na primeira mensagem).
Por etiqueta do LendChat (09/10): `crystal-em-casa/supabase/app_whatsapp_silenciar_telefones.sql` (função por
telefone) + `crystal-em-casa/silenciar-por-etiqueta.py` (na VPS: token do LendChat digitado sem eco, escolhe a
etiqueta, junta contatos e conversas, mostra só contagens, pede SIM; `religar` desfaz). Testado com LendChat e
Supabase falsos e Postgres 16.

## Supabase: "Crystal AI" já está na nossa organização (08/10)

Print do dashboard do dono: a organização tem dois projetos, "Crystal AI" (sa-east-1, Micro) e
"crystal@leticiafelisberto.com's Project" (us-east-2, Micro). O "Crystal AI" é o do app
(login, base de alunos, memória de chegada, lotes; ref `hwbllqepvhddakszqdbk`, conferir na URL).
A transferência está feita. O outro projeto não é usado pelo app.
Agora cabe a nós: (1) trocar a chave service_role que vazou na stack do Tuan, combinando com
ele, porque a Crystal do WhatsApp usa o mesmo projeto: chave nova para a agência e outra para o
app (`app-definir SUPABASE_SERVICE_ROLE_KEY` + `app-subir`), e só então revogar a antiga;
(2) trocar a senha do Postgres do projeto; (3) rever o papel de Owner da agência na organização.

## Crystal do WhatsApp na VPS (stack do Tuan, 06/10): segredos vazados, trocar antes

A stack `docker-stack-production` veio com quatro segredos de produção em texto puro e foi
enviada por upload na sessão. Regra da casa: vazou, troca. Coordenar com o Tuan, nesta ordem:
1. Supabase (projeto Crystal AI): criar chave secreta nova para a agência e outra para o
   nosso app, trocar na VPS (`app-definir SUPABASE_SERVICE_ROLE_KEY`) e revogar a antiga;
   trocar a senha do Postgres do projeto (Settings > Database).
2. OpenRouter: chave nova para a agência; a nossa só se for a mesma (conferir no painel).
3. LendChat: token de API novo na conta `crystal`.
Só depois disso a stack sobe aqui. Cópia sem segredos em
`crystal-em-casa/stacks-app/30-crystal-ia.yaml` (env_file, Host `ia.crystalnowpp.com.br`).
Pendências para subir: imagem `ghcr.io/lfcrystal766/crystal-ia:0.16.2` (workflow manual no
repositório `crystal-ia`), DNS `ia` cinza, `LENDCHAT_WEBHOOK_SECRET` preenchido (na stack veio
vazio, o que desliga a validação do webhook), decisão de onde fica o número do WhatsApp.

## Operação pelo painel (07/10)

O `/equipe/operacao` (só admin) passa a mandar no dia a dia: lotes de acesso (resumo,
liberar os N mais ativos, liberar por lista, CSV), portão de lotes, limite por IP, modelo da
Crystal, aviso e manutenção, reembolso, preço da transcrição e retenção. Roteiro em
`crystal-em-casa/publicar-prd.md`, seção "Operação pelo painel"; SQL em
`crystal-em-casa/supabase/app_equipe_lotes.sql` (rodar antes do deploy).

**O que ainda fica na VPS** (console da Hostinger + `bootstrap-vps.sh`): o deploy
(`app-subir <tag>`), `LOGIN_MODO` e `CHAT_TRANSPORT` (mudam o fluxo inteiro, não são ajuste
ao vivo), todos os segredos e URLs (`app-definir`), backup e vigia. As variáveis que o painel
sobrepõe (`ROLLOUT_GATE`, `LOGIN_CODIGO`, `REFUND_*`, `RATE_AUTH_IP_MAX`,
`TRANSCRIPTION_PRICE_PER_HOUR_USD`) viram só o valor padrão.

**Decisão pendente: deploy pelo painel?** Hoje trocar a tag exige o console da VPS. Duas
opções, se quiser tirar isso de lá:
1. Serviço vigia dentro da VPS que lê da API a tag desejada e roda `docker service update`.
   Exige montar o socket do Docker no contêiner: quem toma esse contêiner toma a VPS inteira.
2. GitHub Actions por SSH, com chave só-deploy (usuário sem sudo, `command=` no
   `authorized_keys` restrito a `bootstrap-vps.sh app-subir`), disparado por tag ou à mão
   no GitHub (que já tem 2FA). O painel, no máximo, mostra a tag no ar e o link do workflow.
Recomendação da sessão: a 2ª. Não expõe o socket, fica auditado no GitHub e a volta é o mesmo
workflow com a tag anterior. Decidir antes de abrir qualquer frente de código para isso.

## Memória de chegada (08/10)

Decisão registrada: a Crystal do app importa o histórico do WhatsApp do aluno UMA vez, no
primeiro login (ou na primeira mensagem), para a memória dela, com resumo; depois o app é a
fonte e nada é sincronizado de volta para o WhatsApp. Liga e desliga pelo painel (Operação,
seção Crystal, chave "Memória de chegada"). Roteiro em `crystal-em-casa/publicar-prd.md`,
seção "Memória de chegada"; SQL em `crystal-em-casa/supabase/app_historico_whatsapp.sql`
(rodar antes do deploy).

**Avisar o Tuan**: a função `app_historico_whatsapp` lê `leticia_crystal_chat_histories` (e
`leticia_crystal_active_accesses`, `leticia_crystal_lead_management`) só leitura, via
service_role, uma vez por aluno. Nenhuma coluna nova, nada gravado no Supabase.

**Pendência com o Tuan** (antes de confiar no resultado):
1. Formato exato do `message` em `leticia_crystal_chat_histories`: `content` direto
   (`{"type":"human","content":"..."}`) ou dentro de `data`
   (`{"type":"human","data":{"content":"..."}}`)? A função aceita os dois; confirmar se há um
   terceiro (conteúdo em lista, por exemplo), que hoje cairia fora.
2. A Crystal do WhatsApp continua respondendo o aluno depois que ele migra para o app? Se sim,
   as duas memórias divergem a partir da importação (decisão acima: não sincronizamos).

## Silêncio no WhatsApp (08/10)

Decisão do dono: quem passa a usar o app deixa de receber resposta da Crystal do WhatsApp. Só
silêncio, sem mensagem de redirecionamento. A chave "Silêncio no WhatsApp" (Operação) começa
desligada. O app grava `is_ai_enabled = false` nos leads do número do aluno em
`leticia_crystal_lead_management` (a Crystal da agência já respeita essa coluna). Roteiro em
`crystal-em-casa/publicar-prd.md`, seção "Silêncio no WhatsApp"; SQL em
`crystal-em-casa/supabase/app_whatsapp_silencio.sql` (rodar antes do deploy).

**Riscos**:
- O aluno pode achar que a Crystal do WhatsApp quebrou: avisar ANTES de ligar (disparo, Bia).
- Aluno com telefone diferente no cadastro (outro chip, sem o 9, sem o 55) não é silenciado.
- Quem nunca escreveu no WhatsApp ainda não tem lead: a primeira resposta lá pode escapar até
  a próxima reaplicação (até 24 h).

**Perguntas ao Tuan** (antes de ligar). No código `crystal-ia` que lemos, nada grava
`is_ai_enabled` e a intervenção humana usa uma chave no Redis, não essa coluna; as perguntas são
sobre o que fica fora desse código (painel, n8n, LendChat, edição à mão):
1. O atendimento humano de vocês usa `is_ai_enabled`? Se usar, religar em massa pode desfazer
   um atendimento em andamento.
2. Vocês concordam com a nossa escrita nessa coluna (e em `updated_at`)?
3. Existe algum processo que religa `is_ai_enabled` sozinho?

## Memória única (08/10)

Decisão do dono: uma memória só por pessoa entre a Crystal do WhatsApp e a do app, "sem alterar
absolutamente nada do que temos". Por isso é **só acréscimo**: `crystal-em-casa/supabase/app_memoria_unica.sql`
cria uma tabela nova (`crystal_memoria_unica`) e três funções (`app_memoria_ler`,
`app_memoria_gravar`, `app_memoria_apagar`); as tabelas da agência só são lidas. A API apaga a
linha do aluno quando ele exclui a conta ou apaga as conversas (LGPD), com a chave ligada ou não. Com a chave "Memória única"
(Operação, começa desligada) a Crystal do app lê o que a do WhatsApp anotou e guarda o resumo do
app na tabela nova. App publicado em 09/10 como `sha-74092e0`. Chave LIGADA em 09/10 antes do SQL: a Crystal recebeu 404
(4 leituras, 1 gravação) e respondeu sem a memória. SQL aplicado em 09/10 (versão sem comentários,
testada em Postgres; "Success. No rows returned"). Conferido na VPS em 09/10: dos 34 alunos do app ligados
à base, 31 têm anotações e preferências da Crystal do WhatsApp chegando pela `app_memoria_ler`, 0 erros.
O teste na conversa precisa ser com conta de ALUNO: conta da equipe (admin) não recebe memória, por regra. Roteiro em `crystal-em-casa/publicar-prd.md`, seção
"Memória única".

- **Pré-requisito**: trocar a chave service_role que vazou (seção "Supabase: 'Crystal AI' já está
  na nossa organização") ANTES de ligar a chave.
- **Volta do app para o WhatsApp** depende do Tuan: a Crystal do WhatsApp só passa a saber o que
  veio do app se ela ler a tabela nova. O trecho pronto (um SELECT pelo telefone do lead) está
  comentado no cabeçalho do SQL; nada é aplicado no lado dele. Se a conexão dele não for com o
  usuário `postgres`, combinar um `grant select` só nessa tabela.
- Avisar o Tuan: `app_memoria_ler` lê `leticia_crystal_lead_memories` (`content` e
  `profile_data`), `leticia_crystal_lead_management` e `leticia_crystal_active_accesses`, só
  leitura, via service_role.

## Decisões do Igor (06/10) e o que a sessão está fazendo com cada uma

- **Divulgação em lotes**: cerca de 500 alunos por dia, decrescente, começando pelos top
  users. A flag `is_in_rollout` do Supabase passa a ser lida no login: quem não foi
  liberado vê "seu acesso está sendo liberado em lotes" (código `LOGIN_NOT_RELEASED`),
  com `ROLLOUT_GATE=off` para abrir geral. Em construção na branch `otimizacao/lotes`.
- **Reembolso**: JSON da Assiny recebido (evento `refunded_purchase`, CPF em
  `data.client.document`, dois produtos). Webhook sendo adaptado na branch
  `otimizacao/reembolso-assiny`, com os três achados da revisão. Prazo de reembolso
  hoje 30 dias; vai a 7 quando a nova VSL entrar (não muda nada no app: o webhook
  reage ao evento, não ao prazo). Não colar JSON real no chat: traz CPF, e-mail e
  telefone de aluno; a sessão só guardou uma cópia anonimizada.
- **Painel da Bia no app**: gestão de alunos no `/equipe` (busca, conta local manual,
  e-mail e WhatsApp, revogar e reativar acesso). O app não tem senha: o acesso é por
  código no e-mail, então "trocar senha" vira "trocar e-mail e reenviar código".
  Escopo proposto; construir depois dos dois acima.
- **DNS `atendimento` no Cloudflare**: tudo centralizado no Cloudflare, como já previsto.
  O registro ainda não existe (NXDOMAIN). Criar com
  `scripts/cloudflare-crystal-vps-dns.sh criar` (precisa de `CLOUDFLARE_API_TOKEN` no
  ambiente) ou à mão: A `atendimento` -> `177.7.61.136`, nuvem cinza, TTL automático.

## Alma da Crystal (06/10): chegou em `LFcrystal766/crystal-ia`

- Conferido: prompt v2.2, prompts auxiliares e código Python da Crystal do WhatsApp.
  Sem segredo vazado. Leitura em `auditorias/2026-10-06/alma-crystal-ia.md`.
- A base de conhecimento não veio no Git: está no Supabase (tabela
  `leticia_crystal_vector_store` + Edge Function `crystal_hybrid_search`). Rodar a
  consulta e o teste que a sessão passou.
- Avisar o Tuan: links da Assiny e hosts da agência ficaram no código (não é segredo).
- Pronto para publicar na branch `otimizacao/alma` do app (prompt adaptado + busca na
  base, 115 testes). Falta: integrar em `otimizacao/etapa-3`, decisão da Letícia sobre
  "3 balões" vs "3 opções" no print, e perguntar ao Tuan qual provedor de embedding a
  Edge Function usa (o texto da mensagem do aluno passa por ele).

## OpenRouter (06/10, uns 5 minutos)

- **07/10: crédito carregado pelo dono** (com recarga automática e limite mensal na chave da
  Crystal). Conferir o saldo pelo painel gerencial (`/equipe/painel`, bloco de custos) ou por
  `bootstrap-vps.sh app-custo 24` depois do primeiro dia de uso cheio. Os itens abaixo ficam
  como histórico.

- **Saldo da conta: cerca de US$ 44** de US$ 6.220 comprados. A chave da Crystal gastou
  US$ 0,07; o resto foi outra chave da mesma conta (Crystal antiga da agência?). Pôr
  crédito ou recarga automática, senão a Crystal para com 402.
- Em openrouter.ai/activity, filtrar por chave e mandar para a sessão a tabela de
  modelo, pedidos, tokens e custo (sem texto de conversa).
- Em openrouter.ai/settings/keys, limite mensal na chave da Crystal (hoje sem limite).
- Decidir se integra `otimizacao/custo-modelo` em `otimizacao/etapa-3` (medição de
  custo por turno e cache do prompt). Detalhes: `auditorias/2026-10-06/openrouter-uso.md`.

## Agora (uns 15 minutos)

1. **Cloudflare, 5 min.**
   - Apague o token antigo que vazou: Manage Account > Account API Tokens >
     id `856e07e65b984fe5ffb01451bfa3e49e` > Delete.
   - Ligue o 2FA: My Profile > Authentication.
2. **Variáveis do ambiente, 5 min.** Em claude.ai/code, no menu do ambiente
   deste repositório, clique em Edit e cole:
   - `CLOUDFLARE_API_TOKEN` = valor do token `claude-crystal-migracao`
   - `CLOUDFLARE_ACCOUNT_ID` = `a938d629ec1d8ac1f21e77e8723ac514`
3. **Sessão nova, 2 min.** Abra uma sessão nova deste repositório e escreva
   "segue o CLAUDE.md". Na primeira chamada ao Cloudflare, aprove. Para não
   ser perguntado de novo, libere em /permissions a regra
   `Bash(scripts/cloudflare-degrau2.sh:*)`.
4. **Registro.br: fica em aberto por decisão do dono (28/09).** Não bloqueia o
   degrau 2. Precisa ser resolvido antes de cancelar a AZAN: o e-mail do
   contato LFMPI73 ainda é admin@leticiafelisberto.com.

## Quando puder (uns 10 minutos)

5. **Mais três credenciais no ambiente**, do mesmo jeito do passo 2:
   - cPanel da AZAN > Segurança > Gerenciar tokens da API > `claude-migracao`,
     90 dias: `CPANEL_AZAN_HOST=jupiter.servidor.net.br`, `CPANEL_AZAN_USER`,
     `CPANEL_AZAN_TOKEN`
   - Stape > Account settings > API Keys > `claude-migracao-leitura`:
     `STAPE_ACCOUNT_API_KEY`
   - wp-admin > Usuários > Perfil (admin) > Senhas de aplicativo >
     `claude-migracao`: `WP_APP_USER=admin`, `WP_APP_PASSWORD`. Troque também
     a senha do admin
6. **MacBook**, quando ligar: enviar para o GitHub as pastas
   `hospedagem-crystal-dns` e `crystal-web-chat`.

## Decisões suas

7. **Resposta da AZAN ao chamado #RAI-374885**: encaminhe para a sessão.
8. **Data do degrau 2**: uma madrugada, às 02:00, depois da resposta da AZAN.
9. **TikTok**: terminar o que falta antes da linha de base, ou congelar até a
   migração acabar.
10. **Aviso ao time**, 48h antes do degrau 2. Texto pronto em
    `pedidos/aviso-time-degrau2.md`.

## Frente paralela: a VPS da Crystal (o app)

Independe dos degraus do site. Detalhes em `crystal-em-casa/README.md`.

11. **VPS contratada em 28/09**: Hostinger KVM 4, Ubuntu 24.04, Boston, IP
    `177.7.61.136`. Falta tudo o que vem depois.
12. **DNS dos três nomes: feito em 29/09** (`painel`, `editor`, `webhook` →
    `177.7.61.136`, cinza, pelo painel). Conferido de fora: os três respondem
    o IP da VPS. Reconferir a qualquer hora com
    `scripts/cloudflare-crystal-vps-dns.sh conferir`.
13. **Três respostas da agência** antes de contratar o Supabase: compute size
    do projeto da Crystal, dono da conta OpenRouter, quem monta a fase 1.
14. **Docker, Swarm e as stacks: feito em 29/09.** Traefik, Portainer, Postgres,
    Redis e os três serviços do n8n em 1/1, HTTPS válido nos três nomes, admin
    do Portainer e dono do n8n criados. Detalhe que custou uma hora: o Docker 29
    recusa a API 1.24 do Traefik v2 da agência; `bootstrap-vps.sh docker-api`
    baixa o piso do daemon. Segredos trocados depois de vazarem no chat.
15. **Contas**: Supabase Pro + convite Owner para `agencia@academialendaria.ai`,
    GitHub (repo privado, e-mail, token `write:packages`), Netlify, Telegram.
16. **Avisar a agência** quando os 16 pontos de "Base pronta" do guia estiverem
    verdadeiros. A fase 2 (código, transferência do Supabase, imagem, corte) é deles.

## O que a sessão do Claude faz sozinha depois do passo 3

- Foto completa da zona e preparação das configurações, ainda com tudo cinza.
  Não muda nada para o visitante.
- Conferência do certificado de borda e da regra "server. sempre cinza".
- Na madrugada combinada: laranja, validação pela borda, Always HTTPS, bloqueio
  do xmlrpc, rewrite do /crystal-teste. Rollback em segundos se algo sair do padrão.
- Com as credenciais do passo 5: backup da AZAN, zona real, caixas de e-mail,
  prova venda a venda pelo Stape, e a cópia na Hostinger.

## PRD de Otimização: squad em paralelo (03/10)

O Luiz pediu para pôr o "PRD de Otimização Crystal" (26 itens, 3 etapas) para rodar
com vários terminais e deu autorização total. Análise do PRD e desenho do squad em
`crystal-em-casa/squad-otimizacao.md`; relatório de cada integração em
`crystal-web-chat/docs/otimizacao/andamento.md`.

Situação em 03/10, fim do dia (branches do `crystal-web-chat`):

| Etapa | Branch | Commit | Testes | Estado |
|---|---|---|---|---|
| 1 (8 itens + blindagem) | `otimizacao/etapa-1` → build `claude/gracious-shannon-6x9l5j` | `79ba6b7` | 944 + e2e 20/20, CI verde | Imagens `sha-79ba6b7` prontas. **Falta publicar** (portão 1) |
| 2 (11 itens) | `otimizacao/etapa-2` | `3b06150` | 1113 + e2e 27/27 | Integrada; migrações `e2_14…e2_18`, fontes locais. Imagem `sha-69ef26c`. Publica depois do portão 1 |
| 3 (7 itens) | `otimizacao/etapa-3` | `ede085b` | 1224 + e2e 33/33 | Integrada; contém a 2. Zero conflitos. Fase 3 do P12 ligada, com chave de desligar |

Custo das 10 sessões de código: cerca de US$ 200. **As três etapas publicadas em 05/10**: etapa 1 (`sha-79ba6b7`), etapas 2+3 num release só (`sha-da617ac`) e os ajustes pós-QA (`sha-8ed9ce8`, `sha-99d80cf`, `sha-398e46e`; versão atual `sha-f866bc0`: correções da revisão, contas locais e contatos do suporte no login, 06/10). QA no iPhone aprovado nas três etapas, segurar para gravar incluído. Faltam o QA em Android e o teste do reembolso com o JSON da Assiny.

Ordem de publicação combinada (roteiro completo, com as listas de conferência em
aparelho, em `crystal-em-casa/publicar-prd.md`), cada passo com `backup` antes:

1. **Portão 1**: `app-definir REFUND_WEBHOOK_SECRET` e `TRANSCRIPTION_API_KEY` (Groq),
   `backup`, `app-subir sha-79ba6b7`. Testar áudio (transcrição), foto e reembolso.
2. **Etapa 2** como um só release: merge de `otimizacao/etapa-2` na branch de build, imagem
   nova, `app-subir`. Antes, garantir que `CRYSTAL_ONBOARDING_URL` não está no `.externos`.
3. **Etapa 3** idem. QA em aparelho da fase 3 do P12 (segurar para gravar) decide se ela
   fica: `SEGURAR_PARA_GRAVAR = false` em `Composer.tsx` desliga numa linha.

Pendências do Luiz para o squad (lista completa em `andamento.md`):

- Exemplo de JSON do webhook de reembolso da **Assiny** (mascarado), para fechar o Q07.
- Chave do **Groq** (`TRANSCRIPTION_API_KEY`).
- **Android** com Chrome para os testes.
- Conferir no iPhone, nos dois temas, as cores do WhatsApp (P16), o papel de parede (P08)
  e `statusBarStyle`; textos "0:07" do gravador; nomes "Tema"/"Sistema".
- Decisões do Luiz em 05/10: **excluir conta NÃO apaga o contato no Chatwoot** (a
  conversa do WhatsApp fica; não definir `CHATWOOT_API_TOKEN`; a política de privacidade
  deve dizer que o histórico de atendimento fica com a equipe); **erro da Crystal em turno
  de risco avisa a equipe por e-mail** (`EQUIPE_EMAIL`, padrão contato@leticiafelisberto.com,
  em implementação); **quem atende o Chatwoot é a equipe de suporte**; gravação de áudio
  também **sem segurar**, com a trava de deslizar para cima como no WhatsApp (em
  implementação). Alunas **sem CPF na base** (1.708 em 05/10): decisão de 06/10, o app orienta a falar com o suporte (WhatsApp da Bia e e-mail aparecem na tela de login quando o cadastro não é encontrado); o suporte completa o CPF no Supabase. Ainda sem resposta: reembolso quando só o e-mail bate; abrir para todas ou só `is_in_rollout` (hoje está aberto para todas com CPF e acesso ativo/pendente).

## Revisão geral do código (02/10)

Pedida pelo Luiz em 02/10 e feita no mesmo dia: ~48 mil linhas lidas por seis
revisores, 770 testes + 20 e2e verdes, smoke real contra o Postgres. Consolidado em
`auditorias/2026-10-02/revisao-geral/00-RELATORIO.md`. Resultado: 0 críticos, 13
altos reais (3 não procederam, 2 já mitigados), 71 médios. Decisões pendentes do
Luiz: DPO, enquadramento da cópia anônima, quando migrar para Docker secrets, quem
atende no Chatwoot. Ordem de correção em três rodadas está no relatório.

## Nosso Chatwoot no lugar do LendChat (02/10)

Decisão do Luiz: o LendChat vai sair. O app vai para o nosso Chatwoot
(`atendimento.crystalnowpp.com.br`), com a nossa Crystal como robô e a equipe
podendo assumir a conversa. Passo a passo em `crystal-em-casa/README.md`, seção
"Ligar o nosso Chatwoot":

1. DNS `atendimento.` cinza no Cloudflare.
2. `atendimento-subir`, `atendimento-segredos` (Bitwarden), `atendimento-configurar TAG`
   (o teste no fim tem que mostrar a resposta da Crystal), 2FA no primeiro login.
3. `app-canal chatwoot` e conversa de teste no app; conferir que ela aparece no Chatwoot.

Depois, sem pressa:
- WhatsApp no nosso Chatwoot: precisa de quem controla o app da Meta e a BM do
  número, um número de teste antes e o corte combinado com a agência (reversível).
- Atendentes da equipe: convidar pelo Chatwoot (Configurações > Agentes), cada um
  com 2FA.
- Exclusão de conta também apagar o contato no Chatwoot (hoje a memória da Crystal
  é apagada; a conversa fica no nosso Chatwoot, não mais num terceiro).

## Esperando o Tuan (agência), em 02/10

Decisão do Luiz em 02/10: a "alma" da Crystal do app espera o material da
agência. Nada de improvisar método ou base de conhecimento até lá.

1. **Prompt completo** do agente em produção (texto de instruções). Vai para
   `crystal-web-chat/apps/crystal/prompt/crystal.md` e tira o RASCUNHO.
2. **Base de conhecimento** (aulas e materiais da Letícia) e onde está guardada.
   Se estiver no Supabase a transferir, quais tabelas. Vai para
   `apps/crystal/conhecimento/` (até 60 mil caracteres; acima disso, busca por trechos).
3. ~~Conserto do LendChat~~: consertado em 02/10 (conferido daqui), mas o app
   não volta para lá: o LendChat vai sair. Pedir ao Tuan para apagar o contato
   de teste `diagnostico-crystal-app-3`.
4. **Transferência do Supabase** (base de alunos e, talvez, a base de conhecimento).
5. **Código do agente** no repositório `crystal-ia`, ainda vazio.

Pronto para quando decidirem: a Crystal do app usar o perfil, as metas e o
progresso da aluna (com consentimento de dados sensíveis) nas respostas.
