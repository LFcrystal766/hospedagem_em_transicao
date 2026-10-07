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

## Depois dos três (sem pressa, qualquer ordem)

- **Nosso Chatwoot**: `crystal-em-casa/README.md`, seção "Ligar o nosso Chatwoot".
  Precisa antes do DNS `atendimento` cinza. `app-canal chatwoot` só depois do teste da
  Crystal respondendo lá. Quem atende é a equipe de suporte (decisão de 05/10). **Não
  definir `CHATWOOT_API_TOKEN`** (decisão de 05/10; o help do bootstrap diz o mesmo):
  excluir conta não apaga o contato no Chatwoot.
- **Vigia**: `bash bootstrap-vps.sh vigia-config` se ainda não estiver ligada.
- **Alma da Crystal**: prompt e base de conhecimento da agência, quando chegarem.
