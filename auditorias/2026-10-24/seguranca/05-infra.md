# Revisão de segurança 24/10/2026 · 05 · Infraestrutura, publicação e cadeia de suprimentos

Escopo desta parte: a VPS da Crystal como ela é montada pelo `crystal-em-casa/bootstrap-vps.sh`
(3442 linhas), as stacks do Swarm (`stacks-app/*.yaml`, `stacks-exemplo/*.yaml`), os scripts em
`scripts/`, os `Dockerfile` e os workflows do GitHub do app (`cw-custo-aluno`, commit `fe6dbd7`),
as dependências (`pnpm audit --prod`, lockfile) e o que os scripts de diagnóstico imprimem.

Como foi feito: só leitura. Nenhuma conexão com a VPS, com o GHCR nem com serviço externo além do
registro do npm (uma rodada de `pnpm audit`). Ferramentas: leitura dos arquivos, `grep`,
`shellcheck -S warning` (zero avisos nos quatro scripts) e `pnpm audit --prod` em 24/10. Nenhum valor
de segredo, chave ou dado pessoal aparece neste documento; onde foi preciso citar um segredo, cito só
o NOME da variável.

Repositório desta revisão: `hospedagem_em_transicao` em `854be1d`; app em `fe6dbd7`.

---

## 1. Resumo para o dono

**Contagem:** 0 críticos · 3 altos · 8 médios · 19 baixos (30 achados). A base está bem feita: a
maior parte das regras da casa (segredo nunca na tela nem na linha de comando, só 22/80/443 abertas,
backup cifrado fora da VPS com trava, painel só para IPs liberados, imagens sem `latest`) está
implementada de verdade no script, e não só escrita. Os problemas abaixo são de **manutenção e de
fronteira de confiança**, não de desenho.

**As três coisas para fazer primeiro:**

1. **Atualizar o Traefik (a "porta de entrada" da VPS).** Ele está na versão `v2.11.3`, de junho de
   2024. Depois dela a linha 2.11 recebeu correções de segurança, entre elas uma que permite
   contornar regras por caminho (`PathPrefix`) com `/../` na URL. Na nossa VPS a única proteção do
   console de super-administrador do Chatwoot (`/super_admin`) é exatamente uma regra dessas com
   lista de IPs. Em linguagem simples: a tranca da porta dos fundos tem um defeito conhecido e
   corrigido pelo fabricante; basta trocar a versão. A linha 2 do Traefik também está em fim de vida;
   o plano é ir para a 3.

2. **Trocar a chave `service_role` do Supabase que vazou em 06/10.** O próprio `PROXIMOS-PASSOS.md`
   registra que ela veio em texto puro na stack entregue pela agência e que a troca ficou pendente
   "combinando com o Tuan". Desde 09/10 não há mais agência, então não há mais o que combinar. Essa
   chave abre a base inteira de alunas, sem passar pelas regras de linha (RLS). Enquanto não for
   trocada e a antiga revogada, quem a tiver guardada entra. Mesma lógica para a chave do OpenRouter
   e o token do LendChat que estavam na mesma stack.

3. **Fechar três torneiras do n8n.** O n8n (automação de compra/reembolso) está público em `editor.`,
   protegido por senha, e hoje um usuário dele pode: ler as variáveis de ambiente do próprio n8n num
   nó de código (aí estão a chave de cifra das credenciais e a senha do banco), rodar comandos do
   sistema (nó "Execute Command") e instalar pacotes do npm de terceiros. São três linhas de
   configuração para desligar isso; o fluxo da Assiny continua funcionando.

**O que vem logo depois (médios):** os arquivos de stack que a VPS baixa vêm de uma *branch* do
GitHub, não de um commit fixo nem com conferência de hash (contraria a regra do `CLAUDE.md`); todos
os segredos do app ficam visíveis a quem abrir o Portainer ou rodar `docker service inspect`; todos
os serviços compartilham uma rede só (o banco do n8n fica na mesma rede que o app e o Chatwoot); a
API entra no Postgres como superusuário; há 4 dependências com correção disponível que o CI não
barra; as actions do GitHub não estão presas por SHA; o pnpm está numa versão que roda scripts de
instalação de qualquer pacote sem quarentena; e o SSH ainda aceita senha e login direto como root
(o script avisa, mas não trava).

**Sobre a exceção do zod (`docs/seguranca/audit-excecoes.md`):** a justificativa é correta no
essencial. O aviso é de esgotamento de memória com entrada gigante, e a entrada já é limitada antes
de chegar ao zod (1 MiB na API; 32 KiB na Crystal, com 8 MiB e 4 MiB em duas rotas autenticadas). Os
webhooks checam a assinatura antes de validar o corpo. Falta só: baixar o limite das rotas públicas
de login para poucos KiB (um login não precisa de 1 MiB) e dar prazo para a migração ao zod 4.

---

## 2. Tabela técnica

Gravidade: **crítico** (exploração direta, sem pré-condição) · **alto** (exploração plausível ou
dado sensível exposto a quem já tem um pé dentro) · **médio** (endurecimento que fecha um caminho
real) · **baixo** (higiene, defesa em profundidade, resíduo).

Caminhos: `bootstrap` = `crystal-em-casa/bootstrap-vps.sh`; `app/` = `/home/user/cw-custo-aluno`.

| id | gravidade | arquivo:linha | cenário | prova | correção proposta |
|---|---|---|---|---|---|
| INF-01 | **alto** | `crystal-em-casa/stacks-exemplo/00-traefik.yaml:30` (`image: traefik:v2.11.3`); `stacks-app/20-atendimento.yaml:85-93` (router `/super_admin` com `ipallowlist`); `bootstrap:216-237` (`docker-api` baixa o piso da API do Docker para 1.24 só para esse Traefik) | Proxy de borda com 16 meses sem atualização, exposto em 80/443. A linha 2.11 recebeu correções depois da 2.11.3 (entre elas CVE-2024-45410, manipulação de cabeçalhos `X-Forwarded-*` pelo cliente, e CVE-2025-32431, contorno de `PathPrefix`/`Path` com `/../` na URL, que permite alcançar um backend por outro router sem passar pela cadeia de middlewares). Na nossa stack, `/super_admin` do Chatwoot é protegido só por um router `PathPrefix` com lista de IPs; o router geral do mesmo Host não tem middleware. A v2 está em fim de vida. | Versão fixa no arquivo; `bootstrap:450` sobe esse arquivo sem mudar a imagem. Nenhum `tls.options`, nenhum middleware global. | Imediato: `image: traefik:v2.11.<última>` (conferir a última 2.11.x publicada; em 2025 já passava da 2.11.24) e `bash bootstrap-vps.sh traefik`. Planejar v3 (`traefik:v3.<última>`, trocar `--providers.docker.swarmMode=true` por `--providers.swarm.endpoint=unix:///var/run/docker.sock`, `--providers.docker.network` → `--providers.swarm.network`), o que dispensa o `docker-api`. Depois de atualizar, provar: `curl -sk -o /dev/null -w '%{http_code}' --path-as-is https://atendimento.crystalnowpp.com.br/x/../super_admin` tem de dar 403, não 200/302. |
| INF-02 | **alto** | `PROXIMOS-PASSOS.md:240-242` e `:247-252`, `:343`; `crystal-em-casa/stacks-app/30-crystal-ia.yaml` (comentário: a stack original trazia segredos inline); `bootstrap:1556-1557` (`SUPABASE_SERVICE_ROLE_KEY` vai para `crystal.env`) | Chave `service_role` do projeto Supabase do app (ignora RLS, executa as funções `app_*` da base de alunas) registrada como **vazada em 06/10** e com troca pendente "combinando com o Tuan". Não há registro de troca em `CONTINUAR-EM-OUTRA-CONTA.md`. Sem agência desde 09/10, a pendência não depende mais de ninguém. O mesmo vale para a chave do OpenRouter e o token do LendChat da mesma stack. | Texto dos dois documentos; `grep -n 'vazou' PROXIMOS-PASSOS.md`. Nenhum valor conferido aqui (e não deve ser). | Supabase > Settings > API: criar chave secreta nova (`sb_secret_…`); na VPS `bash bootstrap-vps.sh app-definir SUPABASE_SERVICE_ROLE_KEY` (cola sem eco; o script recusa anon/publicável) e `app-subir <tag atual>`; conferir `app-supabase-teste` 200; **revogar a antiga**; trocar a senha do Postgres do projeto; remover o Owner da agência da organização. OpenRouter: chave nova só da VPS (`crystal-nossa`), apagar a antiga. LendChat: token novo ou conta encerrada. Registrar as datas em `CONTINUAR-EM-OUTRA-CONTA.md`. |
| INF-03 | **alto** | `crystal-em-casa/stacks-exemplo/04-n8n-editor.yaml:133-135` (`N8N_COMMUNITY_PACKAGES_ENABLED=true`, `N8N_REINSTALL_MISSING_PACKAGES=true`), mesmas variáveis em `05-…` e `06-…`; ausência de `N8N_BLOCK_ENV_ACCESS_IN_NODE` e `NODES_EXCLUDE` (grep vazio nos quatro arquivos); `bootstrap:460` sobe os três | Editor do n8n público em `editor.` com senha. Qualquer conta do n8n (ou sessão roubada) pode, num nó Code, ler `process.env` (aí estão `N8N_ENCRYPTION_KEY`, `DB_POSTGRESDB_PASSWORD`, `QUEUE_BULL_REDIS_PASSWORD`), rodar comandos no contêiner (nó Execute Command) e instalar pacotes npm arbitrários (community packages). O n8n guarda a credencial do Supabase do fluxo `compra-assiny`. O contêiner está na mesma rede que `app_api`, `cw_rails`, Postgres e Redis do n8n (INF-06). | Variáveis do arquivo; padrão do n8n 1.x: `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`, nenhum nó excluído. | Nos três arquivos (04, 05, 06), acrescentar: `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`, `NODES_EXCLUDE=["n8n-nodes-base.executeCommand","n8n-nodes-base.readWriteFile","n8n-nodes-base.localFileTrigger"]`, `N8N_COMMUNITY_PACKAGES_ENABLED=false`, `N8N_REINSTALL_MISSING_PACKAGES=false`, `N8N_PUBLIC_API_DISABLED=true` (se a API pública do n8n não é usada). Exigir 2FA em todas as contas do n8n (Settings > Personal > Two-factor). Redeploy: `bash bootstrap-vps.sh preparar EMAIL && bash bootstrap-vps.sh n8n`. Opcional: `editor.` com `ipallowlist` como o `painel.` (o `webhook.` continua aberto). |
| INF-04 | médio | `bootstrap:174` (`REPO_RAW` padrão aponta para a branch `claude/gracious-shannon-6x9l5j`); downloads em `:252`, `:1061`, `:1760`, `:2981`, `:3266`; `app/.github/workflows/imagens-vps.yml:17` (a mesma branch gera as imagens de produção) | Os YAML das stacks e o fluxo do n8n são baixados de uma **branch mutável** do GitHub e aplicados como root (`docker stack deploy`), sem conferência de hash. Quem gravar nessa branch (conta do GitHub, token com `contents:write`, uma sessão de agente) muda o que a VPS sobe no próximo `app-subir`/`atendimento-subir`. Contraria a regra do `CLAUDE.md` ("nada de origem que não seja este repositório com commit fixo"). O cabeçalho do script pede `<commit>` só para o próprio script. | Única checagem é `grep -q '^services:'`. `sha256sum` só é usado para comparar a cópia do cron (`:635`, `:648`). | (1) `REF` padrão = SHA de 40 hex do commit revisado, e recusar `REF` que não case com `^[0-9a-f]{40}$`. (2) Tabela de hashes no próprio script e conferir após cada download: `echo "$SHA_ESPERADO  $ORIG/$a" \| sha256sum -c --quiet \|\| falha "…"`. (3) Preferir sempre a cópia local: clonar o repositório na VPS (`git -C /root/hospedagem_em_transicao fetch && git checkout <sha>`) e rodar `bash /root/hospedagem_em_transicao/crystal-em-casa/bootstrap-vps.sh` (o script já usa `$AQUI/stacks-app` quando existe). (4) Proteger a branch que gera imagem (branch protection, sem force-push) ou publicar só por tag `v*`. |
| INF-05 | médio | `crystal-em-casa/stacks-app/10-crystal-app.yaml:51,105,142,156` e `20-atendimento.yaml:47,101` (`env_file`); `bootstrap:1582-1628` (gera `api.env`, `crystal.env`) | No Swarm, `env_file` é lido pelo cliente e **embutido no spec do serviço** (`ContainerSpec.Env`). Resultado: `docker service inspect crystal_app_app_api`, a tela de serviço do Portainer e qualquer processo com o `docker.sock` (Traefik, agente do Portainer, n8n se comprometido) leem `ENCRYPTION_KEY`, `CPF_SALT`, `JWT_SECRET`, `OPENROUTER_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`. O cuidado com `chmod 600` nos arquivos não alcança o spec. | Comportamento documentado do `docker stack deploy`; os `.env` são lidos em `10-crystal-app.yaml`. | Mover os segredos de longa vida para **Docker secrets**: `printf '%s' "$(app_valor "$APP_SEG" ENCRYPTION_KEY)" \| docker secret create app_encryption_key -` (um por chave, versão no nome ao trocar); na stack, `secrets: [app_encryption_key, …]` e um `command` que exporta antes do `exec`: `sh -c 'for f in /run/secrets/app_*; do n=$(basename "$f" \| sed "s/^app_//" \| tr a-z A-Z); export "$n=$(cat "$f")"; done; exec pnpm --filter @crystal/api start'`. Mesmo molde para `crystal.env` e para `SECRET_KEY_BASE`/`ACTIVE_RECORD_*` do Chatwoot. Manter em `env_file` só o que não é segredo. Não ligar `--autolock` do Swarm: numa VPS de um operador só, os serviços não voltariam sozinhos após reboot. |
| INF-06 | médio | `stacks-exemplo/02-n8n-postgres.yaml:46`, `03-n8n-redis.yaml:42` (bancos do n8n em `network_swarm_public`); `10-crystal-app.yaml:108-109,165`; `20-atendimento.yaml:59-60,114-115`; `01-portainer.yaml:78` (`attachable: true`) | Uma rede só para tudo: Traefik, Portainer (UI), n8n (editor, webhook, worker, **Postgres e Redis**), `app_api`, `app_web`, `cw_rails`, `cw_sidekiq`, `crystal-ia`. Um contêiner comprometido fala direto com os outros, pulando o Traefik; falando direto com `app_api` ele é o "salto 0" confiado por `TRUST_PROXY=1`, então um `X-Forwarded-For` forjado passa a ser o IP registrado e usado no limite por IP do login (`routes/auth.ts:158`). O banco do n8n (com todas as credenciais cifradas) está alcançável de qualquer serviço. | Topologia dos arquivos; `parseTrustProxy` em `app/apps/api/src/app.ts:37-48`. | Segmentar: (a) `n8n_interno` (overlay) só para Postgres/Redis do n8n e os três serviços do n8n; (b) `crystal_borda` (overlay) para `app_web`, `app_api`, `cw_rails`, `cw_sidekiq`; (c) `network_swarm_public` fica só com Traefik + n8n editor/webhook + Portainer. O Traefik entra nas três redes (`networks:` do 00) e cada serviço mantém `traefik.docker.network=<sua rede>`. Tirar `attachable: true` do 01. Depois, `bootstrap-vps.sh painel-conferir` e um teste: do contêiner do n8n, `nc -zw2 app_api 3001` tem de falhar. |
| INF-07 | médio | `bootstrap:1584-1586` (`POSTGRES_USER=crystal`), `:1598` (`DATABASE_URL=postgresql://crystal:…`), `:2157-2166` (`crystal_banco`), `:554-557` (backup com `-U crystal`) | A API (e a migração do Prisma) conectam ao Postgres como `crystal`, que é o **superusuário** criado pela imagem oficial. Uma falha na API (injeção, RCE) vira `COPY … TO PROGRAM` dentro do contêiner do Postgres, leitura do banco `crystal_agente` (memória da Crystal) e de qualquer arquivo do contêiner. O `revoke connect … from public` de `:2165` não limita superusuário. | Imagem `postgres:16-alpine`: `POSTGRES_USER` é superusuário; nenhum `ALTER ROLE … NOSUPERUSER` no script. | Em `app_gerar_segredos`, gerar `APP_DB_ADMIN_SENHA`; em `crystal_banco`, antes do bloco atual: `do $$ begin if not exists (select from pg_roles where rolname='crystal_admin') then create role crystal_admin superuser login password '<APP_DB_ADMIN_SENHA>'; end if; end $$; alter role crystal nosuperuser nocreatedb nocreaterole noreplication nobypassrls;` (`crystal` continua dono de `crystal_web_chat`, o que basta para o `prisma migrate deploy`). Trocar `backup_pg "$cid" crystal crystal_agente` por `crystal_admin` e usar `crystal_admin` no `crystal_banco`. Passo seguinte (exige mudança no app): papel `app_api` só com DML e `MIGRATE_DATABASE_URL` separado. |
| INF-08 | médio | `app/package.json:21-26` (overrides `fast-uri@3: ^3.1.7`, `fast-uri@4: ^4.1.4`); `app/pnpm-lock.yaml` (resolvidos `fast-uri@3.1.8`, `fast-uri@4.2.1`, `fastify@5.12.5`); `app/.github/workflows/ci.yml:84` (`--audit-level=high`) | `pnpm audit --prod` em 24/10: **10 avisos** = 1 alto (zod, ignorado por exceção documentada), **4 moderados** (fast-uri: falsificação de esquema de URI GHSA-w74x-v6f9-j3xg; confusão de host GHSA-wjr9-j795-jxcr; corrigidos em 3.1.9 / 4.2.3) e 5 baixos (fast-uri GHSA-xhq7-xmqj-769h, GHSA-333x-w4r6-6crp; fastify GHSA-389g-gv7q-r4x8, validação de cabeçalho, corrigido em 5.12.6). Todos têm correção publicada e o CI não falha porque o limiar é `high`. fast-uri entra pela validação de esquema do Fastify (ajv), que roda em toda rota com schema. | Saída do `pnpm audit --prod --json` (sem tokens) resumida acima; `grep -n '^  fast-uri@' pnpm-lock.yaml`. | `pnpm up fastify@^5.12.6` e overrides `"fast-uri@3": "^3.1.9"`, `"fast-uri@4": "^4.2.3"`; `pnpm install` (lockfile novo), testes, imagem nova. No CI: `pnpm audit --prod --audit-level=moderate`. Rodar o audit também no `imagens-vps.yml` antes do build (hoje só o `ci.yml` roda). |
| INF-09 | médio | `app/.github/workflows/ci.yml:24,28,30,131`; `imagens-vps.yml:44,53,55,61`; `android-aab.yml:128,144,148,199`; `ios.yml:39,41`; `crystal-em-casa/ci/build-image.yml:63,65,70` | Actions de terceiros presas por tag maior (`actions/checkout@v4`, `pnpm/action-setup@v4`, `docker/build-push-action@v6`, `actions/setup-java@v4`…), não por SHA. Uma tag é móvel: comprometimento de uma dessas organizações (caso `tj-actions`, 03/2025) injeta código no job que publica as imagens de produção (`packages: write`) e no que assina o AAB (segredos da keystore em `env`). | `grep -n 'uses:' .github/workflows/*.yml` não mostra nenhum `@<sha40>`. | Pinar por SHA com comentário da versão (`actions/checkout@<sha> # v4.2.2`) e ligar o Dependabot para `github-actions` (`.github/dependabot.yml`, `package-ecosystem: github-actions`, `interval: weekly`). Em Settings > Actions > General: "Require actions to be pinned to a full-length commit SHA" quando disponível na conta. |
| INF-10 | médio | `app/package.json:7` (`"packageManager": "pnpm@9.15.9"`); `app/pnpm-workspace.yaml` (sem `minimumReleaseAge`/`onlyBuiltDependencies`); `apps/*/Dockerfile` (`corepack enable` segue essa versão) | pnpm 9 roda o script de instalação de **qualquer** dependência (34 pacotes com `requiresBuild`/`hasBin` no lockfile) e instala versão publicada há minutos. É o caminho das ondas de pacotes npm sequestrados de 2025 (Shai-Hulud e seguintes): um `postinstall` malicioso roda no CI (com `GITHUB_TOKEN`) e no build da imagem. | `packageManager` e ausência das chaves no `pnpm-workspace.yaml`. | Subir para `pnpm@10.<última>` (corepack acompanha) e no `pnpm-workspace.yaml`: `minimumReleaseAge: 10080` (7 dias de quarentena) e `onlyBuiltDependencies: [prisma, @prisma/client, @prisma/engines, sharp, esbuild, unrs-resolver]` (pnpm 10 bloqueia o resto e avisa quem ficou de fora). Conferir que `pnpm install --frozen-lockfile` continua verde nos três Dockerfiles. |
| INF-11 | médio | `bootstrap:995-1005` (`seguranca` só lê `sshd -T` e avisa); todo o script roda como root; `firewall:954` (`22/tcp` aberto para o mundo) | SSH aceita senha e login direto de root se o dono nunca tomou a "decisão" que o relatório pede. fail2ban (5 tentativas/10 min, 1 h) reduz força bruta, não elimina. Com `passwordauthentication yes`, um vazamento de senha do root da Hostinger é a VPS inteira. | Texto dos avisos em `:999-1005`; nenhum `sshd_config.d` escrito pelo script. | Depois de confirmar que a chave entra: `cat > /etc/ssh/sshd_config.d/10-crystal.conf <<'C'\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitRootLogin prohibit-password\nMaxAuthTries 3\nC` e `sshd -t && systemctl reload ssh`. Encapsular isso em `bash bootstrap-vps.sh seguranca --travar-ssh` (recusar sem `-t 0` e sem `~/.ssh/authorized_keys` não vazio). Opcional: limitar 22 à faixa do operador no ufw (`ufw allow from <ip>/32 to any port 22`) mantendo o Web console da Hostinger como porta de emergência. |
| INF-12 | baixo | `stacks-app/10-crystal-app.yaml:70-75` (`redis-server` sem `--requirepass`); `bootstrap:1599` (`REDIS_URL=redis://app_redis:6379`) | Redis do app (sessões, janela de refresh, limites de taxa) sem senha na rede `app_interno`, que `app_crystal` também usa. A Crystal processa saída de modelo e fala com OpenRouter/Supabase: um SSRF ou RCE nela vira acesso de escrita às sessões e aos contadores de limite. O Chatwoot (`20-atendimento.yaml:154-159`) já faz certo. | Comparação entre as duas stacks. | Em `app_gerar_segredos`: `APP_REDIS_SENHA=$(openssl rand -hex 24)`; `redis.env` com `REDIS_PASSWORD`; serviço `app_redis` com `env_file` e `command: ["sh","-c","exec redis-server --appendonly yes --maxmemory-policy noeviction --requirepass \"$$REDIS_PASSWORD\""]`; healthcheck com `REDISCLI_AUTH`; `REDIS_URL=redis://:<senha>@app_redis:6379` no `api.env`. |
| INF-13 | baixo | `app/docs/seguranca/audit-excecoes.md`; `app/package.json:27-31` (`ignoreGhsas`); `apps/api/src/app.ts:116` (`bodyLimit` 1 MiB); `apps/crystal/src/app.ts:314` (32 KiB), `:105` (8 MiB em `/v1/messages`), `:164` (4 MiB em `/v1/contacts/importar`); `routes/auth.ts:259-260` | Exceção do zod (GHSA-mrhx-c7xc-m3w5, esgotamento de memória com entrada gigante, sem correção na linha 3). A justificativa é **válida**: a entrada é limitada antes do zod e os webhooks verificam bearer/HMAC antes do `safeParse` (`refund-webhook.ts:116-123`, `chatwoot-bot.ts:380-395`, `channel-webhook.ts:60-76`). Pontos frouxos: as rotas públicas de login/refresh herdam 1 MiB (um login tem dezenas de bytes); as rotas de 8 e 4 MiB da Crystal dependem só da chave compartilhada com a API; não há prazo para a migração ao zod 4. | Leitura dos limites e da ordem de verificação. | `app.post("/auth/login", { preHandler: [loginLimits], bodyLimit: 16 * 1024 }, …)` e o mesmo em `/auth/refresh`, `/auth/logout` (16 KiB). Na Crystal, manter 8/4 MiB mas acrescentar à exceção a frase "rotas autenticadas por chave compartilhada, só alcançáveis de `app_api`". Dar data à saída da exceção (ex.: zod 4 na onda seguinte) e revisar a linha a cada `pnpm audit` do CI. |
| INF-14 | baixo | `stacks-app/10-crystal-app.yaml:51` (`postgres:16-alpine`), `:70` (`redis:7-alpine`); `stacks-exemplo/02:42` (`postgres:16`), `03:34` (`redis:7`); `bootstrap:1664` (`alpine:3.20`); `apps/*/Dockerfile:1` (`node:22-alpine`) | Tags flutuantes dentro da versão maior. O Swarm resolve o digest no deploy, então a surpresa vem no próximo `app-subir`: Postgres/Redis trocam de patch sem ninguém decidir. O Chatwoot já pina (`redis:7.4.11-alpine`, `pgvector:0.8.7-pg16`). Regra da casa: "imagens com versão fixa". | Linhas citadas. | Fixar patch: `postgres:16.<x>-alpine`, `redis:7.4.<x>-alpine` (ou `@sha256:`), `alpine:3.20.<x>`; nos Dockerfiles `node:22.<x>-alpine`. Anotar no cabeçalho de cada arquivo a data e a razão da versão, como já se faz com `CW_VERSAO`. |
| INF-15 | baixo | `stacks-app/10-crystal-app.yaml:103-134` (`app_api`), `:142-160` (`app_crystal`), `:163-195` (`app_web`) | Sem `read_only: true`, `cap_drop` nem `tmpfs`: um RCE grava no sistema de arquivos do contêiner (código em `/app` é do root, mas `/tmp`, `/home/node` e o cache do Next ficam graváveis) e mantém todas as capabilities padrão. | Ausência das chaves; `USER node`/`nextjs` já existe nos Dockerfiles. | Em cada um dos três serviços: `read_only: true`, `cap_drop: [ALL]`, `tmpfs: [/tmp]`; no `app_web` também `tmpfs: [/app/apps/web/.next/cache]`; `app_api` mantém o volume `app_uploads` gravável. Testar `healthz` e upload de imagem depois. |
| INF-16 | baixo | `app/apps/api/Dockerfile:12,33` (instala devDependencies e roda `tsx src/server.ts` em produção); `apps/api/package.json:8` (`"start": "tsx src/server.ts"`); `apps/crystal/Dockerfile:9,22` | A imagem de produção carrega `vitest`, `typescript`, `prisma` CLI, `tsx` e compila TypeScript a cada boot. Mais pacotes = mais superfície e mais tempo de boot; o `tsx` dispensa build, mas qualquer dependência de desenvolvimento vulnerável também vai para a VPS. | `pnpm install --frozen-lockfile --filter @crystal/api...` sem `--prod`. | Estágio `builder` com `tsc -p apps/api` para `dist/`, estágio `runner` com `pnpm install --prod --frozen-lockfile --filter @crystal/api...` e `CMD ["node","apps/api/dist/server.js"]`; manter `prisma` só se a migração continuar na mesma imagem (ou serviço `migrate` separado com a imagem completa). Mesmo molde para `apps/crystal`. |
| INF-17 | baixo | `app/.github/workflows/imagens-vps.yml:17,62` (`push` em branches de trabalho; `provenance: false`); `bootstrap:1728-1731` (`app-subir` aceita qualquer `sha-xxxxxxx` que exista no ghcr) | Toda `push` em `claude/gracious-shannon-6x9l5j`, `otimizacao/etapa-*` e `painel/onda4*` publica imagem com `packages: write`; nada de atestado de proveniência, SBOM ou assinatura; a VPS não confere de onde a tag veio. | Arquivo do workflow. | `provenance: mode=max`, `sbom: true` no `build-push-action`; `actions/attest-build-provenance` (ou `cosign sign` com OIDC) e, em `app-subir`, `docker buildx imagetools inspect ghcr.io/…:TAG --format '{{json .Manifest.Digest}}'` para pinar `image@sha256` no YAML gravado; produção só por tag `v*` quando a cobrança do GitHub voltar. |
| INF-18 | baixo | `bootstrap:470` (`FORA_DEST`, chave pública do age em arquivo), `:714-716` (`dest=$(cat "$FORA_DEST")`), `:900-925` (`backup-conferir` só olha data e tamanho) | A chave pública que cifra os backups mora na VPS e pode ser trocada por quem controlar a máquina; a partir daí os backups subiriam cifrados para outra chave e ninguém perceberia (o `backup-conferir` passa). O token do R2 na VPS lista o bucket (nomes revelam bancos e datas). | Lógica do script; a trava do bucket protege contra apagar/sobrescrever, não contra "cifrar para o atacante". | Gravar a impressão esperada no script (`FORA_DEST_ESPERADO=age1…`, só a pública) e falhar no `backup_fora` se `cat "$FORA_DEST"` divergir; mostrar o `age1…` no `status` e no alerta mensal da vigia para o dono comparar com o Bitwarden; teste de restauração trimestral com `backup-link` (abrir um dump com a chave do Bitwarden); token do R2 com escopo só no bucket `crystal-backups`. |
| INF-19 | baixo | `bootstrap:481-520, 521-620` (dumps `.sql.gz` e `.tar.gz` em claro em `/root/crystal/backups`, 14 dias) | Cópia em claro dos bancos (alunas, mensagens, Chatwoot) e das fotos fica 14 dias no disco da VPS. Mesmo com `chmod 700`, um snapshot do disco ou um atacante com root leva tudo pronto. | `:530-531` e política de retenção em `:620` (ler o `find -mtime`). | Cifrar local também: logo após gerar cada arquivo, `age -r "$dest" -o "$arq.age" "$arq" && rm -f "$arq"`; manter em claro só o do dia (para `recomecar`); restauração local pede a chave do Bitwarden, o que é aceitável para um evento raro. |
| INF-20 | baixo | `stacks-exemplo/00-traefik.yaml:73-76` (`--log.filePath` e `--accesslog.filepath` dentro do contêiner, sem volume e sem rotação) | Log de acesso com IP de cada visita cresce sem limite na camada gravável do contêiner (até o próximo redeploy) e sem prazo de retenção, o que contraria a rotação já feita nas outras stacks (achado 27) e a LGPD (dado pessoal sem prazo). | Sem `logging:` no serviço e sem `--accesslog.filters`/`fields`. | Tirar `--log.filePath` e `--accesslog.filepath` (vai para stdout), acrescentar `logging: {driver: json-file, options: {max-size: "10m", max-file: "3"}}` e `--accesslog.fields.names.ClientHost=redact` (ou `--accesslog.fields.names.ClientAddr=drop`) se o IP não é necessário; `--accesslog.filters.statuscodes=400-599` reduz volume. Ajustar `status()` em `bootstrap:1180-1187`, que lê o arquivo dentro do contêiner. |
| INF-21 | baixo | `stacks-exemplo/00-traefik.yaml:33-66` (sem `tls.options`, sem middleware de cabeçalhos no entrypoint); HSTS só em `01-portainer-restrito.yaml:72`, no helmet da API e no `next.config.ts:38` | Versão mínima de TLS e cifras ficam no padrão do Go com que a imagem foi compilada; `atendimento.` (Chatwoot) sai sem HSTS e sem `X-Content-Type-Options`; cada app cuida dos seus cabeçalhos, sem rede de segurança na borda. | Ausência das opções; `FORCE_SSL=false` no Chatwoot (`bootstrap:2924`). | Provedor de arquivo no Traefik: `--providers.file.filename=/etc/traefik/dinamico.yml` (montado do `/root/crystal/stacks/traefik-dinamico.yml`) com `tls.options.default.minVersion: VersionTLS12`, `sniStrict: true`, e middleware `seguranca-cabecalhos` (`stsSeconds: 31536000`, `stsIncludeSubdomains: true`, `contentTypeNosniff: true`, `browserXssFilter: false`, `referrerPolicy: strict-origin-when-cross-origin`) aplicado globalmente com `--entrypoints.websecure.http.middlewares=seguranca-cabecalhos@file`. Conferir que o `/.well-known` do app continua respondendo. |
| INF-22 | baixo | `stacks-exemplo/00-traefik.yaml:81` (`docker.sock:ro`); `stacks-app/01-portainer-restrito.yaml:41-42` (agente com `docker.sock` e `/var/lib/docker/volumes`, necessário) | O `:ro` no socket não limita a API do Docker: um RCE no Traefik (processo exposto à internet) é root no host. O agente do Portainer precisa do socket; o Traefik só precisa ler serviços/redes. | Montagens dos arquivos. | Para o Traefik, `tecnativa/docker-socket-proxy` (pinado) na rede `portainer_agentes`-like, com `SERVICES=1 NETWORKS=1 TASKS=1 NODES=1 POST=0`, e `--providers.docker.endpoint=tcp://docker_proxy:2375`. O agente do Portainer fica como está (já isolado em rede interna). |
| INF-23 | baixo | `scripts/cloudflare-degrau2.sh:71-74`; `scripts/cloudflare-crystal-vps-dns.sh:52-56` (`-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"` na linha de comando) | O token da zona do Cloudflare aparece em `ps`/`/proc` da máquina onde o script roda (sandbox compartilhada, Mac com outros usuários). O `bootstrap` resolve isso com `curl -K -`; estes dois scripts não. | Linhas citadas. | `api() { printf 'header = "Authorization: Bearer %s"\n' "$CLOUDFLARE_API_TOKEN" \| curl -sS -m 40 -K - -X "$m" "$API$p" -H 'Content-Type: application/json' ${b:+--data "$b"}; }` (ou `-H @arquivo` com `umask 077`). Mesmo ajuste na chamada GraphQL de `cmd_saude` (`:447`). |
| INF-24 | baixo | `app/docker-compose.yml:8-9,17` (`"5432:5432"`, `"6379:6379"`, senha `crystal`) | Compose de desenvolvimento publica Postgres e Redis em todas as interfaces com senha trivial; num notebook em rede pública, qualquer um na mesma rede entra. Não é produção, mas o banco local pode ter dados reais importados. | Linhas citadas. | `"127.0.0.1:5432:5432"` e `"127.0.0.1:6379:6379"`; comentar que a senha é só local. |
| INF-25 | baixo | Máquina desta sessão: `/tmp/n8n-teste` (1,7 GB, `node_modules` + `install.log`, 09/10), 37 perfis `/tmp/playwright_chromiumdev_profile-*` (256 KB), `/tmp/playwright-transform-cache-0` (15 MB), `/tmp/e2e-full.log` e `/tmp/e2e-old.log` (20/10) | Resíduos de testes e2e e de um n8n instalado para teste fora do repositório. Conferido: os logs têm só nomes de testes e dados de demonstração (`DEMO_SEED`, contas `.test`); nenhum token, cookie, e-mail real ou `.env`. O `e2e/web-server.sh` limpa `crystal-e2e-web.*` corretamente (zero sobras). | Contagens por padrão (`token=0`, `secret=0`, `cookie=0`, nenhum e-mail), listagem de diretórios. | `rm -rf /tmp/n8n-teste /tmp/playwright_chromiumdev_profile-* /tmp/playwright-transform-cache-0 /tmp/e2e-*.log`; instalar coisas de teste no scratchpad da sessão, não em `/tmp`. |
| INF-26 | baixo | `auditorias/2026-10-23/diag-vazamento.sh:5-6` (campos `msg`/`err` dos logs), `:9` (lê `/root/diag-vazamento.sql` fora do repositório); `diag-laboratorio.sh:14-17`; `scripts/auditoria-so-leitura.sh:171-172` (grava `/wp-json/wp/v2/users` e RDAP em `auditorias/<data>/evidencias/`) | Os três diagnósticos imprimem só contagens, códigos, modelos e URLs sem query: bom. Risco residual: `msg`/`err` são texto livre; se um log passar a incluir trecho de conversa ou um erro do zod com o valor recebido, ele vai para a tela e para o chat. As evidências do WordPress guardam nomes de usuários do site (dado pessoal, embora público) e o RDAP no repositório. | Leitura dos scripts e dos `.sql` (só `uso_turnos`, agregados). | Em `diag-vazamento.sh`, limitar `err` a `cut -c1-60` e excluir `msg` quando não casar com um conjunto fechado de mensagens conhecidas; copiar `diag-vazamento.sql` para o repositório (já há `auditorias/2026-10-23/diag-vazamento.sql`; usar esse caminho). Em `auditoria-so-leitura.sh`, guardar só `id` e `slug` dos usuários (tirar `name`) e não versionar `rdap.json`. |
| INF-27 | baixo | `bootstrap:2155-2166` (`crystal_banco`: `create role … password '$senha'` em texto SQL) | A senha vai por stdin (bem), mas dentro da instrução SQL. Se a instrução falhar, o Postgres grava a instrução inteira no log do contêiner (`log_min_error_statement=error`, padrão), com a senha. | Padrão do Postgres. | Abrir a sessão com `set local log_statement = 'none'; set local log_min_error_statement = 'panic';` dentro de uma transação antes do `do $$ … $$` (exige superusuário: usar `crystal_admin` de INF-07). |
| INF-28 | baixo | `bootstrap:216-237` (`docker_api` só grava `min-api-version`); nenhum `no-new-privileges`, `log-opts` ou `userns-remap` no `daemon.json`; stacks 00/01/02-06 sem `logging:` | Padrões do daemon: contêineres podem ganhar privilégio via setuid, logs `json-file` sem limite nas stacks que não têm `logging:` (Traefik, Portainer, n8n). | Leitura da função e dos YAML. | No `docker_api` (renomear para `docker-daemon`): acrescentar `"no-new-privileges": true` e `"log-opts": {"max-size": "10m", "max-file": "3"}` ao `daemon.json`; `logging:` com rotação em 00, 01, 02-06, como já há em 10 e 20. |
| INF-29 | baixo | `bootstrap:1304-1314` (`app_ghcr`: `docker login` guarda o PAT em `/root/.docker/config.json`, base64, sem credential helper); `imagens-vps.yml` publica imagens privadas | Token pessoal do GitHub com `read:packages` em claro (base64) no disco da VPS, possivelmente sem validade. Quem ler o arquivo baixa as imagens (código do app). | Comentário do próprio script em `:1313`. | PAT com validade de 90 dias e só `read:packages`, calendário de troca (ou conta-robô dedicada); `chmod 600 /root/.docker/config.json` conferido pelo `seguranca`; considerar `docker-credential-pass` se o operador aceitar o custo. |
| INF-30 | baixo | `stacks-app/30-crystal-ia.yaml:10-13` (um só `crystal-ia.env` com `SUPABASE_SERVICE_KEY`, `LENDCHAT_API_TOKEN`, `OPENROUTER_API_KEY` no serviço público `ia.`), `:209-211` (Redis sem senha) | A Crystal do WhatsApp (stack da agência) carrega a chave `service_role` e os tokens do LendChat na API pública; vai ser encerrada ("todo mundo vai para o app"). Enquanto estiver no ar ou o `.env` existir, é mais um lugar onde a chave de INF-02 mora. | Cabeçalho e `env_file` do arquivo. | Ao encerrar: `docker stack rm crystal_ia`, `shred -u /root/crystal/app/crystal-ia.env`, apagar o registro DNS `ia.` (cinza) e **revogar** as chaves que ela usou (ver INF-02). Se continuar temporariamente: `--requirepass` no Redis e `logging:` com rotação. |

---

## 3. O que está certo

Vale registrar, porque é o que sustenta a nota geral e não deve ser desfeito em correções futuras.

**Rede e portas**
- Só o Traefik publica porta (80 e 443, `mode: host`, IP real preservado); `firewall` fecha o resto
  com ufw e `portas_docker_conferir` (`bootstrap:930-945`) denuncia qualquer porta que o Docker
  publique por cima do ufw, nas três telas (`firewall`, `seguranca`, `status`).
- Postgres e Redis do app e do Chatwoot em redes internas próprias; Redis do Chatwoot com senha;
  Redis do n8n ganhou senha que o original da agência não tinha (`bootstrap:277-283`, `291-293`),
  com conferência de que o `sed` pegou (`:296-299`).
- Portainer restrito (`01-portainer-restrito.yaml`): `ipallowlist` no Traefik, agente numa rede
  `internal: true` só dele, imagens presas por digest, sem `priority=1`, cabeçalhos de segurança;
  `status()` confere a trava **no serviço em execução**, não só no arquivo (`:1174-1183`);
  `painel_conferir` prova que o n8n não alcança mais a porta 9001 (`:1121-1128`).
- Traefik com `exposedbydefault=false`, painel sem rota pública, redirecionamento HTTP→HTTPS,
  certificados por ACME HTTP com DNS cinza (regra documentada e respeitada nos scripts do Cloudflare,
  que forçam `proxied=false` em `server.`, `mail.` e `ftp.` após cada gravação).

**Segredos no `bootstrap-vps.sh`**
- Gerados com `openssl rand`, gravados com `umask 077` + `chmod 600` em pastas `700`, nunca
  regenerados (`ENCRYPTION_KEY`, `CPF_SALT`, `CRYSTAL_CHAVE_CIFRA`, `SECRET_KEY_BASE`,
  `ACTIVE_RECORD_ENCRYPTION_*`), com cópia antes de qualquer `recomecar` e trava real contra apagar
  banco com alunas (`:2085-2092`).
- Nunca na linha de comando: `read -rsp` para colar, `curl -K -` para credenciais do R2, do
  Telegram e do Supabase, `docker login --password-stdin`, `GIT_CONFIG_*` para o token do GitHub
  no `app-construir`, `docker exec -e NOME` para o CPF do admin, heredoc para SQL, `-e` no
  `rails runner` do Chatwoot. `app-definir` recusa qualquer coisa que não pareça um NOME e não
  repete o que foi digitado (achado 70), valida o formato de cada valor e barra a chave anon/publicável
  do Supabase (`:1352-1372`).
- Exibição só em `less -K` com TTY (`segredos`, `app-segredos`, `atendimento-segredos`,
  `app-revisao`, senha do Chatwoot); fora de terminal, falha em vez de imprimir (achado 70).
- `app_env_preflight` valida o `api.env` novo num contêiner sem rede antes do deploy, mostrando só
  nomes e motivos (`:1803-1817`).
- Chave privada do age nunca toca o disco: aparece uma vez no `less`, o dono digita os 6 últimos
  caracteres lendo do Bitwarden, só então a pública é gravada (`:735-771`).

**Backup e vigilância**
- Cifrado com age para chave pública, enviado ao R2 com assinatura S3 v4 pelo próprio curl;
  `backup-testar-trava` só aceita a prova completa (DELETE 403 **e** HEAD 200) e trata 5xx/429 como
  inconclusivo (achado 69); configuração nova só substitui a antiga depois de um envio de teste
  passar (achado 23).
- Cron em `/etc/cron.d`, rodando uma cópia do script trocada por `mv` atômico e conferida por
  sha256 (`:627-651`); vigia a cada 5 min com alertas de backup atrasado (26 h), falha registrada,
  cópia no R2 atrasada, disco ≥ 85 %, réplicas caídas e falhas da API, sem repetir o mesmo alerta por
  1 h.
- `backup` segue mesmo quando uma parte falha, registra o que falhou e sai 1; prioridade baixa de
  CPU/disco (`nice`/`ionice`); tar incremental para as fotos.

**Máquina**
- `seguranca`: `unattended-upgrades` (sem reboot automático), fail2ban no sshd via systemd, relatório
  de senha/root/portas/pendências; `docker-api` valida o `daemon.json` antes de reiniciar.

**Imagens e stacks do app**
- `USER node`/`nextjs` nas três imagens; volume de uploads entregue ao uid 1000 antes do deploy;
  `--frozen-lockfile`; build do web falha sem `NEXT_PUBLIC_API_URL` e com regex incompatível com
  Safari antigo; standalone do Next sem o monorepo inteiro.
- Stack: healthchecks em tudo, limites de CPU e memória, rotação de log, `update_config` com
  `failure_action: rollback`, `stop-first` para quem migra banco, uma réplica para a API (migração
  única), `restart_policy` sem `max_attempts` (achado 28); `app_conferir_troca` detecta rollback
  silencioso do Swarm mesmo com a mesma tag (achado 4); tags `sha-…`/`v*`, nunca `latest`; a nossa
  Crystal sem rota pública e com a chave do OpenRouter só no `crystal.env`.
- Chatwoot: `ENABLE_ACCOUNT_SIGNUP=false`, `DISABLE_TELEMETRY=true`, `ENABLE_PUSH_RELAY_SERVER=false`,
  `/super_admin` restrito por IP (até INF-01 ser corrigido), banco com `scram-sha-256`.

**Cadeia de suprimentos**
- `pnpm-lock.yaml`: 547 pacotes, todos com `integrity: sha512`, todos do `registry.npmjs.org`,
  nenhum `git+`/`tarball`/`http`. `sharp` pinado em `0.35.5` por override (binário musl pré-compilado
  no Alpine). Nenhuma string com formato de segredo (OpenRouter, Resend, JWT do Supabase, `sb_secret_`,
  age, PAT do GitHub, AWS, chave privada PEM, Slack, bot do Telegram) nos dois repositórios fora de
  `node_modules`.
- Workflows: `permissions:` mínimo em todos (`contents: read`; `packages: write` só onde publica),
  gatilho `pull_request` (nunca `pull_request_target`), `GITHUB_TOKEN` para o GHCR em vez de PAT,
  entrada manual validada por regex e passada por `env` (`build-image.yml`, `android-aab.yml`),
  `GoogleService-Info.plist` apagado após o build do iOS, `concurrency` que não cancela publicação
  de imagem.
- `.gitignore`/`.dockerignore` cobrem `.env*`, keystores, `*.p8/.p12`, `google-services.json`,
  `uploads/`, `test-results/`.

**Aplicação (o que a borda não precisa compensar)**
- API: `@fastify/helmet` (CSP `default-src 'none'`, `frame-ancestors 'none'`), CORS só para
  `WEB_ORIGIN` com métodos explícitos, `trustProxy` com um salto (correto para o Traefik em
  `mode: host`), `bodyLimit` 1 MiB, multipart 10 MiB/1 arquivo, `authorization` e `cookie` redigidos
  no log, IP truncado no log (achado 27), erro 500 sem stack, webhooks verificados antes do parse.
- Web: CSP com nonce por requisição (`middleware.ts`), HSTS 2 anos, `nosniff`, `Referrer-Policy`,
  `Permissions-Policy`.

**Scripts de diagnóstico de 23/10**: só contagens, códigos, modelos e URLs sem query; SQL só sobre
`uso_turnos` agregado; chamadas à API sem sessão (401/404 esperados). Nenhum dado de aluna sai deles.

---

## 4. Ordem sugerida de correção

1. INF-01 (Traefik) e INF-02 (chave do Supabase): uma tarde, janela de madrugada para o Traefik.
2. INF-03 (n8n) e INF-11 (SSH): três linhas de ambiente e um `sshd_config.d`; redeploy do n8n.
3. INF-04, INF-08, INF-09, INF-10: higiene da cadeia de suprimentos, tudo no repositório, sem
   mexer na VPS além de um `app-subir` com a imagem nova.
4. INF-05, INF-06, INF-07, INF-12: endurecimento do Swarm (segredos, redes, papel do banco, Redis);
   planejar como uma "onda de infra" com `backup` antes e roteiro de volta.
5. Baixos restantes conforme as sessões tocarem em cada arquivo.
