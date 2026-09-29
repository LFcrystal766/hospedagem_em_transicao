# Crystal em casa: a VPS do app

Frente separada da migração do site. Aqui é o **app da Crystal** (agente em
Python + n8n) saindo da infraestrutura da agência (Academia Lendária) para uma
VPS nossa. O site WordPress continua no plano dos três degraus, em
`../PROXIMOS-PASSOS.md`. As duas frentes só se cruzam na zona DNS do Cloudflare.

O checklist interativo está no artefato
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
| Netlify | Conta criada em 29/09 (com o GitHub), segundo o Luiz. Sem API aqui para conferir |
| Telegram | **Feito em 29/09**: bot e grupo `Crystal · Alertas`, bot como admin, `sendMessage` testado. Token no Bitwarden; `TELEGRAM_ALERT_CHAT_ID=-1003662546162` |
| Webhook do app | **No ar desde 29/09** no n8n: `n8n/webhook-crystal-app.json`. Health 200, POST sem segredo 403. Formato definitivo depende da agência |
| Respostas da agência | Compute size do Supabase, dono da conta OpenRouter, quem monta a fase 1 |

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
