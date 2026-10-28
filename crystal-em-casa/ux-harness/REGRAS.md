# Regras do harness: execução do PRD de UX/UI da Crystal

Quem lê: todo agente que implementa, verifica, integra ou fecha uma onda. Siga à risca.
Guardado no repositório da hospedagem (`crystal-em-casa/ux-harness/`) desde 28/10: o contêiner zerou e levou a cópia
do scratchpad. `H=/home/user/hospedagem_em_transicao/crystal-em-casa/ux-harness`.

## O que é a fonte da verdade

- **PRD:** `docs/ux/PRD-ux-ui-2026-10-25.md` dentro do worktree (cópia em
  `/home/user/hospedagem_em_transicao/auditorias/2026-10-25/ux/PRD-ux-ui-2026-10-25.md`). Cada item tem: Decisão,
  O que existe hoje, O que fazer, Textos palavra por palavra, Onde mexer, Critérios de aceite, Fora deste item.
  Faça o que o item diz, com os textos EXATAMENTE como estão. Decisão do dono em aberto: aplique o **padrão** escrito
  em "Perguntas ao dono", no fim do PRD, e diga isso na mensagem do commit. A seção "Execução" no fim do PRD registra
  o que as ondas 1 e 2 fizeram e os desvios.
- **Como deve ficar (referência visual):** as 108 telas finais em
  `/home/user/hospedagem_em_transicao/auditorias/2026-10-25/ux/telas-finais/telas/*.png` e o índice
  `telas-finais/telas.json` (cada tela lista os itens Uxx que mostra). Abra com Read as telas dos seus itens antes de
  codar. Elas usam o kit `telas-finais/fonte/ds.css`, que corrigiu cores do PRD para passar no AA (README da pasta):
  use as cores corrigidas (`--success-ink` claro `#097200`; toque do rosa `#c20857`; "Desfazer" do toast no rosa de
  texto do tema oposto; trilho do interruptor desligado com 3:1; contador do suporte amarelo com texto escuro; anel
  de foco rosa por padrão e branco só sobre cor). Registre o desvio no commit.
- **Achados de origem:** `/home/user/hospedagem_em_transicao/auditorias/2026-10-25/ux/achados.json`.

## Decisões do dono de 27/10 (valem sobre tudo)

1. **"Cliente", nunca "aluna".** Todo texto visível que você escrever ou alterar diz "cliente" ou "clientes", nunca
   aluno, aluna, alunos ou alunas (nem em rótulo acessível, título, e-mail ou mensagem da API). URLs, nomes de código,
   rotas e banco não mudam. A varredura foi o U59 (onda 2); o teste `apps/web/lib/cliente-guarda.test.ts` reprova
   texto novo com "aluna".
2. **Erro da conversa nunca mostra a causa.** A cliente vê só a frase neutra e um código (C01 a C09); a causa fica
   com a equipe (U05).

## Onde trabalhar

- Repositório do app: clone em `/home/user/crystal-web-chat` (`LFcrystal766/crystal-web-chat`). Branch da onda:
  `painel/ux-onda-<N>`, com o worktree de integração em `/home/user/cw-ux-onda<N>`. **Não edite o worktree de
  integração**, salvo se você for o integrador ou o portão.
- Cada pacote tem o seu worktree e a sua branch, criados a partir da branch da onda NO ESTADO ATUAL:
  ```bash
  git -C /home/user/cw-ux-onda<N> worktree add /home/user/cwux/<pacote> -b uxp/onda<N>-<pacote> painel/ux-onda-<N>
  cd /home/user/cwux/<pacote> && pnpm install --frozen-lockfile --prefer-offline
  ```
  **Se a branch `uxp/onda<N>-<pacote>` já existir no origin** (trabalho de antes de um reinício), parta dela:
  `git -C /home/user/cw-ux-onda<N> fetch origin uxp/onda<N>-<pacote>` e
  `git -C /home/user/cw-ux-onda<N> worktree add /home/user/cwux/<pacote> -b uxp/onda<N>-<pacote> origin/uxp/onda<N>-<pacote>`;
  leia o que já foi feito (`git log painel/ux-onda-<N>..HEAD`) e continue dali, sem refazer.
- Portas: use SÓ a faixa que o seu pedido der (`--porta P` → web P, API P+1, Chatwoot falso P+2).

## O portão (harness)

```bash
G=/home/user/hospedagem_em_transicao/crystal-em-casa/ux-harness/gate.sh
BASE=painel/ux-onda-<N> bash $G /home/user/cwux/<pacote> rapido                    # tipos, lint, testes do que mudou
bash $G /home/user/cwux/<pacote> e2e --porta <P> e2e/arquivo.spec.ts [outros…]      # e2e só das specs tocadas
bash $G <worktree> completo --porta <P>                                             # tudo do CI, e2e no Chromium
bash $G <worktree> ci --porta <P>                                                   # e2e como o GitHub: Chromium + WebKit juntos
```
Termina com `PORTÃO VERDE` ou `PORTÃO VERMELHO: <etapas>`, com o log de cada etapa em `<worktree>/.gate/`.
Ninguém entrega trabalho com o portão vermelho. Falha que já existia na base: compare com
`$H/base-onda<N>.log` (portão completo da base da onda N sem mudança nenhuma) e, se for a mesma, diga no
relatório; não "conserte" desligando teste.

**Teste de tempo conhecido:** `apps/crystal/src/vazamento-camadas.test.ts` › "menos de ~5 ms" falha nesta máquina
(5,3 a 9 ms) na base também; o GitHub passa. Se só ele falhar, diga no relatório; não afrouxe o limite.

**Como o CI roda o e2e:** os dois projetos (Chromium e WebKit, `E2E_WEBKIT=1`) numa execução só, `workers: 1`,
`retries: 1`, no mesmo servidor de teste. Em 27–28/10 isso achou defeitos que o portão `completo` (só Chromium) não via:
campo preenchido antes da hidratação, título da aba trocado pelo do metadata, leitura do armazenamento logo depois do
login. Por isso: quem mexer em `mobile-audit.spec.ts`, `onda6-iphone.spec.ts`, login, sessão ou título roda também o
modo `ci`; o **portão de saída** roda o modo `ci` uma vez e trata todo teste "flaky" como defeito a resolver. O WebKit
local fica no scratchpad da sessão; se não existir, monte com `bash $H/webkit-local.sh`.

**GitHub Actions bloqueado por cobrança** desde 28/10 02:54 UTC: o CI do GitHub não roda; o portão local é a prova.

## Como trabalhar

1. Leia o item inteiro no PRD, as telas de referência e o código citado em "O que existe hoje".
2. Implemente o mínimo que cumpre "O que fazer" e os textos; respeite "Fora deste item".
3. **Critérios de aceite viram teste.** Para cada critério: um teste unitário (vitest) ou e2e (Playwright) que falharia
   sem a mudança, ou, se for só conferível em aparelho, a linha na lista "Conferir em aparelho" do relatório.
   Testes antigos que fixam o texto ou o comportamento velho mudam junto (nunca apague um teste que ainda vale; nunca
   use `skip`/`only`/`fixme` para passar).
4. Microcopy nos arquivos `apps/web/lib/microcopy-*.ts` (ou onde o PRD mandar), nunca espalhado.
5. Banco: migração do Prisma em `apps/api/prisma/migrations/<data>_<nome>`, só aditiva (a onda 3 não prevê nenhuma).
6. Contrato entre web, API e Crystal: em `packages/shared`, os três na mesma tag.
7. Segurança: o PRD não marca item da onda 3 para o agente de segurança; quem mexer em login, sessão ou API passa
   pelo checklist de `.claude/agents/seguranca.md` mesmo assim.

## O que nunca fazer

- Mudar o texto ou o comportamento da alma da Crystal (prompt, regras, blocos fixos de segurança). A interface muda;
  a alma não.
- Tocar produção: VPS, Supabase, OpenRouter, n8n, Assiny, Chatwoot de verdade. Testes usam mocks e o modo demo.
- Dado pessoal real, segredo ou identificador de modelo de IA em código, teste, texto de interface, log ou commit.
- Git destrutivo: nada de `push --force`, `rebase` de branch compartilhada, `reset --hard`, `checkout -- .`,
  `clean`, `stash drop`, apagar branch que não é sua. Sem PR.
- Mexer fora do seu worktree (exceto ler).

## Commits

Português, no estilo do repositório: `feat(ux): U48 …`, `fix(ux): …`, `test(ux): …`. Um commit por item (ou por itens
que mexem no mesmo arquivo de forma inseparável). Cada mensagem termina com estas duas linhas:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011gQcRsErA5i9n9LpFjWozC
```

Depois de cada commit: `git push -u origin uxp/onda<N>-<pacote>` (a branch de pacote não dispara CI; o push protege o
trabalho se o contêiner reiniciar ou zerar, o que já aconteceu sete vezes).

## Relatório que todo agente devolve

Português, curto: itens feitos (Uxx: o que mudou, commits), critérios de aceite (cada um: teste que prova ou
"aparelho"), resultado do portão (rapido e e2e), desvios do PRD e por quê, o que ficou para o integrador.
