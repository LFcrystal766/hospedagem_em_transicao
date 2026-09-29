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
  entrada `websecure`, emissor `letsencryptresolver`.
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
| Backup do n8n | **Feito em 29/09**: dump diário às 03:30 em `/root/crystal/backups`, 14 dias. Cópia fora da VPS: snapshot/backup semanal da Hostinger (conferir no hPanel). R2 do Cloudflare não está ativado na conta |
| Firewall | **Feito em 29/09**: ufw com 22, 80 e 443. Portas do Swarm fora da internet |
| Portainer restrito | **No ar desde 29/09** (`painel-restringir`): só o IP de casa do Luiz na lista. Conferido de fora: 403 fora da lista; do IP liberado, login e ambiente `primary` funcionando pelo agente na rede interna. Imagens presas em `portainer-ce`/`agent` 2.45.0 (digest). Falta o IP do Igor, se ele for usar |
| Netlify | Conta criada em 29/09 (com o GitHub), segundo o Luiz. Sem API aqui para conferir |
| Telegram | **Feito em 29/09**: bot e grupo `Crystal · Alertas`, bot como admin, `sendMessage` testado. Token no Bitwarden; `TELEGRAM_ALERT_CHAT_ID=-1003662546162` |
| Webhook do app | **No ar desde 29/09** no n8n: `n8n/webhook-crystal-app.json`. Health 200, POST sem segredo 403. Formato definitivo depende da agência |
| OpenRouter | **Conta nossa**, com acesso do Luiz desde 29/09. Não apagar nem trocar chave antes do corte: uma é a do agente em produção. Na fase 2, chave nova só para a VPS |
| Respostas da agência | Compute size do Supabase, qual chave do OpenRouter o agente usa hoje, como o agente atende um canal que não é o LendChat, onde está a base de clientes |
| Código do agente | **Não chegou.** `LFcrystal766/crystal-ia` vazio em 29/09 às 03:00 |
| App web | Repositório `LFcrystal766/crystal-web-chat`, transferido do Igor em 29/09. Avaliação em `app-web-chat.md` |
| Stack do app | **No ar desde 29/09**, tag `sha-1fb80ea`, 4 serviços 1/1. Conferido de fora: `app.` 200 e `api./healthz` 200, os dois com certificado do Let's Encrypt; CORS só para `app.`; CSP do app aponta só para `api.`. Crystal e base de clientes **simuladas** até a agência passar os endereços. Resend com domínio verificado (`send.`, `resend._domainkey`, `_dmarc` p=none), remetente `acesso@crystalnowpp.com.br`. Segredos trocados às 12:17 (`app-recomecar`, os anteriores apareceram no chat). Admin criado (CPF final 3899) e **login ponta a ponta conferido em 29/09**: aceite LGPD, código pelo Resend, entrada no app |

Boston em vez de São Paulo não fere o guia: o tempo do atendimento é dominado
pela resposta do modelo, não pela rede. Vale conferir a região do projeto do
Supabase quando ele for transferido, para o banco não ficar em outro continente
que a VPS.

## Subir a fundação na VPS

`bootstrap-vps.sh` roda **na VPS**, como root. Baixa os yaml deste repositório
(público, sem segredo), gera a senha do banco e a chave do n8n **na própria
máquina** (`/root/crystal/.segredos`, uma vez só), grava os arquivos prontos em
`/root/crystal/stacks/` e sobe as stacks na ordem, esperando cada uma ficar 1/1.

```bash
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/claude/gracious-shannon-6x9l5j/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
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
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/claude/gracious-shannon-6x9l5j/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
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
SSH aceitando senha, root, portas escutando e atualização pendente. Não mexe em
nenhum serviço. Regras completas em "Segurança sempre" no CLAUDE.md.

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

## Ligar o canal do LendChat no app

O app já sabe falar com uma inbox de API no formato do Chatwoot
(`CHAT_TRANSPORT=chatwoot`). Com a inbox criada do nosso lado no LendChat:

```bash
bash bootstrap-vps.sh app-definir CHATWOOT_BASE_URL          # base da API da inbox, https
bash bootstrap-vps.sh app-definir CHATWOOT_INBOX_IDENTIFIER  # identificador da inbox
bash bootstrap-vps.sh app-definir CHATWOOT_WEBHOOK_SECRET    # segredo que assina o webhook
bash bootstrap-vps.sh app-definir CHATWOOT_INBOX_HMAC_TOKEN  # só se a inbox tiver HMAC de identidade
bash bootstrap-vps.sh app-definir CHAT_TRANSPORT             # responder: chatwoot
bash bootstrap-vps.sh app-subir sha-XXXXXXX                  # imagem com o canal (d3e25a5 ou mais nova)
```

Na inbox, o webhook aponta para `https://api.crystalnowpp.com.br/webhooks/chatwoot`.
O aluno precisa ter o telefone do WhatsApp no cadastro; sem ele, a mensagem não sai.
Para voltar à Crystal provisória: `app-definir CHAT_TRANSPORT` com `crystal` e
`app-subir` de novo.

## Ligar o login à base de alunos do Supabase

Depois da transferência do projeto do Supabase:

1. No SQL Editor do Supabase, conferir as colunas de `leticia_crystal_customers` e
   rodar `docs/supabase/app_verificar_login.sql` do repositório do app, ajustando os
   nomes marcados com `<<< CONFERIR`.
2. Na VPS:

```bash
bash bootstrap-vps.sh app-definir SUPABASE_URL               # https://<projeto>.supabase.co
bash bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY  # Settings > API > service_role
bash bootstrap-vps.sh app-subir sha-XXXXXXX                  # 516f6a9 ou mais nova
```

A chave service_role abre o banco inteiro: só no cofre e na VPS, nunca no chat, nunca
no dashboard. Com a base de alunos e o canal ligados, o app deixa de usar simulação.

## Preparar a fase 2 sem depender da agência

- `ci/build-image.yml`: workflow do GitHub Actions que constrói a imagem do
  agente em linux/amd64 e publica em `ghcr.io/lfcrystal766/crystal-ia:<tag>`, sem
  `latest`. Vai para `.github/workflows/` do repositório privado do agente
  depois que a agência entregar o código. Dispensa build no Mac.
- `bootstrap-vps.sh backup` e `backup-cron`: dump diário do banco do n8n em
  `/root/crystal/backups`, 14 dias. A chave do n8n fica só no cofre.
- Firewall da VPS pelo hPanel (VPS > Firewall): liberar só 22, 80 e 443.
  As portas do Swarm (2377, 7946, 4789) não precisam ficar públicas num nó só.
- Portainer > Registries: cadastrar o ghcr.io com o token `write:packages`
  (ou um token só de `read:packages`) para o deploy puxar a imagem privada.

## Conferir o DNS a qualquer hora, sem token

```bash
scripts/cloudflare-crystal-vps-dns.sh conferir
```

Resolve os três nomes por DNS-over-HTTPS e confere se apontam para o IP da VPS
e se `server.` (Stape) continua cinza. Sai 0 quando os três estão certos.
