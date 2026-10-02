# Revisão de código — `apps/web` (crystal-web-chat)

Data: 2026-10-02 · Escopo: `apps/web` (Next.js 15 App Router, PWA, TypeScript, Tailwind v4): `app/**`, `components/**`, `lib/**`, `public/sw.js`, `public/manifest.webmanifest`, `public/offline.html`, `next.config.ts`, `middleware.ts`, `scripts/*.mjs` + `scripts/mobile-audit.spec.ts`, `package.json`, `Dockerfile`, `tsconfig.json`, `vitest.*`, `.env.example` e todos os `*.test.ts(x)`. Ignorados: `.next/`, `node_modules/`, binários em `public/icons`, `design-system/` (docs e tokens; li só `pwa-audit.md` como evidência).

Método: leitura integral de cada arquivo com `Read`, sem executar build ou testes, sem modificar nada. Cada achado foi relido antes de entrar aqui. "A confirmar" marca o que depende da API ou de comportamento de runtime que não dá para provar só lendo o código.

Gravidades: **crítico** / **alto** / **médio** / **baixo** / **observação**.

---

## 1. Bugs reais

### 1.1 `components/native/BiometricLock.tsx:114-138` — **alto**
O efeito de "re-lock ao voltar para o app" não checa `isNativeApp()`. Na web comum, cada `visibilitychange` para `visible` faz `setLockState("locked")` → `runVerify()`; `verifyBiometric` resolve na hora fora do nativo e volta para `unlocked`. Entre os dois estados o render troca `{children}` pelo overlay, ou seja, **toda a árvore de `(chat)/*` é desmontada e remontada a cada troca de aba/retorno ao app**: texto digitado no Composer some, `/me` e o histórico são refeitos, o stream em curso é abortado (`abortRef` no cleanup de `useChat`), `NativePush` reinicia. No nativo com preferência `off` e plugin presente, o mesmo caminho chama `plugin.verifyIdentity` de verdade (prompt de Face ID sem o bloqueio ativado).
Correção: só registrar os listeners quando `isNativeApp()` e a preferência estiver `on` (guardar isso em estado na `init`), e manter `children` montados sob o overlay (overlay por cima, `inert`/`aria-hidden`) em vez de trocar a árvore.

### 1.2 `lib/offline-queue.ts` + `lib/use-chat.ts:298-323` — **alto**
A fila offline (`cw-outbox`, texto da mensagem em claro no `localStorage`) não é atrelada ao usuário. Sessão expira (`onSessionExpired` → `/login?sessao=expirada`) sem `clearQueue()`; outra pessoa entra no mesmo navegador e `useChat` lê a fila e **envia a mensagem da pessoa anterior como se fosse dela** (`flushQueue` na carga inicial). Só `logout` e `deleteData` limpam. Conteúdo de chat é dado sensível neste produto.
Correção: chavear a fila pelo `user.id`/`conversation_id` (`cw-outbox:<id>`) e limpar no `onSessionExpired` e no sucesso de login.

### 1.3 `lib/finance.ts:46-55` — **médio**
`parseBRL("1.297")` (separador de milhar sem centavos) cai no ramo `!s.includes(",")` e vira `parseFloat("1.297")` = 1,297 → **130 centavos** em vez de 129.700. Também `parseBRL("1.000")` → 100. A tela financeira aceita texto livre nesse campo (`NewEntryDialog`, `FinanceEntryDrawer`), então um lançamento pode ser gravado com valor 1000× menor. O teste cobre só `"1.297,00"` e `"97.50"`.
Correção: tratar ponto como milhar quando houver exatamente 3 dígitos após ele e nenhuma vírgula (ou exigir vírgula decimal e rejeitar ambíguo), e adicionar os casos ao `finance.test.ts`.

### 1.4 `app/(equipe)/equipe/financeiro/page.tsx:81-83` + `components/equipe/financeiro/FinanceFilters.tsx:55` — **médio**
`FinanceFilters` chama `onChange` a cada tecla e o efeito `[filters, month, loadFirst]` dispara `loadFirst` (duas requisições: lista + resumo) a **cada keystroke**, sem debounce e sem cancelamento; respostas fora de ordem sobrescrevem a lista com resultado velho. As outras telas da equipe usam o padrão `draft/applied` e não têm esse problema. O `onSubmit` ainda chama `loadFirst` de novo (duplicado).
Correção: adotar `draft/applied` como em `usuarios/page.tsx`, ou debounce + token de sequência para descartar respostas atrasadas.

### 1.5 `lib/use-chat.ts:372-397` — **médio**
`arrived` é atribuído **dentro do updater** de `setMessages` e lido logo depois. React só executa o updater de forma antecipada quando a fila do componente está vazia; com tokens chegando (`appendToken`) ele roda na próxima renderização e `arrived` ainda é `null` no `if` → `typing` não zera e o anúncio para leitores de tela não sai. Em StrictMode o updater roda duas vezes.
Correção: calcular `next`/`arrived` fora do updater (a partir de `messagesRef.current`) e usar `setMessages(next)`.

### 1.6 `lib/api.ts:59-64` — **médio (a confirmar com a API)**
Em 401 cada chamada faz seu próprio `POST /auth/refresh`; a tela de chat abre com 4-5 requisições paralelas (`/me`, mensagens, onboarding, `/health/channel`, sugestões). Se o refresh token for rotativo com detecção de reuso, o segundo refresh concorrente falha e pode derrubar a sessão inteira.
Correção: memorizar a promessa de refresh em curso (single-flight) e reutilizá-la nas chamadas concorrentes.

### 1.7 `lib/register-sw.ts:82-86` — **médio (a confirmar em runtime)**
`registerServiceWorker()` é chamado dentro de `useEffect` (`AppInit`) e espera `window.addEventListener("load")`. Se a hidratação terminar depois do `load` (página leve, cache quente), o listener nunca dispara e o SW não é registrado; o `pwa-audit.md` diz que o gate rodou "sem Chrome", então isso não foi verificado no navegador.
Correção: `if (document.readyState === "complete") register(); else addEventListener("load", register)`.

### 1.8 `components/chat/Composer.tsx:84-133` — **médio**
Gravação de áudio sem cleanup de desmontagem: se o componente sair da tela gravando (ver 1.1, que torna isso frequente), o `MediaRecorder` e as tracks do microfone continuam ativos, o `setInterval` do contador segue rodando e `onstop` chama `setState`/upload num componente morto.
Correção: `useEffect(() => () => { recorderRef.current?.stop(); stream tracks stop; clearInterval })`.

### 1.9 `lib/use-chat.ts:80-136, 428-430` — **baixo**
`abortRef` guarda só o último `AbortController`; mandar duas mensagens em sequência deixa o stream anterior sem abort no unmount (continua consumindo rede e chamando `setState`). O comentário de `retry` (L252) diz que reenvia "resposta perdida", mas o código só aceita `direction === "in"`.
Correção: manter um `Set` de controllers e abortar todos; ajustar o comentário.

### 1.10 `lib/sse-client.ts:28-31` — **baixo**
`JSON.parse(msg.data)` sem `try/catch`: um evento malformado derruba o stream inteiro e dispara até 6 reconexões com backoff, em vez de pular o evento. Não há timeout de inatividade (mitigado pelo `syncLatest` que fecha a bolha pelo histórico).
Correção: `try { ... } catch { continue; }`.

### 1.11 `lib/use-async.ts` / `app/(chat)/suporte/page.tsx:42-44` — **baixo**
`useAsync` ignora mudanças de `fn` (só `tick`); é documentado, mas chamadores como `TicketThread({ id })` não recarregam se `id` mudar sem remontar. `/suporte?novo=1` é lido via `window.location.search` uma vez; navegação client-side para a mesma rota com `?novo=1` não reabre o formulário.

### 1.12 `components/chat/ChatHeader.tsx:74-91` — **baixo**
`optInPush()`/`installApp()` são chamados com `void` e não têm `try/catch`; `enablePushNotifications` pode rejeitar (`/push/public-key` 5xx, `pushManager.subscribe` abortado) → promessa não tratada e nenhum feedback na tela.
Correção: envolver em `try/catch` e mostrar `pushStatus` de erro.

### 1.13 `components/auth/OtpStep.tsx:47-57` — **baixo**
Os dois `useEffect` de contagem dependem de `expiresIn`/`resendIn`: o `setInterval` é destruído e recriado a cada segundo. Funciona, mas é churn desnecessário. Correção: depender só de `> 0` (ou usar `setTimeout` recursivo).

### 1.14 `app/(auth)/login/page.tsx:13` vs `app/(chat)/chat/page.tsx:168` — **baixo**
Depois de excluir a conta, o redirect vai para `/login?conta=excluida`, mas o login só trata `sessao=expirada`; a pessoa não recebe confirmação de que a conta foi excluída.

### 1.15 `components/equipe/financeiro/NewEntryDialog.tsx:37,54-60,67-79` — **baixo**
`paidAt` inicial usa `toISOString().slice(0,10)` (data UTC, pode ser "amanhã" à noite no Brasil); `-03:00` fixo em L95 e em `FinanceEntryDrawer.tsx:80`; o pré-filtro busca o aluno passando o `user_id` como `query` textual (a confirmar se a API casa id nesse campo); o `setTimeout` da busca não é limpo no unmount.

### 1.16 `components/equipe/financeiro/FinanceEntryDrawer.tsx:99,115` — **baixo**
Mostra `err.message` cru ("Failed to fetch", mensagem da API) em vez de `financeErrorMessage(err)` usado no resto da área.

### 1.17 `app/error.tsx:14` / `app/global-error.tsx:13` — **baixo**
`reportError(error)` sem `void`/`catch`; se o import dinâmico do Sentry falhar, vira rejeição não tratada dentro da própria página de erro.

### 1.18 `components/equipe/suporte/SupportBadge.tsx` — **observação**
Renderizado duas vezes (sidebar + abas), então há dois pollers de `/staff/tickets/stats` a cada 60 s por aba aberta.

---

## 2. Segurança do cliente

### 2.1 `public/sw.js:92-105` — **baixo**
`notificationclick` navega/abre `payload.url` sem validar origem; `self.clients.openWindow(url)` aceita URL absoluta. O payload vem do servidor assinado (VAPID), então o risco é um push malicioso só se o servidor for comprometido. `lib/native-push.ts` já tem `caminhoSeguro()` para o caso nativo — reaproveitar a mesma regra aqui.
Correção: aceitar só caminho relativo começando com `/` (sem `//`) e cair em `/chat`.

### 2.2 `middleware.ts:41-54` — **observação (a confirmar)**
CSP com nonce + `strict-dynamic` e sem `worker-src`. Pela spec CSP3, requisições de worker não "parser-inserted" casam com `strict-dynamic`, então `navigator.serviceWorker.register('/sw.js')` deve passar — mas não há evidência em navegador (ver 1.7). Não há `report-to`/`report-uri`, então violações ficam invisíveis. `img-src`/`media-src` liberam só `API_URL`: se a API devolver `media_url` absoluta de outro host (storage/CDN), as mídias serão bloqueadas.
Correção: adicionar `worker-src 'self'` explicitamente e um `report-to` na primeira semana de laranja.

### 2.3 `next.config.ts` — **baixo**
Sem `poweredByHeader: false` (vaza `X-Powered-By: Next.js`). `Permissions-Policy` não cobre `microphone` (o Composer usa microfone de propósito, então ok), nem `payment`, `usb` etc. HSTS sem `preload` (decisão consciente, ok).

### 2.4 `lib/api.ts:80-94` — **observação (CSRF, lado da API)**
`uploadFile` manda `multipart/form-data` com `credentials: include` e sem header custom: é uma "simple request", não passa por preflight. Com cookie `SameSite=None` (necessário para o Capacitor, a confirmar) um site terceiro conseguiria POSTar em `/uploads` com o cookie da vítima; as outras rotas usam `application/json` (preflight). A defesa tem de estar na API (checar `Origin`/`Sec-Fetch-Site`). Anotar para a revisão da API.

### 2.5 `components/chat/ChatHeader.tsx:198-207` — **observação (a confirmar)**
O comentário assume cookie `SameSite=Lax` para o `GET /me/export`. No app Capacitor (origem `capacitor://localhost`) a API é cross-site: `Lax` não vai em `fetch` nem em `<img>/<audio>` (`MessageBubble.tsx:13-15`). Se o app nativo funciona, o cookie já é `None; Secure` — e aí vale o ponto 2.4.

### 2.6 `lib/error-reporting.ts:46-77` — **baixo**
`scrub()` roda em `message` e `exception.value`, mas não em `event.request.url`, `breadcrumb.data.url` nem em `extra` passado por `reportError(err, context)`. Hoje nenhuma URL carrega CPF/e-mail (o lookup por CPF vai em POST — bom), mas o `context` é livre.
Correção: aplicar `scrub` também em `extra` e nas URLs dos breadcrumbs.

### 2.7 `components/chat/Composer.tsx:63` — **baixo (lado da API)**
A validação aceita qualquer `image/*`, inclusive `image/svg+xml` (o `accept` do input é só sugestão). Em `<img>` SVG não executa script, mas se a API servir o arquivo inline na própria origem, abrir a URL diretamente executaria script no domínio da API. Checar na API: lista fechada de tipos e `Content-Disposition: attachment` / `X-Content-Type-Options`.

### 2.8 `lib/native-push.ts:32,45-60` — **observação**
Token FCM em `localStorage` (não é segredo, serve só para evitar re-registro). OK.

### 2.9 `app/layout.tsx:57` — **observação (ok)**
Único `dangerouslySetInnerHTML` do projeto: string constante com nonce. Sem markdown, sem `href` dinâmico com `javascript:`; `caminhoSeguro()` bloqueia URL externa vinda de push nativo. Nenhum segredo no bundle (`.env.example` só tem `NEXT_PUBLIC_*`; `.dockerignore` exclui `.env*`).

### 2.10 `components/equipe/StaffLayout.tsx:27-31` — **observação**
O gate é só client-side: o JS de `/equipe/*` é servido a qualquer pessoa (o 404 é renderizado depois do `/me`). O comentário "o cliente não pode nem inferir que a área existe" não se sustenta; a proteção real está (e deve estar) na API.

### 2.11 `lib/staff.ts:38-48` — **observação (bem feito)**
Busca por CPF completo vai em `POST /staff/users/lookup` e nunca na query string; nome/e-mail ainda vão na URL de `/staff/users?query=` (logs do servidor/proxy).

---

## 3. LGPD / UX legal

### 3.1 `app/privacidade/page.tsx:145-150` — **alto**
Política publicada com placeholder "👤 [nome e e-mail do encarregado — a preencher antes da publicação]". A LGPD (art. 41, §1º) exige a identidade e o contato do encarregado divulgados publicamente; a página já está no ar e é linkada do login.
Correção: preencher antes do próximo deploy (ou ler de `NEXT_PUBLIC_CONTATO_PRIVACIDADE`, já usado em `/excluir-conta`).

### 3.2 `app/termos/page.tsx:16-21, 206-210` — **médio**
Termos marcados como "Versão preliminar — sujeita a revisão jurídica… não deve ser considerado vinculante" e linkados do login, do menu e das lojas. Ou se publica a versão final, ou não se oferece para aceite.

### 3.3 Coerência produto × textos — **alto (a confirmar com o negócio)**
O briefing diz "assistente para alunas de um programa de emagrecimento". Os Termos (§1) descrevem "coaching por IA… desenvolvimento pessoal"; a microcopy do prontuário (`lib/microcopy-chat.ts:37-42, 65, 34-36`) oferece metas de "relacionamento sério", "sair mais, conhecer gente", placeholders "recém-separado, voltando a sair", "marcar um date"; os testes seguem o mesmo domínio. Se o produto é emagrecimento, (a) os campos de perfil/metas não fazem sentido para as alunas e (b) Termos e Política não descrevem o tratamento de **dados de saúde** (peso, alimentação, condição física), que são dados sensíveis (art. 5º, II). A Política só cita "informações sensíveis de caráter pessoal" genericamente.
Correção: alinhar `goalTypeLabels`/placeholders ao programa e explicitar nos textos legais a categoria "dados de saúde" e o consentimento específico.

### 3.4 Base legal para dado sensível — **médio (jurídico)**
Termos §6 declara bases "execução do contrato e legítimo interesse". Para dado sensível (art. 11) essas bases não valem; o app de fato colhe consentimento específico (`ConsentGate` → `POST /me/consent/sensitive`, gate 409 na API), mas nem a Política nem os Termos dizem que a base é **consentimento específico e destacado** nem como revogá-lo (não há botão de revogar no app).
Correção: citar art. 11, I nos textos e oferecer revogação (ou explicar que revogar = excluir prontuário).

### 3.5 Consentimento antes do uso — **observação (bem feito, com ressalva a confirmar)**
O fluxo está correto no cliente: login exige aceite da Política no primeiro acesso (`LoginForm.tsx:141-162`, enviado como `consent: true`); perfil, onboarding, metas, progresso e sugestões mostram `ConsentGate` antes de gravar e tratam `CONSENT_REQUIRED_SENSITIVE`. Ressalva: `insights` "percebidos pela Crystal" (fonte `n8n`) chegam da conversa sem passar pelo gate no cliente — a confirmar se a API só gera/grava insights com `consent_sensitive`.

### 3.6 Textos × código — **observação**
Coerentes: "Baixar meus dados" (`/me/export`, `ChatHeader`), "Apagar minhas conversas" (`DELETE /me/data`), "Excluir minha conta" (`DELETE /me/account` com `confirm: "EXCLUIR"`), remoção do token de push no logout/exclusão, cifra do perfil (dito na Política, feito na API — não verificável aqui), backups "cifrados na Cloudflare" (bate com o R2 do plano de infra). Pequenas inconsistências: `/excluir-conta` manda falar "pelo WhatsApp" quando não há `NEXT_PUBLIC_CONTATO_PRIVACIDADE`, enquanto Termos §10 dizem "não há atendimento por canais não oficiais, só ticket no app"; Termos §13 ainda tem "👤 [e-mail de contato]".

### 3.7 `Dockerfile:12-13` + `.env.example` — **baixo**
Só `NEXT_PUBLIC_API_URL` entra como `ARG`. `NEXT_PUBLIC_CONTATO_PRIVACIDADE`, `NEXT_PUBLIC_SENTRY_DSN`, `NEXT_PUBLIC_SENTRY_ENVIRONMENT`, `NEXT_PUBLIC_APP_VERSION` são inlined no build e nunca chegam na imagem — o e-mail de exclusão da conta cai sempre no fallback do WhatsApp. `ANDROID_CERT_SHA256` e `APPLE_TEAM_ID` (runtime, ok) não estão documentados no `.env.example`.

---

## 4. Acessibilidade e PWA

- `components/auth/OtpStep.tsx:164` — **baixo**: `aria-describedby="otp-error otp-timer"` referencia `otp-error` mesmo quando o `<p>` não existe (id órfão).
- `components/chat/ChatHeader.tsx:101` — **baixo**: subtítulo com `role="status"` muda para "digitando…"/"online" a cada resposta; leitores de tela anunciam toda troca (ruído).
- `components/suporte/TicketThread.tsx:55` — **baixo**: `window.confirm` para encerrar ticket, enquanto o chat usa diálogo modal próprio com focus trap; inconsistente e não estilizável.
- `components/equipe/ui.tsx:71-111` (SidePanel) e `NewEntryDialog`/`SetPasswordDialog` — **baixo**: `aria-modal` sem focus trap nem retorno de foco ao fechar (o chat faz isso certo em `chat/page.tsx:119-154`).
- `public/manifest.webmanifest` — **observação**: `theme_color` fixo `#000000` enquanto `layout.tsx` declara `#ededed` no esquema claro; sem `screenshots`/`shortcuts` (instalação enriquecida); `start_url: "/"` cai na página de redirecionamento (ok).
- `public/sw.js:52-67` — **baixo**: cache de `/_next/static/` só é limpo quando `CACHE_VERSION` muda à mão; chunks de deploys antigos acumulam até alguém editar `v2`. Pontos bons: API/SSE nunca entram no cache, navegações são network-only com `offline.html` próprio, `skipWaiting`+`clients.claim`.
- `app/layout.tsx:38-46`, `globals.css:249-251`, `chat/page.tsx:83-95` — **observação (bem feito)**: `viewport-fit=cover`, safe areas, `VisualViewport` para teclado, `prefers-reduced-motion`, `h-dvh`.
- `scripts/gen-icons.mjs` × `scripts/gerar-icones.mjs` — **observação**: dois geradores de ícone com identidades diferentes (verde-petróleo × rosa da marca) escrevendo nos mesmos arquivos; quem rodar por último ganha. Manter um e apagar o outro.

---

## 5. Testes — o que falta

- `lib/use-chat.ts` (445 linhas, o núcleo do produto) **não tem teste**: envio otimista, reconexão com `after=`, refresh no 401 do stream, `syncLatest` (dedupe/fechar bolha), fila offline + `flushQueue`, polling por visibilidade.
- `lib/sse-client.ts`, `lib/push.ts`, `lib/api.ts#uploadFile`, `lib/prontuario.ts#listAll` (cursor repetido/limite de páginas) sem teste.
- `components/native/BiometricLock.test.tsx` não cobre o re-lock por `visibilitychange` — exatamente o cenário do bug 1.1 (um teste "na web, trocar de aba não desmonta os filhos" teria pego).
- `lib/finance.test.ts`: faltam `"1.297"`, `"1.000"`, `"R$1.297"`, string com espaço (1.3).
- `ChatHeader`, `MessageList` (scroll reverso e preservação de posição), `Composer` (upload de imagem, erro de tipo/tamanho, gravação), `chat/page.tsx` (logout com API fora, exclusão com erro), `OnboardingConversationPage` (só a `View` é testada), `financeiro/page.tsx`, `CanalPanel`, `WebhookPanel/WebhookTestForm`, `middleware.ts` (CSP), `sw.js`.
- `scripts/mobile-audit.spec.ts` é Playwright com credenciais demo fixas e não está em `vitest.config.ts` (correto), mas também não há `playwright` em `devDependencies` do `apps/web` (roda pelo root).

---

## Pontos bem feitos (curto)

- Zero markdown/HTML injetado: todo conteúdo de usuário/IA vai como texto; o único `dangerouslySetInnerHTML` é uma constante com nonce.
- CSP por request com nonce + `strict-dynamic`, `frame-ancestors 'none'`, `object-src 'none'`, HSTS em produção; `.dockerignore` exclui `.env*`; nenhum segredo no bundle.
- Sentry opcional por import dinâmico, `sendDefaultPii: false`, `scrub` de CPF/e-mail/OTP com testes.
- CPF nunca em URL (lookup por POST), CPF sempre mascarado na UI; `caminhoSeguro()` para deep link de push nativo; `assetlinks`/AASA validam formato e usam `force-dynamic`.
- Logout e exclusão de conta não redirecionam em caso de falha da API (evitam "achar que saiu"); exclusão exige `confirm: "EXCLUIR"`; fila offline limpa no logout.
- Diálogo de exclusão com focus trap, Escape e retorno de foco; menu com navegação por setas; `aria-live` separado do `role="log"`; rótulos em todos os inputs.
- SW: API e SSE fora do cache, `offline.html` autônomo, ícones maskable separados; `beforeinstallprompt` só após gesto.
- Erros de API traduzidos em microcopy por área, com `UNAUTHENTICATED` sempre levando ao login; padrão `draft/applied` nas listas da equipe (exceto financeiro).

## Contagem

- Arquivos lidos integralmente: **158** (16.066 linhas), sendo 90 fontes `.ts/.tsx/.css/.mjs` em `app/`, `components/`, `lib/`, `scripts/`, 36 arquivos de teste, mais `sw.js`, `manifest.webmanifest`, `offline.html`, `next.config.ts`, `middleware.ts`, `package.json`, `Dockerfile`, `tsconfig.json`, `vitest.config.ts`, `vitest.setup.ts`, `postcss.config.mjs`, `.env.example`, `next-env.d.ts` e `design-system/pwa-audit.md`.
- Achados: **crítico 0 · alto 4 · médio 8 · baixo 19 · observação 13** (44 no total).
