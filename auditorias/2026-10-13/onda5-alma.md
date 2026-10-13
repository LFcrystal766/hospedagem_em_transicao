# Onda 5: alma da Crystal no painel (13/10)

Orquestração `onda5-alma-crystal` (9 agentes). Nada publicado, nada aplicado no Supabase.

## Desenho

Worktree criada em /home/user/cw-onda5, branch painel/onda5-alma a partir de origin/painel/onda4 (22a65c1), com pnpm install --frozen-lockfile. O commit 708ec04 está só local, sem push.

O que entrou no commit:
- packages/shared/src/alma.ts, exportado no index. Tem os schemas zod e os tipos de tudo:
  - limites em ALMA_LIMITES: alma até 60 mil caracteres, formato até 4 mil, trecho até 4 mil, bateria com 100 perguntas cadastradas e 30 por rodada, teto de US$ 5;
  - superadmin: listaSuperadmin, ehSuperadmin e staffMeSchema;
  - alma: versão, rascunho com rev (trava otimista), estado com fonte banco/memoria/imagem e arquivo_difere, histórico e eventos, publicar e voltar com PUBLICAR mais carimbo, teste lado a lado (lado da Crystal com texto, lado do painel com bolhas);
  - base de conhecimento: trecho, lista, gravar, apagar, restaurar, histórico e busca de teste, via edge ou propria, embedding openai/text-embedding-3-small de 1536 dimensões;
  - bateria: pergunta, prever, rodar com teto, rodada, resultado e veredito;
  - qualidade: números do dia por dia, por versão, por código de erro e por busca, amostra com primeiro nome, pergunta e resposta, avaliação bom/ruim com comentário até 500 e resumo das avaliações;
  - ALMA_ERROR_CODES e o mapa ALMA_ROTAS (cada rota da API com papel, confirmação e a rota interna /v1 da Crystal que ela chama);
  - resumoDaMudanca, que dá o antes/depois para a auditoria sem o texto.
- staff.ts: 11 ações de auditoria novas, com rótulo: crystal.alma_rascunho, alma_teste, alma_publicar, alma_voltar, conhecimento_gravar, conhecimento_apagar, conhecimento_restaurar, bateria_pergunta, bateria_rodar, qualidade_amostra e qualidade_avaliar. As duas de qualidade também aparecem no filtro Aluno.
- settings.ts: chave crystal_busca (edge ou propria). Padrão edge, só admin, e passar para propria pede a palavra TROCAR e a senha.
- docs/painel-admin/ONDA5-ALMA.md: papéis, rotas, como a Crystal lê a alma (banco, depois a última boa em memória, depois o arquivo da imagem), busca edge ou própria, as tabelas novas (Crystal, Prisma pa16_01, Supabase), auditoria e a divisão de arquivos por camada. Mais uma linha em ONDAS.md apontando para ele.

Decisões que tomei e que o dono pode querer rever:
- Apagar um trecho da base: a linha sai da tabela viva e fica inteira no histórico (crystal_conhecimento_versoes), com texto e embedding. Restaurar volta com o mesmo id. Assim a busca deixa de achar o trecho sem mexer na RPC crystal_hybrid_search nem na Edge Function. Para seguir ao pé da letra o "apagado = marca", a alternativa seria uma coluna de marca, mas aí teríamos de reescrever a RPC sem ter o código-fonte dela.
- A amostra de conversas reais é só de admin: o técnico nunca lê conversa, e o suporte não acessa a área.
- Testar custa dinheiro, então só o superadmin testa.

Conferido:
- Typecheck limpo em shared, api, web e crystal.
- Testes do shared: 276 passaram, com alma.test.ts novo.
- Testes de settings e auditoria da API (45) e de Configurações do web (14) passaram com a chave nova.

Sobre o pedido de colocar alunos manualmente no painel com tempo de acesso: isso já existe em painel/onda4 ("Nova conta local" com "Acesso até", e o prazo se troca na ficha, só admin com a senha). Ainda não está no ar: a produção sha-3773e2e não tem o campo. Passa a valer quando a onda 4 for publicada, que é a tarefa 41. Esta onda só acrescenta atalhos de 30 dias, 3 meses, 6 meses, 1 ano e Sem prazo: o helper (PRAZOS_ACESSO_LOCAL e acessoAteDoPrazo, em students.ts, com teste) já está no commit, e a tela fica para o construtor do web. A API não muda para isso.

## Construção e junção

- `painel/onda5-crystal (local; não enviei nada ao remoto)` em `953305e`
- `painel/onda5-api` em `65f09b1`
- `painel/onda5-web` em `1a745a7`

Junção em `painel/onda5-alma` `342f10e`.

Juntei as três camadas na painel/onda5-alma com git merge --no-ff, nesta ordem: onda5-crystal (953305e), onda5-api (65f09b1) e onda5-web (1a745a7). Não houve conflito. Os commits de merge são e88833a, 3bbdea4 e b981d0d, todos com o trailer pedido.

Ao ligar as pontas, dois pontos não casavam.

1. API → Crystal: o cliente da API (apps/api/src/services/crystal-alma.ts) mandava o trecho da base "solto" no corpo de POST e PUT /v1/conhecimento. As rotas da Crystal são estritas e esperam { trecho, autor }, então criar e editar trecho davam 400 de verdade. Criei a função corpoDoTrecho para montar o corpo certo: a nota só vai quando existe (o schema não aceita null) e a versao_esperada só vai na edição.
   - Para não voltar a quebrar, escrevi apps/crystal/src/contrato-api.test.ts. Ele passa o cliente real da API pelas rotas reais da Crystal (o fetch vira app.inject) e cobre alma, base, bateria e números, incluindo os códigos de erro: conflito, sem rascunho, não existe e inválido.
   - Os formatos que a API tinha deixado como suposição conferem: {itens}, {id} e o resumo da rodada. O uso.alma_versao do done chega até messages.alma_versao, e a busca "propria" vai no corpo.

2. Web → API: os tipos das escritas no web (apps/web/lib/alma-equipe.ts) não eram o que a API devolve.
   - Salvar rascunho e "trazer da imagem" recebem o estado da alma relido (AlmaEstadoPainel), e não só o rascunho. A tela lia texto e rev de lugar errado. O AlmaPainel agora pega o rascunho de dentro do estado.
   - Rodar e parar a bateria recebem só o resumo da rodada, sem resultados. A tela quebraria ao listar os resultados. Agora ela guarda o resumo e os resultados chegam pela releitura da rodada a cada 5 s.
   - Acertei também os tipos de trechos (lista), perguntas ({itens}) e avaliação ({nota, comentario}), os mocks da unidade e do e2e, e criei um teste do salvar com a resposta real da API.
   - Commits 781238d e 342f10e (este tira dois imports que sobraram).

origin/painel/onda4 no GitHub continua em 22a65c1, que já é a base desta branch: o merge deu "Already up to date".

O pedido de liberar aluno manualmente com tempo de acesso já está na branch. É a "Nova conta local" da onda 4 com os atalhos de prazo da camada web (30 dias, 3 meses, 6 meses, 1 ano, Sem prazo), em AtalhosPrazo.tsx. Os mesmos atalhos aparecem no "Mudar acesso" da ficha do aluno. A data continua editável à mão.

## QA: 19 achados (7 médios/altos)

### [media] Revisão do rascunho recomeça em 1 depois de publicar ou descartar: uma aba velha sobrescreve o rascunho novo de outra pessoa

- Onde: apps/crystal/src/alma.ts (AlmaPostgres.salvarRascunho / AlmaEmMemoria: rev = (atual?.rev ?? 0) + 1; publicar e descartar apagam a linha de alma_rascunho) + apps/web/components/equipe/crystal/alma/AlmaPainel.tsx (recupera do sessionStorage o texto e a rev local)
- Passos: 1) Superadmin salva o rascunho V2 (rev 1) e publica (a linha do rascunho some). 2) Alguém começa outro rascunho V3: ele nasce de novo com rev 1. 3) Uma aba que ainda guarda a rev 1 do rascunho antigo (no editor ou no sessionStorage, 'Trouxe o que você tinha escrito') salva com rev_esperada=1. Provado pela API: PUT /staff/crystal/alma/rascunho {rev_esperada:1, texto: ...MARCA_QA_ABA_VELHA} respondeu 200 com rev=2 por cima do rascunho V3.
- Esperado: A trava otimista deveria recusar com 409 ALMA_CONFLITO, porque o rascunho atual não é aquele que a aba leu. Para isso a rev precisa crescer sempre (sequência global, ou rev junto com um id ou carimbo do rascunho).
- Obtido: Gravou por cima do rascunho de outra pessoa sem aviso. Isso também deixa ambíguo o rascunho_rev guardado nas rodadas da bateria: a rodada 1 registrou rascunho_rev=1 para um rascunho que já não é o mesmo.

### [media] "Testar com uma mensagem" do painel entra nos Números como resposta real a aluno

- Onde: apps/api/src/routes/staff-crystal.ts (POST /staff/crystal/try usa o turno normal /v1/messages com o contato teste:<id>) + apps/crystal/src/uso.ts (grava tipo 'turno') + agregarQualidade (conta todo 'turno')
- Passos: 1) Superadmin/admin/técnico usa "Testar com uma mensagem" (Operação › Crystal) algumas vezes. 2) Abrir Acompanhar › Números (ou GET /staff/crystal/qualidade/numeros?dias=1).
- Esperado: Respostas por dia, % sem trechos, tamanho médio, custo das respostas e a tabela por versão contam só os turnos de alunos. O teste do painel deveria ser gravado como 'teste' e entrar só no custo do painel, como já acontece com o teste lado a lado.
- Obtido: Com 1 resposta real (Ana) e 12 testes de painel, a tela mostrou RESPOSTAS 13 e 'Por versão da alma' com as versões 1 a 7, cada uma com 1 resposta, todas de teste. Em uso_turnos o teste aparece como tipo=turno, com contato_hash preenchido. Isso distorce exatamente o que serve para 'ver como ela está se saindo' depois de publicar.

### [media] Botão "Restaurar esta versão" aparece no histórico de trecho vivo, mas sempre falha (e a mensagem culpa 'outra pessoa')

- Onde: apps/web/components/equipe/crystal/alma/BasePainel.tsx (FolhaTrecho: mostra Restaurar quando i > 0, mesmo com o trecho vivo) x docs/supabase/app_conhecimento.sql (app_conhecimento_restaurar levanta CONFLITO se o trecho está vivo)
- Passos: 1) Superadmin edita um trecho (versões criar → editar). 2) Abre o trecho, vê no histórico a versão anterior com 'Restaurar esta versão'. 3) Confirma com nota e senha. Pela API: POST /staff/crystal/conhecimento/restaurar {versao_id:29} para o trecho 28 vivo.
- Esperado: Ou voltar o texto antigo de um trecho vivo (gravar uma versão 'editar' com o conteúdo e o embedding daquela versão), ou não oferecer o botão para trecho vivo.
- Obtido: 409 ALMA_CONFLITO, com a mensagem 'Alguém mudou isso enquanto você editava. Recarregue para ver a versão mais nova.' O usuário recarrega e o botão continua lá, falhando do mesmo jeito. A senha foi pedida e consumida à toa.

### [media] Aviso de 'usando a última versão boa em memória' nunca aparece: com o banco da alma fora, o painel só mostra erro 503

- Onde: apps/crystal/src/alma.ts (GestorDaAlma.estado() lê ativa e rascunho do banco e lança 'indisponivel') + apps/api/src/routes/staff-crystal-alma.ts (GET /staff/crystal/alma) + AlmaPainel.tsx (ALMA.fonteMemoria / fonteImagem)
- Passos: 1) Com a Crystal de pé, renomear a tabela alma_ativa do banco da Crystal (simula leitura falhando). 2) Esperar a releitura de 60 s: /healthz passa a dizer alma_fonte=memoria e os turnos continuam com a última boa (conferido). 3) Abrir /equipe/crystal/alma.
- Esperado: A tela mostra a versão em uso e o aviso amarelo 'A Crystal não conseguiu reler o banco e segue com a última versão boa…' (fonte memoria), como no desenho.
- Obtido: GET /staff/crystal/alma devolve 503 ALMA_INDISPONIVEL e a tela diz 'Não consegui falar com a Crystal agora', embora a Crystal esteja respondendo. Os estados 'memoria' e 'imagem' do painel ficam inalcançáveis justamente quando são úteis.

### [media] Qualquer admin (não só o superadmin) troca a busca da base para 'propria'

- Onde: packages/shared/src/settings.ts (crystal_busca: roles ['admin']) + PUT /staff/settings/crystal_busca
- Passos: 1) Subir a API com SUPERADMIN_EMAILS vazia (Rui é admin, mas não superadmin; /staff/me superadmin=false e PUT /staff/crystal/alma/rascunho dá 404). 2) PUT /staff/settings/crystal_busca {value:'propria', reauth_token} como Rui.
- Esperado: Pelo pedido, a busca própria fica atrás de uma chave, com a Edge Function como padrão 'até o dono decidir'. Quem muda o comportamento da Crystal para todos os alunos é o superadmin.
- Obtido: 200: um admin comum trocou a via de busca de todos os turnos (can_write=true na lista de Configurações). Os turnos seguintes saíram com busca=propria.

### [media] Apagar um trecho da base apaga a linha de verdade da tabela viva, em vez de só marcar

- Onde: /home/user/hospedagem_em_transicao/crystal-em-casa/supabase/app_conhecimento_editar.sql, função public.app_conhecimento_apagar (igual em /home/user/cw-onda5/docs/supabase/app_conhecimento.sql)
- Passos: Ler a função app_conhecimento_apagar: ela grava a versão 'apagar' no histórico e em seguida roda `delete from public.leticia_crystal_hybrid_search where id = p_id;`. O 'Volta' do cabeçalho manda `drop table public.crystal_conhecimento_versoes`.
- Esperado: Pedido: 'sem apagar de verdade (apagado = marca, sai da busca)'. A linha continua na tabela com uma marca (ou num lugar de onde não se perde), e a busca deixa de achá-la.
- Obtido: A linha sai fisicamente da tabela da agência. A única cópia (texto e embedding) passa a ser crystal_conhecimento_versoes. Se alguém seguir o próprio roteiro de volta (drop da tabela de histórico), os trechos apagados somem para sempre. Um processo antigo da agência que reescreva a tabela também pode reaproveitar o id, e aí o restaurar dá CONFLITO.

### [media] O SQL não confere nem fecha a escrita direta na leticia_crystal_hybrid_search para anon/authenticated

- Onde: /home/user/hospedagem_em_transicao/crystal-em-casa/supabase/app_conhecimento_editar.sql, blocos de conferência (início e fim) e de permissões
- Passos: Ler a conferência final: ela olha has_function_privilege das funções app_conhecimento_* e has_table_privilege de crystal_conhecimento_versoes. Nenhuma linha olha RLS ou grants de insert/update/delete da public.leticia_crystal_hybrid_search, e não há revoke nela. No repositório não há registro do estado de RLS ou grants dessa tabela da agência.
- Esperado: Pedido: a escrita no Supabase é só por função SECURITY DEFINER para service_role. O arquivo deveria parar (PERMISSAO_ABERTA) se anon ou authenticated puderem escrever direto na tabela viva, ou deveria fechar essa escrita.
- Obtido: As funções estão bem fechadas, mas a garantia depende do estado da tabela da agência, que ninguém confere. Se o RLS estiver desligado com os grants padrão do Supabase, a chave anon edita ou apaga a base pelo PostgREST sem histórico e sem auditoria. O SQL roda com sucesso e dá a impressão de que está tudo fechado.

### Baixos

- Bateria: o padrão 'Atual e rascunho' falha sem rascunho, e depois de publicar nunca há rascunho
- Teto da bateria é passado: a rodada parou com US$ 0,0052 para um teto de US$ 0,003
- Auditoria do 'voltar versão' e das perguntas da bateria sem o antes/depois resumido
- 'Voltar a qualquer versão em 1 clique' virou diálogo com nota, palavra PUBLICAR e senha, e descarta sem aviso o que não foi salvo no editor
- Restaurar pelo 'Ver os apagados': a folha fica aberta e vazia e o aviso 'Trecho restaurado.' só aparece ao fechar
- Editar trecho com conflito gasta um embedding antes de descobrir o conflito
- Resultado da bateria: placar com zeros sem avaliação, trechos sem rótulo e título repetido
- Grupo 👍/👎 das conversas reais com rótulo de acessibilidade errado
- Técnico ou admin comum força a busca 'propria' e ignora crystal_busca=edge
- SUPERADMIN_EMAILS mal formado é descartado em silêncio, sem aviso
- O teto de custo da bateria pode passar do valor, e não há limite de rodadas nem de custo no teste
- Parte das gravações vai para a auditoria sem o resumo de antes e depois, e fora de transação

## Correção (`fad92f5 (painel/onda5-alma em /home/user/cw-onda5, sem push; e2e/alma.spec.ts continua não rastreado, como já estava). R`)

**Corrigidos:**

- 1 (média) A rev do rascunho recomeçava em 1: agora vem de uma sequência que nunca recomeça (alma_rascunho_rev no Postgres, contador na AlmaEmMemoria, e preparar() alinha com a rev de uma linha antiga). Uma aba velha com rev 1 recebe 409 ALMA_CONFLITO e não grava por cima do rascunho novo, e o rascunho_rev da bateria deixa de ser ambíguo. Teste que falhava: alma.test.ts ('a rev nunca recomeça...') e onda5.pg.test.ts no Postgres de verdade. Commit bdbacc3.
- 2 (média) 'Testar com uma mensagem' entrava nos Números como resposta a aluno: a API manda teste:true (o corpo só muda quando o campo é true) e a Crystal grava o uso como tipo 'teste', sem contato_hash e sem guardar memória nem resumo. O contato teste:<id> vale o mesmo, para cobrir a imagem antiga da API. O teste sai das respostas, do % sem trechos, do custo das respostas e da tabela por versão, e entra só no custo do painel. Testes: app.test.ts, staff-crystal-a09.test.ts, crystal.test.ts. Commit bcc4c38.
- 3 (média) 'Restaurar esta versão' aparecia em trecho vivo e sempre falhava: agora só aparece para trecho apagado. No trecho vivo, a versão antiga ganha o botão 'Usar este texto no editor', que leva o texto para o editor; ao salvar vira uma edição normal, com trava otimista e embedding novo, sem pedir senha à toa. O teste antigo, que exercia o botão defeituoso, foi trocado por dois: trecho vivo e trecho apagado (onda5.test.tsx). Commit 82f4b58.
- 4 (média) Com o banco da alma fora, o painel só mostrava 503: GestorDaAlma.estado() agora devolve o que vale no turno. Com a última versão boa, vem fonte memoria com o id dela; sem nenhuma, vem o arquivo da imagem com fonte imagem e id 0 (o contrato aceita id 0 só em almaEstadoSchema.ativa). Nos dois casos rascunho vem null. A API devolve pode_editar=false e recusa gravar com 503, sem chamar a Crystal. A tela mostra o aviso amarelo, fica só de leitura, troca o histórico por uma nota quando ele não vem e não puxa o sessionStorage para o editor. Testes em alma.test.ts, staff-crystal-alma.test.ts e onda5.test.tsx. Commits bb09529 e fad92f5 (docs).
- 5 (média) Qualquer admin trocava crystal_busca: a chave ganhou soSuperadmin, e canWriteSetting(role, key, superadmin) passa a exigir o e-mail em SUPERADMIN_EMAILS (lista vazia = ninguém troca). O admin comum lê a chave com can_write=false e recebe 404 no PUT. Testes em staff-settings.test.ts e shared/alma.test.ts. Commit b7c4bf7.
- 6 (média, corrigido em parte; ver nao_corrigidos) Trecho apagado podia se perder: o histórico crystal_conhecimento_versoes passou a aceitar só insert, com gatilho que barra update, delete e truncate (HISTORICO_SO_ACRESCENTA), e o roteiro de volta não manda mais drop table nele. O trecho apagado continua saindo da tabela viva. Testado num Postgres 16 descartável, variantes A e B. Commits 96a7ddd (app) e 276acef (cópia em hospedagem_em_transicao/crystal-em-casa/supabase/app_conhecimento_editar.sql).
- 7 (média) O SQL não fechava a escrita direta na leticia_crystal_hybrid_search: o arquivo agora revoga insert, update, delete e truncate de public, anon e authenticated, e a leitura continua. Um NOTICE mostra o RLS e a escrita de antes. No fim, app_conhecimento_conferir_tabela_viva() para o arquivo com PERMISSAO_ABERTA se sobrar escrita por papel herdado ou por grant em coluna, e a saída ganhou a coluna tabela_viva_fechada. O teste aplica os grants padrão do Supabase, prova que anon não consegue mais apagar e que um papel herdado faz a conferência parar. Mesmos commits do item 6.

**Não corrigidos:**

- Achado 6, só em parte: o trecho apagado continua saindo fisicamente da tabela viva. Uma marca dentro da própria tabela não tira o trecho da busca sem mudar a RPC crystal_hybrid_search, que é da agência, não está no repositório e que o desenho da onda 5 (ONDA5-ALMA.md) decidiu não tocar. Uma linha com embedding nulo ainda pode aparecer no ranking semântico. O que ficou garantido: o histórico só aceita acréscimo e a volta não o apaga mais. O risco de um processo antigo da agência reaproveitar o id continua; nesse caso o restaurar dá CONFLITO e não grava por cima. Se o dono quiser a marca dentro da tabela, é preciso alterar a RPC.
- e2e/alma.spec.ts e e2e/a11y.spec.ts ainda rodavam quando esta saída foi pedida, então não há resultado deles aqui. O alma.spec.ts é um arquivo não rastreado do QA e só roda com E2E_ALMA_REAL=1. Para ele subi uma pilha local: Crystal real na 3306 com banco crystal_onda5_e2e; um OpenRouter e um Supabase falsos na 3399 sobre o Postgres supa_onda5_e2e, com o app_conhecimento.sql novo aplicado de verdade (script em scratchpad/e2e-alma/falso.mjs); API na 3305 com SUPERADMIN_EMAILS=rui@demo.crystal; web de produção na 3301, em build. O a11y roda com E2E_API_PORT=3405 e E2E_PORT=3401; o log está em scratchpad/a11y.log. Os processos ficaram de pé e os PIDs estão em scratchpad/e2e-alma/*.pid, para parar só por PID. Para rodar o alma: E2E_ALMA_REAL=1 E2E_API_PORT=3305 E2E_PORT=3301 E2E_REUSE_SERVERS=1 ./node_modules/.bin/playwright test e2e/alma.spec.ts.
- Fora do escopo desta tarefa: o pedido do usuário relayado ('colocar novos alunos manualmente no painel, com tempo de acesso') não foi tratado aqui. A branch já traz o commit 0d55425 'atalhos de prazo no acesso da conta local' e há a tarefa #44 aberta. Nada foi feito nisso nesta rodada.

**Bateria:** Typecheck dos 4 pacotes: ok. Lint (eslint .): ok, sem erros. Vitest com CRYSTAL_PG_TEST_URL num Postgres descartável: shared 276/276, crystal 298/298 (16 arquivos, o onda5.pg incluso), web 852/852, api 1231 passaram e 10 pulados (1241). SQL: docs/supabase/testes/app_conhecimento.teste.sql passou nas variantes A e B ('tudo certo'). Playwright: o e2e/a11y.spec.ts ainda rodava, e o e2e/alma.spec.ts estava montado contra a Crystal real e esperava o build do web na 3301; nenhum dos dois tinha terminado quando esta saída foi pedida.

## Pendências para conferir na VPS/Supabase

1. Nada foi enviado ao GitHub. A painel/onda5-alma existe só em /home/user/cw-onda5.
2. Só dá para conferir com a VPS ou o Supabase de verdade:
   - se a Edge Function e a RPC crystal_hybrid_search aceitam o corpo que a Crystal manda, e que nome de pontuação devolvem (score, rrf_score ou similarity);
   - se a coluna fts é gerada pelo banco, ou se a agência usa 'portuguese';
   - se ainda existe algum n8n antigo da agência que reescreve a leticia_crystal_hybrid_search;
   - se a resposta de /embeddings traz usage.cost (sem ele, o custo fica 0);
   - se o PostgREST devolve P0001 com CONFLITO;
   - a troca do check de tipo na uso_turnos, que trava a tabela (cerca de 75 mil linhas) uma única vez.
3. Antes de publicar:
   - pôr SUPERADMIN_EMAILS=<e-mail do dono> no api.env e reiniciar a API (a pa16_01 aplica sozinha no migrate deploy);
   - aplicar docs/supabase/app_conhecimento.sql no Supabase. O commit desse SQL em hospedagem_em_transicao ficou com quem fecha.
4. Ainda falta rodar:
   - o e2e (e2e/alma-onda5.spec.ts e o restante) no CI;
   - a conferência em aparelho que a camada web listou: textarea de 17 mil caracteres no iPhone, folha da base com confirmação por cima, gráfico e tabelas a 390 px, contraste dos avisos amarelos no tema escuro, toque nos chips de prazo e no 👍/👎.
5. Os atalhos de prazo do aluno manual só chegam aos alunos com a onda 4 e esta onda 5 publicadas. Até lá, liberar aluno manual continua pelo caminho atual.
6. O Postgres local da camada Crystal (cluster 16 main) ainda pode estar no ar. Desliga com `pg_ctlcluster 16 main stop`.
