# Revisão de segurança 24/10/2026 · 01 · Autenticação, sessões e tomada de conta

**Alvo:** `LFcrystal766/crystal-web-chat`, commit `fe6dbd7` (o que está em produção), lido só-leitura em `cw-custo-aluno`.
**Modo avaliado:** o de produção, `LOGIN_MODO=email` (aluna entra só com o e-mail da compra + código de 6 dígitos; equipe com e-mail + senha + código).
**Como foi feito:** leitura de todo o código de login, código por e-mail, sessão, cookies, reautenticação da equipe, correção de cadastro pelo suporte e o lado web/iOS; mais um arquivo de testes que **prova** cada achado contra o app em memória (sem tocar em produção nem em serviço externo):

```
cd cw-custo-aluno
pnpm --filter @crystal/api exec vitest run src/seguranca-auth.test.ts     # 10 testes, todos passam = achados confirmados
```

(`--filter api` não acha o pacote; o nome dele é `@crystal/api`.) O arquivo `apps/api/src/seguranca-auth.test.ts` é novo e não foi commitado; nada do repositório foi alterado.

---

## 1. Resumo para o dono (sem jargão)

O miolo está bem feito: o código de 6 dígitos é sorteado do jeito certo, só vale 5 minutos, aceita 5 tentativas e some depois de usado; a senha da equipe é guardada de forma segura; sair ou desligar uma conta derruba a sessão na hora; nada de código, e-mail ou CPF vai para o log. Os pontos que a consultoria apontou em 20/10 sobre o código de confirmação da equipe (B5) **já estão corrigidos** neste commit.

O que precisa de atenção, em ordem de importância:

1. **A senha da equipe não protege a equipe.** A tela da aluna (`/login`) aceita o e-mail de qualquer pessoa da equipe, inclusive admin, e abre o painel só com o código do e-mail, sem pedir senha. Quem tomar a caixa de e-mail de alguém da equipe (phishing num Gmail/Hotmail é o caso mais comum) entra no painel inteiro. Hoje isso está até escrito num teste como comportamento esperado ("equipe entra com e-mail + código, como hoje"). A correção é pequena: a porta da aluna recusa e-mail de equipe; equipe só entra por `/login/equipe` (senha **e** código).
2. **O suporte consegue tomar a conta de qualquer aluna.** Trocar o e-mail de login da aluna no painel não pede o código de confirmação nem motivo (para conta local) — enquanto trocar o CPF, que no modo atual não serve para entrar, pede o código. Como o e-mail é a credencial, quem troca o e-mail e pede o código no novo endereço entra na conta e lê toda a conversa da aluna. Vale para uma pessoa do suporte mal-intencionada ou para um computador do suporte invadido. Correção: pedir o código do e-mail (reautenticação) e motivo em toda troca de e-mail, e avisar o e-mail antigo da troca.
3. **Dá para descobrir quem é aluna da Crystal.** A tela de login responde diferente para e-mail que não existe, aluna que existe, aluna que nunca entrou e conta desligada. Com uma lista de e-mails, um robô descobre quem é cliente (um dado sensível, dado o tema do produto). A consultoria já tinha anotado isso como "decisão de produto"; registro aqui a prova e uma forma de reduzir o dano sem perder a mensagem acolhedora do suporte.
4. **Sessão roubada não cai nunca.** A chave de renovação do app vale 90 dias e é renovada a cada uso, sempre a mesma. Um cookie copiado de um celular (backup, malware) continua valendo indefinidamente, e a aluna não tem onde ver nem derrubar outros aparelhos (só a equipe tem).
5. **Alguém pode encher a caixa de e-mail de uma aluna** com 20 códigos a cada 15 minutos a partir de um só endereço de internet (e sem limite real por e-mail nos reenvios).

Nada aqui é "crítico" no sentido de estar sendo explorado ou aberto a qualquer um sem esforço: os dois "altos" exigem ou invadir uma caixa de e-mail da equipe, ou ter (ou roubar) uma sessão do suporte. Mas são os dois caminhos mais curtos para ler conversas de alunas, e as correções são curtas.

**Contagem:** crítico 0 · alto 2 · médio 4 · baixo 7.

---

## 2. Tabela técnica

Linhas referem-se ao commit `fe6dbd7`. "Prova" cita o nome do teste em `apps/api/src/seguranca-auth.test.ts` ou o raciocínio.

| Id | Gravidade | Arquivo:linha | Cenário de ataque | Prova | Correção proposta |
|---|---|---|---|---|---|
| A2 | **Alto** | `apps/api/src/routes/auth.ts:264,298` (`semBase` pula a base para `role !== "user"` e segue para o código), `auth-otp.ts:149-156` (verify abre sessão com o papel da conta); `auth-email.test.ts:376` fixa o comportamento | Atacante com acesso à caixa de e-mail de alguém da equipe (phishing, senha de e-mail vazada, celular perdido com o e-mail aberto) faz `POST /auth/login {email}` na porta da aluna, recebe o código e entra como admin/superadmin, sem nunca digitar a senha de `/auth/staff/login`. O segundo fator da equipe vira fator único. | Teste **A2**: admin com senha definida; `/auth/staff/login` com senha errada → 401; `/auth/login` só com o e-mail → 200 `step: otp` → verify → `GET /staff/users` → 200. | Em `registrarLoginEmail` (e no modo `cpf_email`): se a conta achada pelo e-mail tem `role !== "user"`, responder como e-mail desconhecido (404 `LOGIN_NOT_FOUND`) ou 403 com texto "Equipe entra em /login/equipe". Equipe só por `/auth/staff/login` (senha + código). Trocar o teste de `auth-email.test.ts:376` para afirmar a recusa. Opcional: exigir senha definida para toda conta de equipe (hoje `passwordHash` pode ser nulo). |
| A3 | **Alto** | `apps/api/src/routes/staff-alunos.ts:295-355` (`PATCH /staff/alunos/:id` troca e-mail de conta local sem `reauth_token` nem motivo), `:244-293` (`trocarEmailDaBase`: só motivo), `staff-alunos-base.ts:103-131` (`POST /staff/alunos/base/:customerId/email`: sem motivo e sem reautenticação). Compare com `staff-alunos-cadastro.ts:180` (CPF exige `reauth_token`) | Pessoa do suporte (ou sessão de suporte sequestrada: XSS, computador invadido, cookie copiado) troca o e-mail de login da aluna para um e-mail dela, pede o código em `/auth/login` e entra na conta da aluna: lê o histórico inteiro da conversa, fotos, perfil. Depois pode trocar de volta. Fica só uma linha de auditoria `aluno.update { fields: ["email"] }`. | Teste **A3**: suporte logado; `PUT …/cpf` com carimbo falso → 403 `REAUTH_REQUIRED`; `PATCH /staff/alunos/:id {email}` sem carimbo → 200; sessão da aluna cai; login com o e-mail novo devolve `user.id` da vítima. | (1) Exigir `reauth_token` (como CPF, acesso, exclusão) e `motivo` obrigatório nas três rotas que trocam e-mail (local, base via PATCH, base via `/base/:id/email`). (2) Mandar aviso ao e-mail **antigo**: "seu e-mail de acesso à Crystal foi alterado; se não foi você, fale com a equipe". (3) Linha de auditoria com `email_hash_antigo/novo` (HMAC, como o rate limit) para investigar. (4) Alerta ao admin quando a mesma pessoa troca mais de N e-mails por dia. (5) Considerar só admin para contas com conversa (suporte só para conta recém-criada sem uso). |
| A1 | Médio | `apps/api/src/routes/auth.ts:287-293` (403 `ACCOUNT_DISABLED` / `LOGIN_INACTIVE`), `:311-316` (404 `LOGIN_NOT_FOUND`), `:318-321` (403 `LOGIN_NOT_RELEASED`), `:329-331` (409 `CONSENT_REQUIRED` antes do código); limite só por IP (`:158`, 50/15 min) e por e-mail (`:159`, 5/15 min). Já anotado em `docs/consultoria/2026-10-20-onda6.md:195` | Robô com lista de e-mails (vazamentos públicos, lista de contatos) descobre quem é cliente da Crystal, quem já usa o app e quem foi desligada — sem precisar de código. 50 e-mails por IP a cada 15 min; com IPv6 (um /64 por cliente) ou proxies baratos, a varredura é ilimitada. Dado sensível: o tema do produto é vida afetiva. | Teste **A1**: quatro e-mails, quatro códigos HTTP distintos (404, 200, 409, 403). | Resposta uniforme para e-mail desconhecido e conhecido: 200 `step: otp` com `challenge_id` aleatório e `masked_email` do que foi digitado, sem enviar nada quando não existe (o verify falha como código errado). A mensagem de apoio ("não achei uma compra com esse e-mail; o suporte atende em…") vai **por e-mail** para o endereço digitado, com limite. Mover a pergunta do consentimento para **depois** do código (grava no verify, como já faz com `consentPending`). Se o dono mantiver a decisão de produto: limitar 404s por IP mais baixo (ex.: 10/15 min), contador global de `LOGIN_NOT_FOUND` por minuto com alerta (vigia), e desafio tipo CAPTCHA/prova-de-trabalho após o 3º 404 do mesmo IP. |
| A5 | Médio | `apps/api/src/routes/auth.ts:86-117` (renovação mantém o mesmo `cw_refresh`, só empurra `expiresAt`), `env.ts:241` (`REFRESH_TTL_S` = 90 dias, janela deslizante, sem teto absoluto), `staff-sessions.ts:35-73` (listar/derrubar aparelhos é só para equipe) | Cookie `cw_refresh` copiado (backup do aparelho, malware no celular, celular emprestado) vale para sempre enquanto o ladrão o usar a cada 90 dias; não há como detectar reuso (sem rotação), a aluna não vê "outros aparelhos" nem consegue derrubá-los; a equipe só se a aluna reclamar. | Teste **A5**: dois `POST /auth/refresh` com o mesmo token → 200 nos dois; o cookie devolvido é idêntico ao original; `expiresAt` avançou. | Rotação com tolerância: ao renovar, emitir refresh novo e manter o anterior válido por 60 s (resolve as renovações simultâneas do S11); reuso de um token já substituído fora da tolerância → revogar a sessão inteira (sinal de roubo). Teto absoluto por sessão (ex.: 180 dias de `createdAt`) além da janela deslizante. Equipe com `REFRESH_TTL_S` menor (7–14 dias). Dar à aluna "Aparelhos conectados" com "sair dos outros" (`/me/sessions` hoje é só equipe). |
| A7 | Médio | `apps/api/src/routes/auth.ts:155-160` (login: 5 por e-mail/15 min), `auth-otp.ts:44-46,200-218` (reenvio: só por IP e por desafio, 3 por desafio) | Um só IP pede 5 códigos e 3 reenvios de cada: **20 e-mails de código em 15 min** na caixa da vítima (80/h). Com mais IPs o teto por e-mail do login segura em 5 desafios, mas cada um rende 4 e-mails. Assédio e desgaste da reputação do remetente (Resend). | Teste **A7**: contador de e-mails do `FakeEmail` = 20; o 6º login → 429. | Contador por endereço de **envios** (login + reenvio), ex.: 6 e-mails por hora e 10 por dia por e-mail (HMAC como chave). Enquanto um desafio do mesmo e-mail está vivo, `POST /auth/login` devolve o **mesmo** `challenge_id` (sem novo e-mail) em vez de abrir outro. Intervalo de reenvio crescente (60 s, 120 s, 300 s). |
| A8 | Médio (condicional) | `apps/api/src/routes/auth.ts:364-662` (modo `cpf_email`), `:611-642` (`LOGIN_CODIGO=nenhum` abre sessão sem código), `env.ts:183`; chave `op_login_codigo` ajustável ao vivo em Operação | Hoje desligado (`LOGIN_MODO=email` ignora). Se alguém voltar a `cpf_email` e ligar "sem código" na área Operação, CPF + e-mail (dados semi-públicos, vazam em todo lugar) passam a ser a credencial inteira: quem tem a lista de uma loja entra em qualquer conta. | Leitura; `auth-sem-codigo.test.ts` documenta o comportamento. | Remover a opção `nenhum` do código, ou só superadmin com reautenticação pode ligá-la, com aviso vermelho na tela e alerta na vigia enquanto estiver ligada. Registrar no runbook: nunca ligar. |
| A4 | Baixo | `apps/api/src/routes/auth-otp.ts:120-156` (verify não compara `challenge.email` com `user.email` atual), `staff-alunos.ts:327-331` (troca de e-mail revoga sessões, não desafios) | Cadastro com e-mail errado (dedo, ou e-mail de outra pessoa). O dono do e-mail errado pede o código (chega na caixa dele). O suporte corrige o e-mail. Nos 5 minutos seguintes, o código antigo ainda abre a conta da aluna para o estranho. | Teste **A4**: desafio emitido para o e-mail antigo; PATCH troca o e-mail; verify com o código antigo → 200 com o `user.id` da aluna. | No verify: se `challenge.email` ≠ `user.email` (minúsculas), apagar o desafio e responder 404 `OTP_CHALLENGE_NOT_FOUND`. Barato e fecha o buraco. |
| A6 | Baixo | `apps/api/src/routes/auth.ts:119-127` (logout só revoga pelo cookie `cw_refresh`) | Pedido de logout que chega só com `cw_access` (cookie de refresh já vencido, apagado ou com `path` fora de `/auth`) responde 204, mas a sessão continua válida no banco: o access token segue abrindo `/me` até vencer (15 min) e um refresh guardado em outro lugar segue renovando. | Teste **A6**: logout só com `cw_access` → 204; `GET /me` com o mesmo cookie → 200. | No logout, também ler `cw_access` (`verifyAccessToken` → `sid`) e revogar essa sessão; responder 204 só depois de revogar o que achou. |
| A9 | Baixo | `apps/api/src/plugins/auth.ts:40` (`jwtVerify(token, secret)` sem `algorithms`) | Hoje sem exploração prática: com chave simétrica o `jose` recusa `none` e algoritmos assimétricos; só sobra HS256/384/512 com o mesmo segredo. É higiene contra regressão futura (troca de biblioteca ou de tipo de chave). | Leitura. | `jwtVerify(token, secretKey(env), { algorithms: ["HS256"] })` e, opcionalmente, `issuer`/`audience` fixos. |
| A10 | Baixo | `apps/api/src/lib/otp-challenge.ts:51`, `services/otp-login.ts:47` (desafio guarda o e-mail em claro no Redis) | Quem lê o AOF/RDB do Redis (ou um `redis-cli` na VPS) vê os e-mails de quem está entrando nos últimos 5 minutos. O mesmo repositório já evita isso nas chaves de rate limit (`rate-limit.ts:76-80`, HMAC) por este motivo. | Leitura. | Guardar o e-mail cifrado (`encryptField` com `ENCRYPTION_KEY`, já existe) ou só o `userId` e reler o e-mail da conta no reenvio. |
| A11 | Baixo | `apps/api/src/lib/password.ts:3-5` (scrypt N=2^14, r=8, p=1) | Se o banco vazar, o custo de quebrar senhas da equipe é ~8× menor que o recomendado (OWASP: N=2^17 para r=8, p=1). Mitigado pelo código por e-mail e pelos limites por e-mail/IP. | Leitura. | Subir para N=2^17 (≈100 ms). O formato guarda os parâmetros, então os hashes antigos continuam válidos até a próxima troca. |
| A12 | Baixo | `apps/api/src/routes/staff-users.ts:152-215` (admin troca papel sem reautenticação), `:221-260` (admin define senha de outra pessoa sem reautenticação e sem derrubar as sessões dela), `staff-alunos-cadastro.ts:232` (liberação manual) e `staff-alunos-base.ts:147` (ligar lote) só com limite de escrita | Sessão de admin sequestrada: promove um suporte a admin, redefine a senha de outro admin (ainda precisa do código do e-mail da vítima, por A2 também não) ou cria acessos gratuitos. Tudo fica na auditoria, mas sem a segunda confirmação que as outras ações perigosas têm. | Leitura. | `reauth_token` para troca de papel, definição de senha por admin, liberação manual e ligar lote. Ao admin definir senha: revogar as sessões do alvo e avisá-lo por e-mail. |
| A13 | Baixo (informativo) | `apps/api/src/routes/auth.ts:268-284,333-343` (conta de revisão recriada no login por quem souber o e-mail; código fixo de 6 dígitos, sem e-mail) | Quem conhece as notas enviadas às lojas (e-mail + código) entra numa conta de aluna "de verdade" (papel `user`) e conversa com a Crystal, gastando tokens do OpenRouter. Sem acesso a dados de outras pessoas. | Leitura; `auth-email.test.ts:395` documenta. | Trocar o código a cada ciclo de revisão (é só variável de ambiente) e deixar `REVIEW_ACCOUNTS` vazio fora das janelas de revisão; limite de mensagens mais baixo para `review: true`. |

---

## 3. Detalhe dos dois achados altos

### A2 · A porta da aluna aceita a equipe

`registrarLoginEmail` acha a conta pelo e-mail (`auth.ts:264`), marca `semBase` para qualquer `role !== "user"` (`:298`) e vai direto para `issueOtpChallenge`. O `/auth/verify` (`auth-otp.ts:154`) cria a sessão com `user.role` da conta, seja ela `support`, `tech` ou `admin`. O `/auth/staff/login` (senha + código) existe, mas é opcional na prática. O teste `auth-email.test.ts:376` ("equipe entra com e-mail + código (como hoje)") fixou isso como comportamento esperado, então foi uma escolha, não um descuido; o custo da escolha é que a segurança do painel (toda a base de alunas, a alma da Crystal, financeiro) depende só da caixa de e-mail de cada pessoa da equipe.

Correção sugerida (meia hora): em `auth.ts` logo após `findByEmail`, `if (user && user.role !== "user") return recusar(request, reply, 404, "LOGIN_NOT_FOUND", MICROCOPY.loginNotFoundEmail)` (mesma resposta de e-mail desconhecido, para não virar oráculo de quem é equipe), e o equivalente no modo `cpf_email`. Ajustar o teste de 376 para afirmar a recusa e o helper `login()` dos testes que entra com equipe pela porta da aluna.

### A3 · Trocar o e-mail da aluna sem o código de confirmação

No modo atual o e-mail **é** a credencial: quem controla o endereço de login controla a conta. Mesmo assim:

- `PATCH /staff/alunos/:id` com `email` para conta local: só `requireArea("alunos")` + `requireRole(["admin","support"])` + limite de 30 escritas/10 min. Sem carimbo, sem motivo (`staff-alunos.ts:295-355`).
- `PATCH /staff/alunos/:id` com `email` para aluna da base: exige `motivo` (texto livre, sem "@"), sem carimbo (`:244-293`).
- `POST /staff/alunos/base/:customerId/email`: nem motivo nem carimbo (`staff-alunos-base.ts:103-131`); a conta do app acompanha o e-mail novo.

Enquanto `PUT /staff/alunos/:id/cpf` (que no modo e-mail não abre nada) exige `reauth_token` (`staff-alunos-cadastro.ts:180`). O teste **A3** mostra o caminho completo até ler `/me` da vítima com a sessão do atacante. O aviso ao e-mail antigo é a medida que dá à aluna a chance de perceber; hoje não existe aviso nenhum.

---

## 4. O que está certo

Confirmado por leitura e, onde indicado, por teste.

**Código por e-mail (aluna e equipe)**
- Sorteio com `crypto.randomInt` (CSPRNG), 6 dígitos (`lib/crypto.ts:24`); `challenge_id` com 32 bytes aleatórios (`otp-login.ts:42`), impossível de adivinhar.
- Só o **hash** do código fica no Redis, com pepper (`hashOtp`), comparação em tempo constante (`safeEqualSecret`, `auth-otp.ts:92`).
- 5 tentativas por desafio com `INCR` atômico (tentativas em paralelo não passam), desafio apagado no bloqueio e no acerto (uso único); vale 5 minutos; reenvio gera código novo e zera as tentativas (`auth-otp.ts:74-118,225-255`). Teste **"O que está certo · código de 6 dígitos"**.
- `dev_code` só sai com `OTP_MODE=mock` **e** `NODE_ENV !== "production"`; produção recusa subir com `OTP_MODE=mock` e exige `RESEND_API_KEY`, `EMAIL_FROM` e `OTP_PEPPER` forte (`env.ts:540-556`). Isso atende a segunda metade do B5 da consultoria.
- Conta desligada ou com prazo vencido **entre** pedir o código e digitá-lo não entra (`auth-otp.ts:131-141`).

**Senha da equipe**
- scrypt com sal por senha, comparação em tempo constante; `verifyPassword` roda o scrypt mesmo quando a conta não existe ou não tem senha, e a resposta é sempre 401 `INVALID_CREDENTIALS`: sem oráculo de e-mail nem de tempo (`auth-staff.ts:48-66`, `password.ts:84-99`). Teste **"login da equipe por senha não revela se o e-mail existe"**.
- Limite por e-mail (5/15 min) e por IP; evento `staff_login_fail` sem a conta de aluna na ficha.
- Troca da própria senha exige a atual, derruba as outras sessões e fica na auditoria (`me.ts:196-243`).

**Reautenticação da equipe (B5 da consultoria 20/10: corrigido)**
- Código preso à **sessão**, só o hash no KV, 10 minutos, intervalo de 60 s entre envios, teto de 4 envios por sessão em 15 min (`reauth.ts:149-156`), 5 tentativas, consumo atômico (`kv.take`), carimbo de 5 minutos e uso único (`reauth.ts:28-42,190-241`). Teste **B5**.
- O carimbo vai no corpo, nunca na URL, e é consumido pelas rotas perigosas: configurações marcadas, Operação, CPF, acesso, exclusão de conta local, cópia e apagamento do titular.
- `JSON.parse` do KV protegido (B11 da consultoria também fechado, `reauth.ts:79-90`).

**Sessões e cookies**
- Refresh token opaco de 32 bytes, guardado só como hash, único no banco (`plugins/auth.ts:88-91`, `schema.prisma` `refreshTokenHash @unique`).
- Access token JWT de 15 min **conferido contra a sessão no banco** a cada pedido: logout, desligamento, troca de papel e exclusão derrubam o acesso na hora, não só o refresh (`plugins/auth.ts:135-144`).
- A renovação relê papel, status e prazo do banco (`auth.ts:92-117`); desligar uma conta é uma função única e transacional que revoga tudo e apaga inscrições de push (`services/account-disable.ts`).
- Cookies `HttpOnly`, `Secure` em produção, `SameSite=Lax`, refresh restrito a `path=/auth`, sem `Domain` (host-only: o site WordPress no apex não os lê); CORS com uma origem só e `credentials`; corpo só JSON (formulário HTML de outro site não passa no schema); `helmet` com CSP `default-src 'none'` na API. Com API e app em hosts diferentes do mesmo domínio, `Lax` + JSON cobre CSRF nas rotas com corpo. Sem fixação de sessão: nada do cliente vira identificador antes do código.
- Sessões da equipe de IP/navegador novo vão para a auditoria (`auth-events.ts:34-54`); a equipe lista e derruba as próprias sessões, admin derruba as de outra pessoa; suporte derruba sessões de aluna pela ficha; `auth_events` mostra as tentativas de entrada da aluna sem IP.

**Base de alunas (Supabase)**
- `app_verificar_login_email` é `security definer`, executável só pela `service_role`; `anon`/`authenticated` sem permissão; e-mail viaja no corpo do POST; CPF não entra nem sai (`docs/supabase/app_verificar_login_email.sql`). O cliente trata 4xx/5xx como "indisponível", nunca como "não encontrado" (`directory.ts:172-174`).
- A identidade da conta é o `contact_id`, não o e-mail: a troca legítima de e-mail na base não cria conta nova nem perde histórico.

**Logs e respostas**
- Headers `cookie`/`authorization` redigidos; o serializador de request não loga headers; query de `/auth`, `/me`, `/staff` nunca entra no log; IP truncado (`app.ts:80-114`). Nenhum `console.*` dos arquivos de auth leva e-mail, CPF ou código; o `MockEmailSender` só imprime o código fora de produção.
- Respostas de erro sem stack; `UserDto` leva só id, nome, CPF mascarado e papel.

**Lado web e app iOS**
- Sem redirecionamento aberto: destinos pós-login fixos (`/` ou `/equipe`), sessão expirada vai para constante `/login?sessao=expirada`; `searchParams` só são lidos para mostrar avisos.
- Nenhum segredo no bundle: só `NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_SENTRY_DSN`, versão; CSP com nonce e `strict-dynamic`, `frame-ancestors 'none'`, HSTS, `Referrer-Policy`.
- Capacitor carrega só `https://app.crystalnowpp.com.br`, `allowNavigation` restrito ao mesmo host, `cleartext: false`; a autenticação do app nativo é a mesma do web (cookies no WKWebView), sem token guardado em `Preferences`. O bloqueio biométrico é uma cortina de privacidade (a sessão continua válida por baixo), o que é adequado para o que promete.

---

## 5. Limites desta revisão

- Testes rodaram contra o app em memória com a base de alunas "nula"; a função do Supabase foi avaliada só pelo SQL versionado. Nada foi executado contra `app.`/`api.crystalnowpp.com.br`.
- A premissa "a base é a verdade do e-mail" (`auth.ts:231-240`) faz com que **qualquer** caminho que altere o e-mail em `leticia_crystal_customers` (RPCs da equipe, fluxo de compra do n8n, SQL direto) seja um caminho de tomada de conta. As RPCs estão cobertas por A3; o fluxo de compra e os webhooks são de outra dimensão desta revisão e devem conferir se uma compra pode **alterar** o e-mail de um cadastro existente em vez de criar outro.
- Limite por IP (`RATE_AUTH_IP_MAX`) depende de `TRUST_PROXY=1` com o Traefik anexando o IP real; com IPv6 um só cliente tem milhares de IPs, então os limites por **e-mail** (A7) e a resposta uniforme (A1) são os que de fato seguram varredura e assédio.
