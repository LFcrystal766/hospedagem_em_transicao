# Crystal em casa: a VPS do app

Frente separada da migração do site. Aqui é o **app da Crystal** (agente em
Python + n8n) saindo da infraestrutura da agência (Academia Lendária) para uma
VPS nossa. O site WordPress continua no plano dos três degraus, em
`../PROXIMOS-PASSOS.md`. As duas frentes só se cruzam na zona DNS do Cloudflare.

O plano para levar o app aos alunos (roadmap de seis semanas e checklist
compartilhado das lojas) está no artefato
[Crystal nas Lojas](https://claude.ai/artifact/C2oPgdhJtGfgbPQ9ko9Q5G).

O checklist interativo da fase 1 está no artefato
[Crystal em Casa](https://claude.ai/artifact/C6yKAGUMgK9pqRaTeZ7M4W) (25 itens,
fase 1). Esta pasta guarda o material da agência e o que a sessão do Claude
precisa para agir.

## Material da agência (10/09/2026)

| Arquivo | O que é |
|---|---|
| `guia-implantacao-stack.html` | Guia "Crystal AI · Implantação da Stack": fases, requisitos, capacidade medida, contas, corte |
| `stacks-exemplo/` | Os 7 arquivos do Docker Swarm (Traefik, Portainer, Postgres, Redis, editor, webhook, worker do n8n) + MCP opcional, com placeholders |

Nenhum arquivo tem segredo: os valores a trocar estão em MAIÚSCULAS ou como
`seudominio.com.br`. Ao usar, trocar por `crystalnowpp.com.br` e gerar a senha
do banco e a chave de criptografia do n8n **uma vez**, iguais em todos os
arquivos, guardadas em cofre. A chave nunca muda depois de o n8n estar em uso.

## O que o guia exige e o checklist resume

- Agente em 4 contêineres (API na porta 8000, worker de entrada, worker de envio
  com **1 réplica fixa**, Redis próprio). O corte é reapontar o webhook do LendChat.
- Supabase: **transferência de projeto** entre organizações. Convite de Owner
  para `agencia@academialendaria.ai` na organização nova (plano Pro). Conexão do
  agente pelo **Session Pooler, porta 5432** (o Transaction Pooler 6543 derruba).
- GitHub: repositório privado, imagem no `ghcr.io`, token `write:packages`,
  build com `--platform linux/amd64` (Mac gera ARM), tag por versão, nunca `latest`.
- Traefik **v2** (não v3). Nomes que precisam bater: rede `network_swarm_public`,
  entrada `websecure`, emissor `letsencryptresolver`. (Desde 24/10 cada stack nossa usa a
  sua rede de borda, `borda_*`; o Traefik continua também na `network_swarm_public`.)
- n8n 1.123.10+, modo fila, limpeza automática de execuções, heap do Node em
  ~75% do limite do contêiner.
- Fase 1 termina com os 16 pontos de "Base pronta" verdadeiros; aí avisa a
  agência e a fase 2 começa (código, transferência do Supabase, imagem, ensaio, corte).

## Situação em 29/09/2026

| Item | Estado |
|---|---|
| VPS | **Contratada.** Hostinger KVM 4: 4 vCPU, 16 GB, 200 GB, Ubuntu 24.04, Boston (EUA), IP `177.7.61.136`. Porta 80 ainda fechada (nada instalado) |
| DNS `painel`, `editor`, `webhook` | **Feito em 29/09**, pelo painel: A → `177.7.61.136`, cinza. Conferido de fora (AdGuard DoH) |
| Docker + Swarm, rede, volumes, label do nó | **Feito em 29/09** pelo Web console: Docker 29.8.1, Swarm ativo (nó `srv2006998`, manager), rede overlay e 4 volumes. O rótulo `app=n8n` o `bootstrap-vps.sh` aplica se faltar |
| Stacks 00 a 06 | **No ar desde 29/09**, 8 serviços 1/1. O Traefik só passou a rotear depois de `docker-api` (Docker 29 recusava a API 1.24 do Traefik v2.11.3). Conferido de fora: `painel` e `editor` respondem 200 em HTTPS, `webhook` 404 na raiz (normal: só serve `/webhook/*`) |
| Segredos | **Definitivos desde 29/09** (terceira geração, via `recomecar-n8n`; as duas anteriores vazaram no chat e foram descartadas com o banco). Guardados no Bitwarden, nunca passaram pelo chat. `segredos` abre no `less`, sem rastro. E-mail do Let's Encrypt: `crystal@leticiafelisberto.com` |
| Portainer e n8n | **Admin do Portainer e dono do n8n criados em 29/09** (dono recriado depois da última troca de segredos). `editor./healthz` responde ok. Lado do servidor da fase 1 fechado |
| Supabase Pro + convite | **Feito em 29/09**: convite de Owner para `agencia@academialendaria.ai` na organização Pro do dashboard (decisão do Luiz). Enquanto Owner, a agência enxerga o projeto do dashboard também; rever o papel depois da transferência. Compute size do projeto: perguntar à agência |
| GitHub | **Feito em 29/09**: repositório privado `LFcrystal766/crystal-ia` (com "ia", não "ai": ajustar `IMAGE_NAME` no workflow). E-mail da conta para o convite da agência: `crystal@leticiafelisberto.com`. Em 29/09 o Luiz também convidou `agencia@academialendaria.ai` como colaborador do `crystal-ia`, para eles poderem enviar o código direto. Token `write:packages` criado em 29/09 (90 dias, vence por volta de 28/12) e cadastrado no Portainer como registry `ghcr` |
| Backup | **Na VPS e fora dela desde 29/09**: dump diário às 03:30 (n8n, banco do app e uploads), 14 dias na VPS; cada arquivo sobe cifrado com age para o bucket R2 `crystal-backups` (ENAM), token só de objeto nesse bucket. Chave privada do age e chave do R2 no Bitwarden. Conferido em 29/09: dois backups completos no R2 (`backup-conferir`). Trava de 30 dias e regra de 60 dias configuradas no bucket em 29/09 (prova: `backup-testar-trava`). Token do R2 não usado apagado em 29/09 (fica só o `abeea6…`). **Restauração testada em 29/09** no Mac do Igor: backup do n8n baixado do R2 por `backup-link` e aberto com a chave do Bitwarden (dump do Postgres 16 legível) |
| Firewall | **Feito em 29/09**: ufw com 22, 80 e 443. Portas do Swarm fora da internet |
| Portainer restrito | **No ar desde 29/09** (`painel-restringir`): só o IP de casa do Luiz na lista. Conferido de fora: 403 fora da lista; do IP liberado, login e ambiente `primary` funcionando pelo agente na rede interna. Imagens presas em `portainer-ce`/`agent` 2.45.0 (digest). Falta o IP do Igor, se ele for usar |
| Netlify | Conta criada em 29/09 (com o GitHub), segundo o Luiz. Sem API aqui para conferir |
| Telegram | **Feito em 29/09**: bot e grupo `Crystal · Alertas`, bot como admin, `sendMessage` testado. Token no Bitwarden; `TELEGRAM_ALERT_CHAT_ID=-1003662546162` |
| Webhook do app | **No ar desde 29/09** no n8n: `n8n/webhook-crystal-app.json`. Health 200, POST sem segredo 403. Formato definitivo depende da agência |
| OpenRouter | **Conta nossa**, com acesso do Luiz desde 29/09. Não apagar nem trocar chave antes do corte: uma é a do agente em produção. Na fase 2, chave nova só para a VPS |
| Respostas da agência | Compute size do Supabase, qual chave do OpenRouter o agente usa hoje, como o agente atende um canal que não é o LendChat, onde está a base de clientes |
| Código do agente | **Não chegou.** `LFcrystal766/crystal-ia` vazio em 29/09 às 03:00 |
| App web | Repositório `LFcrystal766/crystal-web-chat`, transferido do Igor em 29/09. Avaliação em `app-web-chat.md` |
| Canal do app (02/10) | **Nossa Crystal respondendo no app** (`CHAT_TRANSPORT=crystal`, desde 01/10). O LendChat foi consertado pelo Tuan em 02/10 (criar conversa 200, conferido daqui), mas **não volta**: o LendChat vai sair. Destino do app: o **nosso Chatwoot** (linha abaixo), com `app-canal chatwoot`. Conta do Luiz criada com `app-aluno` (CPF final 4906). **PRD de Otimização, 03/10**: etapa 1 integrada na branch de build (commit `79ba6b7` (hotfix do guard https sobre `cdc45f5`), CI verde, imagem `sha-79ba6b7`): API sem root, mídia com transcrição (Groq), webhook de reembolso. Etapa 2 integrada em `otimizacao/etapa-2` (`3b06150`, 1113 testes, e2e 27/27) e etapa 3 em `otimizacao/etapa-3` (`ede085b`, 1224 testes, e2e 33/33), relatórios em `docs/otimizacao/andamento.md` do `crystal-web-chat`. **Etapa 1 publicada em 05/10** (`sha-79ba6b7`, depois de um hotfix no guard de https; evidência em `auditorias/2026-10-05/`). **Etapas 2 e 3 publicadas no mesmo dia** num release só (`sha-da617ac`, backup antes, volta = `app-subir sha-79ba6b7`). QA no iPhone aprovado, segurar para gravar fica. Falta o QA em Android |
| Atendimento (nosso Chatwoot) | **Pronto para subir em 02/10**: Chatwoot CE `v4.18.0-ce` em `atendimento.` (stack `crystal_atendimento`, `stacks-app/20-atendimento.yaml`), Postgres e Redis próprios numa rede interna, cadastro aberto desligado, telemetria desligada, 2FA disponível (chaves de cifra geradas na VPS), `/super_admin` só para os IPs do painel. A Crystal responde como **robô** do Chatwoot pela API do app (`/webhooks/chatwoot-bot`, assinado; imagem `sha-44f356b` ou mais nova): responde nas conversas pendentes e para quando alguém da equipe escreve, quando o aluno pede uma pessoa ou quando falha. Inbox do app com HMAC de identidade obrigatório. Backup e vigia já incluem o Chatwoot. Falta: DNS `atendimento.` cinza e os comandos da seção "Ligar o nosso Chatwoot". WhatsApp fica para depois (BM da Meta e corte com a agência) |
| Revisão geral (02/10) | Código dos dois repositórios lido linha a linha (~48 mil linhas, 6 revisores), 770 testes + 20 e2e verdes, migrações aplicadas do zero e smoke real contra o Postgres. **0 críticos, 13 altos reais.** Consolidado e evidências em `auditorias/2026-10-02/revisao-geral/` (`00-RELATORIO.md`). Antes de `app-canal chatwoot`: exclusão de conta também apagar no Chatwoot e senha no Redis do n8n |
| Vigia do app | Desde 01/10 (`vigia-config`): a cada 5 min confere app, API, réplicas e falhas de resposta no log; de hora em hora testa a nossa Crystal e o crédito do OpenRouter (avisa abaixo de US$ 5). Avisa no grupo Telegram `Crystal · Alertas`, repete o mesmo problema só depois de 1 h e avisa quando normaliza. Token do bot em `/root/crystal/.vigia` (600). Log em `/root/crystal/vigia.log` |
| Lojas (preparo) | **Pronto em 30/09, falta só conta e chave**: telas das lojas (iPhone 6,9"/6,5", Android, banner), ícones rosa, textos e formulários de privacidade em `crystal-web-chat/docs/lojas/`. Android: `.aab` pelo workflow `android-aab` (compila no GitHub; falta a chave de envio nos segredos). iOS: projeto do Xcode com Firebase, Face ID e links universais, compila no workflow `ios` (falta conta Apple e projeto Firebase). Na VPS, quando houver: `app-definir ANDROID_CERT_SHA256`, `APPLE_TEAM_ID`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`. Termos com empresa (LF Produtora de Conteúdo, CNPJ 39.583.272/0001-05) e foro de Florianópolis; falta revisão jurídica |
| Exclusão de conta | Desde 30/09 (commit `a73fbe3` do app): o aluno exclui a conta pelo app; conta, mensagens e perfil somem, e a conversa e a experiência ficam numa **cópia anônima** (tabela `anonymous_conversations`, migração 13): sem id, nome, contatos, CPF ou data exata, texto redigido e cifrado com a `ENCRYPTION_KEY`. Política, `/excluir-conta` e notas das lojas já dizem isso. Pendente: revisão jurídica do desenho |
| Stack do app | **No ar desde 29/09**, tag `sha-1fb80ea`, 4 serviços 1/1. Conferido de fora: `app.` 200 e `api./healthz` 200, os dois com certificado do Let's Encrypt; CORS só para `app.`; CSP do app aponta só para `api.`. Crystal e base de clientes **simuladas** até a agência passar os endereços. Resend com domínio verificado (`send.`, `resend._domainkey`, `_dmarc` p=none), remetente `acesso@crystalnowpp.com.br`. Segredos trocados às 12:17 (`app-recomecar`, os anteriores apareceram no chat). Admin criado (CPF final 3899) e **login ponta a ponta conferido em 29/09**: aceite LGPD, código pelo Resend, entrada no app |

Boston em vez de São Paulo não fere o guia: o tempo do atendimento é dominado
pela resposta do modelo, não pela rede. Vale conferir a região do projeto do
Supabase quando ele for transferido, para o banco não ficar em outro continente
que a VPS.

## Subir a fundação na VPS

`bootstrap-vps.sh` roda **na VPS**, como root. Baixa os yaml deste repositório
(público, sem segredo) do commit fixo `STACKS_COMMIT` gravado no próprio script e só
aceita cada um se o sha256 bater com a tabela `ARQ_SHA256` dele (revisão de 24/10,
INF-04: gravar na branch não muda o que a VPS sobe), gera a senha do banco e a chave do n8n **na própria
máquina** (`/root/crystal/.segredos`, uma vez só), grava os arquivos prontos em
`/root/crystal/stacks/` e sobe as stacks na ordem, esperando cada uma ficar 1/1.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh   # commit de 40 letras, nunca branch (INF-04)
bash bootstrap-vps.sh docker-api                  # Docker 29 x Traefik v2: piso da API em 1.24
bash bootstrap-vps.sh preparar voce@exemplo.com   # e-mail do Let's Encrypt
bash bootstrap-vps.sh segredos                    # copiar os dois pro cofre
bash bootstrap-vps.sh tudo                        # traefik → portainer → bancos → n8n
bash bootstrap-vps.sh status                      # serviços e HTTPS dos três nomes
```

Os segredos nunca passam pelo chat nem pelo repositório.

## Subir o app na VPS (crystal-web-chat)

Stack `crystal_app` em `stacks-app/10-crystal-app.yaml`: PWA em
`app.crystalnowpp.com.br`, API em `api.crystalnowpp.com.br`, Postgres 16 e
Redis 7 próprios numa rede interna só do app. Não usa o banco nem o Redis do
n8n. As imagens saem do GitHub Actions do `LFcrystal766/crystal-web-chat`
(workflow `imagens-vps`, branch `claude/gracious-shannon-6x9l5j`) para o
`ghcr.io`, privadas, com tag `sha-XXXXXXX`.

Antes, uma vez só:

1. **DNS:** registro A `api` → `177.7.61.136`, **cinza**, no painel do
   Cloudflare. O `app` já existe. Conferir com
   `scripts/cloudflare-crystal-vps-dns.sh conferir`.
2. **Resend:** conta criada e uma chave de API. Sem ela a API não sobe em
   produção, porque o login manda um código por e-mail. Para testar, o
   remetente `onboarding@resend.dev` só entrega no e-mail do dono da conta.
   Para valer, verificar o domínio no Resend e usar um remetente dele.

Na VPS, pelo Web console, como root:

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh   # commit de 40 letras, nunca branch (INF-04)
bash bootstrap-vps.sh app-ghcr                  # token do GitHub com read:packages
bash bootstrap-vps.sh app-definir RESEND_API_KEY
bash bootstrap-vps.sh app-definir EMAIL_FROM    # ex.: Crystal <onboarding@resend.dev>
bash bootstrap-vps.sh app-subir sha-1fb80ea     # último build verde (29/09)
bash bootstrap-vps.sh app-segredos              # copiar pro Bitwarden
bash bootstrap-vps.sh app-admin                 # primeiro admin: CPF, e-mail e nome
```

Enquanto a agência não passar os endereços da Crystal e da base de clientes,
a API sobe com a Crystal **simulada** e só entra quem for criado pelo
`app-admin`. Quando chegarem: `app-definir CRYSTAL_API_URL` (e as outras
três) e `app-subir` de novo com a mesma tag.

`ENCRYPTION_KEY` e `CPF_SALT` nunca podem mudar: sem eles os campos cifrados e
o hash do CPF ficam ilegíveis. O `backup` diário passa a levar também o banco
do app, que só se restaura com essas duas chaves.

### Publicar o PRD de Otimização (etapas 1, 2 e 3)

Roteiro completo, um comando por vez e com a lista de conferência em aparelho de
cada release, em **`crystal-em-casa/publicar-prd.md`**. Resumo: `app-definir` do
segredo do reembolso e da chave da Groq; depois, para cada etapa, `backup`,
`app-subir <tag>` e `app-status`. Tags publicadas: `sha-79ba6b7` (etapa 1),
`sha-69ef26c` (etapa 2), `sha-da617ac` (etapa 3) e, por cima, os ajustes pós-QA até
**`sha-398e46e`, a versão no ar desde 05/10**. Subir de novo: `app-subir sha-398e46e`
(as tags antigas voltariam a produção). Volta: `app-subir <tag anterior>`.

Desde a revisão de 05/10 o `app-subir` confere o `api.env` no boot da própria imagem
antes do deploy e falha se o Swarm desfizer a troca (rollback), mesmo com a tag igual,
mostrando o log do contêiner que morreu.

A etapa 1 traz a API **sem root** (`USER node`, uid 1000); o `app-subir` ajusta
sozinho o dono do volume `crystal_app_app_uploads` para 1000:1000 antes do deploy.
A etapa 2 não usa mais `CRYSTAL_ONBOARDING_URL`: `app-remover CRYSTAL_ONBOARDING_URL`
antes de subir. Os padrões de URL e modelo da transcrição já estão no código
(`https://api.groq.com/openai/v1/audio/transcriptions`, `whisper-large-v3-turbo`).

## Crystal provisória (n8n + OpenRouter)

Até a agência entregar o agente, o app pode responder com uma Crystal
provisória: o fluxo `n8n/crystal-provisoria.json` recebe a mensagem do app,
guarda as últimas 20 mensagens de cada conversa no Redis do n8n (banco 2, 7
dias) e pergunta ao OpenRouter. Não tem os prompts, a memória nem as regras
da Crystal de verdade, e o app continua fechado para alunos (a base de
clientes segue simulada).

```bash
bash bootstrap-vps.sh crystal-provisoria            # pede a chave do OpenRouter sem aparecer
bash bootstrap-vps.sh crystal-provisoria-teste      # uma pergunta de teste
bash bootstrap-vps.sh crystal-provisoria-desligar   # volta à Crystal simulada
```

- **Chave do OpenRouter:** uma nova, só para isso, com limite de crédito.
  Nunca a do agente em produção.
- **Modelo e prompt:** no nó "Monta a conversa (modelo e prompt aqui)" do fluxo,
  no editor do n8n. O padrão é `openrouter/auto`.
- **Privacidade:** só o texto e o id da conversa vão ao OpenRouter. O n8n não
  guarda execução com sucesso (só as com erro, que a limpeza apaga em 14 dias).
- **No ar desde 29/09**: fluxo ativo na VPS, app apontando para ele, teste pela
  API do app com status 200.
- Ensaiado em 29/09 com n8n 1.123.10 e Postgres: import, ativação, 403 sem a
  chave, memória entre mensagens, 400 para mensagem inválida, 502 com o
  OpenRouter fora.

## Proteção da VPS contra ataque e malware

```bash
bash bootstrap-vps.sh seguranca
```

Liga a atualização de segurança automática do Ubuntu e o fail2ban no SSH (5 erros
em 10 minutos bloqueiam o IP por 1 hora), e mostra o que ainda depende de decisão:
portas escutando e atualização pendente. Não mexe em nenhum serviço do Docker. Regras
completas em "Segurança sempre" no CLAUDE.md.

SSH (desde 24/10, INF-11): se já existe chave de root em `/root/.ssh/authorized_keys`
(linha de chave sem opções), ele grava `/etc/ssh/sshd_config.d/00-crystal.conf` com
`PasswordAuthentication no`, `KbdInteractiveAuthentication no` e
`PermitRootLogin prohibit-password`, confere com `sshd -t` e recarrega o SSH (a sessão aberta
não cai). Sem chave, não trava: só avisa, como antes. Para não ficar trancado do lado de
fora, a trava nova se desfaz sozinha em 10 minutos, a menos que você entre por **outra**
janela (terminal do navegador da Hostinger ou ssh com a chave) e rode
`bash bootstrap-vps.sh ssh-confirmar`. Se a outra janela não entrar, não faça nada (ou rode
`ssh-voltar` na janela que ficou aberta). Atenção: se o terminal do navegador da Hostinger
entra com a senha do root, ele para de entrar com a trava; nesse caso, `ssh-voltar` e manter
só o aviso até ter uma chave num aparelho seu.

### Portainer só para IPs liberados

O Portainer manda em todo o Docker da VPS e guarda o token do ghcr. No stack da
agência ele fica aberto na internet, só com a senha (o CE não tem 2FA). Para
fechar:

1. No computador de quem vai usar o painel, abrir `https://1.1.1.1/cdn-cgi/trace`
   e anotar o número da linha `ip=`. Repetir para cada pessoa.
2. No Web console da VPS, com todos os IPs de uma vez (a lista nova substitui a
   anterior):
   ```bash
   bash bootstrap-vps.sh painel-restringir 189.1.2.3 200.4.5.6
   ```
3. De um IP liberado, abrir `https://painel.crystalnowpp.com.br` e conferir que o
   ambiente `primary` aparece como *up*.

O que muda (`stacks-app/01-portainer-restrito.yaml`):
- Quem não está na lista recebe **403 do Traefik**, antes da tela de login. O
  Traefik vê o IP real (portas em modo host); um `X-Forwarded-For` forjado não passa.
- O agente do Portainer (que fala com o `docker.sock`) sai da rede pública para uma
  rede interna da stack: o n8n e o app não o alcançam mais.
- Imagens presas no digest que já roda, sem `:sts` flutuante.
- Cabeçalhos: sem iframe, HSTS, `nosniff`.

`bash bootstrap-vps.sh painel-restringir` sem IP mostra a lista. IP de casa mudou e
o painel deu 403: pelo Web console da Hostinger (não depende de IP), rodar de novo
com o IP novo. `painel-desligar` tira o Portainer do ar quando ninguém estiver
usando; `painel-ligar` volta. O `preparar` refaz a trava sozinho se a lista existir.

Ensaiado em 29/09 com o Traefik v2.11.3 e os mesmos rótulos: IP da lista → 200 com
os cabeçalhos; fora da lista → 403, inclusive com `X-Forwarded-For` forjado. Num
Swarm local, o Portainer alcança `tasks.agent:9001` e um vizinho da rede pública
não resolve o agente.

### Revisão de segurança de 24/10: o que rodar na VPS

Relatório: `auditorias/2026-10-24/seguranca/05-infra.md`. **Se a onda 1 ainda não foi rodada
na VPS, não rode este bloco: vá direto ao roteiro da onda 2, logo abaixo**, que já inclui os
itens 1 e 2 daqui (Traefik v2.11.60 no passo 3, Chatwoot no 7, n8n no 5) e evita derrubar
cada serviço duas vezes na mesma noite. Só o item 4 (`app-db-papel`) fica para outra noite,
como já estava. Na VPS, como root, de madrugada (o Traefik some por alguns segundos na
troca), com o `bootstrap-vps.sh` baixado do commit novo e conferido pelo sha256, um comando
por vez:

```bash
bash bootstrap-vps.sh backup                       # bancos, antes de tudo
# 1. Traefik v2.11.3 -> v2.11.60 (INF-01). O preparar regrava os 7 arquivos de
#    /root/crystal/stacks (mesmos segredos) e refaz a trava do painel. Ele pede o
#    e-mail do Let's Encrypt; esta linha reaproveita o que já está no arquivo atual:
bash bootstrap-vps.sh preparar "$(grep -o 'acme.email=[^"]*' /root/crystal/stacks/00-traefik.yaml | cut -d= -f2)"
bash bootstrap-vps.sh traefik                      # no fim: "Traefik no ar: traefik:v2.11.60" e
                                                   # "403 nas 6 variações (inclusive /../ e %2e%2e)"
bash bootstrap-vps.sh atendimento-subir            # regra nova: /monitoring e /platform também só dos IPs
# 2. n8n sem acesso ao ambiente, sem Execute Command / arquivos / pacotes de terceiros
#    (INF-03). Os arquivos novos já saíram do preparar acima; isto só sobe os três:
bash bootstrap-vps.sh n8n                          # editor, webhook e worker, um de cada vez
# 3. SSH só com chave (INF-11): trava sozinho se já houver chave em /root/.ssh/authorized_keys;
#    depois, de OUTRA janela que entrou: bash bootstrap-vps.sh ssh-confirmar (sem isso, volta em 10 min)
bash bootstrap-vps.sh seguranca
# 4. TESTAR PRIMEIRO, noutra noite: a API deixa de entrar no Postgres como superusuário (INF-07)
bash bootstrap-vps.sh app-db-papel                 # simulação: transação desfeita, tem de dizer "simulação limpa"
bash bootstrap-vps.sh app-db-papel --confirmo      # passo 1: papel crystal_api dono do banco do app
bash bootstrap-vps.sh app-subir sha-XXXXXXX        # passo 2: a MESMA tag que está no ar (app-status mostra)
# Volta do 4: bash bootstrap-vps.sh app-db-papel --voltar && bash bootstrap-vps.sh app-subir sha-XXXXXXX
```

Sobre o n8n (`stacks-exemplo/04`, `05` e `06`): entram `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`,
`NODES_EXCLUDE` com `executeCommand`, `readWriteFile` e `localFileTrigger`,
`N8N_COMMUNITY_PACKAGES_ENABLED=false` (e `N8N_REINSTALL_MISSING_PACKAGES=false`) e os nós de
código passam a importar só o `crypto` (`NODE_FUNCTION_ALLOW_BUILTIN`; com `*`, um nó de código
rodava comando por fora do Execute Command). Risco para o nosso fluxo: nenhum. O
`compra-assiny` só usa Webhook, HTTP Request, If e Respond to Webhook; os outros dois fluxos do
repositório não usam `require` nem `$env`. Um fluxo feito à mão no editor que use um desses nós
ou `$env` passa a dar erro na execução: conferir em Executions na primeira hora. Conferência
de ponta a ponta (regrava as mesmas credenciais, faz uma compra e um reembolso de teste):
`python3 compra-assiny-credenciais.py`. Volta: as linhas antigas estão no comentário dos
arquivos; trocar, `preparar` e `n8n` de novo. Falta só uma coisa à mão: 2FA em todas as contas
do n8n (Settings > Personal > Two-factor).

Papel da API no Postgres (INF-07): hoje a API e a migração do Prisma entram como `crystal`,
o superusuário com que a imagem do Postgres nasceu; uma falha na API viraria comando no
contêiner do banco (`COPY ... TO PROGRAM`) e leitura da memória da Crystal. O Postgres 16 não
deixa tirar o superusuário desse papel (ensaiado: "The bootstrap user must have the SUPERUSER
attribute"), então o `app-db-papel` cria `crystal_api`, sem superusuário, e o faz dono do banco
`crystal_web_chat` e de tudo no schema `public` (tabelas, sequências, tipos, funções; o que é
de extensão fica). É o que o `prisma migrate deploy` precisa. A senha nova
(`APP_DB_API_SENHA`) vai para o `.segredos` (copiar pro Bitwarden com `app-segredos`) e a marca
para `/root/crystal/app/.db-papel`; o `app-subir` seguinte monta o `DATABASE_URL` com ela.
`crystal` continua superusuário para backup e diagnóstico. Ensaiado num Postgres 16 com as 44
migrações do app: simulação sem efeito; depois, `crystal_api` cria tabela, enum e índice e
pega trava consultiva, e leva "permission denied" em `COPY ... TO PROGRAM` e `pg_read_file`;
com uma tabela travada, o comando falha sem mudar nada e sem a senha no log. Depois de uma
migração feita como `crystal` ou de uma restauração (o backup é `--no-owner`), rodar
`--confirmo` de novo. Uma migração futura com `CREATE EXTENSION` não confiável falharia como
`crystal_api`: aí, volta, `app-subir`, e `--confirmo` de novo.

Yaml por commit fixo e sha256 (INF-04): o script não baixa mais nada de branch. Quem mudar
um arquivo de `stacks-exemplo/`, `stacks-app/01`, `10`, `20` ou `n8n/crystal-provisoria.json`:
commit e push do arquivo; no repositório, `bash crystal-em-casa/bootstrap-vps.sh arquivos-hash`
(imprime o `STACKS_COMMIT` atual e a tabela, marcando o que mudou); colar no topo do script e
commitar. Sem isso a VPS recusa o arquivo novo ("NÃO usado") e nada é trocado. O commit
gravado tem de continuar no GitHub: juntar esta branch por merge (não por squash/rebase), ou
rodar `arquivos-hash` de novo depois de juntar. `REF=<commit de 40 letras>` troca o commit;
branch não é aceita.

Segredos do app e do Chatwoot no spec do Swarm (INF-05): continuam em `env_file`, que o
Swarm copia para o spec do serviço (o Portainer e `docker service inspect` mostram). A onda 2
avaliou Docker secrets e não fez (as imagens só leem variável de ambiente; ver abaixo); a
defesa é o painel restrito, só o root no Docker e o Traefik pelo proxy só de leitura, e o
`app-subir` e o `atendimento-subir` avisam no fim se o painel não estiver restrito.

Volta do Traefik: `docker service rollback traefik_traefik` (o Swarm guarda a versão
anterior). Conferir de fora, de um IP que não está na lista do painel:
`curl -s -o /dev/null -w '%{http_code}\n' --path-as-is https://atendimento.crystalnowpp.com.br/x/../super_admin`
tem de dar `403`.

#### Onda 2 (infraestrutura): o que rodar na VPS, em ordem

O que muda, em palavras simples:

- **Cada stack na sua rede.** Antes tudo estava numa rede só: um contêiner invadido (um nó
  de código do n8n, por exemplo) falava direto com a API, com o Chatwoot, com a tela do
  Portainer e com o banco do n8n, sem passar pelo Traefik. Agora cada serviço publicado tem
  uma "borda" onde só ele e o Traefik estão (`borda_api`, `borda_web`, `borda_atendimento`,
  `borda_n8n`, `borda_painel`), e o banco e a fila do n8n ficam na `n8n_interno`, só do n8n.
  O Traefik não entra em rede de banco. Os nomes que os apps usam não mudam.
- **O IP de quem acessa não pode ser inventado.** O Traefik apaga o `X-Forwarded-For` que
  vem de fora (sempre fez; agora está escrito) e a API só aceita esse cabeçalho vindo da
  `borda_api`, onde só o Traefik está (`TRUST_PROXY` = a faixa dessa rede). Antes, um vizinho
  de rede falando direto com a API escolhia o IP que entrava no limite de tentativas.
- **O Traefik não manda mais no Docker.** Ele lê as rotas por um proxy só de leitura do
  `docker.sock`; uma falha nele não vira root na VPS. Também ficou só de leitura, sem
  capabilities, com teste de saúde, limite de memória e log com rotação (o log de acesso
  guarda só os erros, com IP, e não cresce mais sem limite).
- **Redis do app com senha**, Postgres e Redis em versão fixa, o app preso no digest da
  imagem, a Crystal só de leitura e sem capabilities (API e web sem capabilities), HSTS no
  Chatwoot e no n8n, rotação de log e limites nas stacks da agência.
- **Docker com `no-new-privileges`** e rotação de log padrão; backups antigos cifrados também
  na VPS; a vigia manda todo mês o fim da chave pública dos backups para comparar com o
  Bitwarden.

Quando: na janela 02:00–05:00 BRT, time avisado, vigia ligada. Este roteiro já inclui a
onda 1 (Traefik v2.11.60, trava do Chatwoot, n8n sem Execute Command): não rode o bloco
anterior antes dele. Cada passo tira um pedaço do ar por segundos (o passo 1, opcional, tira
tudo por 1 a 2 minutos; o 5 tira o n8n por 1 a 3 minutos; o 6 tira a API por 1 a 2 minutos;
o 7 tira o Chatwoot por 1 a 2 minutos; a Assiny reenvia webhook que falhou). Obrigatórios
para o corte das redes: 2, 3, 5, 6 e 7 (o 4 também, se o painel estiver no ar). Sem queda
nenhuma: 0, 2 e 8. Na VPS, como root, com o `bootstrap-vps.sh` baixado do commit novo (o do
topo da branch depois de juntar) e conferido pelo sha256. Um comando por vez; só passe para
o próximo com a conferência do anterior limpa. Volta de cada passo logo abaixo dele.

```bash
# 0. Antes de tudo: backup dos bancos e anotar a tag do app que está no ar
bash bootstrap-vps.sh backup
bash bootstrap-vps.sh app-status                  # anote a tag (sha-XXXXXXX): ela vai no passo 6
bash bootstrap-vps.sh status                      # tudo 1/1 antes de começar

# 1. OPCIONAL (pode ficar para outra noite): Docker com no-new-privileges e rotação de log
#    padrão (INF-28). É o único passo que reinicia o Docker: TUDO cai por 1 a 2 min. As stacks
#    já têm rotação própria; o ganho aqui é o no-new-privileges. Se fizer, faça primeiro.
bash bootstrap-vps.sh docker-daemon               # só mostra o que muda (termina com "ERRO: de madrugada...": é só o aviso)
bash bootstrap-vps.sh docker-daemon --confirmo
#    Conferir: "NoNewPrivs: 1" e, em 2 min, 'bash bootstrap-vps.sh status' com tudo 1/1.
#    Volta: cp "$(ls -t /etc/docker/daemon.json.antes-* | head -1)" /etc/docker/daemon.json && systemctl restart docker

# 2. Arquivos novos e as 6 redes (vazias; nada muda no ar ainda)
bash bootstrap-vps.sh preparar "$(grep -o 'acme.email=[^"]*' /root/crystal/stacks/00-traefik.yaml | cut -d= -f2)"
#    Conferir: "rede(s) criada(s): borda_api ... n8n_interno". Volta: não precisa.

# 3. Traefik em todas as bordas, pelo proxy do docker.sock, só de leitura
bash bootstrap-vps.sh traefik
#    Conferir: "Traefik lendo as rotas" e "Traefik no ar: traefik:v2.11.60". Ainda NÃO espere
#    "403 nas 6 variações": o Chatwoot no ar tem a regra antiga (só /super_admin), então aqui
#    aparecem 2 avisos, de /monitoring/sidekiq e /platform/api/v1/users; eles somem no passo 7.
#    O que importa agora: /super_admin, /x/../super_admin e /x/%2e%2e/super_admin em 403.
#    Depois: bash bootstrap-vps.sh app-status && bash bootstrap-vps.sh atendimento-status
#    Volta: sozinha se nenhuma rota responder em 2 min; à mão: docker service rollback traefik_traefik

# 4. Painel na borda_painel
bash bootstrap-vps.sh painel-restringir $(paste -sd' ' /root/crystal/.painel-ips)
#    Se a resposta for só a lista (ou "painel. está aberto para qualquer IP"), nada subiu:
#    rode então 'bash bootstrap-vps.sh portainer' (painel aberto, mas já na borda_painel).
#    Conferir: 403 vindo da VPS, "o n8n não alcança a tela do Portainer (9000)" e, de um IP
#    liberado, o painel abre com o ambiente primary "up".
#    Volta: docker service rollback portainer_portainer && docker service rollback portainer_agent

# 5. n8n: banco e fila na n8n_interno; o bancos sobe editor, webhook e worker logo em seguida
bash bootstrap-vps.sh bancos
#    O n8n fica sem banco do começo ao fim deste passo (1 a 3 min); o comando de volta aparece
#    na tela antes de ele mexer. Conferir: bash bootstrap-vps.sh status (editor. e webhook.
#    respondem) e, no editor, Executions sem erro na primeira hora (a próxima compra passa).
#    Volta: for s in postgres redis editor webhook worker; do docker service rollback n8n_${s}_n8n_${s}; done

# 6. App: API e web nas bordas, Redis com senha, Crystal só de leitura, imagens no digest
bash bootstrap-vps.sh app-subir sha-XXXXXXX       # a MESMA tag anotada no passo 0
#    Conferir: "API lê o IP do cliente só do Traefik (TRUST_PROXY=10.x.x.0/24)", "presa no
#    digest", app-status com app. e api. em 200 e: bash bootstrap-vps.sh crystal-conferir
#    Volta: for s in api web crystal redis postgres; do docker service rollback crystal_app_app_$s; done
#    (o rollback do Swarm volta junto o ambiente antigo, Redis sem senha e TRUST_PROXY=1)

# 7. Chatwoot: Rails na borda_atendimento, Sidekiq só na rede interna, HSTS, Redis sem root
bash bootstrap-vps.sh atendimento-subir
#    Conferir: atendimento-status ("403 nas 6 variações") e bash bootstrap-vps.sh atendimento-teste
#    (a Crystal responde na inbox: prova que Chatwoot -> API -> Crystal continua de pé).
#    Volta: for s in rails sidekiq redis postgres; do docker service rollback crystal_atendimento_cw_$s; done

# 8. Prova final e arremates
bash bootstrap-vps.sh redes-conferir              # tudo "ok"; nenhum "!!"
bash bootstrap-vps.sh seguranca --sem-ssh         # grupo docker vazio, docker.sock 660, token do ghcr; o SSH fica como está
bash bootstrap-vps.sh backup-cron                 # regrava o cron do backup com PATH fixo
#    O --sem-ssh é de propósito: quem entra pelo terminal do navegador da Hostinger, sem chave
#    própria, não troca o SSH para "só chave" no meio da madrugada (se já houver uma chave de
#    root de outra pessoa em /root/.ssh/authorized_keys, o 'seguranca' sem a opção trava e
#    espera 10 min por uma confirmação de outra janela). A trava do SSH (INF-11) fica para
#    quando a sua chave estiver num aparelho seu: aí 'bash bootstrap-vps.sh seguranca' e, de
#    OUTRA janela que entrou, 'ssh-confirmar' (como descrito em "Proteção da VPS").
```

**Volta de tudo de uma vez** (algo parou de conversar e não dá para achar o quê na hora):
`bash bootstrap-vps.sh redes-voltar --confirmo`. Ele grava a marca `/root/crystal/.redes`
(daí em diante tudo o que subir vai para a rede única de antes, a `network_swarm_public`) e
sobe de novo, uma de cada vez, n8n, painel, app (com a tag que está no ar) e Chatwoot. O
Traefik fica como está, em todas as redes, e é por isso que cada stack volta sozinha.
Redis com senha, versões fixas, HSTS e o resto ficam. Para separar de novo depois de
corrigir: `bash bootstrap-vps.sh redes-separar` (mostra os passos 2 a 8 de novo).

Se a Crystal ou o Traefik não subirem por causa do sistema de arquivos só de leitura (o
Swarm desfaz a troca sozinho e o passo termina com ERRO): `touch
/root/crystal/.sem-somente-leitura` e, para a Crystal, `app-subir` com a mesma tag de novo;
para o Traefik, `preparar` (a mesma linha do passo 2, que regrava o arquivo sem a trava) e
depois `traefik`. O arquivo sai sem o `read_only`, com aviso. Apagar
`.sem-somente-leitura` assim que a causa for corrigida.

**O que conferir depois** (na manhã seguinte, de um aparelho):

- [ ] `bash bootstrap-vps.sh redes-conferir` sem `!!`: o n8n não alcança a API, o Chatwoot, o
      painel nem o Postgres do app; a Crystal não alcança o Postgres do n8n; o IP forjado não
      aparece no log da API, nem o do Traefik.
- [ ] O app abre, o login com código por e-mail funciona e uma foto sobe (a API sem
      capabilities continua gravando no volume).
- [ ] A Crystal responde no app e pela inbox (`crystal-conferir`).
- [ ] O Chatwoot abre para a equipe; `/super_admin` dá 403 de fora; `curl -sI
      https://atendimento.crystalnowpp.com.br/api | grep -i strict-transport` mostra
      `max-age=31536000`.
- [ ] O n8n abre no editor e a próxima compra da Assiny aparece em Executions sem erro.
- [ ] O painel abre de um IP liberado, com o ambiente primary "up".
- [ ] `bash bootstrap-vps.sh status`: sem aviso de certificado, backup e R2 em dia, "redes
      separadas por stack", cron sem aviso, chave pública dos backups igual à do Bitwarden.
- [ ] `docker service logs --since 1h traefik_traefik 2>&1 | grep -ci 'permission\|403'` perto de
      zero (o proxy do docker.sock não está recusando o Traefik).
- [ ] Na noite seguinte: o backup das 03:30 passou e os arquivos das rodadas anteriores viraram
      `.age` em `/root/crystal/backups`.
- [ ] Dia 1º: chegou no Telegram a conferência mensal da chave pública; bate com o Bitwarden.
      Opcional: pôr a pública em `FORA_DEST_ESPERADO`, no topo do script (é pública), para a VPS
      se recusar a cifrar para outra.

**Por serviço: o que ficou travado e o que não, e por quê**

| serviço | só leitura | capabilities | outros |
|---|---|---|---|
| Traefik | sim (tmpfs em `/tmp`) | nenhuma, só `NET_BIND_SERVICE` | proxy do docker.sock, saúde, 1 CPU/512 MB, log com rotação |
| proxy do docker.sock | não (o HAProxy grava a config em `/tmp` e o pid em `/run`; só o Traefik o alcança, numa rede interna) | padrão | só GET de `/version`, `/_ping`, `/services`, `/networks`, `/tasks`, `/nodes` |
| app_crystal | sim (tmpfs em `/tmp`) | nenhuma | processa saída de modelo: é a que mais ganha |
| app_api | não: o bootstrap grava scripts temporários em `/app/apps/api` e o start pelo pnpm/corepack não foi ensaiado sem escrita | nenhuma | Redis com senha; IP só do Traefik |
| app_web | não: o Next grava cache em `.next/` | nenhuma | |
| Postgres e Redis (app, Chatwoot, n8n) | não: a entrada da imagem troca o dono da pasta de dados e o usuário (precisa de CHOWN/SETUID) | padrão | rede interna da stack; versão fixa; Redis do app e do Chatwoot com senha e sem root |
| n8n (editor, webhook, worker) | não: grava em `/home/node/.n8n` (sem volume nas stacks da agência) | padrão (já roda como `node`) | INF-03 da onda 1; log com rotação |
| Chatwoot (Rails, Sidekiq) | não: grava `tmp/` e `log/` dentro de `/app` | padrão | Sidekiq fora da borda; HSTS |
| Portainer e agente | não ensaiado | padrão (o agente precisa do docker.sock) | painel só para IPs liberados; limites; sem teste de saúde (a imagem não tem shell) |

`no-new-privileges` vale para todos, pelo daemon (passo 1): o `docker stack deploy` ignora
`security_opt` por serviço. Segredos em Docker secrets: não (INF-05). As imagens do app e do
Chatwoot só leem variável de ambiente; a defesa é quem alcança o spec dos serviços: só o
root (o `seguranca` confere grupo docker vazio, `docker.sock` 660 e nada da API do Docker em
TCP), o Portainer só para IPs liberados e o Traefik pelo proxy só de leitura (que ainda lê o
spec: é o limite que fica).

A situação de cada achado do relatório (feito, de propósito não, ou no repositório do app)
está no fim de `auditorias/2026-10-24/seguranca/05-infra.md`.

## Backup fora da VPS (Cloudflare R2, cifrado)

Um ransomware na VPS apaga o backup que está nela. Por isso cada backup diário
também sobe para um bucket do R2, com três travas:

- **Cifrado na VPS com [age](https://age-encryption.org)**, para uma chave pública.
  A chave privada existe só no Bitwarden: quem invadir a VPS acha a chave do R2,
  mas não lê backup nenhum.
- **Trava do bucket (bucket lock) de 30 dias**: nem com a chave do R2 dá para
  apagar ou sobrescrever o que subiu.
- **Token do R2 só daquele bucket**, "Object Read & Write". A chave vai ao curl pela
  entrada padrão, nunca na linha de comando.

Sobe: banco do n8n, banco do app, memória da Crystal (`crystal_agente`), uploads do
app e, com o Chatwoot no ar, o banco e os anexos dele. Pastas vão em tar incremental
(completo no domingo, diferencial nos outros dias; o `backup-link` dá os dois). Parte
que falha não para as outras nem o envio ao R2: o backup termina com o resumo do que
falhou e saída 1, e a vigia avisa (backup com mais de 26 h, falha registrada, R2
velho, disco a partir de 85%). Não sobe segredo nenhum: `N8N_CHAVE`,
`ENCRYPTION_KEY`, `CPF_SALT` e `CRYSTAL_CHAVE_CIFRA` ficam no Bitwarden, e sem eles
as credenciais do n8n, os campos cifrados do app e a memória da Crystal não abrem.

**No Cloudflare (uma vez):**
1. R2 > ativar (plano gratuito: 10 GB, sem custo de saída).
2. Criar o bucket `crystal-backups`, localização automática.
3. No bucket, Settings > **Bucket lock rules** > regra para todos os objetos,
   retenção de **30 dias**.
4. No bucket, Settings > **Object lifecycle rules** > apagar objetos com mais de
   **60 dias**.
5. R2 > Manage API tokens > criar token com **Object Read & Write**, só para o
   bucket `crystal-backups`. Guardar Access Key ID e Secret Access Key no Bitwarden.

**Na VPS (Web console):**
```bash
bash bootstrap-vps.sh backup-chave         # chave privada no less -> Bitwarden; confere os 6 últimos
bash bootstrap-vps.sh backup-fora-config   # Account ID, bucket, Access Key, Secret (não aparece); testa
bash bootstrap-vps.sh backup               # um backup agora, já indo para o R2
bash bootstrap-vps.sh backup-conferir      # o que está no R2 e há quanto tempo
bash bootstrap-vps.sh backup-testar-trava  # tenta apagar um teste no R2 com a chave da VPS: tem que ser recusado
```
O `backup-fora-config` testa os dados novos antes de trocar (se o teste falha, a
configuração anterior continua) e reinstala o cron das 03:30. A cópia do script que o
cron roda é trocada a cada `app-subir` e `atendimento-subir`; o `status` mostra se ela
é igual ao script e avisa se o último envio ao R2 tem mais de 26 horas. O
`backup-testar-trava` só dá "trava valendo" com recusa 403 e o arquivo ainda lá.

**Restaurar (ou só testar, uma vez por mês), no Mac:**
```bash
brew install age
# baixar o .age: no painel do R2 (bucket > objeto > Download) ou, mais fácil,
# rodar "bash bootstrap-vps.sh backup-link" na VPS e colar no Mac a linha curl
# que ela mostra (link de 10 minutos, só para aquele arquivo)
# copiar a chave AGE-SECRET-KEY-... do Bitwarden e, sem colar em lugar nenhum:
pbpaste | grep -o 'AGE-SECRET-KEY-1[0-9A-Z]*' | age -d -i - ~/Downloads/n8n_queue-AAAAMMDDTHHMMSSZ.sql.gz.age | gunzip | head -40
```
Para restaurar de verdade, sem o `head`: `... | gunzip > n8n.sql`, copiar para a
VPS nova e `docker exec -i CID psql -U postgres -d n8n_queue < n8n.sql`.

Ensaiado em 29/09 contra um S3 local que confere a assinatura (região `auto`, como
o R2): envio dos três arquivos, listagem, chave errada recusada (403, backup falha
e avisa), arquivo abre com a chave privada e não abre sem ela, chave privada nunca
em arquivo, segredo do R2 nunca na tela, configuração errada não fica gravada.

## A nossa Crystal (em paralelo com a da agência)

**No ar desde 30/09** (`sha-532523d`): o app aponta para ela e o teste pela API do
app respondeu 200. Chave do OpenRouter própria da VPS, com limite de crédito. A
provisória do n8n continua instalada, como caminho de volta.

Decisão de 30/09: cobrar a agência com prazo e, em paralelo, ter a nossa pronta.
O código está em `apps/crystal` do `crystal-web-chat` e sobe como o serviço
`app_crystal` da stack do app: sem endereço público, só o `app_api` a alcança.

- **Mesmo contrato do app**: trocar de Crystal é só mudar para onde o app aponta.
  `crystal-nossa` aponta para a nossa; `crystal-provisoria` volta para a do n8n.
- **Modelo**: OpenRouter, com `provider.data_collection: deny`. Ao modelo vai só o
  texto da conversa. Chave própria da VPS, com limite de crédito no OpenRouter.
  Modelo padrão `openrouter/auto`; fixar um depois de testar (`app-definir CRYSTAL_MODEL`).
- **Memória**: últimas 20 mensagens por contato, 180 dias, em banco e papel
  próprios (`crystal_agente`, sem acesso ao banco do app), texto cifrado e contato
  em HMAC. `CRYSTAL_CHAVE_CIFRA` nunca muda depois de guardar conversa.
- **Segurança**: risco à vida ou violência sai sempre com CVV 188, SAMU 192,
  Ligue 180 e 190, mesmo que o modelo esqueça. Log sem conteúdo.
- **Prompt**: `apps/crystal/prompt/crystal.md` é RASCUNHO nosso. Quando a agência
  mandar o prompt e a base, entram em `prompt/` e `conhecimento/`.

```bash
bash bootstrap-vps.sh crystal-nossa sha-XXXXXXX   # pede a chave do OpenRouter sem aparecer
bash bootstrap-vps.sh crystal-nossa-teste
bash bootstrap-vps.sh crystal-provisoria          # volta para a do n8n
```

Ensaiado em 30/09: 36 testes; o cliente do próprio app (`HttpCrystalClient`) contra
o serviço em modo produção com Postgres 16 e um OpenRouter falso: streaming,
memória entre turnos, contatos de ajuda acrescentados, chave errada recusada,
nenhum id no pedido ao modelo, texto cifrado no banco, log sem conteúdo, papel
sem acesso ao banco do app.

## Ligar o nosso Chatwoot (atendimento.)

O LendChat vai sair; o app passa a conversar pelo nosso Chatwoot, onde a equipe vê
as conversas e pode assumir. A Crystal continua a nossa (`app_crystal`), agora como
robô do Chatwoot.

1. No Cloudflare, zona crystalnowpp.com.br: registro **A**, nome `atendimento`,
   IP `177.7.61.136`, **Somente DNS (nuvem cinza)**. Ou, com token:
   `scripts/cloudflare-crystal-vps-dns.sh criar --aplicar`.
2. Na VPS, um comando de cada vez (desde 24/10 o script já sabe de qual commit baixar o
   yaml, sem `REF=`):

```bash
bash bootstrap-vps.sh atendimento-subir                           # até 10 min na 1ª vez
bash bootstrap-vps.sh atendimento-segredos                        # copiar pro Bitwarden
bash bootstrap-vps.sh atendimento-configurar sha-XXXXXXX          # admin, inbox, robô; testa
bash bootstrap-vps.sh app-canal chatwoot                          # o app passa a usar o Chatwoot
```

3. Entrar em `https://atendimento.crystalnowpp.com.br` com o login do Bitwarden e
   ligar a verificação em duas etapas (Perfil > Senha e segurança).

Como funciona: a mensagem do aluno vai à inbox "App da Crystal" (API pública,
contato pelo telefone com HMAC); o Chatwoot avisa o robô em
`https://api.crystalnowpp.com.br/webhooks/chatwoot-bot`; a API pergunta à Crystal e
publica a resposta; o Chatwoot devolve ao app por `/webhooks/chatwoot`. Os dois
webhooks são assinados e passam pelo endereço público de propósito (o Chatwoot
recusa endereço interno, proteção contra SSRF que fica ligada).

A equipe assume escrevendo na conversa (ela sai de "Pendentes" e o robô para). Para
devolver ao robô, marcar a conversa como pendente ou resolver: a próxima mensagem do
aluno reabre como pendente. Voltar o app para a Crystal direto: `app-canal crystal`.
O aluno precisa de telefone no cadastro (`app-telefone EMAIL` para contas feitas aqui).

## Ligar o login à base de alunos do Supabase

Depois da transferência do projeto do Supabase:

**Ligada em 05/10**, com alunas reais: função criada, URL e chave na VPS, login de
uma aluna real da base testado no app. A URL foi colada primeiro com `/rest/v1/` no
fim (todo login daria 503) e corrigida; hoje o `app-definir` corta esse caminho
sozinho e recusa a chave anon ou publicável. Roteiro em `publicar-prd.md`, seção
"Base de alunos no Supabase".

1. No SQL Editor do Supabase, rodar `crystal-em-casa/supabase/app_verificar_login.sql`
   deste repositório (já com as colunas reais do projeto Crystal AI, conferidas em
   05/10). Não usar o modelo `docs/supabase/` do repositório do app: os nomes de lá
   não existem e o filtro de acesso ativo é outro.
2. Na VPS:

```bash
bash bootstrap-vps.sh app-definir SUPABASE_URL               # https://<ref>.supabase.co, nada depois
bash bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY  # sb_secret_... ou service_role; nunca a anon
bash bootstrap-vps.sh app-supabase-teste                     # 200 ok, 404 função não existe, 401 chave errada
bash bootstrap-vps.sh app-subir sha-398e46e                  # roda o app-supabase-teste no fim
```

A chave service_role abre o banco inteiro: só no cofre e na VPS, nunca no chat, nunca
no dashboard. Com a base de alunos e o canal ligados, o app deixa de usar simulação.

## Preparar a fase 2 sem depender da agência

- `ci/build-image.yml`: workflow do GitHub Actions que constrói a imagem do
  agente em linux/amd64 e publica em `ghcr.io/lfcrystal766/crystal-ia:<tag>`, sem
  `latest`. Vai para `.github/workflows/` do repositório privado do agente
  depois que a agência entregar o código. Dispensa build no Mac.
- `bootstrap-vps.sh backup` e `backup-cron`: dump diário do banco do n8n em
  `/root/crystal/backups`, 14 dias, e cópia cifrada no R2 (ver "Backup fora da
  VPS"). A chave do n8n fica só no cofre.
- Firewall da VPS pelo hPanel (VPS > Firewall): liberar só 22, 80 e 443.
  As portas do Swarm (2377, 7946, 4789) não precisam ficar públicas num nó só.
- Portainer > Registries: cadastrar o ghcr.io com o token `write:packages`
  (ou um token só de `read:packages`) para o deploy puxar a imagem privada.

## Conferir o DNS a qualquer hora, sem token

```bash
scripts/cloudflare-crystal-vps-dns.sh conferir
```

Resolve os seis nomes (`painel`, `editor`, `webhook`, `app`, `api` e `atendimento`)
por DNS-over-HTTPS e confere se apontam para o IP da VPS e se `server.` (Stape)
continua cinza. Sai 0 quando os seis estão certos.
