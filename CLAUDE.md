# Migração do crystalnowpp.com.br

Saída do site da AZAN (hospeda.info, cPanel `jupiter`) para a Hostinger, com o
Cloudflare na frente, em três degraus reversíveis. O plano completo, item a
item, está no artefato "Virada Cloudflare do Crystal" (link no README). A
situação mais recente está em `artefato/overview-2026-09-28.html` e em
`PROXIMOS-PASSOS.md`.

## Onde estamos (28/09/2026)

- **Degrau 1 feito** entre 18 e 22/09: NS no Cloudflare (`aldo`/`jule`), zona
  `c8f015c8ed7347f8900aa90d6701a15c` ativa, tudo cinza, valores iguais aos da
  AZAN. Certificado de borda ativo para apex e `*.`.
- **Degrau 2 não começou.** O apex ainda resolve `45.224.128.177` (AZAN).
- **Chamado #RAI-374885** aberto na AZAN em 28/09 para liberar os IPs do
  Cloudflare e ler `CF-Connecting-IP`. O laranja só entra depois da resposta.
- **Fatura AZAN**: mensal, R$ 99,90, próxima prevista para 14/10/2026. Não cancelar.
- **Frente paralela, o app da Crystal**: VPS Hostinger KVM 4 (`177.7.61.136`). Em 06/10:
  app em `sha-94a2648`: alma da agência (prompt v2.2 + busca na base do Supabase), login em
  lotes (`ROLLOUT_GATE`), login sem código (`LOGIN_CODIGO=nenhum`, modo de lançamento),
  webhook de reembolso da Assiny, painel de alunos no /equipe, legenda na foto;
  Chatwoot v4.18.0-ce em `atendimento.` com a Crystal como robô e o canal do app ligado
  (`CHAT_TRANSPORT=chatwoot`, 06/10 à noite), base de alunos no Supabase. Situação e roteiros em `crystal-em-casa/`.

## Primeira coisa a fazer numa sessão nova

1. Conferir quais variáveis existem (sem imprimir valores):
   `env | grep -E 'CLOUDFLARE|CPANEL|STAPE|WP_APP|SUPABASE|HOSTINGER' | sed 's/=.*//'`
2. Com `CLOUDFLARE_API_TOKEN`: `scripts/cloudflare-degrau2.sh foto` e depois
   `scripts/cloudflare-degrau2.sh preparar` (simulação). Mostrar o resultado e
   aplicar com `--aplicar`. Tudo em `preparar` só age com a nuvem laranja.
3. Registrar cada rodada em `auditorias/<data>/` e atualizar o overview.

## Regras que não mudam

- `server.crystalnowpp.com.br` (Stape, `35.199.71.234`) fica **sempre cinza**.
  Laranja nele derruba GTM, CAPI e o webhook de Purchase. `mail.` e `ftp.` também.
- **URL que responde 301 nunca recebe fbclid, utm ou gclid.** O LiteSpeed grava
  o 301 com a query de teste para todo mundo (aconteceu em 11/09).
- **Laranja só na janela 02:00–05:00 BRT**, com a vigia ligada e o time avisado.
  Rollback do degrau 2: `scripts/cloudflare-degrau2.sh cinza --aplicar`.
- Não mexer na zona da AZAN nem nos NS no Registro.br. Não seguir o "aponte
  seus DNS" da Hostinger nem ligar a integração Cloudflare do hPanel.
- Segredos só em variável de ambiente. Nunca em arquivo do repositório nem no chat.
- Não publicar nada no GTM: a migração não exige mudança lá.
- `painel.`, `editor.`, `webhook.`, `app.`, `api.` e `atendimento.` (VPS da Crystal) ficam
  **cinza** enquanto o Traefik emitir o certificado por HTTP. Laranja neles só
  depois da stack no ar, com decisão explícita. Não são a mesma Hostinger do
  site: é uma VPS, não o hPanel.
- Segredos do app na VPS (`/root/crystal/app/.segredos`): `ENCRYPTION_KEY`,
  `CPF_SALT` e `CRYSTAL_CHAVE_CIFRA` nunca mudam depois de o banco ter dado.
  O mesmo vale para o Chatwoot (`/root/crystal/atendimento/.segredos`):
  `SECRET_KEY_BASE` e as três `ACTIVE_RECORD_ENCRYPTION_*`.
- A nossa Crystal (`app_crystal`) não tem rota pública; a chave do OpenRouter vai só
  para o `crystal.env`, nunca para o `api.env`.

## Segurança sempre (pedido em 29/09)

Toda mudança leva em conta ataque e malware, sem precisar pedir:

- Segredo nunca no chat, no repositório, em URL ou em log. Vazou, troca.
- Menor privilégio: token só com o escopo necessário, chave `service_role` só no
  servidor, função SQL em vez de acesso à tabela, webhook sempre assinado.
- Superfície mínima na VPS: só 22, 80 e 443 abertas; nada de porta de banco ou do
  Docker exposta; painéis (Portainer, n8n) com senha forte e 2FA onde houver.
  `painel.` (Portainer) só para IPs liberados: `bootstrap-vps.sh painel-restringir`.
- Atualização de segurança automática e bloqueio de força bruta no SSH
  (`bootstrap-vps.sh seguranca`); imagens com versão fixa, nunca `latest`.
- Backup fora da VPS (ransomware apaga o que está na máquina): R2 cifrado com age,
  chave privada só no Bitwarden, trava de 30 dias no bucket (`backup-fora-config`).
- Entrada de fora é sempre validada; nada de `curl | bash` de origem que não seja
  este repositório com commit fixo.
- 2FA em todas as contas: GitHub, Hostinger, Cloudflare, Supabase, OpenRouter,
  Resend, Bitwarden.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| `scripts/auditoria-so-leitura.sh` | Auditoria só GET/DNS. Rodar de fora: o proxy deste ambiente retermina TLS |
| `scripts/cloudflare-degrau2.sh` | Degrau 2 inteiro, com simulação, backup antes de gravar e rollback |
| `scripts/cloudflare-crystal-vps-dns.sh` | DNS da VPS da Crystal (`painel`, `editor`, `webhook`, cinza). `conferir` roda sem token |
| `crystal-em-casa/` | Frente do app: guia e stacks da agência, situação da VPS |
| `crystal-em-casa/stacks-app/` | Stack do app web (`LFcrystal766/crystal-web-chat`) na VPS, subida pelo `bootstrap-vps.sh app-subir`, e o Portainer restrito (`painel-restringir`) |
| `crystal-em-casa/publicar-prd.md` | Roteiro de publicação das 3 etapas do PRD na VPS: comandos, tags, conferência em aparelho, volta |
| `crystal-em-casa/stacks-app/20-atendimento.yaml` | O nosso Chatwoot (no lugar do LendChat) em `atendimento.`, com a Crystal como robô: `atendimento-subir`, `atendimento-configurar`, `app-canal` |
| `auditorias/<data>/` | Evidências de cada rodada |
| `pedidos/` | Chamado da AZAN e prompt do Cowork |
| `artefato/` | Cópia do plano e o overview |

## O que existe fora deste repositório

As sessões "TASK-DNS-001" e "DNS-002" (18 a 21/09) fizeram o degrau 1 a partir
do MacBook, na pasta `hospedagem-crystal-dns` (6 scripts, linha de base de 45
páginas, commit `c437fa3`). Ela não está no GitHub. Se aparecer, conciliar com
`scripts/cloudflare-degrau2.sh` antes de usar os dois.
