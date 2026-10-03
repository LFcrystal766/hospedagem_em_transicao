# Squad do PRD de Otimização: terminais em paralelo

Como executar o "PRD de Otimização Crystal" (doc do Luiz, 5 abas, 26 requisitos em 3
etapas) com vários terminais do Claude Code ao mesmo tempo, sem que eles se atropelem.
Lido inteiro em 03/10: Visão geral, Etapa 1 (8 itens), Etapa 2 (11), Etapa 3 (7) e
Fora do escopo (21 itens recusados, 4 riscos assumidos).

## O que o PRD é, em uma olhada

| | |
|---|---|
| Formato | Cada item com Decisão, Objetivo, Hoje (com `arquivo:linha`), O que fazer, Textos prontos, Onde mexer, Critérios de aceite, Fora, Depende de, Cuidados |
| Base | Commit `1e17b44` do `crystal-web-chat`. O atual é `44f356b`: só 11 arquivos mudaram desde então (robô do Chatwoot), então as linhas citadas ainda valem quase todas |
| Regra de ouro | Etapa seguinte só começa com o portão da anterior fechado. A etapa 2 vai ao ar numa publicação só (o P11 trava a conversa de todo aluno até salvar o perfil) |
| Testes | Todo item com tela exige iPhone (Safari e instalado) e Android (Chrome); a equipe não tem Android. Sem ambiente de teste: cada publicação vai direto aos alunos |
| Ordem dentro da etapa | Fixa, porque cada item reaproveita arquivo do anterior (`suporte.ts`, `imagem.ts`, `CrystalAvatar`, `crystal-status.ts`, rota `/me/marks`, página `/equipe/crystal`) |

## Análise: o que pode dar errado e como o squad evita

1. **Arquivos quentes.** `GET /me` (`routes/me.ts` + `meResponseSchema`) é mexido por P10,
   S08, P11, P02, P15, S27 e P09. `services/messages.ts` por S02, S03, S08, S26, S06.
   `lib/use-chat.ts` por S02, S11, P11, S26, S06. `Composer.tsx` por S02, S03, S26, P12.
   `ChatHeader.tsx` por P01, P17, P14, P09. Em paralelo, isso vira conflito de merge
   todo dia. Solução: **um dono por arquivo quente em cada etapa**, e os outros pedem a
   mudança a ele (ou fazem PR pequeno em cima da branch dele), nunca editam sozinhos.
2. **Sequência dura dentro da etapa.** A ordem do PRD existe por reaproveitamento, não por
   necessidade de um terminal só. Dá para paralelizar em **trilhas** que compartilham
   pouco, com os arquivos de ligação (ex.: `imagem.ts`, `suporte.ts`) criados primeiro,
   em commits pequenos, na branch de integração.
3. **Hoje a equipe não tem Android nem Galaxy.** Metade dos critérios de aceite exige. É a
   pendência número 1 do próprio PRD. Agente nenhum substitui o aparelho: a trilha de QA
   em aparelho é humana e começa junto com a etapa 1.
4. **Publicação direta aos alunos.** Cada etapa precisa de uma versão de volta (`app-subir`
   com a tag anterior) decidida antes de publicar, e a etapa 2 de backup na hora
   (`bootstrap-vps.sh backup`) porque o P13 apaga `onboarding_states`.
5. **Choque com a revisão de 02/10.** O PRD já corrige dois achados da revisão (Q07 fecha o
   `/auth/verify` com conta desligada; S27 restringe o endpoint do push). Os outros altos
   da revisão (fila offline por usuário, API sem root, abort da Crystal, pool do Postgres,
   CVV no erro, dedup do robô, plist do iOS, e2e no CI, exclusão no Chatwoot, Redis do
   n8n) **não estão no PRD** e mexem nos mesmos arquivos quentes. Entram numa trilha
   própria de "blindagem", merjada **antes** de a etapa 1 começar, para ninguém
   construir em cima de bug conhecido.
6. **S06 tira o streaming.** A API passa a esperar a resposta inteira e dividir em bolhas.
   A nossa Crystal continua emitindo SSE (o robô do Chatwoot usa o evento `done`); nada
   quebra, mas o prazo de 60 s vira o teto visível de "digitando…" em resposta longa.
7. **S11 para de girar a chave de renovação.** É troca consciente (cookie fixo por 90 dias
   em vez de rotação): o próprio PRD manda passar pelo agente `seguranca`. Mitigações já
   previstas: revogação no Sair, no painel e por reembolso; limpeza das sessões vencidas.
8. **P17 tira "Baixar meus dados" e "Apagar conversas" do app.** A lei continua obrigando a
   atender: vira pedido ao suporte (pendência 11 do PRD, sem dono). Precisa de alguém.
9. **Base de alunos (S10) ficou fora.** Só entra quem foi criado à mão (`app-aluno`) até a
   transferência do Supabase. Isso limita o lançamento, não o PRD.

## O squad

Seis cadeiras: **1 integrador, 4 terminais de desenvolvimento e 1 QA em aparelho**
(humana). Mais do que 4 terminais em código aumenta conflito sem acelerar, porque os
arquivos quentes são poucos.

| Cadeira | Quem | Papel |
|---|---|---|
| **T0 · Integrador** | Esta sessão (Claude) | Abre as branches, faz o S24 (só documentos), merja na ordem do PRD, roda `lint`, `typecheck`, `test`, `test:e2e` a cada merge, mantém `docs/otimizacao/`, cuida do repositório de hospedagem (`APP_EXTERNOS`, migrações, backup), prepara cada publicação e a volta. Dono do `GET /me` e do `schemas.ts` em todas as etapas |
| **T1 · Conta e sessão** | Terminal Claude Code | Autenticação, sessão, webhooks, tela de início |
| **T2 · Conversa e mídia** | Terminal Claude Code | `messages.ts`, `use-chat.ts`, `Composer`, `MessageBubble`, a nossa Crystal (`apps/crystal`) |
| **T3 · Painel e perfil** | Terminal Claude Code (pode ser o Igor) | Área da equipe, formulário de perfil, componentes novos (`CrystalAvatar`, `Tutorial`, `InstallBanner`) |
| **T4 · Blindagem e infra** | Terminal Claude Code | Os altos da revisão de 02/10, Dockerfile, CI, iOS, hospedagem (Redis do n8n, secrets). Termina antes da etapa 1 e vira reserva (revisor de PR) depois |
| **QA · Aparelhos** | Luiz (iPhone) + alguém com Android e Galaxy | Roda os critérios de aceite de aparelho de cada item assim que o integrador avisa "pronto para testar", registra no doc do PRD (comentário no item) o que não bateu |

### Trilhas por etapa

Cada linha é uma branch de trilha (`otimizacao/e1-conta`, `otimizacao/e1-midia`…) que
nasce da branch de integração da etapa (`otimizacao/etapa-1`) e volta para ela por PR,
na ordem da coluna "merge". Nada vai direto para `claude/gracious-shannon-6x9l5j` sem
passar pela integração.

**Antes da etapa 1 (1 a 2 dias)**

| Trilha | Itens | Observação |
|---|---|---|
| T0 | **S24** guias + `docs/otimizacao/` (as 5 abas em Markdown, já convertidas) | Só `.md`. Destrava todo o resto: hoje os guias proíbem tutorial, papel de parede, bolhas e tiram o CPF da tela |
| T4 | Blindagem: abort e pool da Crystal, CVV no erro, dedup do robô, fila offline por usuário, API sem root, plist do iOS, `continue-on-error` do CI, guards de produção (`DATABASE_URL`, `REDIS_URL`, `TRUST_PROXY`), senha no Redis do n8n, exclusão de conta apagando no Chatwoot | Merge antes de T1–T3 começarem a mexer nos mesmos arquivos |
| T0 | Hospedagem: `APP_EXTERNOS` ganha `REFUND_WEBHOOK_SECRET*`, `TRANSCRIPTION_API_URL`, `TRANSCRIPTION_API_KEY*`, `TRANSCRIPTION_MODEL`, `TRANSCRIPTION_TIMEOUT_MS`; `CRYSTAL_MODEL_RESERVA` já está | Numa mudança só, como o PRD pede |

**Etapa 1 · Base, conta e a Crystal que entende (3 a 4 dias de código)**

| Trilha | Itens, na ordem | Arquivos que é dona | Merge |
|---|---|---|---|
| T1 | **Q07** webhook de reembolso → **S11** sessão longa → **Q09** DPO | `routes/auth*.ts`, `routes/refund-webhook.ts`, `lib/api.ts` (web), `LoginForm`, `retention.ts`, `lib/suporte.ts`, páginas legais | 1º e 2º |
| T2 | **S02** áudio transcrito → **S03** print lido | `services/messages.ts`, `services/crystal.ts`, `services/transcription.ts`, `apps/crystal/**`, `Composer`, `MessageBubble`, `use-chat.ts`, `lib/imagem.ts` (cria no 1º dia e sobe sozinho) | 3º e 4º |
| T3 | **P10** foto da Crystal → **S08** memória, resumo, fuso | `routes/staff-crystal.ts`, `app/(equipe)/equipe/crystal/`, `CrystalAvatar`, `apps/crystal/src/memoria.ts` e `resumo.ts` (combina com T2, que é dono de `app.ts`) | 5º e 6º |
| T0 | `GET /me` (`crystal_photo_url`, `x-timezone`), `docs/crystal-api.md`, `.env.example`, portão 1 | | contínuo |
| QA | Critérios de aparelho de cada item ao chegar na integração; o teste de **8 dias sem uso** do S11 começa no dia em que o S11 for publicado e não segura o portão | | |

Ponto de atenção: S08 mexe em `apps/crystal/src/app.ts` (ordem da lista ao modelo) que
S02 e S03 também mexem. T2 fecha S02/S03 primeiro; T3 faz o S08 em cima.

**Etapa 2 · Primeiro acesso e tela de início (5 a 6 dias de código, 1 publicação)**

| Trilha | Itens, na ordem | Arquivos que é dona | Merge |
|---|---|---|---|
| T1 | **P01** tela de início e regra de voltar → **P11** trava do perfil → **P07** Crystal como contato | `app/(chat)/page.tsx`, `lib/voltar.ts`, `ChatHeader` (seta), `sw.js` (`/?abrir=chat`), `lib/crystal-status.ts` | 1º, 4º, 7º |
| T3 | **S25** suporte em cartões → **P13** perguntas do perfil → **P06** → **P03** foto e nome | `app/(chat)/suporte/`, `app/(chat)/perfil/`, `packages/shared/prontuario.ts` (`profileSchema`, `isProfileComplete`), `services/prontuario.ts`, migrações P13 e P03, `next.config.ts` (redirects) | 2º, 3º, 5º, 6º |
| T2 | **P17** menu curto → **P02** tutorial → **P15** faixa de instalar → **S27** notificações | `AppMenu`, `Tutorial`, `InstallBanner`, `InstallGuideSheet`, `lib/install.ts`, `lib/push.ts`, `register-sw.ts`, `routes/staff-notices.ts`, `services/push.ts`, migrações P02/P15/S27 | 8º a 11º |
| T0 | `GET /me` (`profile_complete`, `chat_unlocked`, `marks`, `notices_enabled`), rota `/me/marks`, ordem das 5 migrações, backup antes de publicar, `CRYSTAL_ONBOARDING_URL` conferida na VPS, portão 2 | | contínuo |

T2 começa o P17 assim que o esqueleto do P01 (tela com os três botões) estiver na
integração, não precisa esperar o P11. P02 precisa de P07 e P13 (alvos do tutorial): T2
faz `Tutorial.tsx` genérico enquanto espera e liga os alvos no fim.

**Etapa 3 · Conversa com cara de WhatsApp (4 a 5 dias de código)**

| Trilha | Itens, na ordem | Arquivos que é dona | Merge |
|---|---|---|---|
| T1 | **P08 + P16** papel de parede e temas (mesmo PR) → **P14 + P09** cabeçalho (mesmo PR) | `globals.css`, `theme.ts`, `manifest`, `offline.html`, `sw.js` (`CACHE_VERSION`), `ChatHeader`, `lib/crystal-status.ts` (campo `crystal`), `deps.ts` (`channelState`) | 1º e 2º |
| T2 | **S26 + S06** tiques, reenvio, bolhas e ritmo (mesmo PR) | `messages.ts`, `services/bolhas.ts`, `use-chat.ts`, `MessageBubble`, `StatusTicks`, `MessageList`, `stream-hub.ts`, rota `/messages/:id/retry`, `apps/crystal/src/prompt.ts` | 3º |
| T3 | **P12** áudio: fase 1 tocador → fase 2 gravar → fase 3 segurar | `AudioPlayer`, `Composer` (painel de gravação), `uploads.ts` (Range), migração P12, `PUT /staff/crystal/ritmo` na página do painel (com T2) | 4º (fase 3 só com aprovação em aparelho) |
| T0 | `claro.png`/`escuro.png` conferidos, `CACHE_VERSION`, migração P12 depois das da etapa 2, portão 3 | | contínuo |

## Mecânica, para não se atropelar

- **Uma branch de integração por etapa**, uma branch por trilha, PR por item (ou por par
  do PRD). Título do PR = ID do item. O integrador merja na ordem da coluna "merge".
- **Cada PR traz** os testes do item (os "Teste automatizado" dos critérios), `lint` +
  `typecheck` + `test` verdes, e a lista dos critérios de aparelho que ainda faltam.
- **Arquivo quente só pelo dono.** Quem precisar de uma linha nele pede no PR do dono ou
  faz um PR de 10 linhas em cima da branch dele.
- **Textos do PRD são literais.** Copiar como estão; nada de "melhorar" a frase. Se um
  texto não couber, o integrador anota no doc do PRD, no item, antes de mudar.
- **Agente `seguranca`** (do próprio repositório) revisa Q07, S11, S02, S03, S08, P10 antes
  do merge, como o PRD exige para o portão 1.
- **Publicação**: só no portão da etapa, pelo integrador, com a tag anterior anotada para
  voltar. Etapa 2: `bootstrap-vps.sh backup` antes, e os 11 itens numa tag só.
- **Diário**: o integrador mantém em `docs/otimizacao/andamento.md` o estado de cada item
  (em código, em integração, aguardando aparelho, publicado) e as pendências. É o que o
  Luiz lê.

## Estimativa honesta

| Fase | Código (4 terminais) | Aparelho e portão | Calendário |
|---|---|---|---|
| Pré: S24, blindagem, hospedagem | 1–2 dias | — | semana 1 |
| Etapa 1 | 3–4 dias | 1–2 dias (o teste de 8 dias corre em paralelo) | semana 1–2 |
| Etapa 2 | 5–6 dias | 2 dias + publicação única | semana 2–3 |
| Etapa 3 | 4–5 dias | 2 dias (fase 3 do P12 pode sair) | semana 3–4 |

Três a quatro semanas de calendário, com os terminais rodando em paralelo e os
aparelhos disponíveis desde o primeiro dia. Sem Android, cada portão atrasa até achar um.

## O que trava agora (do próprio PRD, ordem do que trava primeiro)

1. **Android com Chrome** para os testes (a equipe só tem iPhone). Trava os portões.
2. **Serviço de transcrição e a chave** (OpenAI ou Groq, formato `/audio/transcriptions`).
   Sem ela, o S02 publica com a resposta fixa "não consegui entender esse áudio".
3. **Origem dos eventos de reembolso** (qual plataforma dispara, se manda CPF e o
   `Authorization: Bearer`). Sem isso, o Q07 só corta pelo painel.
4. **Quem roda os comandos na VPS** (`app-definir`, `app-subir`, `backup`): hoje é o Luiz
   com esta sessão. Continua assim, salvo decisão contrária.
5. **Quem atende os pedidos de cópia e exclusão de dados** que vão chegar ao suporte
   depois do P17.
6. Galaxy com Samsung Internet (etapa 2), e-mail de acesso dos alunos (P15), prints do
   WhatsApp no iPhone para as cores (P16), foto da Crystal (P10).

## Como abrir o squad

O integrador (esta sessão) abre as sessões dos terminais T1 a T4 no mesmo ambiente,
cada uma com o repositório, a branch da trilha e o recorte do PRD dela (só os itens que
ela faz, mais a lista de arquivos de que é dona e de que não pode mexer). Cada sessão
reporta no PR; o integrador acompanha e merja. O Igor pode assumir a cadeira T3 no
terminal dele, com as mesmas regras.
