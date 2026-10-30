# Regras do harness: execução do PRD do Motor 2.0 da Crystal

Quem lê: todo agente que implementa, verifica, corrige ou fecha uma fase do Motor 2.0. Siga à risca.
`H=/home/user/hospedagem_em_transicao/crystal-em-casa/motor2-harness` · `G=/home/user/hospedagem_em_transicao/crystal-em-casa/ux-harness/gate.sh`

Você é um subagente. **Não** atualize `CONTINUAR-EM-OUTRA-CONTA.md` nem mande arquivo ao dono: isso é do orquestrador.

## Fonte da verdade

- **PRD:** `docs/motor2/PRD-motor-2.0-crystal.md` dentro do worktree (cópia em
  `/home/user/hospedagem_em_transicao/auditorias/2026-10-30/motor2/`). Leia sempre, além do seu item: "Decisões que
  este PRD fixa", "Princípios", "Como o Motor 2.0 monta uma resposta" e "Avisos que não têm volta". Cada item tem
  Decisão, Hoje, O que fazer, Textos, Onde mexer, Critérios de aceite, Fora deste item, Depende de e Cuidados.
- **Ordem:** um item por vez, na ordem do PRD. O item seguinte parte do anterior já integrado.
- **Textos literais** do PRD entram caractere por caractere (aspas, travessões, acentos, "·").
- **Linhas citadas no "Hoje"** são da `466886d`. Os itens anteriores mexem nos mesmos arquivos: confirme no código
  atual antes de editar.
- **Andamento:** `docs/motor2/andamento.md` (um bloco por item: o que mudou, commits, critério → teste, desvios). Leia
  antes de começar; o implementador escreve o bloco do item dele.
- Banco da agência (conferido em 30/10, só leitura): `match_leticia_crystal_vector_store(query_embedding vector,
  match_threshold double precision default 0.0, match_count integer default 10, filter jsonb default '{}')` devolve
  `(id bigint, content text, metadata jsonb, similarity double precision)`; 168 linhas em
  `leticia_crystal_vector_store`; 27 em `leticia_crystal_hybrid_search`; `app_conhecimento_listar()` devolve `jsonb`.
  Testes usam respostas falsas nesse formato; nada chama o Supabase de verdade.

## Regras do dono que valem sobre tudo

1. **A alma não muda uma letra** (`apps/crystal/prompt/crystal.md`, regras e blocos fixos de segurança). Os títulos de
   sistema que a alma cita ("Base de conhecimento para esta mensagem", "O que você já sabe deste aluno") ficam como
   estão.
2. **"Cliente", nunca "aluna/aluno"** em texto visível novo do app e do painel (U59). Rotas, código e banco não mudam.
   Os textos de sistema do PRD que vão ao modelo (cabeçalhos, `INSTRUCAO_PERFIL`, `INSTRUCAO_QUALIDADE`) entram
   literais, como o PRD escreve.
3. **Erro da conversa nunca mostra a causa** ao cliente: só a frase neutra e o código (C01–C09).
4. **Segurança sempre:** segredo nunca em código, teste, log ou commit; conteúdo de mensagem, regra, exemplo ou perfil
   nunca em log (só números, ids, níveis); `service_role` só no servidor; entrada externa validada com Zod; dado de
   cliente real nunca em teste ou fixture.
5. **Nada chega à produção.** Proibido: VPS, `app-subir`, migração em produção, Supabase/OpenRouter/n8n/Chatwoot de
   verdade, publicar no GTM. Identificadores de modelos do catálogo (ex.: `openai/gpt-4.1-mini`) podem aparecer onde o
   PRD manda (env, testes de prefixo); o nome do assistente que escreve o código, nunca.

## Onde trabalhar

- Repositório do app: `/home/user/crystal-web-chat`. **Integração:** worktree `/home/user/cw-motor2`, branch
  `painel/motor2` (nasceu de `466886d` com o PRD em `c7e77a6`). Implementador e corretor trabalham **nele**, um de cada
  vez (o orquestrador garante).
- **Verificador:** worktree próprio, solto no commit que vai verificar:
  `git -C /home/user/crystal-web-chat worktree add --detach /home/user/cwm2/verif-<item> <commit>` e
  `pnpm install --frozen-lockfile --prefer-offline` lá. Os testes extras que ele escrever vão numa branch
  `m2v/<item>` (`git switch -c m2v/<item>` no worktree dele) com push; ele não toca `painel/motor2`.
- **Portas** (web N, API N+1, Chatwoot falso N+2; Postgres descartável N+50): implementador e corretor 6200; verificador
  6300; fechamento 6400 e 6500. Nunca use a porta de outro papel.
- **Postgres descartável** para os `*.pg.test.ts` (memória, `uso_turnos`, `resumos`, migrações):
  `url=$(bash $H/pg-descartavel.sh <porta+50> | tail -1)` e a variável que o teste pede (`CRYSTAL_PG_TEST_URL` na
  Crystal; os da API dizem a sua). Teste novo de esquema ou de memória tem versão `.pg.test.ts` rodada assim.

## O portão

```bash
BASE=<commit de início do item> bash $G <worktree> rapido          # tipos, lint e testes dos pacotes mudados
bash $G <worktree> e2e --porta <P> e2e/arquivo.spec.ts             # e2e só das specs tocadas (itens de tela)
bash $G <worktree> completo --porta <P>                             # tudo do CI (fechamento de fase)
bash $G <worktree> ci --porta <P>                                   # e2e como o GitHub (Chromium + WebKit)
```

Termina com `PORTÃO VERDE` ou `PORTÃO VERMELHO: <etapas>`; logs em `<worktree>/.gate/`. Ninguém entrega com o portão
vermelho. Falha que já existia na base: compare com `$H/base-motor2.log` e diga no relatório; nunca desligue teste.
Teste de tempo conhecido: `apps/crystal/src/vazamento-camadas.test.ts` › "menos de ~5 ms" falha nesta máquina também na
base; se só ele falhar, diga e siga (não afrouxe o limite).

## Harness por tipo de tarefa (por que é assim)

Os benchmarks independentes de 2025–2026 mostram três coisas, e cada uma vira regra:

- **O harness pesa tanto quanto o modelo.** No Terminal-Bench 2.0 e no SWE-bench Pro (placar padronizado da Scale), o
  mesmo modelo muda de 5 a 17 pontos conforme o harness, e o gargalo é achar o contexto certo. → **Mapa antes do
  código** (passo 1 do implementador) e um item por agente.
- **Teste fraco aprova correção errada.** UTBoost (ACL 2025) achou 15,7% de correções "resolvidas" erradas no
  SWE-bench Verified; o SWE-ABS (2026), cerca de 1 em 5. → **Teste que falha antes** (cada critério prova que falha sem
  a mudança), **mutação** (quebrar a linha certa tem de derrubar um teste) e **testes adversariais** de um verificador
  independente.
- **Teste verde não é código pronto.** O METR (ago/2025) viu correções que passavam nos testes e ainda precisavam de
  trabalho grande para entrar: documentação, lint, qualidade. → **Rubrica holística** no verificador e no fechamento,
  e o verificador recebe o diff e o PRD, não a narrativa do implementador.

Perfis (o orquestrador diz qual vale para o item):

| Perfil | Itens | O que o portão do item exige, além do `rapido` verde |
|---|---|---|
| **N · núcleo** (montagem, contrato, triagem, busca, custo) | M01–M04, M06, M12; a parte de servidor de M09, M10 e M13 | teste que falha antes para cada critério; teste de contrato byte a byte quando o PRD pede "igual ao de hoje"; teste de prefixo estável (M03); mutação em 3 linhas críticas |
| **D · dados e LGPD** | M05, M09, M10 (e todo item que muda tabela) | o do N, mais `.pg.test.ts` no Postgres descartável, migração só aditiva e reversível, nada de texto de cliente em coluna nova, apagar (LGPD) continua apagando; checklist de `.claude/agents/seguranca.md` |
| **T · tela** | M07, M08, M11; a tela de M09 e M13 | testes de componente, e2e nos tamanhos 1440 e 390, axe sem violações, textos literais, nenhum texto de regra/exemplo/perfil no navegador (teste da rota); modo `ci` se tocar login, sessão ou título |

Item com "Passa pelo agente `seguranca`" no PRD: o verificador aplica o checklist de `.claude/agents/seguranca.md`
e dá APROVADO ou REPROVADO.

## Como o implementador trabalha

1. `git -C /home/user/cw-motor2 pull --ff-only` se o remoto andou; anote `inicio=$(git rev-parse HEAD)`.
2. **Mapa:** leia o item inteiro, as seções gerais do PRD e `docs/motor2/andamento.md`; abra cada arquivo de "Onde
   mexer" e confirme as linhas do "Hoje". Anote no relatório o que mudou de lugar.
3. **Testes primeiro:** um teste por critério de aceite (ou a linha "manual/aparelho" quando o PRD diz manual). Rode e
   veja **falhar** pelo motivo certo; guarde a saída resumida.
4. Implemente o mínimo que cumpre "O que fazer"; respeite "Fora deste item" e os "Cuidados".
5. `BASE=$inicio bash $G /home/user/cw-motor2 rapido` até verde; e o que o perfil pedir.
6. Documentos de "Onde mexer" (`docs/crystal-api.md`, `docs/equipe.md`, README) e o bloco do item em
   `docs/motor2/andamento.md`.
7. Commits e push (abaixo). Relatório.

## Commits e push

Conventional Commits em português, um commit por item (ou poucos, coesos): `feat(motor2): M02 triagem determinística`,
`test(motor2): …`, `fix(motor2): M02 … (achado do verificador)`. Toda mensagem termina com:

```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_011gQcRsErA5i9n9LpFjWozC
```

Depois de cada commit: `git push origin painel/motor2` (o verificador: `git push -u origin m2v/<item>`). O dono
autorizou em 30/10 o push dessas branches de trabalho para proteger o trabalho do contêiner que zera; **sem PR, sem
merge em outra branch, sem publicar**.

## O que nunca fazer

- Mudar a alma; mexer fora do seu papel e do seu worktree (exceto ler).
- `skip`, `only`, `fixme`, apagar teste que ainda vale, afrouxar limite para passar.
- Git destrutivo: `push --force`, `rebase` de branch compartilhada, `reset --hard`, `checkout -- .`, `clean`,
  `stash drop`, apagar branch.
- Dado pessoal real, segredo, conteúdo de mensagem em log.

## Relatório

Português, curto, no formato pedido pelo orquestrador: o que mudou (com commits), cada critério de aceite → teste que
prova (com a prova de que falhava antes) ou "manual/aparelho", resultado do portão, desvios do PRD e por quê, o que o
próximo item precisa saber.
