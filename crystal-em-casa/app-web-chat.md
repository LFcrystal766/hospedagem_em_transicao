# O app da Crystal: onde está e quanto falta (29/09/2026)

O app é o `LFcrystal766/crystal-web-chat`, transferido da conta do Igor
(`o-igor-andrade`) em 29/09. O Igor segue como colaborador com escrita. É um
monorepo pnpm: PWA em Next.js 15, BFF em Fastify com Prisma e Redis, pacote de
tipos compartilhados, empacotamento para as lojas (TWA Android e Capacitor iOS).

Esta avaliação foi feita lendo o código e a documentação das três branches. Não
rodei a suíte de testes nesta sessão: os números de teste abaixo são os que o
próprio repositório registra.

## As três branches

| Branch | O que tem | Estado |
|---|---|---|
| `main` | O app em si: 64 commits de 02 a 07/09 | Produto maduro, CI com typecheck, lint, vitest, build e e2e |
| `lfchat/g0-discovery` | LFChat: Chatwoot próprio + Bridge para substituir o LendChat e falar direto com o WhatsApp. Cerca de 200 commits de 16 a 18/09 | **Parado desde 18/09** por ordem do tech lead, "até a migração de DNS terminar" |
| `legacy/mvp-original` | O MVP de 23/08 | Só referência |

`main` e `lfchat/g0-discovery` têm **históricos separados**: a `main` foi achatada
em 07/09 e a outra linha continuou a partir do histórico antigo. Não dá para
fazer merge direto. Antes de retomar, é preciso escolher qual das duas é a base.

## O que o app já faz (`main`)

- Login por CPF + e-mail conferidos na base de clientes, com código de 6 dígitos por e-mail (OTP) como segundo fator
- Chat com a Crystal com resposta em streaming, histórico paginado, rate limit
- Imagem e áudio pelo navegador, PWA instalável, push web e push nativo (FCM e APNs)
- Painel da equipe: suporte, técnico, financeiro manual, alertas de integração
- Modo backup: sonda de saúde da Meta, que liga o app como canal de reserva
- LGPD: consentimento, exportação, exclusão, cifra por campo, retenção
- Onboarding do perfil e sugestões dirigidos pela Crystal (metas, progressos)
- Revisão de segurança de 04/09 com os três achados tratados
- Textos das lojas (listagem, Data Safety, App Privacy, termos) e screenshots

## O que falta para o app atender aluno de verdade

Caminho mais curto: o app como está na `main`, em que o BFF chama a Crystal
direto, sem Chatwoot nem Bridge. Na `main` esse é o único modo; o transporte
`lfchat` só existe na outra branch.

| Falta | Depende de |
|---|---|
| Saber como o agente da agência atende um canal que não é o LendChat | Código do agente no `crystal-ia` ou resposta do Tuan |
| `CRYSTAL_API_URL`: endereço que recebe a mensagem do app e devolve a resposta | Item acima. Pode ser um fluxo no nosso n8n na frente do agente |
| `DIRECTORY_API_URL`: consulta de CPF + e-mail na base de clientes | Saber onde está essa base, provavelmente no Supabase da Crystal |
| Entrada das mensagens proativas em `POST /webhooks/crystal`, assinada | Formato da agência. O webhook `crystal-app` do n8n segura o endereço enquanto isso |
| Conta no Resend e remetente de e-mail para o OTP | Luiz ou Igor |
| Endereço do app e registro DNS cinza apontando para a VPS | Decisão. O D-024 do app previa `app.crystalnowpp.com`, sem `.br`, e foi suspenso pelo D-029 |
| Stack do app na VPS: BFF, PWA, Postgres e Redis próprios, atrás do Traefik | **Pronta em 29/09** (`stacks-app/`, `bootstrap-vps.sh app-*`). Falta rodar na VPS |
| Segredos de produção (`JWT_SECRET`, `ENCRYPTION_KEY`, `CPF_SALT`, `WEBHOOK_SECRET`, VAPID) | **Automático**: o `app-subir` gera na VPS, uma vez só |
| Apps nas lojas | Contas Apple e Google, chaves de push nativo. Pode ficar para depois da PWA |

### Achados ao montar a stack (29/09)

- Os Dockerfiles da `main` não construíam: a API rodava `prisma generate`
  antes de copiar o schema, e o web não tinha o `tsconfig.base.json` nem o
  `package.json` da raiz. Corrigido na branch `claude/gracious-shannon-6x9l5j`
  do app, junto com o workflow `imagens-vps`. Falta levar para a `main`.
- O `docker-compose.prod.yml` do app monta os uploads em `/app/uploads`, mas a
  API grava em `apps/api/uploads` porque roda de dentro do pacote. A stack da
  VPS fixa `UPLOAD_DIR=/app/uploads`.
- `docs/n8n/README.md` do app manda deixar `CRYSTAL_API_PATH` vazio, mas o
  app troca variável vazia pelo padrão `/v1/messages`. Com o n8n, dividir o
  endereço: base em `CRYSTAL_API_URL` e o caminho do webhook em
  `CRYSTAL_API_PATH` (é o que o `crystal-provisoria` faz).
- O CI da `main` (`ci.yml`) está vermelho desde 07/09, nas três execuções, e
  nenhum teste chega a rodar: o `setup-node` pede cache do pnpm antes de o
  pnpm existir no runner ("Unable to locate executable file: pnpm"). Falta um
  passo `pnpm/action-setup` antes dele.
- A sonda da Meta usa a Graph API v21.0, que deve expirar por volta de
  outubro de 2026.

## Como o app fala com a Crystal (definido pelo Tuan em 29/09)

O app não chama o agente. Ele usa um **canal de API do LendChat** criado para o app,
no formato do Chatwoot, e a resposta volta **assíncrona, em várias mensagens**, por
webhook assinado. O identificador do aluno é o **telefone em E.164**, igual ao do
WhatsApp, para a Crystal ter a mesma memória nos dois canais. O login consulta a
tabela `leticia_crystal_customers` do Supabase, que vem para nós na transferência.

**Implementado em 29/09** na branch `claude/gracious-shannon-6x9l5j` do app
(commit `d3e25a5`), com `CHAT_TRANSPORT=chatwoot`. O modo padrão continua o antigo:
sem configurar a inbox, nada muda. Detalhes em `docs/crystal-api.md` do app.
Falta receber do lado da agência a confirmação do formato (contrato técnico), se a
inbox usa `identifier_hash`, e a inbox de teste; e ter o telefone dos alunos, que vem
da base `leticia_crystal_customers` no login.

Consequências para o código (análise antes da implementação):

- A `main` do app não tem esse modo: ela só sabe chamar a Crystal e esperar a
  resposta inteira. Não serve como está.
- A branch `lfchat/g0-discovery` já tem quase tudo: `services/lfchat-channel.ts`
  cria contato e conversa pela API pública da inbox (`/public/api/v1/inboxes/...`,
  com `identifier_hash`), manda a mensagem com `echo_id`, e
  `services/lfchat-webhook.ts` valida `X-Chatwoot-Signature` sobre timestamp e
  corpo e filtra só as mensagens de saída. Foi feito para o Chatwoot próprio do
  LFChat, mas o LendChat fala o mesmo formato.
- Ajustes: o identificador hoje é um id opaco do aluno e precisa virar o telefone
  E.164 vindo da base; o modo exige a Bridge do LFChat para a exclusão de dados
  (`LFCHAT_BRIDGE_BASE_URL`), o que precisa ser desacoplado; e as respostas em
  várias mensagens precisam aparecer no chat conforme chegam.
- Os 3 críticos abertos da pausa (L-286) são na exclusão e exportação de dados
  do titular dessa branch. Precisam fechar antes de aluno real, com ou sem Bridge.
- O LendChat continua sendo da agência. O canal do app passa a depender dele,
  como o WhatsApp já depende.
- O Supabase fica em São Paulo e a VPS em Boston. Cada consulta do agente ao banco
  atravessa essa distância. O tempo do modelo pesa mais, mas vale medir no ensaio.

## Propriedade da Crystal

Código do agente, prompts e base de conhecimento são nossos (confirmado pelo
Luiz em 29/09). Na fase 2 eles chegam ao `LFcrystal766/crystal-ia`; depois
disso, mudar o jeito da Crystal é editar o prompt no repositório e publicar
uma imagem nova, sem depender da agência.

## LFChat enxuto: nosso Chatwoot no lugar do LendChat (proposta de 29/09)

A agência não vai passar o LendChat. A ideia é o LFChat substituí-lo. Faz sentido
como destino, com um desenho bem menor que o original do Igor.

**Por que dá para encolher.** O LendChat fala o protocolo do Chatwoot (o Tuan citou
`X-Chatwoot-Signature`, `X-Chatwoot-Delivery`, `message_type`). O agente da agência
já agrupa mensagens, usa fila com repetição e fila de mensagens mortas, e trata
áudio e imagem. A Bridge do LFChat repetia esse trabalho e exigia um contrato novo
da Crystal. Sem ela, o LFChat vira:

| Peça | Papel |
|---|---|
| Chatwoot CE na VPS | Substitui o LendChat: WhatsApp, caixa de entrada, tela da equipe |
| Agente da Crystal | Igual, só aponta para o nosso Chatwoot |
| App | Canal de API do Chatwoot (código na branch `lfchat/g0-discovery`) |

A maior parte dos achados graves abertos na pausa era da Bridge e do histórico
importado, e sai junto.

**O app não é feito duas vezes.** A API do LendChat e a do Chatwoot são a mesma.
Se o app precisar sair antes, usa a inbox de API do LendChat que o Tuan ofereceu;
no corte, trocam só endereço e chaves.

**Ordem:**
1. Fase 2 da agência: agente na VPS, ainda com o LendChat. Corte deles.
2. Chatwoot na VPS em paralelo, testado com um número de teste do WhatsApp.
3. Segundo corte: o número sai do LendChat para o nosso Chatwoot, e o agente
   aponta para ele. Reversível: o número volta ao LendChat.
4. App para os alunos no nosso Chatwoot (ou antes, pelo LendChat, se o prazo apertar).

Nunca os dois cortes juntos: trocar cérebro e canal ao mesmo tempo esconde qual
lado quebrou.

**A confirmar antes de decidir:**
- Quais chamadas o agente faz ao LendChat (no código, quando chegar ao `crystal-ia`).
- Quem controla o app da Meta e a BM ("Contabilizei Tecnologia") do número.
- O que fazer com o histórico das conversas que está no LendChat.
- Quem da equipe atende pelo LendChat hoje.
- Se a VPS comporta o Chatwoot junto com o resto (medir antes).
- Até quando o contrato com a agência cobre o LendChat.

Aproveitável do trabalho do Igor: o compose e o script de configuração do
Chatwoot, o canal do app no BFF e o kit de migração. A Bridge fica arquivada.

## Estimativa

| Frente | Estado | Quanto falta |
|---|---|---|
| Base na VPS (fase 1) | Pronta e conferida | Nada |
| Agente na VPS (fase 2) | Não começou. `crystal-ia` vazio | 1 a 2 semanas depois que o código chegar |
| App no modo simples | Código pronto | Cerca de 1 semana de trabalho depois de saber o formato do agente. Dá para adiantar a stack na VPS antes |
| LFChat enxuto (Chatwoot no lugar do LendChat) | Proposto em 29/09 | 1 a 2 semanas de montagem depois da fase 2, mais o corte do WhatsApp |
