# Revisão CI / Docker / Mobile / E2E / scripts / docs das lojas

Repositório: `/home/user/crystal-web-chat`, branch `claude/gracious-shannon-6x9l5j`,
commit `44f356b`. Data: 2026-10-02. Revisão linha a linha, só leitura: nada foi
modificado no repositório.

Ferramentas: `yamllint` **não está instalado** neste ambiente (pulado); os quatro
workflows foram carregados com `yaml.safe_load` (sintaxe OK). `twa-manifest.json`,
`capacitor.config.json`, `manifest.webmanifest`, os `Contents.json` e os
`package.json` passaram no `json.load`; `Info.plist`, `App.entitlements` e
`IDEWorkspaceChecks.plist` passaram no `plistlib.load` (python 3.11).

Contagem no fim do documento.

---

## Resumo por gravidade

| Gravidade | Qtde |
|---|---|
| Crítico | 0 |
| Alto | 4 |
| Médio | 10 |
| Baixo | 22 |
| Observação | 9 |

---

## 1. CI (`.github/workflows/`)

### A1. `ci.yml:99` — **alto** — E2E nunca quebra o build
`continue-on-error: true` no job `e2e`. Qualquer falha de Playwright (jornada,
login, a11y, conta de revisão) fica verde no PR. O `e2e/README.md:82` e o
`a11y.spec.ts:5` prometem que violações sérias "quebram o build": não quebram.
Combinado com `retries: 1` (`playwright.config.ts:25`), a suíte hoje não é gate.
Correção: remover `continue-on-error`; se houver teste instável, isolar com
`test.fixme`/`test.skip` com motivo, nunca o job inteiro.

### M1. `ci.yml:24,28,30,132`; `imagens-vps.yml:42,53,55,61`; `android-aab.yml:58,74,78,129`; `ios.yml:39,41` — **médio** — actions por tag móvel
Todas as actions estão em `@v3`/`@v4`/`@v6` (tag que o autor pode mover), não por
SHA. Nenhuma está em `@main` (bom), mas a regra "versões fixadas" não é cumprida
na cadeia de suprimento do CI, que tem acesso à chave de envio Android, ao
`GITHUB_TOKEN` com `packages: write` e ao plist do Firebase.
Correção: fixar por SHA com a versão em comentário
(`uses: actions/checkout@<sha> # v4.2.2`) e deixar o Dependabot atualizar.

### M2. `.github/` — **médio** — sem Dependabot/Renovate
Não existe `.github/dependabot.yml`. Actions, imagens base, as deps npm da raiz
(pnpm) e os dois diretórios npm fora do workspace (`apps/mobile/android-twa/gerador`,
`apps/mobile/ios-capacitor`) só são atualizados à mão; o `pnpm audit` do CI
(`ci.yml:94`) avisa depois que o CVE já saiu e não olha os diretórios npm.
Correção: `dependabot.yml` com ecossistemas `github-actions`, `docker`, `npm`
(raiz, `gerador/`, `ios-capacitor/`), agrupando atualizações menores.

### M3. `imagens-vps.yml:16-19` — **médio** — imagem de produção sai sem o CI ter passado, a partir de uma branch de trabalho
O workflow publica em `ghcr.io` em todo push na branch `claude/gracious-shannon-6x9l5j`
e em tag `v*`, de forma independente do `ci.yml` (sem `needs`, sem `workflow_run`).
Um commit que quebra typecheck/testes gera imagem `sha-XXXXXXX` publicável na
stack. Além disso a origem é uma branch de sessão, não `main`: se ela for
renomeada ou apagada, nada mais publica.
Correção: publicar só em tag `v*` (ou em `main`) e condicionar ao CI verde
(`workflow_run` com `conclusion == 'success'`, ou um único workflow com `needs: gate`).

### B1. `ci.yml:20-72, 74-94` — **baixo** — sem `timeout-minutes`
Jobs `gate` e `audit` usam o padrão de 360 min; um teste travado consome a cota.
Correção: `timeout-minutes: 20` nos dois (o `e2e` e os mobile já têm).

### B2. `ci.yml:94` — **baixo** — `pnpm audit --audit-level=high` sem válvula de escape
Um CVE "high" sem correção publicada bloqueia o CI sem saída, e o audit não cobre
`gerador/` nem `ios-capacitor/` (npm). Hoje o resultado local é "No known
vulnerabilities found".
Correção: `npm audit --omit=dev` nos dois diretórios npm (ou Dependabot) e
documentar o procedimento para CVE sem fix (`pnpm audit --ignore`/`overrides`,
como já é feito em `package.json:18-25`).

### B3. `imagens-vps.yml:61-76` — **baixo** — sem varredura da imagem; `provenance: false`
Nada roda Trivy/Grype antes do push; `provenance: false` desliga a atestação do
buildx (a stack tampouco verifica assinatura, então hoje é coerente).
Correção: passo `aquasecurity/trivy-action` (fixado por SHA) com `exit-code: 1`
para CRITICAL/HIGH com correção; avaliar `cosign` quando a stack puder verificar.

### B4. `android-aab.yml:116-127` — **baixo** — keystore fica no runner se o `jarsigner` falhar
O `rm -f "$RUNNER_TEMP/upload.jks"` é a última linha; com `bash -e` (padrão do
`run`), falha no `jarsigner`/`keytool` pula o `rm`. O runner é efêmero, então o
risco é baixo, mas a intenção ("segredo só no passo de assinatura") não se cumpre.
Correção: `trap 'rm -f "$RUNNER_TEMP/upload.jks"' EXIT` logo depois do `umask 077`.

### M7. `android-aab.yml:69` e `android-twa/README.md:19` — **médio** — `versionCode` = `GITHUB_RUN_NUMBER` sem garantia de só subir
O contador é por arquivo de workflow: renomear/recriar `android-aab.yml`, migrar o
repositório ou mover o workflow para outro repositório zera o número, e a Play
recusa `versionCode` menor que o último enviado. Pushes na branch (build sem
assinatura) também consomem números, o que é inofensivo mas confuso.
Correção: guardar o último enviado em variável de repositório
(`vars.ANDROID_LAST_VERSION_CODE`) e falhar se `VC <= último`; ou derivar do
tempo (`date +%y%m%d%H` cabe em 2.100.000.000 até 2099).

### B5. `android-aab.yml:97-102` + template do Bubblewrap 1.25.0 — **baixo** — Gradle sem checksum
O projeto gerado usa `gradle-wrapper.properties` do template
(`distributionUrl=https://services.gradle.org/distributions/gradle-8.11.1-bin.zip`)
sem `distributionSha256Sum`; AGP 8.9.1 e `compileSdk/targetSdk 36` vêm fixados no
template (bom). O download é HTTPS, mas não é verificado.
Correção: depois de gerar, acrescentar `distributionSha256Sum=<hash oficial>` ao
`projeto/gradle/wrapper/gradle-wrapper.properties` (um `sed` no workflow) ou usar
`gradle/actions/setup-gradle` com validação do wrapper.

### B6. `ios.yml:33,61-66` — **baixo** — runner móvel e log truncado
`macos-15` é imagem que muda de Xcode ao longo do tempo (não há `-xcode` fixado)
e `xcodebuild ... | tail -60` pode esconder o erro real quando ele aparece cedo
no log (o `pipefail` garante o status, não o diagnóstico).
Correção: fixar o Xcode (`sudo xcode-select -s /Applications/Xcode_16.x.app`) e
salvar o log inteiro como artefato (`tee "$RUNNER_TEMP/xcodebuild.log"`).

### O3. `imagens-vps.yml:69-70` — **observação** — build-arg para api e crystal
`NEXT_PUBLIC_API_URL` é passado às três imagens; só o web declara o `ARG`. O
buildx avisa "unused build arg". Inofensivo.

### O4. `ci.yml:15-17` — **observação** — `defaults.run.working-directory: .` é o padrão; pode sair.

### O10. `playwright.config.ts:25` — **observação** — `retries: 1` em CI
Aceitável, mas junto com A1 esconde instabilidade. Revisar quando A1 for corrigido.

**Conferido e OK no CI:** `permissions` mínimas em todos (`contents: read`;
`packages: write` só onde faz push); nenhum `echo` de segredo, nenhum `set -x`;
senhas do `jarsigner`/`keytool` via `:env` (`android-aab.yml:121,125`); nenhum
`pull_request` com acesso a segredos (o `ci.yml` não usa segredo algum; os
workflows com segredo não rodam em PR); `platforms: linux/amd64` e tag
`sha-XXXXXXX`/`v*`, sem `latest`; cache GHA com escopo por app e sem PR de fork
(sem vetor de cache poisoning); `pnpm/action-setup@v4` lê o `packageManager`
(pnpm 9.15.9) em vez de instalar a última; `cancel-in-progress: false` onde há
publicação; `concurrency` por ref; o plist do Firebase é apagado em `if: always()`
(`ios.yml:68-70`); o `.gitignore` barra `*.jks`, `*.p8`, `*.p12`,
`GoogleService-Info.plist`, `projeto/`.

---

## 2. Dockerfiles e `.dockerignore`

### A2. `apps/api/Dockerfile:1-19` — **alto** — a API roda como root
Única das três imagens sem `USER`. É justamente a que recebe upload de arquivo
de aluno (`routes/uploads.ts`), fala com Postgres/Redis e guarda os segredos de
cifra em memória. O web (`apps/web/Dockerfile:31-38`) e a crystal
(`apps/crystal/Dockerfile:16`) já rodam sem root.
Correção: `RUN mkdir -p /app/uploads && chown node:node /app/uploads`, `USER node`
e `COPY --chown=node:node`; conferir na stack `10-crystal-app.yaml` que o volume
`app_uploads` fica gravável pelo uid 1000 (ou `chown` no bootstrap).

### M4. `apps/api/Dockerfile:10,19` e `apps/crystal/Dockerfile:7,18` — **médio** — devDependencies e `tsx` em produção
`pnpm install --frozen-lockfile --filter ...` instala devDependencies (vitest,
`@types/*`, prisma CLI, tsx), `COPY apps/api apps/api` traz `*.test.ts`,
`vitest.config.ts`, `.env.example`, e o processo de produção executa TypeScript
via `tsx` (`CMD ["pnpm","--filter","@crystal/api","start"]` → `tsx src/server.ts`).
Mais superfície, imagem maior, boot mais lento. O `prisma` CLI precisa ficar,
porque a stack migra no mesmo contêiner (`db:migrate:deploy && start`).
Correção: multi-stage com `tsc` → `dist/`, `pnpm install --prod` (ou
`pnpm deploy --prod`), mantendo só `prisma` + `@prisma/client` no runtime e
`CMD ["node","dist/server.js"]`.

### M5. `apps/api/Dockerfile:1`, `apps/web/Dockerfile:1,24`, `apps/crystal/Dockerfile:1` — **médio** — base `node:22-alpine` sem digest
A tag `22-alpine` muda a cada release do Node e do Alpine; a regra "versões
fixadas" vale para a imagem base também.
Correção: `FROM node:22.x.y-alpine3.2z@sha256:...` (a mesma linha nas três) e
Dependabot `docker` para subir o digest com PR.

### B7. `.dockerignore:1-13` — **baixo** — contexto leva o que não precisa e não protege o que importa
Não exclui `**/uploads` (o `UPLOAD_DIR` padrão é `./uploads`, `env.ts:135`; mídia
de aluno de um ambiente local entraria na imagem num build feito à mão),
`deploy/backups`, `*.dump`, `*.jks`, `*.keystore`, `*.p8`, `*.p12`,
`GoogleService-Info.plist`, `apps/mobile`, `docs`, `TASK`, `e2e`, `test-results`,
`*.zip`, `**/*.test.ts`, `*.tsbuildinfo`.
Correção: acrescentar essas linhas; o Dockerfile da API já faz `COPY apps/api`
inteiro, então o `.dockerignore` é a única barreira.

### B8. `apps/web/Dockerfile:11-22` — **baixo** — telemetria do Next no build
Sem `ENV NEXT_TELEMETRY_DISABLED=1` o `next build` tenta mandar telemetria de
dentro do runner. Correção: adicionar a linha no stage `builder`.

### B9. `docker-compose.yml:8-9,19-20` (raiz, dev) — **baixo** — Postgres e Redis expostos em todas as interfaces
`"5432:5432"` e `"6379:6379"` com senha `crystal` e Redis sem senha. É só o
compose de desenvolvimento, mas em máquina com IP público vira porta aberta.
Correção: `"127.0.0.1:5432:5432"` e `"127.0.0.1:6379:6379"`.

### M9. `scripts/backup-postgres.sh:9` + `.gitignore` + `deploy/` — **médio** — dump de produção pode ir para o Git; pilha `deploy/` é legado
O backup grava em `deploy/backups/` por padrão e o `.gitignore` não lista
`deploy/backups/` nem `*.dump` (lista só `deploy/.env.production.local`). Um
`git add -A` depois de um backup commita dados de aluno. Além disso
`deploy/docker-compose.prod.yml`, `Caddyfile`, `fly.*.toml`, `railway*.json` e
`render.yaml` descrevem uma produção (Caddy/Fly/Railway/Render) que não é a real
(Swarm + Traefik na VPS, stack em `hospedagem_em_transicao/crystal-em-casa/stacks-app/`),
e divergem em detalhes como o `UPLOAD_DIR` (ver `app-web-chat.md:60-62`).
Correção: `deploy/backups/` e `*.dump` no `.gitignore` já; marcar `deploy/` como
legado no README ou remover o que não é mais usado.

### O5. `apps/api/Dockerfile:8-14` — **observação** — `prisma generate` roda duas vezes
Uma no `postinstall` (`apps/api/package.json:15`) e outra explícita na linha 14.
Inofensivo; o comentário da linha 8 explica por que o schema é copiado antes.

**Conferido e OK em Docker:** nenhum `COPY .env`, nenhum segredo em `ARG`/`ENV`
(`NEXT_PUBLIC_API_URL` é valor público e documentado como tal em
`imagens-vps.yml:7-9`); `.dockerignore` barra `.env`, `.env.*` (menos
`.env.example`), `node_modules`, `.next`; web em multi-stage, `output: "standalone"`
(`next.config.ts:9`) com `server.js`, `static` e `public` nos caminhos certos para
monorepo, `HOSTNAME=0.0.0.0`, usuário `nextjs:nodejs`; crystal com `USER node` e
arquivos de root (só leitura, como o comentário diz); migração `prisma migrate deploy`
no lugar certo (stack, 1 réplica, `order: stop-first`, `start_period: 90s`), não
no build; `HEALTHCHECK` ausente nas imagens mas presente na stack com `wget` do
busybox, coerente com `/healthz` da API (`routes/health.ts:5`) e da crystal
(`app.ts:90`) e com `/` do web; `EXPOSE` coerente com as portas do Traefik.

---

## 3. Mobile

### A3. `apps/mobile/ios-capacitor/ios/App/App/Info.plist:29-30` — **alto** — falta `NSMicrophoneUsageDescription`
O compositor do chat grava áudio com `navigator.mediaDevices.getUserMedia({audio:true})`
(`apps/web/components/chat/Composer.tsx:85-97`) e o botão aparece no app da loja
(é o mesmo site dentro do WKWebView). No iOS, acessar o microfone sem a chave no
`Info.plist` **encerra o app na hora** (e a Apple rejeita por 5.1.1). O
`Permissions-Policy` do `next.config.ts:22` bloqueia `camera` e `geolocation`,
não `microphone`. O plist só tem `NSFaceIDUsageDescription`.
Correção: adicionar `NSMicrophoneUsageDescription` ("Para gravar um áudio para a
Crystal.") e declarar o uso em `app-privacy-apple.md`/`data-safety-google.md`
(áudio já consta lá).

### M10. `Info.plist` — **médio, a confirmar** — `NSCameraUsageDescription` para o seletor de arquivo
O `<input type="file" accept="image/...">` (`Composer.tsx:185-193`) no WKWebView
oferece "Tirar foto" além da biblioteca; escolher a câmera sem
`NSCameraUsageDescription` também derruba o app. Escolher da biblioteca usa o
PHPicker e não precisa de chave.
Correção: adicionar `NSCameraUsageDescription` (ou `capture` desabilitado) e
testar no simulador/aparelho antes do TestFlight.

### A4. `docs/lojas/listagem.md:42` — **alto (coerência)** — Google Play promete Face ID/digital que o Android não tem
A descrição longa é "as duas lojas" e diz "Protege as conversas com Face ID ou
digital". O Android é TWA: não há plugin, `window.Capacitor` não existe,
`BiometricLock`/`BiometricToggle` nunca aparecem (`native.ts:26-28,67-69`). A
Play recusa listagem com funcionalidade inexistente. A nota ao revisor da Apple
(linha 76) está certa ("shown only in the iOS app").
Correção: tirar a frase da versão Google Play ou escrever "no iPhone, protege as
conversas com Face ID".

### M6. `ios/App/CapApp-SPM/Package.swift:15` + plugin — **médio** — Firebase iOS SDK sem versão fixa
`capacitor-swift-pm` está em `exact: "8.5.2"` (bom), mas o
`@capacitor-firebase/messaging` 8.5.2 declara `firebase-ios-sdk .upToNextMajor(from: "12.7.0")`
e não existe `Package.resolved` versionado
(`ios/App/App.xcodeproj/project.xcworkspace/xcshareddata/` só tem
`IDEWorkspaceChecks.plist`). Cada build do CI pega o Firebase mais novo da série 12.
Correção: versionar `.../xcshareddata/swiftpm/Package.resolved` e usar
`-disableAutomaticPackageResolution` no `xcodebuild` do `ios.yml:64`.

### B10. `Info.plist:66-72` — **baixo** — orientações de iPad em app só iPhone
`UISupportedInterfaceOrientations~ipad` lista paisagem, mas `TARGETED_DEVICE_FAMILY = 1`
(`project.pbxproj:339,362`) e o README diz "só retrato". Inofensivo; remover a chave.

### B11. `Base.lproj/LaunchScreen.storyboard:18,28-30` — **baixo** — flash branco na abertura
Fundo `systemBackgroundColor` (branco) sob a imagem `Splash`; o app é preto
(`capacitor.config.ts:14,24,29`, `manifest.webmanifest:10-11`).
Correção: cor de fundo `#000000` no storyboard.

### B12. `project.pbxproj:326,333,350,357` — **baixo** — versão fixa `1.0`/`1`
`MARKETING_VERSION = 1.0` e `CURRENT_PROJECT_VERSION = 1` sem mecanismo para subir
(no Android o workflow faz). Para o TestFlight cada upload precisa de
`CFBundleVersion` maior.
Correção: no futuro workflow de distribuição, passar `MARKETING_VERSION`/
`CURRENT_PROJECT_VERSION` pela linha do `xcodebuild`, derivados de tag `ios-v*`
e do número da execução.

### B13. `apps/mobile/ios-capacitor/.npmrc:3` — **baixo** — `legacy-peer-deps=true` para tudo
Silencia todos os conflitos de peer do diretório, não só o do SDK web do Firebase.
Correção: manter, mas acrescentar ao README a verificação `npm ls` a cada subida
de versão; ou usar `overrides` para `firebase` em vez do flag global.

### B14. `apps/mobile/android-twa/twa-manifest.json:39-42` — **baixo** — `signingKey` não usado e com alias errado
`path: ./android.keystore`, `alias: crystal`; o alias real é `upload`
(`android-aab.yml:122`). Quem rodar `bubblewrap build` à mão vai tropeçar. O
README já avisa (linhas 36-37).
Correção: remover o bloco (o `TwaManifest` aceita ausência) ou alinhar o alias.

### O1. `AppDelegate.swift:12-13` — **observação** — comentário desatualizado
Diz que "o build de conferência usa um arquivo vazio"; o `ios.yml` e a fase
"Firebase config" do `project.pbxproj:173` só copiam o plist se existir, nunca
criam um vazio. O código está certo (checa `googleAppID`), e o plugin
`@capacitor-firebase/messaging` 8.5.2 também protege
(`FirebaseMessaging.swift:16-21`: sem `defaultOptions()` não chama `configure()`),
então não há crash sem plist. Só atualizar o comentário.

### O2. `project.pbxproj:331` — **observação** — `OTHER_SWIFT_FLAGS "-D COCOAPODS"` em projeto SPM (resquício do template); inofensivo.

**Conferido e OK no mobile:** `br.com.crystalnowpp.app` idêntico em
`twa-manifest.json:2`, `capacitor.config.ts:11`, `project.pbxproj:335,358`,
`lib/app-links.ts:13` e nos docs; `assetlinks.json` com
`delegate_permission/common.handle_all_urls` + SHA-256 validado por regex
(`app-links.ts:15-18`) e `apple-app-site-association` com `applinks`
(`/chat`, `/perfil/conversa`, `/suporte/*`) e `webcredentials`, batendo com os
dois entitlements (`App.entitlements:9-13`); `aps-environment development` (o
Xcode troca na distribuição); `UIBackgroundModes remote-notification` coerente
com FCM; `ITSAppUsesNonExemptEncryption false` correto para HTTPS;
`LSRequiresIPhoneOS`, `arm64`, retrato; `capacitor.config` com `server.url`
HTTPS, `allowNavigation` só no host do app e `cleartext: false`; `fallbackType:
"customtabs"` na TWA; cores/orientação/nome coerentes com
`manifest.webmanifest`; `gerar-projeto.mjs` serve ícones em `127.0.0.1` porta
efêmera com nome validado por regex (sem path traversal) e valida `VERSION_CODE`/
`VERSION_NAME`; `@bubblewrap/core 1.25.0` e Capacitor 8.5.2 fixos com lockfile;
`ios/.gitignore` cobre `public/`, `capacitor.config.json`, `config.xml` gerados;
URLs de privacidade/termos/exclusão apontam para rotas que existem
(`apps/web/app/privacidade`, `termos`, `excluir-conta`); `native-push.ts:66-69`
só abre caminho relativo do próprio app a partir da notificação.

---

## 4. E2E e Playwright

### B15. `e2e/journey.spec.ts:22,24` — **baixo** — seletores por classe CSS
`.bubble-tail-bot` e `.streaming-caret` são classes de estilo; qualquer troca no
design system quebra o teste sem o produto ter mudado.
Correção: `data-testid`/`role` + `aria-busy` no caret.

### B16. `e2e/onboarding.spec.ts:10` — **baixo** — condição de corrida
`if (await consent.isVisible())` não espera; se o botão aparecer 100 ms depois, o
clique não acontece e o teste falha de forma intermitente.
Correção: o mesmo padrão de `support.ts:21-25` (`waitFor` com timeout curto).

### B17. `e2e/a11y.spec.ts:25-47` — **baixo** — estado global sem `afterEach`
Liga "backup manual" e desfaz no fim do teste; se falhar no meio, os testes
seguintes veem o banner ("estou te atendendo por aqui") no chat.
Correção: desfazer num `test.afterEach`, ou `describe.serial` com `afterAll`.

### B18. `e2e/web-server.sh:24-30` — **baixo, a confirmar** — hard links podem alterar o repositório original
`rsync --link-dest` cria hard links; `next build` reescreve `next-env.d.ts` (e
`tsconfig.json`, quando ajusta opções) na cópia, e por serem o mesmo inode a
escrita aparece no `apps/web` original. Depende de o Next escrever no lugar
(sem rename). Correção: excluir esses dois arquivos do `--link-dest` ou copiar
`apps/web` sem hard link.

### B19. `apps/web/scripts/mobile-audit.spec.ts` — **baixo** — spec que nunca roda
Está fora de `testDir: "./e2e"` (`playwright.config.ts:22`), usa
`http://localhost:3000`/`3001` fixos e credenciais próprias; o `playwright test` não
o descobre e o CI não o executa.
Correção: mover para `e2e/` com `test.skip(!process.env.MOBILE_AUDIT)` ou
documentar como auditoria manual com o comando exato.

### O6. `e2e/README.md:89-90` — **observação** — "20/20 ✓ em 2026-09-04" é foto antiga; com A1 o CI não a renova.

**Conferido e OK no E2E:** nenhuma dependência de rede externa nos testes (só
`playwright install` e `prisma generate` no setup); credenciais fixas
(`equipe-senha.spec.ts:3-7`, `revisao.spec.ts:3-5`, `playwright.config.ts:46-48`)
são da API demo em memória com `DEMO_SEED=1`, nunca de produção, e o README manda
gerar a conta de revisão real com `bootstrap-vps.sh app-revisao`;
`revisao.spec.ts:21` garante que `dev_code` não vaza para a conta de revisão;
`errors.spec.ts:33` garante que jargão (SSE/502/timeout) não aparece; portas
validadas (`playwright.config.ts:4-13`); build de produção de verdade (CSP com
nonce) em diretório temporário; `workers: 1` coerente com estado compartilhado;
`trace: retain-on-failure` + upload de `test-results/` só em falha.

---

## 5. Scripts da raiz (`scripts/`)

### B20. `scripts/backup-postgres.sh:26-27` — **baixo** — senha do banco em argumento de processo
`pg_dump ... "$DATABASE_URL"` expõe a URL (com senha) em `ps`/auditd enquanto o
dump roda. Correção: `PGPASSWORD`/`~/.pgpass` com `PGHOST`/`PGUSER`/`PGDATABASE`,
ou `--dbname` lido de arquivo com `0600`. (Observação: o backup de produção real
é o do `hospedagem_em_transicao` — R2 cifrado com age; estes scripts servem à
pilha legada de `deploy/`, ver M9.)

**Conferido e OK em scripts:** `gen-secrets.sh` gera com `openssl rand`, `mktemp`
no mesmo diretório, `chmod 600` antes do `mv`, `unset` de tudo, `npx --no-install`
(sem download de origem desconhecida), nunca imprime valores, escapa `\`, `&`, `|`
no `sed`; `restore-postgres.sh` com `--exit-on-error`, `--clean` só com
`RESTORE_CLEAN=1`; `smoke.sh` com `set -uo pipefail` sem `-e` de propósito,
`--max-time`, limpeza do temporário protegida por `case`, e os testes de
segurança certos (`/staff/users` anônimo = 404 sem oráculo, webhook sem
assinatura = 401, CORS exato com credenciais, `nosniff`, CSP, framing). Nenhum
`curl | bash` em lugar nenhum do repositório.

---

## 6. `docs/lojas/` (coerência com o código)

### M8. `apps/web/app/termos/page.tsx:199-202` e `docs/lojas/termos-de-uso.md:79,138-139` — **médio** — página pública com placeholders
`/termos` (URL que vai no formulário das duas lojas, `listagem.md:26`) ainda
mostra "👤 [e-mail de contato]" e "👤 [nome e e-mail do encarregado]"; o revisor
abre o link. O `.md` ainda tem "👤 [URL da política de privacidade]" (linha 79)
embora a página já linke `/privacidade` (`page.tsx:122`).
Correção: preencher e-mail e DPO antes de submeter; alinhar o `.md` com a página.

(A4 acima: Face ID/digital na descrição do Google Play.)

### B22. `docs/lojas/listagem.md:18` vs `apps/mobile/README.md:59` e `data-safety-google.md:48` — **baixo** — "17+" na Apple e "18+" no resto
Não é erro (a Apple não tem 18+, 17+ é o máximo), mas vale uma nota no
`listagem.md` para ninguém "corrigir" para 18 no App Store Connect.

### O7. `docs/lojas/privacidade-revisao.md` — **observação, a confirmar** — documento de setembro lista lacunas (DPO, retenção, terceiros, e-mail/telefone) que os docs de 30/09 (`app-privacy-apple.md`, `data-safety-google.md`) tratam como resolvidas. Conferir se `apps/web/app/privacidade/page.tsx` já cobre tudo e, se sim, marcar o `.md` como concluído.

**Conferido e OK nos docs:** tudo que a listagem promete existe no código:
exportar dados (`GET /me/export`, `routes/me.ts:44`), excluir conta
(`DELETE /me/account`, `me.ts:153`, e rota `/excluir-conta`), token de notificação
(`POST/DELETE /me/push/devices`, `routes/push.ts`), imagem e áudio no chat
(`Composer.tsx`), links universais (entitlements + AASA), pacote
`br.com.crystalnowpp.app`, política em `/privacidade`; `data-safety-google.md` e
`app-privacy-apple.md` contam a mesma história (sem tracking, sem anúncio,
Sentry opcional não vinculado, cópia anônima das conversas declarada);
`screenshots.md` coerente com `store-screenshots.mjs` e sem telas de `/equipe`.

---

## 7. Raiz do monorepo

### B21. `package.json:27-35`, `apps/*/package.json`, `package.json:7` — **baixo** — ranges `^` e `packageManager` sem hash
Dependências em `^` (next `15.5.25` e prisma `6.19.3` fixos são exceção); na
prática o `pnpm-lock.yaml` + `--frozen-lockfile` fixam o que é instalado, então a
regra "versões fixadas" é cumprida pelo lockfile. `packageManager: pnpm@9.15.9`
sem `+sha512.…`: o `corepack enable` dos Dockerfiles baixa o pnpm do registry no
build sem verificar hash.
Correção: `save-exact=true` num `.npmrc` da raiz e
`packageManager: "pnpm@9.15.9+sha512.<hash>"` (o corepack valida).

### O9. raiz — **observação** — `simulacro-whatsapp-docs.zip` e `TASK/qa/*.diff` versionados; binário e artefatos de QA no repositório. Fora do escopo desta revisão; só registro.

**Conferido e OK na raiz:** `pnpm-workspace.yaml` (`apps/*`, `packages/*`) não
engloba `apps/mobile/*` (sem `package.json` direto), de propósito e documentado;
`engines.node >=20.19` compatível com Node 22 do CI e das imagens; `overrides`
de segurança (`deepmerge-ts`, `postcss`, `sharp`, `fast-uri`); `tsconfig.base.json`
estrito; `eslint.config.mjs` cobre `e2e/` e `scripts/`, ignora gerados; não há
`turbo.json` (não é necessário).

---

## 8. Pontos bem feitos (resumo)

1. Nenhum segredo em log, repositório, URL ou build-arg; senhas do `jarsigner`
   por `:env`; plist do Firebase apagado em `always()`; `.gitignore` e README
   tratam chave de envio, `.p8`, keystore e plist como fora do Git.
2. `permissions` mínimas por workflow; `packages: write` só no que publica.
3. Tags `sha-XXXXXXX` e `v*`, nunca `latest`; `platforms: linux/amd64`; labels OCI.
4. Web em multi-stage, `standalone`, usuário sem root; crystal com `USER node`.
5. Migração do Prisma na stack com 1 réplica e `stop-first`, não no build.
6. IDs, entitlements, AASA e assetlinks coerentes entre web, iOS, Android e docs;
   valores do ambiente validados por regex antes de sair na rota.
7. Firebase só inicializa com plist real (AppDelegate + plugin), sem crash.
8. Gerador da TWA sem depender do site no ar, com validação de entrada e
   dependência fixa; `fallbackType: customtabs`.
9. `native-push.ts` só abre caminhos internos a partir da notificação; token
   apagado no logout e na exclusão da conta.
10. E2E contra build de produção com CSP de nonce, sem rede externa, com teste
    explícito de que `dev_code` não vaza para a conta de revisão.
11. `gen-secrets.sh` e `smoke.sh` corretos no detalhe (permissões, limpeza,
    sem eco de segredo, checagens de segurança de verdade).
12. Docs das lojas conferidos com o código: o que prometem existe (exceto A4).

---

## 9. Contagem

- **Escopo lido linha a linha:** 71 arquivos, 3.418 linhas (`wc -l`): 4 workflows,
  `.dockerignore`, 3 Dockerfiles, 29 arquivos de `apps/mobile/**` (o
  `project.pbxproj`, 405 linhas, foi lido nos trechos relevantes — build settings,
  fase de script, referências SPM — não nos blocos de UUID), 12 de `e2e/`,
  `playwright.config.ts`, 4 scripts, 6 docs de lojas, `package.json`,
  `pnpm-workspace.yaml`, `tsconfig.base.json`, `eslint.config.mjs`, 4
  `package.json` dos pacotes, `docker-compose.yml`, `.gitignore`.
- **Apoio (lidos para confirmar achados):** 16 arquivos, ≈1.000 linhas:
  `lib/app-links.ts`, `lib/native.ts`, `lib/native-push.ts`, `next.config.ts`,
  `manifest.webmanifest`, as duas rotas `.well-known`, `apps/api/src/server.ts`,
  trechos de `Composer.tsx`, `env.ts`, `routes/*.ts`, `termos/page.tsx`,
  `deploy/*` (compose, Caddyfile, fly, railway, render, chaves do template),
  `stacks-app/10-crystal-app.yaml` (serviço `app_api`), o `FirebaseMessaging.swift`
  do plugin e o template do Bubblewrap.
- **Achados:** 0 críticos, 4 altos (A1–A4), 10 médios (M1–M10), 22 baixos
  (B1–B22), 9 observações (O1–O7, O9, O10). Marcados "a confirmar": M10, B18, O7.
