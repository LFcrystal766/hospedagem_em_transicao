export const meta = {
  name: 'motor2-fase',
  description: 'Executa uma fase do PRD do Motor 2.0 da Crystal: item por item com testes primeiro, verificador adversarial em paralelo ao item seguinte, corretor e fechamento com revisão de segurança e holística',
  phases: [
    { title: 'Implementar', detail: 'um item por vez no worktree de integração, mapa e testes primeiro' },
    { title: 'Verificar', detail: 'verificador independente: falha antes, mutação, testes adversariais, rubrica' },
    { title: 'Corrigir', detail: 'traz os testes do verificador e corrige o que ele provou' },
    { title: 'Fechamento', detail: 'segurança e revisão holística da fase, correção e portão completo' },
  ],
}

// Guardado em crystal-em-casa/motor2-harness/motor2-fase.js (hospedagem). Args: { fase, harness, gate, itens: [{ id, esforco, perfil, seguranca, nota }] }
const F = args.fase
const ITENS = args.itens
const H = args.harness
const G = args.gate
const WT = '/home/user/cw-motor2'
const BR = 'painel/motor2'
const PRD = `${WT}/docs/motor2/PRD-motor-2.0-crystal.md`
const BASE = `Você trabalha na execução do PRD do Motor 2.0 da Crystal, FASE ${F} (itens ${ITENS.map((i) => i.id).join(', ')}). LEIA PRIMEIRO E SIGA À RISCA ${H}/REGRAS.md (fonte da verdade, worktrees, portas, portão, perfis de harness, commits, o que nunca fazer). PRD: ${PRD}. Branch de integração: ${BR} no worktree ${WT}. Portão: ${G}.`

const IMPL = {
  type: 'object',
  properties: {
    item: { type: 'string' },
    inicio: { type: 'string', description: 'commit completo de onde o item partiu' },
    fim: { type: 'string', description: 'commit completo do fim do item, já empurrado' },
    commits: { type: 'string', description: 'hash curto e título de cada commit' },
    testes: { type: 'string', description: 'arquivos e nomes dos testes que provam cada critério' },
    criterios: { type: 'string', description: 'cada critério de aceite: teste que prova e a prova de que falhava antes, ou "manual/aparelho"' },
    mapa: { type: 'string', description: 'o que mudou de lugar em relação às linhas do "Hoje"' },
    portao: { type: 'string' },
    desvios: { type: 'string' },
    proximo: { type: 'string', description: 'o que o próximo item precisa saber' },
  },
  required: ['item', 'inicio', 'fim', 'commits', 'testes', 'criterios', 'mapa', 'portao', 'desvios', 'proximo'],
}

const ACHADOS = {
  type: 'array',
  items: {
    type: 'object',
    properties: {
      gravidade: { type: 'string', enum: ['alta', 'media', 'baixa'] },
      titulo: { type: 'string' },
      onde: { type: 'string', description: 'arquivo:linha' },
      prova: { type: 'string', description: 'teste vermelho, comando ou trecho de código e a regra do PRD que ele fere' },
      correcao: { type: 'string' },
    },
    required: ['gravidade', 'titulo', 'onde', 'prova', 'correcao'],
  },
}

const VERIF = {
  type: 'object',
  properties: {
    item: { type: 'string' },
    veredito: { type: 'string', enum: ['APROVADO', 'COM_ACHADOS'] },
    achados: ACHADOS,
    branch_testes: { type: 'string', description: 'branch m2v/<item> com os testes adversariais, ou "nenhuma"' },
    falha_antes: { type: 'string', description: 'cada critério: o teste falhou no código anterior? (sim/não, qual)' },
    mutacao: { type: 'string', description: 'as 3 mutações e se algum teste pegou' },
    rubrica: { type: 'string', description: 'rubrica holística item a item' },
    seguranca: { type: 'string', description: 'APROVADO/REPROVADO com motivos, ou "não se aplica"' },
  },
  required: ['item', 'veredito', 'achados', 'branch_testes', 'falha_antes', 'mutacao', 'rubrica', 'seguranca'],
}

const FIX = {
  type: 'object',
  properties: {
    item: { type: 'string' },
    commits: { type: 'string' },
    corrigidos: { type: 'string' },
    nao_corrigidos: { type: 'string', description: 'achado que não procede, com a evidência' },
    portao: { type: 'string' },
  },
  required: ['item', 'commits', 'corrigidos', 'nao_corrigidos', 'portao'],
}

const REVISAO = {
  type: 'object',
  properties: {
    veredito: { type: 'string', enum: ['APROVADO', 'COM_ACHADOS', 'REPROVADO'] },
    achados: ACHADOS,
    branch_testes: { type: 'string' },
    resumo: { type: 'string' },
  },
  required: ['veredito', 'achados', 'branch_testes', 'resumo'],
}

function implementar(it) {
  return agent(`${BASE}
Você é o IMPLEMENTADOR do item ${it.id} (perfil ${it.perfil} do REGRAS.md; esforço ${it.esforco}). ${it.nota || ''}
Siga "Como o implementador trabalha" do REGRAS.md, passo a passo, no worktree ${WT}. Portas: 6200 (Postgres descartável 6250).
Antes de terminar: portão rapido verde com BASE=<inicio>, o que o perfil ${it.perfil} exige, documentos de "Onde mexer", bloco do ${it.id} em docs/motor2/andamento.md, commits empurrados para origin/${BR}.
Devolva o relatório no formato pedido.`, { label: `impl:${it.id}`, phase: 'Implementar', schema: IMPL, effort: it.esforco })
}

function verificar(it, imp) {
  const dir = `/home/user/cwm2/verif-${it.id}`
  return agent(`${BASE}
Você é o VERIFICADOR independente do item ${it.id} (perfil ${it.perfil}${it.seguranca ? ', com revisão de segurança' : ''}). Você recebe só o intervalo de commits e os testes que o implementador declara; desconfie de tudo.
Intervalo: ${imp.inicio}..${imp.fim}. Testes declarados: ${imp.testes}
1. Crie o worktree solto ${dir} no commit ${imp.fim} (REGRAS.md › Onde trabalhar) e instale as dependências. Portas: 6300 (Postgres descartável 6350).
2. Leia o item ${it.id} inteiro no PRD e as seções gerais. Leia o diff inteiro (git diff ${imp.inicio} ${imp.fim}).
3. FALHA ANTES: para cada critério de aceite, prove que o teste que o cobre FALHA no código anterior: restaure só os arquivos de produção (nunca os de teste) para ${imp.inicio} com git checkout ${imp.inicio} -- <arquivos>, rode os testes do item, e volte com git checkout ${imp.fim} -- <arquivos>. Critério sem teste que falhe antes = achado.
4. MUTAÇÃO: escolha as 3 linhas mais críticas da implementação (decisão, ordem, limite, filtro, corte), quebre uma de cada vez, rode os testes do item, anote se algum pegou, restaure. Mutação que nenhum teste pega = achado.
5. TESTES ADVERSARIAIS: escreva testes novos para o que o PRD exige e os testes do implementador não cobrem: bordas, ordem, limites, regressão do motor atual (pedido sem motor igual ao de hoje), vazamento, log sem conteúdo. Faça git switch -c m2v/${it.id}, commit (padrão do REGRAS.md) e git push -u origin m2v/${it.id}. Teste seu que falha por defeito do código = achado, com o teste como prova. Teste seu que está errado não é achado: conserte o teste.
6. RUBRICA HOLÍSTICA: "O que fazer" completo; nada de "Fora deste item"; textos literais caractere por caractere; documentos de "Onde mexer" atualizados; bloco em docs/motor2/andamento.md; nenhum conteúdo de cliente, regra, exemplo ou perfil em log; nenhum segredo; BASE=${imp.inicio} bash ${G} ${dir} rapido verde (falha da base: compare com ${H}/base-motor2.log).
${it.seguranca ? `7. SEGURANÇA: aplique o checklist de .claude/agents/seguranca.md e o Princípio 5 do PRD ao diff; dê APROVADO ou REPROVADO com os motivos. REPROVADO entra também como achado de gravidade alta.` : ''}
Não corrija o código do app: só testes, na sua branch. No fim: git -C /home/user/crystal-web-chat worktree remove --force ${dir} (a branch fica no origin).
Achado só com prova. Devolva o veredito no formato pedido.`, { label: `verif:${it.id}`, phase: 'Verificar', schema: VERIF })
}

async function corrigir(it, imp, verP) {
  const v = await verP
  if (!v) { log(`${it.id}: verificador sem resposta; segue sem correção`); return { item: it.id, verificacao: null, correcao: null } }
  const temTestes = v.branch_testes && v.branch_testes !== 'nenhuma'
  if (v.veredito === 'APROVADO' && v.achados.length === 0 && !temTestes) {
    log(`${it.id}: APROVADO pelo verificador, sem achados`)
    return { item: it.id, verificacao: v, correcao: null }
  }
  log(`${it.id}: ${v.achados.length} achado(s) do verificador; corrigindo`)
  const fx = await agent(`${BASE}
Você é o CORRETOR do item ${it.id} (esforço ${it.esforco}), no worktree ${WT}. A ${BR} pode já ter itens seguintes por cima: não os desfaça.
Achados do verificador (cada um com a prova): ${JSON.stringify(v.achados)}
Branch com os testes do verificador: ${v.branch_testes}.
1. ${temTestes ? `Traga os testes dele: git fetch origin ${v.branch_testes} e git cherry-pick ${imp.fim}..origin/${v.branch_testes} (conflito com item seguinte: mantenha os dois).` : 'O verificador não deixou testes: escreva você o teste vermelho de cada achado.'}
2. Para cada achado: reproduza (teste vermelho), corrija o código, teste verde. Achado que você prova não proceder (com evidência): não mexa e explique.
3. BASE=${imp.inicio} bash ${G} ${WT} rapido verde, e o que o perfil ${it.perfil} exige. Portas 6200 (Postgres 6250).
4. Atualize o bloco do ${it.id} em docs/motor2/andamento.md (achados e correções). Commits "fix(motor2): ${it.id} …" e push para origin/${BR}.
Devolva o relatório no formato pedido.`, { label: `corrigir:${it.id}`, phase: 'Corrigir', schema: FIX, effort: it.esforco })
  return { item: it.id, verificacao: v, correcao: fx }
}

const relatorios = []
const resultados = []
let anterior = null
for (const it of ITENS) {
  const imp = await implementar(it)
  if (!imp) {
    log(`${it.id}: implementador sem resposta; a fase para aqui (os itens seguintes dependem dele)`)
    if (anterior) resultados.push(await corrigir(anterior.it, anterior.imp, anterior.verP))
    return { fase: F, parou_em: it.id, relatorios, resultados }
  }
  relatorios.push(imp)
  log(`${it.id} implementado: ${imp.commits.split('\n')[0]}`)
  const verP = verificar(it, imp)
  if (anterior) resultados.push(await corrigir(anterior.it, anterior.imp, anterior.verP))
  anterior = { it, imp, verP }
}
if (anterior) resultados.push(await corrigir(anterior.it, anterior.imp, anterior.verP))

phase('Fechamento')
const inicioFase = relatorios[0].inicio
const lista = ITENS.map((i) => i.id).join(', ')
const [seg, hol] = await parallel([
  () => agent(`${BASE}
Você é o REVISOR DE SEGURANÇA do fechamento da fase ${F} (${lista}), no papel do agente .claude/agents/seguranca.md: você audita e bloqueia, não implementa.
Crie o worktree solto /home/user/cwm2/fech-seg na ponta atual de origin/${BR} (git fetch antes) e instale as dependências; portas 6400 (Postgres 6450).
Revise o diff inteiro da fase (git diff ${inicioFase} origin/${BR}) com o checklist de .claude/agents/seguranca.md e o Princípio 5 e os "Avisos que não têm volta" do PRD: segredos, service_role só no servidor, nada de conteúdo de cliente/regra/exemplo/perfil em log ou resposta de rota, Zod em toda entrada externa, cifra em repouso, LGPD (apagar continua apagando), migrações aditivas, chaves perigosas com LIGAR e senha onde o PRD manda, nada que mude o comportamento dos clientes (pedido sem motor = corpo byte a byte igual ao de hoje).
Achado só com prova; quando der, escreva o teste vermelho numa branch m2v/fase${F}-seguranca (commit e push). No fim remova o worktree.
Veredito: APROVADO, COM_ACHADOS (só baixos) ou REPROVADO.`, { label: `seguranca:fase${F}`, phase: 'Fechamento', schema: REVISAO }),
  () => agent(`${BASE}
Você é o REVISOR HOLÍSTICO do fechamento da fase ${F} (${lista}): a revisão de fechamento que o PRD pede com "ultracode ligado". Seja exaustivo e adversarial.
Crie o worktree solto /home/user/cwm2/fech-hol na ponta atual de origin/${BR} (git fetch antes) e instale as dependências; portas 6500 (Postgres 6550).
Quatro lentes, uma de cada vez, sobre o diff inteiro da fase (git diff ${inicioFase} origin/${BR}):
(1) Fidelidade ao PRD: cada "O que fazer" e cada critério de aceite de ${lista}, inclusive o critério que fecha a fase; textos literais; "Fora deste item" intocado; docs/crystal-api.md e docs/motor2/andamento.md batem com o código.
(2) Regressão do motor atual: pedido sem motor gera corpo e prompt iguais aos de hoje; laboratório, bateria, dossiê e Chatwoot sem mudança de comportamento.
(3) Custo e cache: prefixo idêntico byte a byte até o fim das regras para OpenAI, Google, DeepSeek e Anthropic; nada variável antes dele; tetos por nível; colunas de uso gravadas.
(4) Qualidade de código (o que teste não pega): duplicação, nomes, comentários na língua e no estilo do repositório, tratamento de erro, código morto.
Achado só com prova; escreva os testes vermelhos numa branch m2v/fase${F}-holistica (commit e push). No fim remova o worktree.
Veredito: APROVADO, COM_ACHADOS ou REPROVADO.`, { label: `holistica:fase${F}`, phase: 'Fechamento', schema: REVISAO }),
])

const saida = await agent(`${BASE}
Você é o PORTÃO DE SAÍDA da fase ${F} (${lista}), no worktree ${WT}.
Parecer de segurança: ${JSON.stringify(seg)}
Revisão holística: ${JSON.stringify(hol)}
1. Traga os testes das branches m2v/fase${F}-* que existirem (cherry-pick dos commits delas) e corrija cada achado provado (teste vermelho → código → verde). Achado que não procede: explique com evidência.
2. bash ${G} ${WT} completo --porta 6400 VERDE (falha da base: compare com ${H}/base-motor2.log). Postgres descartável na 6450 para os .pg.test.ts tocados.
3. docs/motor2/andamento.md: bloco "Fase ${F} fechada" com o parecer de segurança, os achados e as correções, e o que o dono confere (manual/aparelho) desta fase.
4. Commits e push para origin/${BR}.
Devolva em português: achados corrigidos e não procedentes, resultado do portão completo etapa por etapa, HEAD empurrado, pendências do dono.`, { label: `saida:fase${F}`, phase: 'Fechamento', effort: 'xhigh' })

let seg2 = null
if (seg && seg.veredito === 'REPROVADO') {
  seg2 = await agent(`${BASE}
Você é o REVISOR DE SEGURANÇA, segunda leitura do fechamento da fase ${F}. O parecer anterior foi REPROVADO: ${JSON.stringify(seg.achados)}. Confira na ponta atual de origin/${BR} (worktree solto /home/user/cwm2/fech-seg2, portas 6400) se cada achado foi resolvido de verdade e se a correção não abriu outro problema. Remova o worktree no fim. Veredito APROVADO ou REPROVADO.`, { label: `seguranca2:fase${F}`, phase: 'Fechamento', schema: REVISAO })
}

return { fase: F, relatorios, resultados, seguranca: seg, holistica: hol, saida, seguranca2: seg2 }
