# Publicar o PRD de Otimização na VPS

Três releases, nesta ordem, cada um com `backup` antes e teste em aparelho depois.
Tudo que não é comando na VPS já está feito: código integrado, testes verdes,
imagens construídas. Este roteiro é só o que o Luiz roda e confere.

> **Versão no ar desde 05/10: `sha-398e46e`** (as três etapas e os ajustes pós-QA).
> Qualquer `app-subir` de hoje em diante usa `sha-398e46e` ou uma tag mais nova.
> As tags `sha-79ba6b7`, `sha-69ef26c` e `sha-da617ac` abaixo são o histórico de
> cada release: rodar `app-subir` com elas VOLTA a produção para uma versão anterior.

| Release | Branch | Commit no `crystal-web-chat` | Tag da imagem |
|---|---|---|---|
| 1 · Base e segurança | `otimizacao/etapa-1` | `79ba6b7` (hotfix do guard https sobre `cdc45f5`) | `sha-79ba6b7` |
| 2 · Início e perfil | `otimizacao/etapa-2` | `69ef26c` | `sha-69ef26c` |
| 3 · Conversa e visual | `otimizacao/etapa-3` | `398e46e` (`da617ac` + ajustes pós-QA de 05/10) | `sha-398e46e` |

Aprendido em 05/10, na primeira tentativa da etapa 1: a API nova recusou
`CRYSTAL_API_URL=http://app_crystal:8080` (guard de https em produção), morreu na
subida e o Swarm voltou sozinho para a imagem anterior, deixando web novo com API
velha. O guard passou a aceitar http só para host interno do Docker (sem ponto), e o
`app-subir` agora confere a tag de cada serviço e mostra o log do contêiner que
morreu. Se isso acontecer de novo: `app-subir <tag anterior>` e mandar o log.

Regras que valem nos três:

- **Um comando por vez**, no console web da Hostinger, e esperar o `ok`.
- `<commit>` nas URLs é o commit **deste** repositório (`git log -1` na branch
  `claude/gracious-shannon-6x9l5j`). Nunca `curl | bash`: baixar, depois rodar.
- Migrações do banco rodam sozinhas na subida da API: o próprio `app_api` roda
  `prisma migrate deploy` antes de subir (não existe serviço `migrate` na stack) e tenta
  de novo por até 1 min se o Postgres ainda estiver subindo. São
  aditivas; a volta de imagem não precisa de volta de banco. A exceção é a etapa 2, que
  apaga a tabela `onboarding_states` (vazia no nosso uso): o `backup` antes cobre.
- Volta de qualquer release: `bash bootstrap-vps.sh app-subir <tag anterior>`.
- **O `ok` do `app-subir` agora vale** (revisão de 05/10, achado 4): antes do deploy o
  `api.env` passa pelo boot da própria imagem (valor errado para ali, com a API atual no
  ar); depois do deploy, o script falha se o Swarm desfez a troca (`UpdateStatus` em
  `rollback_*`), mesmo com a tag igual, e mostra o log do contêiner que morreu. Conferir
  à mão, se quiser: `docker service inspect crystal_app_app_api -f '{{.UpdateStatus.State}}'`
  (tem que ser `completed` ou vazio).
- Segredos só pelo `app-definir`, que pergunta sem eco. Nunca na linha de comando.

## Antes do release 1 (uma vez)

Fora da VPS:

1. **Groq**: criar a chave em console.groq.com (conta com 2FA), limite de gasto baixo.
   Guardar no Bitwarden.
2. **Segredo do reembolso**: `openssl rand -hex 32` no Mac. Guardar no Bitwarden.
3. **Assiny**: webhook com URL `https://api.crystalnowpp.com.br/webhooks/reembolso`,
   cabeçalho `Authorization: Bearer <segredo do passo 2>`, eventos de reembolso,
   chargeback e cancelamento, todos os produtos. Pedir à Assiny um exemplo do JSON
   (mascarado) e mandar para a sessão: o parser ainda é suposição até isso chegar.
4. Dois aparelhos à mão: iPhone (Safari e app instalado) e Android (Chrome).

Na VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh app-definir REFUND_WEBHOOK_SECRET   # cola o segredo do passo 2
bash bootstrap-vps.sh app-definir TRANSCRIPTION_API_KEY   # cola a chave da Groq
bash bootstrap-vps.sh app-status                          # anotar a tag atual (volta)
```

## Release 1 · etapa 1 (`sha-79ba6b7`)

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-79ba6b7
bash bootstrap-vps.sh app-status
```

Conferir em aparelho (iPhone e Android):

- [ ] Entrar: código por e-mail chega, sessão fica depois de fechar e abrir o app.
- [ ] Modo avião: tela "sem conexão" aparece; volta sozinha com rede.
- [ ] Áudio: gravar 5 s e enviar; a bolha mostra a transcrição em alguns segundos.
- [ ] Foto: enviar uma foto; a Crystal comenta o conteúdo.
- [ ] Termos: o nome do DPO e o e-mail aparecem na política.
- [ ] Equipe: `/equipe/crystal` abre com a foto da Crystal.
- [ ] Reembolso (só com o JSON da Assiny): evento de teste bloqueia a conta certa.

Se a transcrição falhar, a vigia mostra `transcricao` nos logs da API; a resposta
fixa "não consegui ouvir" aparece para o aluno e o resto do app segue.

## Release 2 · etapa 2 (`sha-69ef26c`)

```bash
bash bootstrap-vps.sh app-remover CRYSTAL_ONBOARDING_URL   # a etapa 2 não usa mais
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-69ef26c
bash bootstrap-vps.sh app-status
```

Conferir em aparelho:

- [ ] Tela inicial `/` com os cards; contato da Crystal na lista.
- [ ] Aluno novo: o chat fica travado até o perfil completo; depois libera na hora.
- [ ] Foto do aluno: trocar e ver no menu.
- [ ] Menu: tutorial roda uma vez só; "Excluir conta" pede `EXCLUIR` e apaga.
- [ ] Banner "instalar": aparece no Android, soma no iPhone (orientação de "Adicionar à tela").
- [ ] Equipe: `/equipe/avisos` manda um aviso de teste; chega no aparelho.
- [ ] Cards de suporte abrem o WhatsApp e o e-mail certos.

## Release 3 · etapa 3 (publicada em 05/10 como `sha-da617ac`; hoje `sha-398e46e`)

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-398e46e   # NÃO sha-da617ac: essa voltaria antes dos ajustes pós-QA
bash bootstrap-vps.sh app-status
```

Conferir em aparelho (roteiros completos em `docs/otimizacao/pedidos-e3-*.md` do
`crystal-web-chat`):

- [ ] Visual: papel de parede só atrás das bolhas; tema claro/escuro/sistema troca na
  hora; comparar lado a lado com o WhatsApp no iPhone, nos dois modos.
- [ ] Topo: foto da Crystal, "online", sem CPF; deitado também.
- [ ] Conversa: relógio, um tique, dois cinza, dois azuis; resposta em 2 a 4 bolhas com
  "digitando…"; derrubar a rede no meio mostra "Tentar de novo" sem repetir a pergunta.
- [ ] Áudio: tocador com onda; áudio antigo toca sem "NaN"; gravar por toque com onda ao
  vivo; iPhone logo depois de gravar toca no alto-falante.
- [ ] **Segurar para gravar** (decide se fica): segurar 3 s e soltar envia; arrastar para a
  esquerda cancela; tela não rola nem seleciona texto; toque curto abre o painel.
  Reprovou em um dos dois aparelhos: `SEGURAR_PARA_GRAVAR = false` em
  `apps/web/components/chat/Composer.tsx`, imagem nova, `app-subir`. O resto fica.
- [ ] Equipe: `/equipe/crystal` ajusta o ritmo das bolhas e vale na próxima resposta.

## Ajustes pós-QA (05/10, depois do iPhone aprovar)

Pedidos do Luiz do mesmo dia, em três imagens (`sha-8ed9ce8`, `sha-99d80cf`, `sha-398e46e`, todas publicadas): teclado no iPhone não esconde mais a conversa; foto da Crystal padrão, recortada no rosto; trava de gravação deslizando para cima; e-mail à equipe quando a Crystal falha em turno de risco (`EQUIPE_EMAIL`). Na primeira: a pílula "Manda o print" saiu
(imagem só pelo ícone de clipe à direita do campo, como no WhatsApp) e a folha de
notificações fecha sozinha 1,5 s depois do "Pronto!", com botão Fechar. Subida:
`backup` e `app-subir sha-8ed9ce8`. Conferir: ícone de clipe no lugar da pílula;
ativar notificações no menu e ver a folha sumir.

## Base de alunos no Supabase (ligada em 05/10)

Feito em 05/10, com alunas reais entrando: a função `app_verificar_login` foi criada no
SQL Editor do Supabase (`crystal-em-casa/supabase/app_verificar_login.sql`), a URL e a
chave foram gravadas na VPS e o login de uma aluna real da base foi testado no app. No
caminho, a URL foi colada com `/rest/v1/` no fim (todo login daria 503) e foi corrigida
para `https://<ref>.supabase.co`. Desde a revisão de 05/10 o `app-definir` corta esse
caminho sozinho, avisa, e recusa a chave anon ou publicável.

Para refazer ou trocar a chave (um comando por vez):

```bash
bash bootstrap-vps.sh app-definir SUPABASE_URL               # https://<ref>.supabase.co, nada depois
bash bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY  # sb_secret_... ou a service_role (eyJ...), colar no prompt
bash bootstrap-vps.sh app-supabase-teste                     # 200 ok; 404 função não existe; 401 chave errada
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-398e46e                  # confere o api.env antes, o rollback depois, e roda o app-supabase-teste no fim
```

O `app-supabase-teste` chama a função com um CPF fictício e mostra só o código HTTP e o
que ele quer dizer, nunca a chave nem a resposta. Se a base parar (chave trocada no
painel, função apagada), todo login de aluna da base dá 503: rodar o teste primeiro.
Contas criadas pelo `app-aluno` também passam pela base a cada login.

## Comandos novos da revisão de 05/10

- `app-supabase-teste`: acima.
- `app-definir` aceita `EQUIPE_EMAIL` (quem recebe o aviso de risco) e os limites de login
  `RATE_AUTH_MAX`, `RATE_AUTH_WINDOW_S`, `OTP_MAX_ATTEMPTS`, `OTP_RESEND_COOLDOWN_S`,
  `OTP_RESEND_MAX`, todos conferidos antes de gravar. Vale na próxima `app-subir`.
- `backup` leva também a memória da Crystal (`crystal_agente`); uploads em tar
  incremental (completo no domingo, diferencial nos outros dias). Parte que falha não para
  as outras nem o envio ao R2; no fim mostra o que falhou e sai 1. `backup-link
  crystal_agente` dá o link do dump da memória.
- A vigia avisa backup completo com mais de 26 h, falha no último backup, cópia no R2
  velha e disco do Docker a partir de 85%.
- `app-recomecar` e `recomecar-n8n` pedem `APAGAR` digitado, só seguem com o banco
  comprovadamente vazio e copiam bancos e segredos antes.
- A primeira `app-subir` depois desta versão reinicia cada serviço do app uma vez (rotação
  de log e restart_policy novos na stack). Fazer com `backup` antes, fora do pico.

## Correções da revisão completa (05/10, imagem `sha-9a554f6`; depois `sha-f866bc0` com os contatos do suporte no login)

Os 76 achados da revisão (`auditorias/2026-10-05/revisao-completa/`) foram corrigidos,
menos os três do reembolso, que esperam o JSON da Assiny. Do lado do app: detecção
de risco também na API e contatos garantidos em qualquer falha; exclusão de conta
apaga a memória da Crystal; sonda real do Supabase; limite de login por IP em 50;
`client_message_id` contra mensagem duplicada; contas locais de aluno (`app-aluno` não passa pela base); 1439 testes, e2e 35/35. Do lado da
VPS: script `894a7c5` ou mais novo. A primeira subida com ele reinicia cada serviço
uma vez (a stack mudou): fazer com backup e fora do pico.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-9a554f6      # valida o api.env, confere rollback e testa o Supabase no fim
```

Conferir depois: login com a conta de aluna; áudio do iPhone e do Android (o upload
agora recusa bytes que não batem com o tipo, 415); `/equipe` mostra "Supabase (base
de alunas)" nas integrações.

## Medição de custo e cache do prompt (branch `otimizacao/custo-modelo`, 06/10)

A Crystal passa a registrar tokens e custo de cada turno e de cada resumo (só
números) e marca o prompt fixo para cache. Leitura em `auditorias/2026-10-06/openrouter-uso.md`.
A imagem só sai quando a branch for integrada em `otimizacao/etapa-3` (decisão do dono).

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-XXXXXXX
bash bootstrap-vps.sh app-custo 24             # depois de um dia de uso: custo por turno e projeção
# opcional: bash bootstrap-vps.sh app-definir CRYSTAL_MODEL_RESUMO   (modelo mais barato só para o resumo)
```

## Alma da Crystal (publicada em 06/10 como `sha-6cd7626`, junto com o Chatwoot)

Publicada em 06/10 pelo `atendimento-configurar sha-6cd7626`: stack em `sha-6cd7626` sem
rollback, Supabase 200, Crystal respondeu como robô na inbox do Chatwoot. Chatwoot
v4.18.0-ce no ar em `atendimento.` (DNS cinza, certificado válido). `app-canal chatwoot`
ainda NÃO foi ligado: o app segue falando direto com a Crystal.

Prompt v2.2 da agência (repositório `crystal-ia`) adaptado em `apps/crystal/prompt/crystal.md`
e busca na base de conhecimento da Letícia (Edge Function `crystal_hybrid_search` do
Supabase, 168 trechos) a cada turno. A branch inclui `otimizacao/custo-modelo`.
Leitura: `auditorias/2026-10-06/alma-crystal-ia.md`. Antes de publicar, decisão da
Letícia: o prompt pede no máximo 3 balões e proíbe listas; o fluxo de print entrega
leitura + 3 opções.

```bash
# 1. integrar otimizacao/alma em otimizacao/etapa-3 (dispara a imagem) — decisão do dono
# 2. na VPS, com o script 805dab3 ou mais novo (a URL e a chave do Supabase passam ao crystal.env):
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-XXXXXXX
bash bootstrap-vps.sh crystal-nossa-teste         # /healthz deve mostrar conhecimento_busca: true
bash bootstrap-vps.sh app-custo 24                 # no dia seguinte: trechos por turno, cache e custo
# Volta: bash bootstrap-vps.sh app-subir sha-f866bc0
```

Conferir no aparelho: uma pergunta de conselho (deve vir com o tom da Crystal e tática
da base), um "oi" (sem busca, resposta curta), um print.

## Lotes de divulgação + webhook da Assiny (publicada em 06/10 como `sha-bbfa96b`)

Publicada em 06/10 15:10 UTC: stack em `sha-bbfa96b` sem rollback, Supabase 200. O backup
passou a incluir o Chatwoot (banco e anexos), na VPS e no R2.
Aprovada no iPhone em 06/10 (dono): alma com tom bom, busca com 6 trechos por conselho,
cache em 93%, custo US$ 0,003 por turno com a base.

Branch `otimizacao/lotes-reembolso` (= `otimizacao/lotes` + `otimizacao/reembolso-assiny`).
Decisões do Igor em 06/10. SQL do Supabase já aplicado em 06/10 (função devolve `liberado`;
1.459 liberados, 9.514 esperando; contas de teste do time liberadas).

- **Lotes**: `ROLLOUT_GATE` (padrão `on`): quem está na base com acesso mas `is_in_rollout`
  falso vê "Falta pouco! Seu acesso ao app está sendo liberado em lotes" (403
  `LOGIN_NOT_RELEASED`), sem conta nem código. Liberar um lote = `update ... set
  is_in_rollout = true where ...` no Supabase. Abrir geral: `app-definir ROLLOUT_GATE` = `off`.
- **Reembolso**: o webhook lê o envelope real da Assiny. `REFUND_EVENTS` (padrão
  `refunded_purchase,chargeback,chargedback_purchase,canceled_subscription,subscription_canceled`)
  e `REFUND_PRODUCT_IDS` (vazio = qualquer produto corta). Idempotente por transação (30 dias).
  Teste manual no formato antigo `{cpf,email,event_id}` passa a dar 400.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-bbfa96b
# Volta: bash bootstrap-vps.sh app-subir sha-6cd7626
```

Conferir: login com conta liberada entra; login com CPF+e-mail de aluno fora do lote mostra
"Falta pouco!"; na Assiny, o webhook segue em https://api.crystalnowpp.com.br/webhooks/reembolso
com `Authorization: Bearer <REFUND_WEBHOOK_SECRET>`, eventos de reembolso, chargeback e
cancelamento, todos os produtos. Um reembolso de teste deve responder 200 `matched: true|false`.
Depois de um dia: `app-custo 24`.

## Sem travessão (imagem `sha-6a4b16a`, integrada em 06/10)

Achado do dono no iPhone: respostas com "cara de IA", cheias de travessão. Bloco de formato
do prompt proíbe travessão e hífen no meio da frase; a API, antes das bolhas, troca travessão,
meia-risca e hífen entre espaços por quebra de linha (frase seguinte em maiúscula) e reduz
grupos de emoji a um. Inclui também os overrides de segurança `source-map-js` 1.2.2 e
`sharp` 0.35.5 (avisos publicados em 06/10).

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-6a4b16a
# Volta: bash bootstrap-vps.sh app-subir sha-bbfa96b
```

Conferir no aparelho: uma resposta de conselho sem travessão e com no máximo um emoji por bolha.

## Painel de alunos para o suporte (imagem `sha-55ad193`, integrada em 06/10)

Branch `otimizacao/painel-alunos` em cima do travessão (`6a4b16a`). "Alunos" no `/equipe`,
papéis admin e suporte: busca por e-mail ou CPF (só os 2 últimos dígitos aparecem), conta
local para quem não tem CPF na base, corrigir e-mail e WhatsApp, revogar e reativar. Rotas
`/staff/alunos*` com limite por pessoa e auditoria sem dados pessoais. Sem migração.

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-55ad193
# Volta: bash bootstrap-vps.sh app-subir sha-bbfa96b
```

Depois: criar a conta da Bia na área de equipe com o papel de suporte; ela entra em
app.crystalnowpp.com.br/equipe > Alunos. Testar: buscar o Igor por e-mail, criar uma conta
local de teste e revogá-la.

## Legenda na foto (imagem `sha-88c681f`, integrada em 06/10)

Feedback do time no iPhone: a foto ia na hora, sem lugar para a legenda. Agora, ao escolher
a imagem, abre uma pré-visualização com a foto, o campo de legenda (já com o texto digitado)
e o botão de enviar; X cancela e devolve o texto ao campo. A imagem inclui o painel de
alunos, o travessão e os avisos de segurança.

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-88c681f
# Volta: bash bootstrap-vps.sh app-subir sha-bbfa96b
```

Conferir no aparelho: escolher uma foto, escrever a legenda com o teclado aberto, enviar;
cancelar uma segunda foto e ver o texto voltar ao campo.

## Login sem código, modo de lançamento (publicado em 06/10 como `sha-94a2648`)

Canal do Chatwoot ligado no app em 06/10 à noite (`app-canal chatwoot`, mesma tag): toda
conversa passa pela inbox em atendimento.; a equipe assume quando quiser. Volta: `app-canal crystal`.

Publicado em 06/10 22:05 UTC com `LOGIN_CODIGO=nenhum`: stack em `sha-94a2648` sem rollback,
Supabase 200. Conta local criada para o e-mail de contato da equipe (`app-aluno`).
Aprovado no iPhone em 06/10 (dono): entrou direto sem código; tudo passou.

Decisão do dono em 06/10, depois de ouvir o risco (quem souber CPF e e-mail entra como o
aluno): por enquanto, aluno entra sem o código do e-mail. Chave `LOGIN_CODIGO` (`email`
padrão | `nenhum`). Compensações com `nenhum`: 5 erros por 15 min por CPF e por e-mail
além do limite por IP; e-mail "Alguém entrou na sua conta da Crystal" a cada login novo
(hora em Brasília, aparelho resumido, contatos da Bia); trocar e-mail revoga sessões;
auditoria `auth.login { codigo: "nenhum" }`. Equipe e contas de revisão seguem com código.
A imagem inclui tudo de 06/10 (alma, lotes, reembolso, travessão, painel, legenda).

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/505a5ed/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
bash bootstrap-vps.sh app-definir LOGIN_CODIGO     # digitar: nenhum
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-94a2648
# Voltar ao código: bash bootstrap-vps.sh app-definir LOGIN_CODIGO (email) e app-subir de novo
```

Conferir: sair da conta no iPhone e entrar de novo com CPF e e-mail: cai direto no chat, e o
e-mail "Alguém entrou na sua conta" chega. Equipe no /equipe continua pedindo código.

## Canal: aluno sem WhatsApp (publicado em 07/10 como `sha-e84fa62`)

Publicado em 07/10 de madrugada: stack em `sha-e84fa62` sem rollback, Supabase 200.

Primeiro dia com o canal do Chatwoot ligado: conta sem WhatsApp no cadastro recebia "Não
achei o seu WhatsApp" e não falava com a Crystal. Agora o contato na inbox nasce com
`app:<id do aluno>` quando não há número; com número, segue sendo o WhatsApp.

```bash
bash bootstrap-vps.sh app-subir sha-e84fa62
# Volta: bash bootstrap-vps.sh app-subir sha-94a2648
```

Conferir: com a conta sem WhatsApp, mandar texto e foto; a resposta vem e a conversa aparece
no Chatwoot.

## Painel corrige a base de alunos (imagem `sha-7039a99`, integrada em 07/10)

Decisão do dono em 07/10: a Bia corrige a base da compra pelo painel, sem SQL. Aba "Base de
alunos" em /equipe > Alunos: busca por CPF ou e-mail na base do Supabase; corrigir e-mail,
informar CPF (só quando vazio), liberar ou tirar do lote. Quatro funções no Supabase, só
para a chave do servidor (`crystal-em-casa/supabase/app_equipe_alunos.sql`). Corrigir e-mail
de quem já entrou no app ajusta a conta e derruba as sessões. Auditoria sem dados pessoais.

```bash
# 1. Supabase, SQL Editor: aplicar o arquivo inteiro app_equipe_alunos.sql (commit 6f0ea10)
# 2. VPS:
bash bootstrap-vps.sh app-definir RATE_AUTH_IP_MAX     # digitar: 200 (operadoras com IP compartilhado)
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-7039a99
# Volta: bash bootstrap-vps.sh app-subir sha-e84fa62
```

Conferir: na aba Base de alunos, buscar o Igor por e-mail; num aluno de teste, corrigir o
e-mail e entrar com o novo. Sem o SQL aplicado, a aba responde "base indisponível".

## Painel gerencial + uso da Crystal (imagem `sha-eb1b460`, integrada em 07/10)

Inclui o painel da base (`sha-7039a99`). Painel gerencial em /equipe/painel, só admin:
acessos (1, 3, 7, 14, 21, 30 dias), ao vivo, mensagens por tipo e por hora, nuvem de
palavras agregada, top 20, custos da Crystal por modelo, áudio (`TRANSCRIPTION_PRICE_PER_HOUR_USD`,
padrão 0,04) e imagem, saldo do OpenRouter (alerta abaixo de US$ 20), funil de login,
retenção, projeção de 30 dias. A Crystal grava `uso_turnos` (sem texto) e expõe
`GET /v1/uso` e `/v1/uso/conta`; a tabela nasce sozinha na subida.

```bash
# Supabase: app_equipe_alunos.sql aplicado (commit 6f0ea10)
bash bootstrap-vps.sh app-definir RATE_AUTH_IP_MAX     # digitar: 200
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-eb1b460
# Volta: bash bootstrap-vps.sh app-subir sha-e84fa62
```

Conferir: /equipe > Painel abre com números (bloco da Crystal vazio até o primeiro turno
depois da subida); /equipe > Alunos > Base de alunos acha o Igor por e-mail.

## Login só com o e-mail da compra (publicado em 07/10 como `sha-e62f697`)

Publicado e aprovado no iPhone em 07/10 (dono): entrou só com o e-mail e o código.

Decisão do dono em 07/10: aluno digita só o e-mail da compra e recebe o código de seis
dígitos; CPF deixa de ser obrigatório (resolve os 1.673 sem CPF). `LOGIN_MODO` (`email`
padrão | `cpf_email` para voltar); no modo `email` o código é sempre exigido. Migração
`e3_22_login_email` no boot: CPF opcional, vínculo com o cadastro da base único. Função
`app_verificar_login_email` no Supabase (`crystal-em-casa/supabase/`, commit 1ba7b2f),
OBRIGATÓRIA antes do deploy. Inclui os três painéis e o uso da Crystal (`sha-eb1b460`).

```bash
# 1. Supabase, SQL Editor: app_verificar_login_email.sql e app_equipe_alunos.sql (arquivo inteiro cada)
# 2. VPS:
bash bootstrap-vps.sh app-definir RATE_AUTH_IP_MAX     # digitar: 200 (se ainda não fez)
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-e62f697            # testa a função do modo no fim
# Volta sem trocar imagem: app-definir LOGIN_MODO (cpf_email) + app-subir sha-e62f697
# Volta total: app-subir sha-e84fa62
```

Conferir: sair da conta no iPhone e entrar só com o e-mail: código chega, entra. Conta
local sem WhatsApp: texto e foto. /equipe > Painel e /equipe > Alunos > Base de alunos.

## Operação pelo painel (07/10)

Decisão do dono em 07/10: operar a Crystal pelo `/equipe/operacao` (só papel `admin`),
sem VPS e sem SQL. Spec: `spec-operacao.md` da sessão. O que muda de verdade:

- **As variáveis do `app-definir` passam a ser só o PADRÃO.** O painel grava chaves `op_*`
  em `system_settings` (lidas a cada requisição) e elas valem na frente do `api.env`, sem
  `app-subir`: `ROLLOUT_GATE`, `LOGIN_CODIGO`, `REFUND_EVENTS`, `REFUND_PRODUCT_IDS`,
  `RATE_AUTH_IP_MAX` e `TRANSCRIPTION_PRICE_PER_HOUR_USD`. Cada campo mostra "origem:
  painel/padrão" e tem "Voltar ao padrão" (apaga a chave; volta a valer o `api.env`).
  Também pelo painel, sem padrão em env: modelo da Crystal e reserva, trechos da base,
  aviso no chat, modo manutenção e dias de retenção.
- **Continuam só na VPS**: `LOGIN_MODO`, `CHAT_TRANSPORT`, todas as chaves (Resend, Supabase,
  OpenRouter, Groq, webhook da Assiny, Chatwoot) e URLs. E o deploy (`app-subir`).
- **Lotes de acesso** saem do SQL Editor: resumo, "Liberar próximos N mais ativos dos últimos
  D dias" (padrões 500 e 30), liberar por lista de e-mails e CSV (sem CPF, liberados, não
  liberados, ativos 30d). Quatro funções novas em `crystal-em-casa/supabase/app_equipe_lotes.sql`,
  mais a coluna `app_liberado_em` em `leticia_crystal_customers` (carimbo para "liberados hoje";
  única mudança de esquema, nula, avisar o Tuan) e `app_equipe_liberar` redefinida com o carimbo.
  O arquivo roda DEPOIS de `app_equipe_alunos.sql` (já aplicado em 07/10).
- Variáveis novas, **todas opcionais** (padrão = o nome da função; só definir se renomear
  a função no Supabase): `SUPABASE_EQUIPE_LOTE_RESUMO_RPC` (`app_equipe_lote_resumo`),
  `SUPABASE_EQUIPE_LIBERAR_LOTE_RPC` (`app_equipe_liberar_lote`),
  `SUPABASE_EQUIPE_LIBERAR_LISTA_RPC` (`app_equipe_liberar_lista`),
  `SUPABASE_EQUIPE_EXPORTAR_RPC` (`app_equipe_exportar`). Ainda não estão na lista do
  `app-definir`; entram quando alguém precisar.

```bash
# 1. Supabase, SQL Editor: crystal-em-casa/supabase/app_equipe_lotes.sql (arquivo inteiro, uma vez).
#    Conferir: select public.app_equipe_lote_resumo();  (só números)
# 2. VPS, quando a tag sair:
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-<tag>
# Volta (passo 4): bash bootstrap-vps.sh app-subir sha-e62f697
```

3. Conferir no iPhone, em `/equipe/operacao`: o resumo dos lotes carrega (total, liberados,
ativos sem liberar, liberados hoje); salvar uma chave (ex.: texto do aviso + aviso ligado) e ver
"salvo" com origem "painel"; abrir o chat como aluno e ver a faixa com o aviso; "Voltar ao
padrão" apaga. Só depois disso liberar um lote pela tela.

4. Volta: `app-subir` com a tag anterior (`sha-e62f697`). As chaves gravadas em
`system_settings` continuam no banco e não atrapalham a imagem antiga (ela não as lê). Para
voltar ao padrão antes de voltar a imagem: "Voltar ao padrão" na tela, campo a campo, ou, no
Postgres do app, `delete from system_settings where key like 'op_%'`. A coluna
`app_liberado_em` e as funções do Supabase podem ficar: a imagem antiga não as usa.

## Memória de chegada (08/10)

A Crystal do app passa a lembrar do que o aluno já conversou com a Crystal do WhatsApp: no
primeiro login (ou na primeira mensagem) o app importa UMA vez, por aluno e em silêncio, as
últimas 200 mensagens do histórico da agência (Supabase) para a memória da nossa Crystal e gera
o resumo; depois disso o app é a fonte, nada volta para o WhatsApp. Spec: `spec-memoria-chegada.md`
da sessão. SQL: `crystal-em-casa/supabase/app_historico_whatsapp.sql` (só leitura, só
service_role, nenhuma mudança de esquema no Supabase).

- Variável nova, **opcional**: `SUPABASE_HISTORICO_WHATSAPP_RPC` (padrão `app_historico_whatsapp`;
  só definir se renomear a função no Supabase). Nada mais em env: liga e desliga pelo painel.
- Custo: um resumo por aluno, uma vez, no modelo barato de resumo (`CRYSTAL_MODEL_RESUMO`),
  uns US$ 0,002 cada. Mil alunos com histórico dão uns US$ 2.
- Migração do Postgres do app: `e3_23_memoria_chegada`, duas colunas nulas em `users`
  (`whatsapp_importado_em`, `whatsapp_importado_mensagens`). Roda sozinha no `app-subir`.

```bash
# 1. Supabase, SQL Editor: crystal-em-casa/supabase/app_historico_whatsapp.sql (arquivo inteiro, uma vez).
#    Conferir (só números): select count(*) from public.app_historico_whatsapp('<uuid de um aluno>', 200);
# 2. VPS, quando a tag sair:
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-<tag>
# Volta (passo 4): bash bootstrap-vps.sh app-subir sha-<tag anterior>
```

3. Conferir no iPhone com uma conta de aluno que tenha histórico no WhatsApp: entrar e mandar a
primeira mensagem; a resposta já vem com contexto (ela sabe do que falaram). Na equipe, em
Alunos, aba "Contas no app", a conta mostra "Memória do WhatsApp: importada em <data>
(<n> mensagens)". Conta sem histórico mostra "(0 mensagens)" e segue normal. "Importar agora"
força de novo; a Crystal recusa (`ja_tinha`) se o aluno já conversou no app.

4. Desligar sem deploy: chave "Memória de chegada" na área Operação, seção Crystal
(`op_memoria_chegada` off). Quem já importou fica como está; ninguém novo importa. Volta
completa: `app-subir` com a tag anterior (hoje `sha-e62f697`; se a de Operação já estiver no ar,
a dela). A migração `e3_23_memoria_chegada` só acrescenta duas colunas nulas e pode ficar: a
imagem antiga não as lê. A função do Supabase também pode ficar.

## Silêncio no WhatsApp (08/10)

Decisão do dono em 08/10: quem passa a usar o app deixa de receber resposta da Crystal do
WhatsApp (a da agência). Só silêncio, sem mensagem de redirecionamento. Spec:
`spec-whatsapp-silencio.md` da sessão. SQL: `crystal-em-casa/supabase/app_whatsapp_silencio.sql`.

- Como funciona: a Crystal do WhatsApp não responde lead com `is_ai_enabled = false` em
  `leticia_crystal_lead_management` (nulo = ligado). Com a chave "Silêncio no WhatsApp" ligada
  (Operação, seção WhatsApp, `op_whatsapp_silencio`; começa desligada), cada mensagem do aluno
  no app grava false nos leads do número dele, no máximo 1 vez a cada 24 h por aluno. Efeito
  imediato. É a única escrita nossa numa tabela da agência além de `leticia_crystal_customers`,
  e só em `is_ai_enabled` e `updated_at`.
- Limites: aluno que nunca escreveu no WhatsApp não tem lead; a linha nasce ligada na primeira
  mensagem dele lá e só cala na próxima reaplicação (até 24 h, se ele seguir usando o app).
  Telefone do cadastro diferente do WhatsApp (outro chip, sem o 9, sem o 55): não cala.
- Variáveis novas, **opcionais**: `SUPABASE_WHATSAPP_SILENCIAR_RPC` (padrão
  `app_whatsapp_silenciar`) e `SUPABASE_WHATSAPP_ESTADO_RPC` (padrão `app_whatsapp_estado`); só
  definir se renomear as funções no Supabase.
- Migração do Postgres do app: `e3_24_whatsapp_silencio`, duas colunas nulas em `users`
  (`whatsapp_silenciado_em`, `whatsapp_religado_em`). Roda sozinha no `app-subir`.

```bash
# 1. Supabase, SQL Editor: crystal-em-casa/supabase/app_whatsapp_silencio.sql (arquivo inteiro, uma vez).
#    Se parar em ESQUEMA_DIFERENTE, nada foi criado: ler o hint antes de seguir.
#    Anotar quantos já estão silenciados ANTES de ligar (são os da agência; só números):
#      select count(*) filter (where is_ai_enabled is false) as silenciados, count(*) as leads
#        from public.leticia_crystal_lead_management;
# 2. VPS (feito em 09/10: os três serviços em sha-74092e0, sem rollback, HTTPS e base ok):
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-74092e0
# Volta da imagem: bash bootstrap-vps.sh app-subir sha-c320aa0
```

3. **ANTES de ligar**: avisar os alunos (disparo, Bia) que quem usa o app passa a ser atendido
só lá, e avisar o Tuan (escrita em `is_ai_enabled`; perguntas em `PROXIMOS-PASSOS.md`, seção
"Silêncio no WhatsApp").

4. Ligar a chave "Silêncio no WhatsApp" em Operação (pede confirmação). Daí em diante, cada aluno
que mandar mensagem no app é silenciado. Para pegar de uma vez quem já usa o app: "Aplicar agora
a quem já usa o app" (pede confirmação; mostra quantos alunos e conversas).

5. Conferir com um número de teste (conta com o mesmo WhatsApp do cadastro): mandar mensagem no
app, depois mandar no WhatsApp: não vem resposta. Na equipe, em Alunos, a conta mostra "Crystal
no WhatsApp: silenciada desde <data>". A consulta do passo 1 sobe na mesma conta.

6. Desfazer:
   - Desligar a chave: para de silenciar novos. Quem já foi silenciado continua.
   - Religar um aluno: botão "Religar WhatsApp" na conta, em Alunos. Ele fica "religado pela
     equipe" e o app não o silencia de novo.
   - Em massa, no SQL Editor (até 1000 por chamada; e-mails só de exemplo):
     ```sql
     select public.app_whatsapp_silenciar(array(
       select c.id from public.leticia_crystal_customers c
        where lower(trim(c.email)) = any(array['aluno1@exemplo.com', 'aluno2@exemplo.com'])
     ), false);
     ```
     Ou religar TODOS os leads silenciados:
     ```sql
     update public.leticia_crystal_lead_management set is_ai_enabled = true
      where is_ai_enabled is false;
     ```
     Atenção: esse `update` também religa quem a agência silenciou à mão (o número anotado no
     passo 1). E pelo SQL o app não fica sabendo: a tela de Alunos segue mostrando "silenciada
     desde" e, com a chave ligada, o app silencia de novo na próxima mensagem do aluno no app
     (até 24 h depois). Desligar a chave ANTES do SQL em massa.

## Memória única (08/10)

Pedido do dono: a Crystal do app e a do WhatsApp com uma memória só por pessoa, "sem alterar
absolutamente nada do que temos". Com a chave "Memória única" ligada, a nossa Crystal lê, no
começo de cada turno, o que a Crystal do WhatsApp anotou sobre o aluno (fatos e preferências de
`leticia_crystal_lead_memories`, só leitura, cache de 10 min por pessoa) e, quando regrava o
resumo do contato, guarda uma cópia numa tabela NOVA do Supabase. Spec: `spec-memoria-unica.md`
da sessão. SQL: `crystal-em-casa/supabase/app_memoria_unica.sql`.

- **Só acréscimo**: o SQL cria a tabela `crystal_memoria_unica` e as funções `app_memoria_ler`,
  `app_memoria_gravar` e `app_memoria_apagar`, e nada mais. Nenhuma tabela, coluna, função ou permissão que já existe
  muda; as tabelas da agência só aparecem em SELECT. Se já houver tabela ou função com esses
  nomes que não veio do arquivo, ele para em `JA_EXISTE` sem criar nada; se faltar coluna da
  agência, para em `ESQUEMA_DIFERENTE`. Testado em Postgres 16 com esquema fictício: contagem e
  hash das tabelas da agência iguais antes e depois, e o `pg_dump -s` só ganhou os quatro objetos novos.
- A chave "Memória única" (Operação, seção Crystal, `op_memoria_unica`) nasce desligada.
  Desligada, o pedido do app à Crystal é idêntico ao de hoje.
- Por enquanto o caminho é só para o app: a Crystal do WhatsApp não lê a tabela nova enquanto o
  Tuan não quiser (trecho pronto, comentado, no cabeçalho do SQL; nada é aplicado do lado dele).
- Variáveis novas, **opcionais**, no `crystal.env`: `SUPABASE_MEMORIA_LER_RPC` (padrão
  `app_memoria_ler`) e `SUPABASE_MEMORIA_GRAVAR_RPC` (padrão `app_memoria_gravar`); só definir
  se renomear as funções. Usa o `SUPABASE_URL` e a `SUPABASE_SERVICE_ROLE_KEY` que a Crystal já
  tem para a busca na base. Atenção: o `bootstrap-vps.sh` monta o `crystal.env` com uma lista
  fixa e hoje não passa essas duas (com `app-definir` elas iriam para o `api.env`). Com os
  padrões não faz falta; renomear exige acrescentá-las à lista antes.

```bash
# 1. Supabase, SQL Editor: crystal-em-casa/supabase/app_memoria_unica.sql (arquivo inteiro, uma vez).
#    Se parar em JA_EXISTE ou ESQUEMA_DIFERENTE, nada foi criado: ler o hint antes de seguir.
#    Conferir (só nomes; espera-se só postgres e service_role):
#      select routine_name, grantee from information_schema.routine_privileges
#       where routine_schema = 'public' and routine_name like 'app_memoria_%' order by 1, 2;
# 2. VPS, quando a tag sair:
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-<tag>
# Volta da imagem: bash bootstrap-vps.sh app-subir sha-<tag anterior>
```

3. **ANTES de ligar**: trocar a chave service_role que vazou na stack do Tuan (passos em
`PROXIMOS-PASSOS.md`, seção "Supabase: 'Crystal AI' já está na nossa organização"): chave nova
para o app (`app-definir SUPABASE_SERVICE_ROLE_KEY` + `app-subir`, que leva a chave ao `api.env`
e ao `crystal.env`), chave nova para a agência, e só então revogar a antiga. Com a chave antiga
na rua, quem a tem lê por esta função o que o WhatsApp e o app sabem de cada aluno.

4. Ligar a chave "Memória única" em Operação, seção Crystal (pede confirmação).

5. Conferir com uma conta de aluno que tenha memória no WhatsApp (o mesmo número do cadastro):
perguntar no app algo que só a Crystal do WhatsApp saberia; a resposta usa o que ela anotou, sem
despejar tudo de uma vez. No SQL Editor, só números:
   ```sql
   select char_length(r->>'whatsapp_fatos') as fatos,
          json_array_length(r->'whatsapp_preferencias') as prefs,
          r->>'app_atualizado_em' as app_em
     from (select public.app_memoria_ler('<uuid do aluno>') as r) s;
   ```
   `app_em` aparece depois que o app regravar o resumo do contato (não é a cada mensagem). Conta
   sem memória no WhatsApp segue normal (fatos nulo, prefs 0).

6. Desfazer: desligar a chave "Memória única". Volta tudo ao que era: o pedido à Crystal fica
idêntico ao de antes e nada mais é lido nem gravado no Supabase. A tabela nova e as três funções
podem ficar (ninguém as chama, a não ser `app_memoria_apagar`, que a API chama sempre que um
aluno exclui a conta ou apaga as conversas, para a LGPD). Apagar de vez só se o dono pedir (os
`drop` estão no cabeçalho do SQL). Na agência não há nada a desfazer.

## Compra direta pela Assiny, sem a agência (09/10)

Decisão do dono: "ele compra na Assiny e já tem que liberar o app", tudo nosso, via n8n. Caminho:
Assiny (webhook) → nosso n8n (`webhook.crystalnowpp.com.br/webhook/assiny-compras`) →
`app_compra_evento` no Supabase (tabela NOSSA `crystal_compras`) → o login do app aceita quem está
lá, já liberado. Compra nova manda e-mail de boas-vindas pelo Resend; reembolso, chargeback e
cancelamento bloqueiam a linha e são repassados à API (`/webhooks/reembolso`), que desliga a conta.

- SQL: `crystal-em-casa/supabase/app_compras.sql` (tabelas `crystal_compras`, `crystal_compras_eventos`,
  `crystal_compras_produtos`; `app_compra_evento`; `app_verificar_login_email` passa a olhar a base
  antiga primeiro e depois `crystal_compras`). Testado em Postgres 16 (17 casos, incluindo reenvio,
  renovação, reembolso de outra compra, aprovação atrasada, recompra e login de quem já é da base).
- Fluxo: `crystal-em-casa/n8n/compra-assiny.json` (n8n 1.123.10). Testado num n8n 1.123.10 local com
  serviços falsos: cabeçalho errado 403; compra 200 + um e-mail; reenvio 200 sem e-mail; reembolso
  200 + repasse à API; inválido 500; Supabase fora do ar 500 (a Assiny reenvia) e depois 200.
- Desfazer: desativar o fluxo no n8n e rodar `app_verificar_login_email.sql` de novo.

Ligar, nesta ordem:
1. Supabase, SQL Editor: `app_compras.sql` inteiro. Depois, API Keys > New secret key `n8n-compras`.
2. Resend: API Keys > Create, nome `n8n-boas-vindas`, permissão Sending access, domínio
   crystalnowpp.com.br.
3. Segredo do reembolso: gerar novo (`openssl rand -hex 32`, guardar no Bitwarden),
   `bash bootstrap-vps.sh app-definir REFUND_WEBHOOK_SECRET` e `app-subir sha-74092e0` (troca o que
   a agência pudesse ter). Segredo do cabeçalho da Assiny: outro `openssl rand -hex 32`.
4. n8n (editor.crystalnowpp.com.br): importar o JSON; criar 4 credenciais Header Auth
   (`Assiny webhook`: x-crystal-token; `Supabase n8n-compras`: apikey; `Resend boas-vindas`:
   Authorization = Bearer re_...; `API reembolso`: Authorization = Bearer <segredo do reembolso>);
   escolher cada uma no seu nó; salvar e ativar.
5. Teste com um e-mail seu de teste (curl no roteiro do chat de 09/10); conferir e-mail e login.
6. Assiny: webhook para a URL acima, com o cabeçalho, eventos de compra aprovada, renovação,
   reembolso, chargeback e cancelamento. Tirar o webhook antigo da agência.
7. Depois das primeiras compras: preencher `crystal_compras_produtos` só com os produtos da Crystal.

Atalho de 10/10 para os passos 2 a 5: `crystal-em-casa/n8n/compra-assiny-credenciais.py`, na VPS. Lê
as chaves que o app já usa (`.externos`: service_role, Resend, segredo do reembolso), gera o token da
Assiny em `/root/crystal/n8n-compras.segredos`, testa cada chave direto no serviço, grava os valores
nas 4 credenciais que o fluxo já usa (`n8n import:credentials`, nada sai da VPS) e testa de ponta a
ponta com a caixa de teste do Resend. Testado num n8n 1.123.10 com Postgres e serviços falsos.
Fraquezas aceitas pelo dono: o n8n usa a mesma service_role e a mesma chave do Resend que o app
(`--supabase-proprio` e `--resend-proprio` trocam por chaves só do n8n).

Limites: o painel (Alunos > base) ainda não lista quem está só em `crystal_compras` (aparece em
Alunos depois do primeiro login). Recompra depois de reembolso: o suporte reativa a conta no painel.

### Pacote de imagens extras (13/10)

Caminho: Assiny (compra ou reembolso do pacote) → nosso n8n (`assiny-compras`, o mesmo webhook) →
`app_compra_evento` responde `ignorado/produto` (o pacote não está em `crystal_compras_produtos`, que tem
os 7 produtos que liberam o app) → IF **"Produto fora da lista?"** (`acao == 'ignorado'` e
`motivo == 'produto'`) → HTTP **"Repassar ao app (pacote de imagens)"**: POST do corpo cru da Assiny em
`https://api.crystalnowpp.com.br/webhooks/imagens`, com a mesma credencial do "Desligar no app (reembolso)"
(Bearer do `REFUND_WEBHOOK_SECRET`), 3 tentativas. A API olha o produto em Configurações › pacotes de
imagens: se é pacote, credita (compra) ou estorna (reembolso); se não é, responde 200 e ignora. A Assiny
já recebeu a resposta antes do repasse, então falha da API não faz a Assiny reenviar: aparece como
execução com erro no n8n (Executions) e o suporte lança à mão na ficha.

Atenção: se `crystal_compras_produtos` ficar vazia, a função libera o app para qualquer produto e nada é
repassado (reembolso do pacote bloquearia o aluno). Conferir antes, no SQL Editor:
`select produto_id from crystal_compras_produtos;` (tem que listar só os produtos da Crystal, não o pacote).

Pré-requisito: a API no ar com a rota `/webhooks/imagens` (imagem da onda 4 com o limite de imagens).
Antes dela, o repasse dá 404 e a execução fica com erro no n8n, sem efeito no resto do fluxo.

Na VPS, como root (fluxo `crystal-em-casa/n8n/compra-assiny.json`, script testado num n8n 1.123.10 local
com Postgres e serviços falsos). Rodar em hora calma: o n8n reinicia (1 a 2 min) e, nesse intervalo, o
webhook pode recusar; a Assiny reenvia.

```bash
cd /root/crystal
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/8cb2ea9/crystal-em-casa/n8n/compra-assiny-imagens.py -o compra-assiny-imagens.py
echo "f8ea4111a1c7fd24828dbf31295a901b38f143c8b7f0f5210dc6b82ec68a42ae  compra-assiny-imagens.py" | sha256sum -c      # tem que dizer: OK
python3 compra-assiny-imagens.py --testar     # antes: lista o que falta (8 nós), não muda nada
python3 compra-assiny-imagens.py              # acrescenta os 2 nós, reimporta com o mesmo id, reativa, confere
```

O script acha o fluxo pelo webhook `assiny-compras`, para se o editor tiver rascunho não publicado,
guarda a cópia de antes em `/root/crystal/n8n-copias/compra-assiny-<data-hora>.json` (0600; só ids e
nomes das credenciais, nenhum segredo), acrescenta só o que falta (rodar de novo diz "nada a mudar"),
reaproveita a credencial do nó do reembolso, importa com o id `qMRPSFT9OAScVUP4`, grava a versão no
histórico do n8n (o truque do `crystal-provisoria`), ativa e reinicia editor, webhook e worker.

Conferência: `python3 compra-assiny-imagens.py --testar` (só leitura, não dispara compra): ativo, versão
publicada igual à salva, 10 nós, ligação e condições, URL, mesma credencial do reembolso, webhook
registrado e 403 sem token pelo endereço público. Depois da primeira compra real do pacote: no editor,
Executions, a execução tem que passar por "Repassar ao app (pacote de imagens)" com sucesso, e o saldo
de imagens extras do aluno sobe na ficha.

Volta: `python3 compra-assiny-imagens.py --voltar` (reimporta a cópia mais recente, reativa e reinicia;
`--voltar /root/crystal/n8n-copias/<arquivo>.json` para uma cópia específica). Com a volta, compra do
pacote não credita sozinha: o suporte lança à mão na ficha.

O que o dono faz:
1. No painel, Configurações › pacotes de imagens: cadastrar o id do produto do pacote na Assiny (o mesmo
   que vem em `data.offer.product.id`) e quantas imagens ele dá. Produto não cadastrado é ignorado pela API.
2. Na Assiny (Integrações › Webhooks): se o webhook é configurado por produto, incluir o produto do pacote
   no webhook do nosso n8n, com os eventos de compra aprovada e reembolso (e chargeback). Se o webhook vale
   para a conta toda, nada a fazer.
3. Não pôr o pacote em `crystal_compras_produtos` (isso faria o pacote liberar o app).

## Publicação de 10/10: painel, modelo da Crystal, ligações e avisos programados

Imagem `sha-5a5b198` (branch `otimizacao/publicar-10-10` do app). Junta as correções da bateria de testes do
painel, a escolha do modelo por fornecedor com a tabela de gasto, "Ligações da Crystal" e os avisos programados.
Nenhuma variável nova. Uma migração nova, só aditiva (`e3_26_avisos_programados`: cria `scheduled_notices`), que o
serviço `migrate` aplica na subida. As três imagens (api, web, crystal) têm a mesma etiqueta: um `app-subir` troca
tudo.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/182a12e/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
echo "6eb9d955c70cb4181d209ec8d572d37ecb017a628a98e7e290ac35411a81d428  bootstrap-vps.sh" | sha256sum -c
bash bootstrap-vps.sh crystal-conferir        # antes: a versão de hoje, de ponta a ponta (deve dar TUDO LIGADO)
bash bootstrap-vps.sh app-status              # anotar a tag atual (sha-74092e0)
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-5a5b198
bash bootstrap-vps.sh crystal-conferir        # depois: de novo, agora com a versão nova
# Voltar: bash bootstrap-vps.sh app-subir sha-74092e0
```

Conferir no painel (admin), em Operação › Crystal:
1. "Conferir tudo agora" em **Ligações da Crystal**: os 11 elos com ✓ (o saldo abaixo de US$ 5 aparece como atenção).
2. **Modelo**: escolher o fornecedor e o modelo; a tabela mostra o gasto real dos 7 dias e o "se fosse". Salvar só
   troca se o modelo responder; um gratuito deve ser recusado com o motivo.
3. Integrações: o cartão "Crystal" agora olha a nossa Crystal (antes, no modo chatwoot, olhava só o Chatwoot).
4. Avisos › Programados: programar um aviso para daqui a 5 minutos para a própria equipe e ver sair.

## Correção do painel intermitente (13/10): `sha-3773e2e`, no ar desde 13/10 18:44 UTC (TUDO LIGADO)

Branch `otimizacao/painel-rapido` do app, 6 commits sobre `0e2f79d` (produção). CI verde e imagens publicadas
(disparo manual do `imagens-vps`). O painel gerencial travava o processo da API: criava um formatador de data
por mensagem (12–20 s de CPU no período de 7 dias e 45–77 s no de 30, com 300 mil mensagens), lia o texto de
todas as mensagens de 2× o período, não tinha índice em `messages(created_at)` e guardava o resultado só 60 s.
Medido em Postgres local (2 mil alunos, 300 mil mensagens): 7 dias de 12–20 s para 0,6 s; 30 dias de 45–77 s
para 1,8 s; com resultado guardado, resposta na hora e um recálculo só por trás. O `/v1/uso` da Crystal tinha o
mesmo problema (5,2 s para 0,29 s) e por isso o bloco da Crystal às vezes vinha vazio.

Uma migração nova, só aditiva: `e3_27_painel_indice_mensagens` (`CREATE INDEX IF NOT EXISTS
messages_created_at_idx`). Enquanto o índice é criado, gravar mensagem espera (segundos numa tabela pequena).

```bash
bash bootstrap-vps.sh painel-diagnostico 24   # antes: a fotografia do problema (só leitura)
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-3773e2e
bash bootstrap-vps.sh crystal-conferir
# Voltar: bash bootstrap-vps.sh app-subir sha-0e2f79d (o índice pode ficar; não atrapalha a versão anterior)
```

**Atenção para a onda 4:** a `pa12_26_metricas` do painel novo cria o mesmo índice, com o mesmo nome e sem
`IF NOT EXISTS`. Com a produção já tendo a `e3_27`, o deploy da onda 4 falharia (P3009). Antes de gerar a imagem
da onda 4: trocar essa linha por `CREATE INDEX IF NOT EXISTS`, levar a pasta `e3_27_painel_indice_mensagens` e
fazer cherry-pick dos 6 commits (`e24509f` a `3773e2e`). Testado: os 4 casos de `migrate deploy` passam.

## Publicação do painel novo (onda 4): imagem `sha-9ec8151`, NO AR desde 14/10 ~09:25 UTC

O painel novo (`painel/base` + `otimizacao/publicar-10-10`, juntados pela T1 em `painel/onda4`) traz 9 migrações do
Prisma (todas aditivas), uma migração da T1 que apaga `scheduled_notices` (os avisos programados de 10/10) e um passo
novo, o `audit:backfill`, que calcula a cadeia de hash da auditoria. **A ordem é obrigatória: API parada → migração +
backfill → API nova.** Se a API nova gravar antes do backfill, a trilha nasce quebrada e não há conserto (ensaiado).
Tudo abaixo foi ensaiado num Postgres local com dados fictícios (`crystal-em-casa/painel-novo/README.md`); os três
comandos novos do `bootstrap-vps.sh` não rodaram na VPS ainda. **Nenhuma variável nova**: `app-definir` não muda.

**Pré-requisitos (fora da VPS)**
1. Produção em `sha-3773e2e` (correção do painel intermitente) ou, se ela ainda não subiu, em `sha-0e2f79d`. As duas
   servem: a onda 4 traz a `e3_27` (índice em `messages`) e a `pa12_26` agora usa `IF NOT EXISTS` (ensaiado nos dois casos).
2. Feito em 13/10: `painel/onda4` em `9ec8151` com a T2 (Mensagens), as fichas, 16 correções da QA
   (`auditorias/2026-10-13/onda4-qa.md`) e a correção do painel intermitente (até `22a65c1`, CI run 38425864762).
   **Não usar `sha-06aaa0a`** (CI vermelho) nem `sha-22a65c1` (sem as imagens).
   Pendência 20 do PRD (suporte desliga e religa aluno) espera o dono; hoje fica como está.
   Também em `9ec8151`: **limite semanal de imagens** (25 por semana, zera domingo 00:00 de Brasília; acima do limite
   a imagem não vai ao modelo e a Crystal manda a mensagem com o botão do checkout; saldo de extras na ficha) e o
   **crédito automático do pacote** (`POST /webhooks/imagens`, mesmo segredo do reembolso). Migração nova só aditiva
   `pa16_01_imagens_semana`. CI run 38463529669 e imagens run 38463529667 verdes. **Atenção:** as imagens já
   mandadas desde domingo contam na semana; quem já passou de 25 fica no limite assim que a versão subir.
3. Janela 02:00–05:00 BRT, vigia ligada, equipe avisada: **a API fica fora do ar uns 3 a 5 minutos** (o app não
   responde aos alunos; web e Chatwoot continuam). Cancelar no painel qualquer aviso programado pendente (a tabela some).
4. Conta de admin, suporte e técnico à mão para conferir as telas depois.

**Pré-checagens (na VPS, um comando por vez, esperar o `ok`)**

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/c0379c9/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
echo "770983400c98d05bd98065e7efc515dc48de5b9ccc4e91ae9a2c505c47ad7d6d  bootstrap-vps.sh" | sha256sum -c      # tem que dizer: bootstrap-vps.sh: OK
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/2c3f92108ff0aaf4891c6bc8bd1251e9d9793294/crystal-em-casa/painel-novo/volta-migracoes.sql -o volta-migracoes.sql
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/2c3f92108ff0aaf4891c6bc8bd1251e9d9793294/crystal-em-casa/painel-novo/volta-scheduled-notices.sql -o volta-scheduled-notices.sql
bash bootstrap-vps.sh app-status              # espera: as três imagens em sha-3773e2e (ou sha-0e2f79d), app. e api. -> 200
bash bootstrap-vps.sh crystal-conferir        # espera: "ok TUDO LIGADO" (uns centavos de dólar)
df -h / | tail -1                             # espera: pelo menos 5G em Avail (as imagens novas pesam ~1G)
bash bootstrap-vps.sh backup                  # espera: "ok" em cada banco e nos uploads, e a cópia no R2
bash bootstrap-vps.sh backup-conferir         # espera: o backup de agora listado no R2
```

**Publicar (a API para no passo 1 e volta no passo 3)**

```bash
# 1. parar a API (a palavra --confirmo é de propósito)
bash bootstrap-vps.sh app-api-parar --confirmo
#    espera: "ok API parada (nenhuma tarefa rodando)"
# 2. migração + backfill com a imagem NOVA (serviço temporário; ~3 s de migração + 1,5 s por mil linhas de auditoria)
bash bootstrap-vps.sh app-auditoria-backfill sha-9ec8151
#    espera, no fim: uma linha {"msg":"auditoria: backfill da cadeia","total":N,"preenchidas":N,"ok":true,...}
#    e "ok migrações aplicadas e cadeia da auditoria fechada (N linhas conferidas)". Se der ERRO: NÃO seguir,
#    a API continua parada e o banco inteiro; voltar ao ar com: bash bootstrap-vps.sh app-subir sha-3773e2e
# 3. subir a API nova (as migrações já estão; o migrate deploy da subida só diz "No pending migrations")
bash bootstrap-vps.sh app-subir sha-9ec8151
#    espera: "ok api.env aceito pelo boot da API", "ok os três serviços estão em sha-9ec8151 e nenhum voltou",
#    app-status com as três imagens novas e o teste do Supabase "ok"
# 4. conferir
bash bootstrap-vps.sh app-painel-conferir
#    espera: migrate status limpo, "9 migrações pa*" (ou 10), "N linhas na auditoria, todas com hash",
#    conferência do app {"cadeia_ok":true,...}, telas novas -> 200, telas antigas -> 307, e no fim "ok PAINEL NOVO NO AR"
bash bootstrap-vps.sh crystal-conferir        # espera: "ok TUDO LIGADO" de novo, agora pela versão nova
```

**Conferir no navegador (https://app.crystalnowpp.com.br/equipe)**
- **Admin**: Início (cartões e "agendadas para hoje"); Alunos (lista com totais e filtros, uma ficha, aba Lotes com a
  palavra LIBERAR e senha); Mensagens (Nova mensagem, "Teste para mim", aba Agendadas); Crystal (modelo, teste,
  pausa); Configurações (as chaves da antiga Operação, com quem/quando); Métricas; Auditoria → "Verificar
  integridade" tem que dizer "Trilha íntegra: N registros conferidos."; Equipe. Os links antigos `/equipe/operacao`,
  `/equipe/avisos` e `/equipe/painel` levam para Alunos › Lotes, Mensagens e Métricas.
- **Suporte**: Alunos (ficha com "Tentativas de entrada" e aba Dados do titular), Mensagens para um aluno só;
  **não vê** Auditoria nem Configurações. Lotes e agendamento não aparecem.
- **Técnico**: Mensagens, Métricas, Configurações e Auditoria (lê, sem "Exportar"); não vê e-mail nem telefone de aluno.
- Com um aluno (conta de teste): entrar, conversar, receber uma mensagem da equipe com botão.

**Volta** (para a etiqueta que estava no ar antes, a do `app-status` da pré-checagem: `sha-3773e2e` abaixo; se a
correção do painel não tinha subido, trocar por `sha-0e2f79d`)
- Só a imagem (primeira opção, ensaiada: a antiga convive com as tabelas novas):
  `bash bootstrap-vps.sh app-subir sha-3773e2e`. Antes, cancelar no painel os envios agendados (a antiga não os
  entrega). Se a migração da T1 já apagou `scheduled_notices`, a aba "Programados" da antiga quebra: rodar o SQL
  abaixo (`volta-scheduled-notices.sql`) antes do `app-subir`.
- Imagem + banco (só se a antiga reclamar do banco; apaga o que o painel novo gravou, lista no topo do arquivo):

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-api-parar --confirmo
pg=$(docker ps -q -f name=crystal_app_app_postgres | head -1)
docker exec -i "$pg" psql -U crystal -d crystal_web_chat -v ON_ERROR_STOP=1 < volta-scheduled-notices.sql
#    espera: CREATE TABLE, CREATE INDEX e "migracoes_da_t1_tiradas | 1"
docker exec -i "$pg" psql -U crystal -d crystal_web_chat -v ON_ERROR_STOP=1 < volta-migracoes.sql
#    espera: nenhuma linha de ERROR (sai calado); ~0,1 s
bash bootstrap-vps.sh app-subir sha-3773e2e
#    espera: "No pending migrations" no boot, três serviços em sha-3773e2e
bash bootstrap-vps.sh crystal-conferir
```

Ida de novo depois de uma volta: repetir "Publicar" do passo 1 (o backfill refaz a cadeia inteira).

**Depois de publicar (13/10): imagens.** No painel novo, Configurações (grupo Produto): `imagens_checkout_link` (o
link do checkout do pacote; vazio = a mensagem pede para falar com o suporte), conferir `imagens_limite_semana` (25)
e `imagens_limite_texto`, e `op_imagens_pacotes` (uma linha por pacote: `id do produto da Assiny | imagens | nome`).
Só então rodar o script do n8n da seção "Pacote de imagens extras (13/10)" (`compra-assiny-imagens.py`, commit
`cbffaa4`): antes disso a API ainda não tem `/webhooks/imagens`.


## Correção do iPhone antigo + trava contra vazamento (16–17/10): imagem `sha-8308e71` (sai depois da cobrança do GitHub)

Aluno com iPhone abaixo do iOS 16.4 via a tela "Algo deu errado do meu lado. Um erro crítico aconteceu." ao abrir o
app: o código do navegador tinha regex com lookbehind, que esse Safari não compila (detalhes em
`auditorias/2026-10-16/erro-iphone-antigo.md`). Branch `painel/onda4` em `f8f53b4` = produção (`9ec8151`) + 4 commits:
regex de risco e de CPF reescritas sem lookbehind (mesmo resultado em ~500 mil textos de teste), `.at(-1)`,
`crypto.randomUUID` e `AbortSignal.timeout` com plano B no navegador, e uma trava no build do web (Dockerfile e CI)
que falha se o bundle voltar a ter lookbehind. Testes: shared 285, web 832, crystal 239, api 1219, nenhum falhou.
**Sem migração e sem variável nova:** pode subir a qualquer hora; os serviços só reiniciam.

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-8308e71
bash bootstrap-vps.sh crystal-conferir
# Voltar: bash bootstrap-vps.sh app-subir sha-9ec8151 (nada de SQL)
```

Conferência em aparelho: abrir `app.crystalnowpp.com.br` num iPhone com iOS 15 ou 16.0–16.3 (ou pedir a um aluno que
mandou o print): a tela de entrada aparece em vez do erro. A onda 5 já leva a correção (merge em `painel/onda5-alma`
`e05ba35`): **etiqueta esperada da onda 5 agora `sha-e05ba35`**.

**Trava contra vazamento (17/10, `5a99dcd` a `8308e71`, por cima de `f8f53b4`):** depois do vazamento de 16/10
(`auditorias/2026-10-16/vazamento-base-gemini.md`), a Crystal confere cada resposta antes de entregar: se trouxer o
cabeçalho da base, uma categoria em snake_case abrindo a linha, tag ou frase do prompt, descarta, tenta uma vez a
reserva e, se de novo, responde "Desculpa, me perdi aqui. Pode repetir?" (nada disso vai para a memória; o log leva
só o tipo). Modelos que não são `anthropic/*` recebem um `system` só no começo. Testes do apps/crystal: 293 passaram
(onda 4) e 353 (onda 5). Depois de subir: `crystal-conferir` e, por uns dias, a contagem de respostas vazadas (item 17
do `CONTINUAR-EM-OUTRA-CONTA.md`) tem que ficar em zero.

## Onda 6 (20/10): imagem `sha-c45a71a` (sai depois da cobrança do GitHub)

Branch `painel/onda6` `c45a71a` (com o #reset, o e2e e as correções da consultoria) = onda 5 (`e05ba35`, já com a correção do iPhone e a trava contra vazamento) + B01
(notificação só para quem está fora do app, texto genérico na tela bloqueada) + banners e eventos B02–B08 (PRD de 15/10)
+ Laboratório da Crystal (área própria no painel) + regra "limite em abuso" no prompt. Publicar a onda 6 no lugar da
onda 5: vale tudo o que a seção da onda 5 abaixo pede (SQL `app_conhecimento_editar.sql` no Supabase e
`SUPERADMIN_EMAILS`), na janela 02:00–05:00.

- Migrações novas, só aditivas: `pa19_01_banners`, `pa20_01_laboratorio` e `pa22_01_reset_conversa` (#reset; rodam no `app-subir`).
- A Crystal, ao subir, recria o check de `uso_turnos` com o tipo `laboratorio` (DDL no banco dela, no boot).
- Variáveis novas, só na API e opcionais no começo: `ACTIVEDEV_URL` (https, sem barra no fim) e
  `ACTIVEDEV_INBOUND_TOKEN` (do Bitwarden, nunca no chat), pelas duas juntas no `app-definir` quando o token do ActiveDev
  for trocado. Sem elas, inscrição e lembrete funcionam e o envio fica "Aguardando configuração".
- Depois de subir: `crystal-conferir`; conferir que `app_crystal` segue sem rota pública; republicar a alma em Crystal ›
  Alma se houver versão publicada (para a regra nova valer); banners nascem desligados: ligar o primeiro só depois do
  teste no iPhone e no Android e do "Testar no ActiveDev" (texto de privacidade aprovado pelo Luiz em 20/10).

**Sem o GitHub Actions (provisório, 21/10):** baixar o bootstrap novo e montar as imagens na VPS antes do `app-subir`:

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/1075cb3/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
echo "f865a1a7a9392406b311c70cd1329c1e1ddb7877f1a95c2705e0f1064239821a  bootstrap-vps.sh" | sha256sum -c   # tem que dizer OK
bash bootstrap-vps.sh app-construir painel/onda6 c45a71a   # pede o token só de leitura; 15 a 30 min
```

```bash
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-c45a71a
bash bootstrap-vps.sh crystal-conferir
# Volta: bash bootstrap-vps.sh app-subir sha-9ec8151 (as tabelas novas ficam; não atrapalham a versão anterior)
```

**Da consultoria independente (20/10, `docs/consultoria/2026-10-20-onda6.md` no app):**
- Ordem: Supabase (o SQL da base `app_conhecimento_editar.sql`; conferido em 21/10 que só `service_role` escreve na tabela da
  agência, então o `revoke` é seguro; a troca de e-mail já está aplicada desde 14/10) → migrações (rodam no
  `app-subir`, antes da API nova; a API nova lê `users.conversa_recomecada_em` em todo login) → Crystal → API → web.
- `ACTIVEDEV_URL` e `ACTIVEDEV_INBOUND_TOKEN`: as duas juntas (ou nenhuma), URL https, senão a API não sobe.
- `SUPERADMIN_EMAILS` vazia = ninguém edita alma, base nem bateria (respondem 404).
- **Antes de voltar para `sha-9ec8151`** (o agendador antigo mandaria lembretes de evento sem as proteções novas),
  rodar no banco do app:
  `UPDATE notices SET status='canceled' WHERE lembrete=true AND status IN ('scheduled','sending');` e
  `UPDATE notice_deliveries SET status='skipped' WHERE status='queued' AND notice_id IN (SELECT id FROM notices WHERE evento_id IS NOT NULL);`
  Nunca rodar os comandos de volta comentados nas migrações (apagam dados). Detalhes: `docs/deploy/rollback-onda6.md` no app.

## Alma da Crystal no painel (onda 5): imagem `sha-f3d6616` (13/10, CI verde)

Branch `painel/onda5-alma` do app em `f3d6616` = onda 4 (`9ec8151`) + a alma. CI run 38469721794 (e2e 68 passaram) e
imagens run 38470890991. Desenho: `docs/painel-admin/ONDA5-ALMA.md` no app; relatório: `auditorias/2026-10-13/onda5-alma.md`.
O que traz (área Crystal do painel): alma e regras de formato com rascunho, teste lado a lado, publicar, histórico e
voltar (só superadmin edita e testa; admin e técnico veem); base de conhecimento editável com histórico; bateria de
perguntas-padrão (até 30 por rodada, teto US$ 5); amostra de conversas reais com 👍/👎 (só admin, só com a leitura de
conversa liberada); números do dia; atalhos de prazo na conta local (30 dias, 3 e 6 meses, 1 ano, sem prazo).
Migração nova só aditiva: `pa17_01_crystal_avaliacoes` (ensaiada sobre a `pa16_01_imagens_semana`). A Crystal
troca, na subida, uma regra da tabela de uso (`uso_turnos`, ~75 mil linhas): trava a tabela uns segundos, uma vez.

**Pré-requisitos**
1. Onda 4 (`sha-9ec8151`) publicada e conferida. A onda 5 não sobe direto sobre a produção de hoje.
2. Supabase › SQL Editor: `crystal-em-casa/supabase/app_conhecimento_editar.sql`, o arquivo inteiro de uma vez (cria o
   histórico dos trechos e as funções de escrita, só para `service_role`; a RPC `crystal_hybrid_search` e a Edge Function
   da agência não mudam). As conferências estão no fim do arquivo.
3. Janela 02:00–05:00 (por causa da trava na `uso_turnos`).
4. A função `app_aluno_trocar_email` (troca de e-mail de aluno da base pelo suporte) já foi aplicada em 14/10. A etiqueta
   vai mudar (troca de e-mail e reautenticação por código entram na mesma branch): usar a que estiver na passagem.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/36c0efd/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
echo "b92a691455ca47155d7a99e2dcc3745455c4af3701e6e07cbc5dd0d506284904  bootstrap-vps.sh" | sha256sum -c
bash bootstrap-vps.sh app-definir SUPERADMIN_EMAILS   # o e-mail de admin de quem edita a alma (vários: separados por vírgula)
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-subir sha-f3d6616
bash bootstrap-vps.sh crystal-conferir
bash bootstrap-vps.sh app-painel-conferir
# Voltar: bash bootstrap-vps.sh app-subir sha-9ec8151 (a tabela de avaliações, a coluna alma_versao e as tabelas
# da alma no banco da Crystal ficam; a versão anterior não as usa e volta a ler a alma do arquivo da imagem)
```

**Conferir no painel (como superadmin):** Crystal › Alma mostra a alma em uso (fonte "imagem" até a primeira
publicação); salvar um rascunho, testar a mesma pergunta nos dois lados, publicar e ver o "Testar com uma mensagem"
responder com a versão nova; voltar à anterior. Base: abrir um trecho e ver o histórico (editar só quando quiser
mudar de verdade: vale na hora para os alunos). Bateria: cadastrar 3 perguntas e rodar (custa centavos). Números.
Com outro admin que não está em `SUPERADMIN_EMAILS`: tudo só leitura.

**A busca da base** continua pela Edge Function da agência (chave `crystal_busca` = `edge`). Trocar para `propria`
(a Crystal gera o embedding com a chave dela) só depois de conferir de quem é a chave da Edge Function
(`OPENROUTER_API_KEY_CRYSTAL` no Supabase); a troca pede a palavra TROCAR e a senha.

## Ficha completa de cada aluno antes do primeiro acesso (SQL aplicado em 13/10, imagem `sha-0e2f79d`)

Memória completa de cada aluno gerada do histórico inteiro do WhatsApp, pronta antes de ele chegar ao app.
Código na branch `otimizacao/memoria-ficha` do app (sobre `otimizacao/publicar-10-10`, `sha-5a5b198`),
4 commits: Crystal (`apps/crystal/src/ficha.ts` + rotas `/v1/fichas`), API (`/staff/operacao/fichas`,
só admin, com auditoria), painel (um componente só, `FichasAlunos`, em Operação › Crystal, logo abaixo de
"Memória do WhatsApp para todos") e docs. SQL: `crystal-em-casa/supabase/app_memoria_ficha.sql` (commit
`e447c0f`, testes em `crystal-em-casa/supabase/testes/`), **aplicado em 13/10** (migração `app_memoria_ficha_20261012`).
Imagem: `sha-0e2f79d` (tem tudo de `sha-5a5b198` e as fichas; CI verde, run 174). Decisão do dono: piloto de 20 com
`openai/gpt-4.1-mini` e outro com `anthropic/claude-haiku-4.5`, 12 meses, teto US$ 5 cada.

Nada acontece sozinho: sem o SQL as rotas respondem 503 e o bloco do painel mostra "as funções
app_ficha_* já estão no Supabase?"; nenhum lote começa sem alguém clicar, escolher modelo, alcance e teto.

```bash
# 1. Decisões do dono (ver PROXIMOS-PASSOS.md): modelo, alcance, teto do piloto, recarga do OpenRouter.
# 2. Supabase, SQL Editor: crystal-em-casa/supabase/app_memoria_ficha.sql (arquivo inteiro, uma vez).
#    Depende de app_telefone_chave.sql e app_memoria_unica.sql (já aplicados). Conferir:
#    select public.app_ficha_andamento();        -- {"alunos": ~9.6 mil, "com_ficha": 0, ...}
# 3. VPS: backup + app-subir sha-0e2f79d (no lugar do sha-5a5b198 da seção de 10/10). Nenhuma variável nova
#    é obrigatória (SUPABASE_FICHA_*_RPC só se renomear as funções).
# 4. Painel, Operação › Crystal › "Ficha completa de cada aluno": "Prever custo" (só leitura, mede 20 alunos
#    de verdade e usa o preço do catálogo); depois "Começar lote" com limite 20 (piloto) e teto pequeno.
# 5. Piloto conferido (ficha boa, custo dentro do previsto): lote inteiro com limite vazio e teto decidido.
#    Parar a qualquer hora; "Começar" de novo continua de onde parou (cursor por aluno na tabela).
# Volta: app-subir sha-5a5b198 (ou 74092e0). A tabela e as funções podem ficar: sem a imagem nova ninguém as chama;
# para tirar a ficha do turno, rodar app_memoria_unica.sql de novo (volta o app_memoria_ler sem a ficha).
```

O que o lote faz: quem conversou nos últimos 30 dias primeiro; aluno sem conversa no WhatsApp (comprador novo
da Assiny) grava "sem conversa" sem custo e entra de novo quando conversar; histórico grande vai em blocos;
para no teto, em erro fatal (sem crédito, chave recusada, modelo inválido) ou em 5 erros seguidos; manutenção
depois disso só lê as mensagens novas de cada aluno (barato). Na conversa, a ficha entra primeiro no bloco
"O que você já sabe desta pessoa" (memória única, chave já ligada), antes das anotações da Crystal do WhatsApp.

## Depois dos três (sem pressa, qualquer ordem)

- **Nosso Chatwoot**: `crystal-em-casa/README.md`, seção "Ligar o nosso Chatwoot".
  Precisa antes do DNS `atendimento` cinza. `app-canal chatwoot` só depois do teste da
  Crystal respondendo lá. Quem atende é a equipe de suporte (decisão de 05/10). **Não
  definir `CHATWOOT_API_TOKEN`** (decisão de 05/10; o help do bootstrap diz o mesmo):
  excluir conta não apaga o contato no Chatwoot.
- **Vigia**: `bash bootstrap-vps.sh vigia-config` se ainda não estiver ligada.
- **Alma da Crystal**: prompt e base de conhecimento da agência, quando chegarem.
