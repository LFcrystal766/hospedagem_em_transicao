# Revisão geral de 02/10/2026: código, testes e evidências

Pedido do Luiz em 02/10: "revisão geral em todo o código, cada linha, cada minúcia;
testes e print dos testes; tudo". Esta pasta é a resposta. Nada foi alterado nos
repositórios durante a revisão: só leitura, execução de testes e gravação das saídas.

## O que foi revisado

| Repositório | Commit | Escopo |
|---|---|---|
| `LFcrystal766/crystal-web-chat` | `44f356b` | API (Fastify/Prisma), web (Next.js), nossa Crystal, `shared`, mobile, e2e, CI, Dockerfiles |
| `LFcrystal766/hospedagem_em_transicao` | `a582ab2` | `bootstrap-vps.sh`, as 3 stacks do Swarm, stacks da agência, fluxos do n8n, scripts do Cloudflare |

Seis revisores independentes leram o código inteiro, cada um numa área, com a
instrução de confirmar cada achado relendo o trecho antes de reportar. Total lido:
**~48 mil linhas em ~450 arquivos**. Os seis relatórios estão nesta pasta
(`rev-*.md`), cada achado com `arquivo:linha`, gravidade e correção sugerida.

## Testes executados (as saídas estão nos arquivos `0N-*.log`)

| # | Verificação | Resultado | Evidência |
|---|---|---|---|
| 1 | Typecheck dos 4 pacotes (`tsc --noEmit`) | ✅ sem erro | `01-typecheck-lint.log` |
| 1 | Lint (`eslint .`) | ✅ sem erro | `01-typecheck-lint.log` |
| 2 | Testes `shared` | ✅ 64/64 | `02-testes-shared-crystal-api.log` |
| 2 | Testes da nossa Crystal | ✅ 38/38 | idem |
| 2 | Testes da API | ✅ 432/432 | idem |
| 3 | Testes do web | ✅ 236/236 | `03-testes-web.log` |
| 4 | `bash -n` nos 4 scripts | ✅ 4/4 | `04-shellcheck-yaml.log` |
| 4 | `shellcheck` | ✅ 0 erros; 1 aviso (falso positivo: contador de laço) | idem |
| 4 | YAML das 3 stacks | ✅ válidos | idem |
| 5 | `pnpm audit --prod` (o que vai para a imagem) | ✅ nenhuma vulnerabilidade | `05-audit-dependencias.log` |
| 5 | `pnpm audit` completo | 9 em ferramentas de desenvolvimento (eslint, vitest); não vão para produção | idem |
| 6 | Build de produção do web (`next build`) | ✅ compilou, 26 páginas | `06-build-web.log` |
| 7 | E2E no navegador (Playwright, Chromium, build de produção + API em modo demo) | ✅ **19 passaram, 1 oscilou** e passou na repetição | `07-e2e-playwright.log` e `07-e2e-relatorio-html/index.html` |
| 8 | Cobertura dos testes | shared 96%, API 78%, Crystal 74%, web 35% (linhas) | `08-cobertura.log` |
| 9 | Migrações do Prisma aplicadas do zero num Postgres vazio | ✅ 14/14 aplicaram | `09-prisma-migracoes.log` |
| 9 | `prisma migrate diff` (migrações × schema) | ⚠️ divergência de tipo em `finance_entries` (ver M-DB1) | idem |
| 10 | **Smoke real da API contra o Postgres** (login com OTP, mensagem, histórico, exportação, exclusão de conta) | ✅ tudo respondeu certo; usuário e mensagens apagados, cópia anônima e auditoria gravadas, 0 erros no log | `10-smoke-prisma.log` |

Total: **770 testes unitários/integração + 20 testes de ponta a ponta, todos verdes.**

Observações sobre os testes:
- O e2e falhou duas vezes antes por causa **deste ambiente** (faltavam `rsync` e o Chromium
  na versão do Playwright 1.62), não do código. Está anotado no próprio log.
- A oscilação do teste de onboarding é do teste: ele olha o botão de consentimento num
  instante só (`isVisible()` sem espera). Correção de uma linha no teste.
- **Nenhum teste automatizado exercita a camada Prisma** (`apps/api/src/db/prisma-*.ts`,
  ~1.200 linhas, 0% de cobertura): os 432 testes da API usam repositórios em memória. Por
  isso fiz o smoke real (item 10). Falta um conjunto de testes de integração com Postgres.

## Resultado da leitura, por área

| Área | Arquivos / linhas | Crítico | Alto | Médio | Baixo | Obs. | Relatório |
|---|---|---|---|---|---|---|---|
| API: rotas, auth, plugins | 66 / 10.103 | 0 | 3 | 13 | 14 | 6 | `rev-api-rotas.md` |
| API: serviços, banco, migrações | 91 / 10.082 | 0 | 2 | 17 | 26 | 7 | `rev-api-servicos.md` |
| Web (Next.js, PWA) | 158 / 16.066 | 0 | 4 | 8 | 19 | 13 | `rev-web.md` |
| Nossa Crystal + shared | 47 / 3.835 | 0 | 3 | 6 | 17 | 10 | `rev-crystal-shared.md` |
| VPS: bootstrap, stacks, Cloudflare | 17 / 5.197 | 0 | 2 | 17 | 15 | 11 | `rev-vps.md` |
| CI, Docker, mobile, e2e, docs das lojas | 71 / 3.418 | 0 | 4 | 10 | 22 | 9 | `rev-ci-mobile.md` |
| **Total** | **450 / 48.701** | **0** | **18** | **71** | **113** | **56** | |

**Nenhum achado crítico** (exploração direta de dado sensível ou perda de dados sem
pré-condição). Dos 18 "altos", 3 não procedem depois de conferidos (abaixo), e 2 já estão
mitigados pela configuração da VPS. Sobram **13 altos reais**.

## Achados que NÃO procedem (conferidos por mim)

1. **"O Chatwoot não assina os webhooks"** (`rev-api-rotas.md`, A2). Conferi no código-fonte
   do Chatwoot v4.18.0 (`lib/webhooks/trigger.rb`, `app/listeners/agent_bot_listener.rb`,
   `app/listeners/webhook_listener.rb`): quando a inbox ou o robô tem `secret`, ele envia
   `X-Chatwoot-Timestamp` e `X-Chatwoot-Signature = sha256=HMAC(secret, "ts.body")`,
   exatamente o que a API confere. A inbox de API e o agent bot geram o segredo
   automaticamente (`WebhookSecretable`). O `atendimento-teste` do bootstrap confirma isso na
   prática quando o Chatwoot subir.
2. **"Textos de relacionamento fora do domínio" e "dados de saúde não declarados"**
   (`rev-web.md` 1.x, `rev-crystal-shared.md` observação). **Erro meu na instrução aos
   revisores**: descrevi a Crystal como assistente de um "programa de emagrecimento". O
   produto é **coach de relacionamento com IA** (textos das lojas, prompt da nossa Crystal,
   onboarding). Os textos de perfil, metas e onboarding estão coerentes com o produto.
   Permanece válido só o que não depende do domínio: placeholders do DPO e base legal do
   dado sensível (vida afetiva é dado sensível pela LGPD, art. 5º, II).
3. **`TRUST_PROXY` desligado em produção** (`rev-api-rotas.md`, A1). O bootstrap grava
   `TRUST_PROXY=1` no `api.env`, então o rate limit por IP funciona atrás do Traefik. Fica
   como melhoria (médio): a API deveria recusar subir em produção sem esse valor.
4. **Mais de uma réplica da API** (`rev-api-rotas.md` M8, `rev-api-servicos.md` M1). A stack
   fixa `replicas: 1` e `order: stop-first`. Vale deixar documentado no YAML por que não
   escalar.

## Os 13 altos que procedem, em ordem de importância

**Segurança e privacidade**

1. **Segredos visíveis no spec do Swarm** (`rev-vps.md` A1). `docker stack deploy` lê o
   `env_file` no cliente e grava cada variável em `ContainerSpec.Env`: `docker service inspect`
   e a tela Env do Portainer mostram `ENCRYPTION_KEY`, `CPF_SALT`, `SUPABASE_SERVICE_ROLE_KEY`,
   `SECRET_KEY_BASE` etc. Quem chega lá já é root ou admin do Portainer (restrito por IP), mas
   a regra do projeto ("nunca no spec") não está sendo cumprida e os cabeçalhos dos YAML dizem
   o contrário. Correção: Docker `secrets` montados em `/run/secrets` (Postgres e n8n aceitam
   `*_FILE`; app e Chatwoot precisam de uma linha no entrypoint). Enquanto isso: corrigir os
   cabeçalhos e tratar a saída de `docker service inspect` como segredo.
2. **Redis do n8n sem senha na rede pública do Swarm** (`rev-vps.md` A2). Herdado da stack da
   agência. Qualquer contêiner da `network_swarm_public` (app, Chatwoot) alcança `n8n_redis:6379`.
   Correção: `--requirepass` + `QUEUE_BULL_REDIS_PASSWORD` no `preparar`, ou rede interna só do n8n.
3. **Exclusão de conta não alcança o Chatwoot** (`rev-api-servicos.md` A1). Com
   `CHAT_TRANSPORT=chatwoot`, a conversa fica na inbox depois do purge e, como o contato é
   pelo telefone, o próximo envio reaproveita a conversa antiga. Correção: na exclusão, apagar
   o contato pela API do Chatwoot (ou resolver a conversa e apagar as mensagens) e auditar.
   **Obrigatório antes de `app-canal chatwoot`.**
4. **Fila offline do app não é por usuário** (`rev-web.md` 1.2). Mensagem digitada sem rede
   fica no `localStorage` sem o id do usuário e não é limpa quando a sessão expira; outra
   pessoa no mesmo navegador enviaria a mensagem da anterior. Correção: chave por usuário e
   limpeza ao expirar a sessão.
5. **Web Push aceita qualquer URL como destino** (`rev-api-rotas.md` M6, promovido). O
   servidor faz POST para a URL que o cliente mandar, inclusive endereços internos da VPS
   (SSRF cega). Correção: lista de domínios de push permitidos e recusa de IP privado.
6. **Cópia anônima deixa passar nomes** (`rev-api-servicos.md` A2). Nomes em início de frase
   ou em minúsculas ("a zuleide ligou") sobrevivem à redação por regras. Decisão jurídica:
   tratar a tabela como **pseudonimizada** (prazo e acesso restrito) ou acrescentar uma
   passada de redação por modelo antes de gravar.
7. **API roda como root na imagem** (`rev-ci-mobile.md` A2, `rev-api-servicos.md`). Web e
   Crystal já rodam sem root. Correção: `USER node` no Dockerfile da API (conferir permissão
   da pasta de uploads).

**Correção e robustez**

8. **Abort do cliente não chega ao OpenRouter** (`rev-crystal-shared.md` 1). `req.raw.on("close")`
   não dispara no Fastify 5; quem fecha o app no meio da resposta deixa o modelo gerando (e
   cobrando) até o fim. Correção: `reply.raw.on("close")`. O revisor confirmou com teste isolado.
9. **Pool do Postgres da Crystal sem `on("error")`** (`rev-crystal-shared.md` 2). Um reinício
   do Postgres derruba o processo da Crystal (o Swarm sobe de novo, mas com respostas perdidas).
   Correção: `pool.on("error", log)`.
10. **Em turno de risco, falha do modelo sai sem o CVV** (`rev-crystal-shared.md` 3). Se a
    pessoa escreve algo que indica risco e o modelo falha, a resposta de erro não traz contato
    de ajuda. Correção: a camada determinística (`garantirContatos`) também no caminho de erro.
11. **Robô do Chatwoot pode perder mensagem num reinício** (`rev-api-rotas.md` M7, promovido
    por ser código novo de hoje). Responde 200, grava o dedup e trabalha depois; um reinício
    no meio perde a mensagem e o reenvio do Chatwoot vira "duplicata". Correção: liberar a
    chave de dedup quando a tarefa falha e, no boot, passar para a equipe as conversas pendentes.
12. **`continue-on-error: true` no job e2e do CI** (`rev-ci-mobile.md` A1). Os 20 testes de
    navegador nunca quebram o build. Correção: remover a linha (agora que o e2e está estável).
13. **Microfone sem `NSMicrophoneUsageDescription` no iOS** (`rev-ci-mobile.md` A3). O app
    grava áudio; sem a descrição, o iOS encerra o app e a Apple rejeita. Correção: duas linhas
    no `Info.plist`.

Um 14º item é de conteúdo, não de código: **a Política de Privacidade e os Termos publicados
têm "[nome e e-mail do encarregado — a preencher]"** no lugar do DPO. Precisa do nome.

## Médios que valem corrigir na mesma rodada (pequenos e de segurança)

- `/auth/verify` não confere conta desligada; contador de tentativas do OTP não é atômico;
  `PUT /me/password` sem rate limit e sem derrubar as outras sessões (`rev-api-rotas.md` M1, M2, M4).
- `crystal.forget` fora de try/catch depois do purge: Crystal fora do ar faz a exclusão
  responder 500 depois de já ter apagado (`rev-api-rotas.md` M3).
- Guards de produção: exigir `DATABASE_URL`, `REDIS_URL`, `TRUST_PROXY` e `https` em
  `CRYSTAL_API_URL` (`rev-api-rotas.md` A3, A1, B8, M11).
- Admin lê mídia de qualquer aluna sem auditoria; lookup de CPF pela equipe sem auditoria nem
  limite (`rev-api-rotas.md` M5, M9).
- 401/402/403 do OpenRouter (crédito acabou) tratados como "indisponível" e tentados de novo
  (`rev-crystal-shared.md`); a vigia deveria distinguir.
- `z.coerce.boolean()` em `shared/finance.ts` faz `"false"` virar `true` (`rev-crystal-shared.md`).
- `parseBRL("1.297")` vira R$ 1,30; busca do financeiro sem debounce (`rev-web.md` 1.3, 1.4).
- `BiometricLock` remonta a tela inteira a cada troca de aba na web (perde texto digitado,
  aborta stream) (`rev-web.md` 1.1).
- Migrações: `TIMESTAMPTZ` nas migrações 10/11 vs `DateTime` no schema (`migrate diff` acusa,
  confirmado no log 09); pastas sem zero à esquerda aplicam em ordem `0,1,10,11,12,13,2,…`
  (funcionou até aqui, mas uma `14_` vai antes da `2_`); faltam índices em
  `users.crystal_contact_id`, `messages.created_at`, `users.email` (`rev-api-servicos.md`).
- `backup-fora-config` apaga a configuração que funcionava se o teste falhar; `volume rm || true`
  no `app-recomecar`; cron roda cópia congelada do script; listagem do R2 sem paginação
  (`rev-vps.md` M2, M4, M5, M13).
- Token do Cloudflare na linha de comando do curl (visível no `ps`) (`rev-vps.md` M10).
- `//super_admin` pode contornar a lista de IPs do Traefik (a confirmar na VPS) (`rev-vps.md` M6).
- Actions do GitHub por tag sem SHA; sem Dependabot; `node:22-alpine` sem digest (`rev-ci-mobile.md`).

## Decisões que são do Luiz

1. **DPO**: nome e e-mail do encarregado para a Política e os Termos.
2. **Cópia anônima**: tratar como pseudonimizada (com prazo, ex.: 24 meses) ou investir em
   redação por modelo? Recomendo a primeira, com revisão jurídica do texto da Política.
3. **Segredos do Swarm**: migrar para Docker `secrets` agora (meio dia, exige subir as stacks
   de novo) ou depois do Chatwoot no ar? Recomendo logo depois do Chatwoot, numa janela calma.
4. **Equipe de atendimento**: quem olha a caixa do Chatwoot quando o robô passa a conversa.
   Sem resposta, a mensagem ao aluno deve deixar de prometer atendente.

## Ordem de correção proposta

1. **Rodada 1, hoje**: itens 8, 9, 10 (Crystal), 11 (robô), 12 (CI), 13 (iOS), 4 (fila
   offline), 5 (SSRF do push), 7 (root), e os médios de auth e guards. Tudo pequeno, com teste.
2. **Rodada 2, antes de `app-canal chatwoot`**: item 3 (exclusão no Chatwoot), item 2 (Redis
   do n8n), `//super_admin`, aviso ao aluno conforme a decisão 4.
3. **Rodada 3, janela calma**: item 1 (Docker secrets), migrações (timestamptz, índices,
   nomes com zero), testes de integração com Postgres, Dependabot e SHAs das actions.
4. **Conteúdo**: DPO e revisão jurídica da cópia anônima.

## Lacunas de teste mais importantes

- Camada Prisma inteira (0%); `use-chat.ts` (núcleo do chat no web, 445 linhas), `sse-client`,
  `push`, `uploadFile`; `MemoriaPostgres` da Crystal; abort do cliente (por isso o item 8
  passou despercebido); conta desligada entre os dois passos do login; OTP concorrente;
  `X-Forwarded-For`; endpoint de push inválido; reenvio de webhook depois do TTL.

## Arquivos desta pasta

| Arquivo | Conteúdo |
|---|---|
| `00-RELATORIO.md` | Este consolidado |
| `01-typecheck-lint.log` … `10-smoke-prisma.log` | Saídas brutas de cada verificação |
| `07-e2e-relatorio-html/` | Relatório HTML do Playwright (abrir `index.html`), com o trace da tentativa que oscilou |
| `rev-api-rotas.md`, `rev-api-servicos.md`, `rev-web.md`, `rev-crystal-shared.md`, `rev-vps.md`, `rev-ci-mobile.md` | Os seis relatórios de leitura, achado por achado |
