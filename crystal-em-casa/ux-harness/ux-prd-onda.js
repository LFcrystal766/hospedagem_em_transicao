export const meta = {
  name: 'ux-prd-onda',
  description: 'Executa uma onda do PRD de UX/UI da Crystal: planeja pacotes, implementa e verifica cada um em worktree próprio, integra por camada e fecha com o portão completo',
  phases: [
    { title: 'Planejar', detail: 'divide os itens da onda em pacotes sem conflito, em camadas' },
    { title: 'Implementar', detail: 'um agente por pacote, worktree e portas próprias' },
    { title: 'Verificar', detail: 'revisor adversarial por pacote contra o PRD' },
    { title: 'Integrar', detail: 'junta a camada na branch da onda e roda o portão' },
    { title: 'Portão', detail: 'CI inteiro, e2e como o GitHub, a11y, mobile-audit, docs, lista de aparelho' },
  ],
}

// Guardado em crystal-em-casa/ux-harness/ux-prd-onda.js (hospedagem) desde 28/10: o contêiner zerou e levou a cópia
// da sessão. Args: { onda, itens, harness, porta0, nota?, plano? } — `plano` (texto) fixa pacotes e camadas para o
// planejador só detalhar (retomada depois de um reinício sem o journal).
const N = args.onda
const ITENS = args.itens
const H = args.harness
const G = `${H}/gate.sh`
const WT = `/home/user/cw-ux-onda${N}`
const BR = `painel/ux-onda-${N}`
const PRD = `${WT}/docs/ux/PRD-ux-ui-2026-10-25.md`
const PORTA0 = args.porta0
const NOTA = args.nota ? ` ${args.nota}` : ''

const BASE = `Você trabalha na execução do PRD de UX/UI da Crystal, ONDA ${N} (itens ${ITENS}). LEIA PRIMEIRO E SIGA À RISCA ${H}/REGRAS.md (fonte da verdade, worktrees, portão, o que nunca fazer, commits, relatório). PRD: ${PRD}. Branch da onda: ${BR}, worktree de integração ${WT}. Trabalhe sozinho (sem subagentes), sem trabalho em segundo plano pendente ao entregar.${NOTA}`

const PLANO = {
  type: 'object',
  properties: {
    camadas: {
      type: 'array',
      description: 'camadas em ordem; pacotes da mesma camada não dependem um do outro nem mexem nos mesmos arquivos',
      items: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string', description: 'nome curto do pacote, kebab-case' },
            itens: { type: 'string', description: 'itens do PRD, ex.: U01, U02' },
            arquivos: { type: 'string', description: 'arquivos principais que o pacote toca' },
            specs_e2e: { type: 'string', description: 'specs e2e que mudam ou precisam rodar' },
            seguranca: { type: 'boolean', description: 'tem item para o agente de segurança ou mexe em login, sessão ou API' },
            notas: { type: 'string', description: 'dependências, riscos, decisões com padrão aplicado' },
          },
          required: ['id', 'itens', 'arquivos', 'specs_e2e', 'seguranca', 'notas'],
        },
      },
    },
    observacoes: { type: 'string' },
  },
  required: ['camadas'],
}

phase('Planejar')
const plano = await agent(`${BASE}
Você é o PLANEJADOR. Leia no PRD o "Roteiro em ondas" (inclusive a ordem de execução dentro da onda: os primeiros itens criam o que os seguintes usam), a seção "Tokens e componentes", a seção "Execução" no fim (o que as ondas anteriores já fizeram) e TODOS os itens ${ITENS}; e o código em ${WT} citado em "O que existe hoje" e "Onde mexer" de cada item (só leitura; o código pode já ter mudado: confira). Divida os itens em PACOTES de trabalho: cada pacote tem 1 a 5 itens que mexem nos mesmos arquivos ou dependem um do outro. Pacotes da mesma camada rodam em paralelo e são juntados depois: NÃO podem mexer nos mesmos arquivos. Um item que cria o que outros usam vai numa camada anterior. Para cada pacote: id curto (kebab-case), itens, arquivos principais, specs e2e que mudam ou precisam rodar, se tem item de segurança (ou mexe em login, sessão ou API) e notas (ordem interna, dependências, riscos, perguntas ao dono com o padrão que vale).${args.plano ? `\nPLANO FIXO (retomada): use exatamente estes pacotes, ids e camadas e só detalhe cada um: ${args.plano}` : ''}
Não implemente nada. Devolva as camadas.`, { label: `planejar:onda${N}`, phase: 'Planejar', schema: PLANO })

if (!plano || !plano.camadas || !plano.camadas.length) return { erro: 'planejador não devolveu camadas' }
const todos = plano.camadas.flat()
log(`Onda ${N}: ${todos.length} pacotes em ${plano.camadas.length} camadas: ${plano.camadas.map((c) => c.map((p) => p.id).join(', ')).join(' | ')}`)

const RESULT = {
  type: 'object',
  properties: {
    pacote: { type: 'string' },
    branch: { type: 'string' },
    commits: { type: 'string', description: 'hash curto e título de cada commit' },
    itens: { type: 'string', description: 'cada item: feito / parcial (o que falta) / não feito (por quê)' },
    criterios: { type: 'string', description: 'cada critério de aceite: teste que prova ou "aparelho"' },
    portao: { type: 'string', description: 'resultado do rapido e do e2e (e do ci, quando rodado)' },
    seguranca: { type: 'string', description: 'parecer APROVADO/REPROVADO com achados, quando aplicável; "não se aplica" senão' },
    aparelho: { type: 'string', description: 'o que só dá para conferir no iPhone/Android' },
    desvios: { type: 'string' },
    pendente: { type: 'string', description: 'o que o integrador precisa saber ou fazer' },
  },
  required: ['pacote', 'branch', 'commits', 'itens', 'criterios', 'portao', 'seguranca', 'aparelho', 'desvios', 'pendente'],
}

let k = 0
const porta = {}
for (const p of todos) { porta[p.id] = PORTA0 + 20 * k; k++ }
const resultados = []
const integracoes = []

for (let c = 0; c < plano.camadas.length; c++) {
  const camada = plano.camadas[c]
  const feitos = await pipeline(
    camada,
    (p) => agent(`${BASE}
Você é o IMPLEMENTADOR do pacote "${p.id}" (camada ${c + 1} de ${plano.camadas.length}). Itens: ${p.itens}. Arquivos principais: ${p.arquivos}. Specs e2e: ${p.specs_e2e}. Notas do planejador: ${p.notas}. Sua faixa de portas: --porta ${porta[p.id]}.
1. Crie o worktree /home/user/cwux/${p.id} na branch uxp/onda${N}-${p.id} a partir de ${BR} (comandos em REGRAS.md; se a branch já existir no origin, parta dela e continue o que já foi feito) e instale as dependências.
2. Para cada item: leia o item inteiro no PRD, abra as telas de referência dele (telas.json → PNG), leia o código, implemente, escreva os testes que provam cada critério de aceite, rode \`BASE=${BR} bash ${G} /home/user/cwux/${p.id} rapido\` até ficar verde, faça o commit do item e o push da branch.
3. No fim rode o e2e das specs tocadas e das novas: \`bash ${G} /home/user/cwux/${p.id} e2e --porta ${porta[p.id]} <specs>\`, até verde (e o modo \`ci\` se mexeu em mobile-audit, onda6-iphone, login, sessão ou título; ver REGRAS.md).
${p.seguranca ? '4. Este pacote tem item de segurança ou mexe em login, sessão ou API: passe pelo checklist de .claude/agents/seguranca.md e corrija o que reprovar antes de entregar.' : ''}
Devolva o relatório no formato pedido.`, { label: `impl:${p.id}`, phase: 'Implementar', schema: RESULT }),
    (r, p) => agent(`${BASE}
Você é o VERIFICADOR adversarial do pacote "${p.id}" (itens ${p.itens}), no worktree /home/user/cwux/${p.id}, branch uxp/onda${N}-${p.id}. Relatório do implementador: ${JSON.stringify(r)}.
Desconfie de tudo. Leia o diff inteiro (\`git diff ${BR}...HEAD\`) e, item por item do PRD: (1) "O que fazer" foi feito por completo, sem sobra e sem invadir "Fora deste item"? (2) os textos na tela são EXATAMENTE os do PRD (compare caractere por caractere)? (3) cada critério de aceite tem um teste que de fato falharia sem a mudança, ou está corretamente marcado como "aparelho"? (4) acessibilidade: axe, foco visível, alvos de 44 px, contraste com as cores do kit, leitor de tela; (5) "cliente, nunca aluna" e erro da conversa só com o código; (6) segurança quando o pacote tiver item marcado ou mexer em login, sessão ou API (checklist de .claude/agents/seguranca.md); (7) nada da alma, de produção, de segredo ou de dado pessoal; (8) corrida de tempo: teste que só passa com a máquina calma (hidratação, efeitos, armazenamento) é defeito.
CORRIJA você mesmo o que achar (commits seguindo REGRAS.md, push da branch), rode \`BASE=${BR} bash ${G} /home/user/cwux/${p.id} rapido\` e o e2e das specs (\`--porta ${porta[p.id]}\`) até verde. Devolva o relatório FINAL do pacote (mesmo formato), já com o que você corrigiu, o parecer de segurança quando houver e a lista de aparelho.`, { label: `verif:${p.id}`, phase: 'Verificar', schema: RESULT }),
  )
  feitos.forEach((f, i) => resultados.push(f || { pacote: camada[i].id, erro: 'sem relatório' }))
  const ids = camada.map((p) => p.id)
  const integ = await agent(`${BASE}
Você é o INTEGRADOR da camada ${c + 1} de ${plano.camadas.length} da onda ${N}. Pacotes: ${ids.join(', ')}. Relatórios: ${JSON.stringify(feitos)}.
No worktree de integração ${WT} (branch ${BR}): faça \`git pull --ff-only\` se o remoto andou; junte cada branch de pacote com \`git merge --no-ff uxp/onda${N}-<id>\` (mensagem "Merge: onda ${N}, pacote <id> (<itens>)" + as duas linhas de autoria), resolvendo conflitos com cuidado para manter o que os DOIS lados fizeram (os textos do PRD mandam). Um merge que já está no HEAD (retomada depois de reinício) não se refaz. Pacote sem relatório ou com portão vermelho: investigue a branch; se estiver incompleto, termine você mesmo no worktree dele antes de juntar, ou deixe de fora e diga por quê. Depois rode \`bash ${G} ${WT} completo --porta ${PORTA0 + 500}\` e corrija até PORTÃO VERDE (falha igual à da base em ${H}/base-onda${N}.log só se não for causada pela onda; diga qual). Commit das correções, \`git push origin ${BR}\`. Por fim remova os worktrees dos pacotes juntados (\`git -C ${WT} worktree remove /home/user/cwux/<id>\`; só se a branch estiver juntada E empurrada; nunca --force em worktree com mudança não commitada). Devolva: o que juntou, conflitos e como resolveu, correções, resultado do portão completo, HEAD empurrado.`, { label: `integrar:camada${c + 1}`, phase: 'Integrar' })
  integracoes.push(integ)
}

phase('Portão')
const portao = await agent(`${BASE}
Você é o PORTÃO DE SAÍDA da onda ${N}. No worktree ${WT} (branch ${BR}, já com todas as camadas juntadas). Relatórios dos pacotes: ${JSON.stringify(resultados)}. Integrações: ${JSON.stringify(integracoes)}.
Cumpra o "Portão de saída de cada onda" do PRD (seção "Roteiro em ondas"), item por item:
1. Todo item ${ITENS} feito? Confira cada um no código contra o PRD (não confie nos relatórios). Faltou algo: implemente agora, com teste.
2. \`bash ${G} ${WT} completo --porta ${PORTA0 + 600}\` VERDE (tipos, lint, 4 suítes, build do web, conferir-safari, audit, e2e inteiro, incluindo a11y e mobile-audit nas telas que a onda tocou).
3. \`bash ${G} ${WT} ci --porta ${PORTA0 + 700}\` VERDE: o e2e como o GitHub roda (Chromium e WebKit juntos). Todo teste "flaky" é defeito: ache a causa (app ou teste) e corrija.
4. \`apps/web/lib/contraste.test.ts\` ampliado e verde; \`CACHE_VERSION\` do service worker subiu se a onda mudou offline.html, global-error.tsx, manifest ou tela cacheada.
5. Documentos: \`apps/web/design-system/DESIGN.md\` (regras novas), \`docs/equipe.md\`, \`e2e/README.md\`, \`docs/otimizacao/andamento.md\` (um bloco "UX · onda ${N}" com cada item e o commit) e, se algo do PRD mudou na execução, a seção "Execução" no fim do PRD com os desvios e as cores corrigidas do kit.
6. Escreva \`docs/ux/onda-${N}-conferir-em-aparelho.md\`: a lista do que o dono confere no iPhone (Safari e app instalado) logo depois de subir, em português simples, tela por tela, com o que tem de ver; e as decisões do dono aplicadas com o padrão.
7. Commit e \`git push origin ${BR}\`.
Devolva em português: itens feitos/faltando (deve ser zero faltando), resultado do portão completo e do ci (cada etapa), migrações de banco e variáveis novas, HEAD empurrado, o que conferir em aparelho (resumo), desvios do PRD.`, { label: `portao:onda${N}`, phase: 'Portão' })

return { plano, resultados, integracoes, portao }
