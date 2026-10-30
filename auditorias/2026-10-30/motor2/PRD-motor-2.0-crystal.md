# PRD · Motor 2.0 da Crystal

30 de outubro de 2026 · Luiz Filippe (dono) · para o Igor executar · versão 3 (a versão 2 foi revisada por dois revisores independentes; a 3 tira a dependência do Haiku: cache e custo valem para qualquer fornecedor, com a OpenAI como principal provável)

Este PRD cria o **Motor 2.0**: a nova forma de a Crystal guardar o que sabe e montar cada resposta, descrita na análise "Cérebro da Crystal" de 30/10/2026 (https://claude.ai/artifact/JvXbDBBHXENKCGbueaAVmj; explicador visual deste PRD em https://claude.ai/artifact/3CjqXqTCaxGbcnXwvvQson). Ele nasce **ao lado** do motor atual, desligado para os clientes, e pode ser testado de duas formas: no Laboratório do painel (conversa artificial, qualquer modelo do OpenRouter) e em contas de teste no app de verdade (a do Luiz e as que ele marcar). Quando o Luiz aprovar, um interruptor só o torna o padrão para todos, no app e no WhatsApp via Chatwoot. Se der problema, o mesmo interruptor volta.

Base do código: branch `painel/ux-onda-3` (commit `466886db`, 29/10/2026). Antes de qualquer item: `git fetch` e partir da ponta mais nova. Caminhos citados são relativos à raiz do repositório `crystal-web-chat`. O app e o painel dizem **cliente**, nunca "aluno" (U59); os títulos das mensagens de sistema que a alma cita ("O que você já sabe deste aluno") ficam como estão, porque a alma os procura.

## Ponto de partida: como a Crystal responde hoje

A cada mensagem, `apps/crystal/src/app.ts` monta uma lista de blocos e chama o modelo escolhido no painel (`op_crystal_modelo`; padrão do código `anthropic/claude-haiku-4.5`, `apps/crystal/src/env.ts:26`; em 16/10 a produção rodava `google/gemini-2.5-flash-lite`, `apps/crystal/src/vazamento.ts:8`). A montagem está em `apps/crystal/src/montagem.ts`, chamada por `ensaio.ts:48` (`montarMensagens`, que `app.ts` e `rotas-laboratorio.ts` usam):

| Bloco | Tamanho típico | Cache | Onde |
| --- | --- | --- | --- |
| Alma (prompt fixo + bloco de formato S06) | ~17,5 mil caracteres, ~5.000 tokens | Pelo marcador `cache_control` na Anthropic; automático na OpenAI e no Google, porque é o começo idêntico de todo pedido | `montagem.ts:69-75`, `prompt.ts:38-43` |
| Base de conhecimento do turno: 6 trechos buscados no Supabase da agência | até 12.000 caracteres, ~1.200 tokens | Nenhum | `conhecimento.ts:76-83, 127-160` |
| Resumo do cliente | até 1.000 caracteres | Nenhum | `resumo.ts:8, 206` |
| Memória única (ficha até 4.000 + fatos do WhatsApp até 4.000 + preferências) | 500 a 4.000 tokens | Nenhum | `memoria-unica.ts:56-58, 175-191` |
| Histórico: últimas 20 mensagens | ~2.000 tokens | Nenhum | `env.ts:52` |
| Data e hora, nota do anexo, orientação de risco | 100 a 400 tokens | Nenhum | `datahora.ts`, `app.ts:254-270`, `risco.ts` |
| Mensagem do cliente (texto, ou imagem em base64) | | | `app.ts:608-617` |

Fora da Anthropic, tudo que é sistema vira **uma única mensagem `system`** sem marcador de cache (`montagem.ts:87-104`), porque Gemini e GPT tratam mal várias mensagens de sistema (foi assim que a base vazou ao cliente em 16/10). Sem marcador não quer dizer sem cache: a OpenAI e o Google guardam sozinhos o começo repetido do pedido, e hoje esse começo é a alma.

**Os cinco fatos que motivam este PRD** (todos medidos; detalhe na análise):

1. **A base de regras tem 27 trechos, 17.941 caracteres.** Cabe inteira no prompt. Buscar 6 por mensagem paga rede, embedding e preço cheio para esconder do modelo 78% das regras.
2. **O app perdeu 168 diálogos-modelo.** A ferramenta do n8n original, `crystal_knowledge_search`, consultava duas tabelas: `leticia_crystal_hybrid_search` (as 27 regras) e `leticia_crystal_vector_store` (168 diálogos-modelo, 155 mil caracteres, 7 cenários). O commit `a7546486` de 06/10 ligou a Crystal à Edge Function `crystal_hybrid_search`, que lê só a primeira; a RPC de mesmo nome também (conferido no banco em 30/10). Não há decisão registrada: foi descuido. O Luiz confirmou em 30/10 que os 168 estão validados. Os dois índices usam vetores de 1.536 dimensões gerados pelo mesmo `openai/text-embedding-3-small` que a Crystal já usa (conferido: `vector_dims` = 1536 nas duas tabelas; o n8n consultava as duas com uma só consulta).
3. **Uma em cada seis mensagens tem menos de 12 letras úteis** ("oi", "valeu", "entendi"). Hoje custa quase o mesmo que uma consulta tática.
4. **Três blocos de memória dizem a mesma coisa** (resumo, ficha, fatos) e podem passar de 4.000 tokens por turno.
5. **Ninguém mede qualidade em produção de forma contínua.** A amostra humana 👍/👎 da onda 5 (`apps/api/src/routes/staff-crystal-qualidade.ts`) existe, mas depende de alguém abrir; bateria e dossiê rodam só sob demanda. No WhatsApp, 52,8% das respostas passaram de 3 balões.

## Decisões que este PRD fixa

| # | Decisão | O que fica | Por quê | Para mudar |
| --- | --- | --- | --- | --- |
| 1 | Onde o 2.0 vive | **Lado a lado com o atual**, no mesmo serviço `apps/crystal`, escolhido por pedido pelo campo `motor` (`"atual"` ou `"2.0"`). Nenhuma rota nova para o cliente. | Um serviço só, uma memória só, um painel só. A promoção vira um interruptor, e a volta também. | Separar serviços dobraria memória e deploy. |
| 2 | Onde se testa | **Nas duas frentes** (opção C do Luiz, 30/10): Laboratório 2.0 no painel e contas de teste no app real. | Comparar modelos exige conversa repetível; aprovar exige sentir na mão. | Riscar o M09 deixa só o Laboratório. |
| 3 | A alma | **Não muda uma letra.** Congelada em 23/10. O 2.0 continua entregando a mensagem de sistema "Base de conhecimento para esta mensagem" que a alma espera (`apps/crystal/prompt/crystal.md:160-171`). Os **textos de sistema novos** deste PRD (dois cabeçalhos da base, a instrução do perfil, a instrução do avaliador e a frase do teto) moldam a voz da Crystal e passam pela Letícia antes da promoção; não travam a fase 1. | É dela; e a regra de ouro da alma ("tática só com trecho") é o que faz as camadas A e B funcionarem. | Só com a Letícia. |
| 4 | As 27 regras | **Entram inteiras, sempre**, logo depois da alma, com cache (camada A). A busca por turno nelas acaba. Lidas da tabela que o painel edita, recarregadas a cada 10 minutos. Se a base passar de 60 mil caracteres, volta a busca para esta camada (válvula). | O modelo vê 100% das regras em vez de 22%, e nenhuma resposta depende do Supabase para ter as regras. No cache, esse trecho fixo sai a 10% do preço na Anthropic, no Google e na linha `gpt-5`, a 25% na `gpt-4.1` e a 50% na `gpt-4o`. Em dinheiro, esta troca sozinha fica mais barata nos modelos de 10% e um pouco mais cara nos de 25% ou 50%: o ganho dela é de qualidade. | Trocar o limite no M03. |
| 5 | Os 168 diálogos-modelo | **Camada B**: buscados por semelhança só nos níveis tática e print, 4 por vez, corte em 0,5 de similaridade, consulta formada pela mensagem atual mais a mensagem anterior do cliente; em print, a legenda; em print sem legenda, a consulta fixa que já existe ("leitura de print de conversa e como responder"), para não esperar a descrição da imagem. Entram na mesma mensagem de sistema das regras, numa seção "Exemplos de como você já respondeu situações parecidas". | Cada trecho começa com a pergunta de um cliente real: casar pergunta com pergunta funciona. Dentro da mesma mensagem, a alma trata os exemplos como base, não como ordem. | `match_count`, limiar e janela são variáveis de ambiente (M04). |
| 6 | Triagem | **Determinística, sem modelo**: `leve`, `conversa`, `tatica`, `print`, sobre o histórico completo (20), não o do nível. Decide o que entra e o teto de saída. Gravada em `uso_turnos.nivel`. | Custo zero, 1 ms, testável. Na dúvida, tática. | As listas são uma função pura com testes (M02). |
| 7 | Memória | **Perfil único** de até 1.500 caracteres, no lugar de resumo + ficha + fatos. Ficha e fatos entram no turno só até o primeiro perfil consolidado; se os fatos do WhatsApp mudarem depois (hash diferente), uma nova consolidação roda na rodada seguinte. O resumidor usa sempre a janela de 20, qualquer que seja o nível do turno. | Economia de 500 a 3.500 tokens por turno e um só lugar para o veto do cliente. Sem lote de migração. | Limite de 1.500 é variável (M05). |
| 8 | Modelo | **Qualquer modelo do OpenRouter**, com três exclusões: `openrouter/auto` e sufixo `:online` (já recusados no pedido, `pedidos.ts:17-24`) e, na prática, os **gratuitos** e fornecedores que não aceitam `provider.data_collection: deny` (o pedido da Crystal sempre o envia, `openrouter.ts:202`; o OpenRouter devolve "sem provedor" e a resposta falha). O modelo dos clientes continua em `op_crystal_modelo`; o 2.0 em teste usa `op_crystal_modelo_2`. **O motor não depende de fornecedor.** Para OpenAI, Google e DeepSeek vale a montagem de mensagem de sistema única, e o cache automático deles pega no começo fixo (Passo 3, M03). A OpenAI é a principal provável (Luiz, 30/10). Três cuidados com ela: (1) `gpt-5.x`, `gpt-6.x` e a linha `o` pensam antes de responder (`raciocinio.ts:74-80`), recebem teto de pelo menos 1.500 e gastam uns 150 tokens de raciocínio por resposta, cobrados como saída; `gpt-4.1`, `gpt-4o` e os `-chat` não pensam. (2) A reserva tem de ser de **outro fornecedor**: o padrão de hoje é `openai/gpt-4.1-mini` (`env.ts:31`), que cairia junto com a OpenAI. (3) Modelo sem desconto de cache no catálogo, como `deepseek/deepseek-chat`, fica mais caro no 2.0, porque o pedido tem mais tokens; o seletor marca e o portão de custo pega. | Separar o modelo de teste do de produção permite testar OpenAI, Google, Anthropic ou DeepSeek sem tocar nos clientes. | Nada: o seletor já lista o catálogo real. |
| 9 | Promoção | **Um interruptor global**, `op_crystal_motor` (tipo `enum`, molde da chave `crystal_busca`), com palavra LIGAR e senha para ir ao 2.0 e **sem senha** para voltar. A API lê as configurações a cada mensagem (não há cache, `operacao-config.ts:187-195`): vale na mensagem seguinte, no app e no Chatwoot. O atual fica no código por 30 dias; depois sai (M14). | Volta em segundos. | Prazo dos 30 dias é do Luiz. |
| 10 | Suporte e produto | Mensagens claramente de suporte **continuam indo ao modelo**, no nível `leve`, que a alma já sabe tratar (Menu › Suporte). Sem resposta fixa. | Resposta fixa erra com falso positivo e soa robô. | Item futuro com texto da Letícia. |
| 11 | Avaliação automática de qualidade | Roda **dentro do processo da Crystal**, sobre a tabela `mensagens` dela (cifrada, `memoria.ts:135-146`), avalia **100% dos turnos 2.0** enquanto o atual é o padrão (são poucos) e **2% dos turnos atuais**, e grava **só booleanos e rótulos**. É um uso novo do dado do cliente: passa pelo agente `seguranca` e pela decisão do Luiz como encarregado de dados antes de ser codado (M10). | Sem termômetro, toda mudança é no escuro; e com 2% de 200 turnos o portão nunca fecharia. | Trocar as porcentagens em env. |

## Princípios do Motor 2.0

1. **Fixo no cache, variável fora dele.** Alma e regras primeiro, com cache. Exemplos, perfil e histórico depois.
2. **Pagar pelo que a mensagem pede.** Um "valeu" não carrega 168 diálogos nem 20 mensagens.
3. **Nada que a alma não espere.** Os títulos das mensagens de sistema são os que a alma cita. A alma não sabe que existe um 2.0.
4. **Medir antes de trocar.** Cada turno grava motor, nível, trechos, cache e custo. Nenhuma promoção sem o portão.
5. **Mesmas travas, mesmos segredos.** Trava de ataque, de vazamento e semântica, cifra, HMAC, retenção e LGPD valem igual. Chave da Crystal só no servidor; CPF nunca em claro; toda entrada externa validada com Zod; segredos só em `.env`.
6. **Volta em segundos.** Os dois motores convivem até o Luiz desligar o antigo.

## Como o Motor 2.0 monta uma resposta

### Passo 1 · Triagem (sem modelo)

`classificarTurno(texto, anexo, historico)` devolve um nível e um motivo. Regras, nesta ordem (a primeira que casar vale), sobre o texto normalizado por `normalizar()` de `vazamento.ts:81` e `semConfusaveis()` de `confusaveis.ts:101` (não existe texto já normalizado para reusar: a trava de ataque só testa, não devolve):

| Nível | Quando | Fatia estimada |
| --- | --- | --- |
| `print` | Veio imagem (com ou sem legenda). | ~20% |
| `leve` | Menos de 12 letras úteis (a mesma conta de `conhecimento.ts:177-182`), **ou** casa com a lista de saudações e confirmações (M02), **ou** é assunto de suporte sem palavra-tema. | ~16% |
| `conversa` | Não é leve; há pelo menos 2 mensagens de histórico; até 200 caracteres; sem "?"; sem palavra-tema; sem pedido de roteiro. Exemplo: "mandei do jeito que você falou", "tá bom assim?" não (tem "?"). | ~30% |
| `tatica` | Tudo o mais. Sem histórico, toda mensagem não-leve é tática. "ela respondeu kkk" é tática (palavra-tema `ela`). | ~34% |

Áudio: a transcrição segue as regras de texto.

### Passo 2 · O que entra no prompt, por nível

| Bloco | leve | conversa | tatica | print |
| --- | --- | --- | --- | --- |
| Alma (cache) | sim | sim | sim | sim |
| Camada A: 27 regras (cache) | sim | sim | sim | sim |
| Camada B: até 4 diálogos-modelo | não | não | sim | sim |
| Perfil único (≤ 1.500 caracteres) | sim | sim | sim | sim |
| Ficha + fatos do WhatsApp | só até a consolidação | idem | idem | idem |
| Histórico | 6 mensagens | 20 | 20 | 20 |
| Data e hora, orientação de risco | sim | sim | sim | sim |
| Nota do anexo / instrução de print | não | não | não | sim |
| Modelo de visão separado (se configurado) | não | não | não | sim |
| Teto de saída (`max_tokens`) | 150 | 300 | 450 | 600 |

Modelos que pensam antes de responder, pela lista de `raciocinio.ts:74-80`, recebem `reasoning: { effort: "minimal", exclude: true }` e piso de 1.500 tokens (`raciocinio.ts:29`). Na OpenAI pensam `gpt-5.x`, `gpt-6.x`, `o1`, `o3`, `o4` e `gpt-oss`; não pensam `gpt-4.1`, `gpt-4o` e os `-chat`. No Google pensam `gemini-2.5-flash`, `gemini-2.5-pro` e `gemini-3`; o `gemini-2.5-flash-lite` não. A Anthropic só pensa na variante `:thinking`. Nos que pensam, o teto por nível **não** reduz a saída, e o raciocínio mínimo usa cerca de 10% do teto, uns 150 tokens cobrados como saída (`raciocinio.ts:6-13`). Se o modelo recusar o campo, o código reenvia uma vez sem ele (`openrouter.ts:212-216`) e o modelo pensa no padrão dele, mais caro. O selo do Laboratório mostra o `max_tokens` efetivo e os tokens de raciocínio.

### Passo 3 · Ordem das mensagens

**Anthropic** (várias mensagens `system`, cache por prefixo; `ParteConteudo` já aceita `cache_control` em qualquer parte, `openrouter.ts:8-16`):

1. `system` [alma + bloco de formato] com `cache_control: ephemeral`
2. `system` "Base de conhecimento para esta mensagem" com **duas partes**: parte 1 = `CABECALHO_BASE` atual (que começa com `TITULO_BASE`, `conhecimento.ts:127-133`) mais a frase das regras, mais as 27 regras no formato `### [categoria]\n{content}`, com `cache_control: ephemeral`; parte 2 (só tática e print, quando há exemplo acima do corte) = cabeçalho dos exemplos + até 4 diálogos. Com a parte 1, o começo fixo chega a ~10.300 tokens, acima do mínimo de cache de qualquer fornecedor: 1.024 na OpenAI e no Google, 4.096 no Haiku 4.5. No modo válvula a parte 1 muda a cada turno, e esse segundo ponto de cache não reaproveita nada; o log avisa.
3. `system` "O que você já sabe deste aluno" + perfil único (e, só até a consolidação, o bloco da memória única como hoje)
4. histórico (6 ou 20)
5. `system` data e hora; `system` nota do anexo (print); `system` orientação de risco (se houver)
6. `user` mensagem do cliente

**Outros fornecedores: OpenAI, Google, DeepSeek** (uma `system` só, como `montagem.ts:87-104`): alma, rótulo da base, as 27 regras, os exemplos (só tática e print), perfil, data e hora, nota, risco, rótulo de fim; depois histórico e cliente. Nessa ordem, tudo até o fim das 27 regras é **idêntico byte a byte** entre turnos e entre clientes. O rótulo interno leva um sufixo sorteado uma vez por processo, não por turno (`SUFIXO_DOS_ROTULOS`, `montagem.ts:47`), e `neutralizarMarcadores` é pura. É esse começo que o cache automático aproveita. A OpenAI guarda sozinha prefixos a partir de 1.024 tokens, sem cobrar a gravação, com 75% a 90% de desconto na leitura conforme o modelo; o Google faz o mesmo no Gemini 2.5. Dois limites: o cache expira depois de alguns minutos sem uso, então com tráfego de produção fica quente e só com contas de teste nem sempre; e se o OpenRouter alternar o fornecedor por trás do mesmo modelo, o cache recomeça. `tokens_cache` em cada turno e o `cache_pct` do painel mostram se pegou.

### Passo 4 · Depois da resposta

Igual ao atual: porta única de saída (`saida.ts`), travas, reserva, gravação da memória. Novo: o **perfil** é reescrito pelo resumidor 2.0 (`max_tokens` 400, temperatura 0,2, corte por frase) a cada 10 mensagens novas da janela de 20. Tudo gravado em `uso_turnos` com `motor`, `nivel`, `trechos_a`, `trechos_b`, `cortada`.

## Os 14 itens

Ordem de execução = ordem abaixo. Um item por vez. Esforço do Claude Code por item segue a tabela do `CLAUDE.md` do workspace: integração com a Crystal → `xhigh`; tela do painel → `high`; ajuste simples → `medium`. Ultracode desligado na execução; ligado na revisão de fechamento de cada fase.

| Fase | Itens | O que entrega | Clientes sentem? |
| --- | --- | --- | --- |
| 1 · Motor | M01 contrato e chaves · M02 triagem · M03 camada A · M04 camada B · M05 perfil único · M06 tetos, resumidor e visão | O 2.0 existe e responde quando o pedido traz `motor: "2.0"`. | Não |
| 2 · Teste e proteção | M07 Laboratório 2.0 · M08 catálogo completo e lado a lado · M09 contas de teste · M10 qualidade medida (números) · M11 qualidade na tela · M12 teto por cliente | Luiz e Letícia testam no painel e no app; números por motor e por modelo; teto de gasto por cliente nos dois motores. | Só as contas marcadas (e o teto, para todos) |
| 3 · Promoção | M13 aba Motor 2.0, portão e interruptor · M14 aposentar o atual | O 2.0 vira o padrão; volta em segundos; o antigo sai depois de 30 dias. | Sim, na promoção |

---

### M01 · Contrato `motor` e chaves do painel

**Esforço:** `xhigh`.

**Decisão.** O motor é escolhido por pedido. A API decide qual mandar: `"2.0"` quando a conta está marcada (M09) ou quando o interruptor global está ligado (M13); senão não manda nada.

**Objetivo.** Ter o campo e as chaves prontos antes de qualquer comportamento novo.

**Hoje.** `apps/crystal/src/pedidos.ts:57-66` define `ajustesPedido`. `apps/api/src/services/crystal.ts:554-578` monta o corpo e só envia cada ajuste quando há valor. `apps/api/src/services/operacao-config.ts:50-53, 187-195` lê as chaves `op_crystal_*` **a cada mensagem** (sem cache). `packages/shared/src/settings.ts:452-503` descreve as chaves; `packages/shared/src/operacao.ts:83-105` tem `OPERACAO_VALIDADORES`. `SETTING_TYPES` em `settings.ts:30` inclui `enum`; o molde de chave `enum` perigosa é `crystal_busca` (`settings.ts:506-523`).

**O que fazer.**

1. `pedidos.ts`: `motorPedido = z.enum(["atual", "2.0"])` e campo opcional `motor` em `ajustesPedido`. Ausente = `atual` (até o M14).
2. `settings.ts`, grupo `crystal`:
   - `op_crystal_motor`: `type: "enum"`, `options: [{ value: "atual", label: "Atual" }, { value: "2.0", label: "Motor 2.0" }]`, `schema: z.enum(["atual", "2.0"])`, padrão `atual`, `roles: ["admin"]`, `risk: "alto"`, `dangerous: { word: "LIGAR", when: ["2.0"] }` e **sem** `reauthWhen` (a volta é sem senha).
   - `op_crystal_modelo_2`, `op_crystal_modelo_reserva_2`, `op_crystal_modelo_imagem_2`: mesmos validadores dos atuais, padrão vazio (vazio = usa o do motor atual).
3. `operacao-config.ts`: ler as quatro chaves; `ajustesDoMotor(motor)` devolve modelo, reserva e imagem do motor pedido.
4. `apps/api/src/services/crystal.ts`: `...(input.motor === "2.0" ? { motor: "2.0" } : {})`.
5. `apps/crystal/src/app.ts`: ler `motor` validado e repassar aos insumos. Enquanto M02 a M06 não existem, `motor: "2.0"` responde pelo atual, sem erro.
6. `docs/crystal-api.md` (tabela de opcionais, `:71-72`): `motor` · `atual` ou `2.0`.
7. Testes: `pedidos.test.ts`, `contrato-api.test.ts` (corpo sem a chave idêntico), `operacao-config.test.ts`, teste da API de configurações (gravar `2.0` exige LIGAR e senha; `tech` não vê).

**Textos.** Rótulos das opções acima. A tela só aparece no M13.

**Onde mexer.** `apps/crystal/src/pedidos.ts`, `apps/crystal/src/app.ts`, `apps/api/src/services/crystal.ts`, `apps/api/src/services/operacao-config.ts`, `packages/shared/src/settings.ts`, `packages/shared/src/operacao.ts`, `docs/crystal-api.md`.

**Critérios de aceite.** Pedido sem `motor` gera corpo byte a byte igual ao de hoje. `motor: "2.0"` é aceito e grava `uso_turnos.motor = 'atual'` enquanto o motor não existe. `op_crystal_motor` só grava `2.0` com LIGAR e senha (teste da API de configurações). `pnpm lint && pnpm typecheck && pnpm test` verdes.

**Fora deste item.** Prompt, busca, memória.

**Depende de.** Nada.

**Cuidados.** Nesta fase a API nunca envia `motor: "2.0"`: a chave não tem tela e a coluna de conta não existe. Passa pelo agente `seguranca`.

---

### M02 · Triagem determinística

**Esforço:** `xhigh`.

**Decisão.** Função pura, sem modelo, listas versionadas no código com testes. Grava `nivel` e `motor` em `uso_turnos`.

**Objetivo.** Um "valeu" não carregar exemplos, 20 mensagens de histórico nem teto de 700 tokens, e cada turno dizer no painel por que custou o que custou.

**Hoje.** Única triagem: regra das 12 letras úteis para buscar ou não (`conhecimento.ts:177-182`). Teto único de 700 tokens (`env.ts:37`). Histórico sempre 20. `uso_turnos` tem `busca` com valores `pulada|edge|propria|falhou|desligada` (`packages/shared/src/alma.ts:605`) e `trechos`; `sem_trechos_pct` conta `trechos = 0` com busca não nula (`uso.ts:620`); `agregarUso` agrega por modelo e por dia (`uso.ts:502-525`), índice só em `em` (`uso.ts:226`).

**O que fazer.**

1. Novo `apps/crystal/src/triagem.ts`: `classificarTurno(entrada): { nivel, motivo }`, `Nivel = "leve" | "conversa" | "tatica" | "print"`, `motivo` em `imagem | curta | saudacao | confirmacao | suporte | continuacao | pergunta | tema | roteiro | longa | sem_historico`. Normaliza com `normalizar()` (`vazamento.ts:81`) e `semConfusaveis()` (`confusaveis.ts:101`). Olha o histórico completo (20), não o do nível.
2. Listas (texto normalizado, minúsculas, sem acento):
   - **Saudações:** `oi`, `oie`, `ola`, `opa`, `eai`, `e ai`, `eae`, `bom dia`, `boa tarde`, `boa noite`, `hey`, `fala`, `oi crystal`, `crystal`, seguidas ou não de `crystal`, `gata`, `linda`, `tudo bem`, `tudo bom`, `td bem`, `td bom`, `blz` e pontuação.
   - **Confirmações:** `ok`, `okay`, `blz`, `beleza`, `valeu`, `obrigado`, `obrigada`, `vlw`, `entendi`, `sim`, `nao`, `kk+`, `haha+`, `rs+`, `show`, `top`, `boa`, `massa`, `certo`, `ta`, `ta bom`, `isso`, `perfeito`, `legal`, `entendido`, `otimo`, `pode ser`, `claro`, `vou tentar`, `vou fazer isso`, `bora`, `fechou`, `combinado`, `tmj`, emoji sozinho.
   - **Suporte:** `pagamento`, `pagar`, `assinatura`, `cancelar`, `reembolso`, `estorno`, `nao consigo entrar`, `login`, `senha`, `cobranca`, `boleto`, `cartao recusado`, `renovar`, `mensalidade`, **e** nenhuma palavra-tema.
   - **Palavras-tema:** `ela`, `ele`, `mina`, `garota`, `mulher`, `namorada`, `esposa`, `ex`, `crush`, `match`, `tinder`, `bumble`, `instagram`, `insta`, `direct`, `story`, `stories`, `vacuo`, `visualizou`, `respondeu`, `friendzone`, `encontro`, `date`, `sair`, `convidar`, `beijo`, `ficar`, `ficamos`, `transar`, `sexo`, `casamento`, `relacionamento`, `conversa`, `mensagem`, `print`.
   - **Pedido de roteiro:** `o que (eu )?(respondo|mando|falo|digo|escrevo)`, `me (da|manda|passa) (um|uma|umas|uns|algumas) (exemplo|ideia|frase|mensagem|resposta|texto|opcao)`, `como (eu )?respondo`, `o que (eu )?posso (falar|mandar|responder)`, `sugestao de (mensagem|resposta)`, `me ajuda a responder`.
3. `app.ts`, com `motor: "2.0"`: triagem logo após as travas de entrada; o nível define histórico (6 ou 20), busca da camada B (M04), nota do anexo e `max_tokens` (M06).
4. `uso.ts`: colunas `motor text not null default 'atual'` e `nivel text` (nula no atual), pelo padrão `alter table add column if not exists` (`uso.ts:227-231`). Coluna `busca` ganha o valor `camada_a` (turno 2.0 sem busca), acrescentado a `USO_BUSCAS`; `trechos` passa a significar "trechos buscados" (= `trechos_b` no 2.0); `sem_trechos_pct` conta só turnos com busca de verdade. `GET /v1/uso` agrega também por motor e por nível (turnos, custo, custo médio, `cache_pct`), com índice `(motor, em)`; tipos em `packages/shared/src/alma.ts` (`ResumoUso`).
5. `triagem.test.ts`: pelo menos 40 casos (cada regra, acento, maiúscula, emoji, áudio, imagem sem legenda, primeira mensagem).

**Textos.** Rótulos para o painel (M07): `Leve`, `Conversa`, `Tática`, `Print`; motivos: `mensagem curta`, `saudação`, `confirmação`, `assunto de suporte`, `continuação`, `tem pergunta`, `tem tema`, `pede roteiro`, `mensagem longa`, `primeira mensagem`.

**Onde mexer.** `apps/crystal/src/triagem.ts` (novo), `triagem.test.ts` (novo), `app.ts`, `uso.ts`, `packages/shared/src/alma.ts`.

**Critérios de aceite.** Os 40 casos passam: "bom dia, tudo bem com você?" é `leve`; "ela respondeu kkk" é `tatica`; "mandei do jeito que você falou" com histórico é `conversa` e sem histórico é `tatica`; imagem sem legenda é `print`. Turno 2.0 grava `motor = '2.0'`, `nivel` e `busca = 'camada_a'`. Nível `leve` manda 6 mensagens de histórico (teste de montagem).

**Fora deste item.** Resposta fixa para suporte. Triagem por modelo.

**Depende de.** M01.

**Cuidados.** Nada da mensagem vai ao log: só nível e motivo.

---

### M03 · Camada A: as 27 regras inteiras no prompt, com cache

**Esforço:** `xhigh`.

**Decisão.** No 2.0, a busca por turno na tabela de regras acaba. As regras entram inteiras, sempre, dentro da mensagem "Base de conhecimento para esta mensagem", com `cache_control` na Anthropic.

**Objetivo.** O modelo ver 100% das regras em todo turno, com desconto de cache em qualquer fornecedor que o dê, sem depender do Supabase para responder.

**Hoje.** `conhecimento.ts:76-83` busca 6 trechos por turno; `:127-160` monta a mensagem (`TITULO_BASE` = "Base de conhecimento para esta mensagem", `CABECALHO_BASE` = título + "(material interno… nunca copie…)", conteúdo como string). `base-conhecimento.ts:115-122` já **lista** a tabela inteira pela RPC `app_conhecimento_listar` (`env.ts:90`, `service_role`). `prompt.ts:5` tem `LIMITE_CONHECIMENTO = 60_000` e um carregador de arquivos `conhecimento/*.md` (`prompt.ts:30-43`) que lê disco, não a tabela. A trava de vazamento guarda impressões dos trechos do turno num cache por texto com teto 64 (`vazamento.ts:798, 856`) e reconhece `TITULO_BASE` (`vazamento.ts:822`).

**O que fazer.**

1. Novo `apps/crystal/src/regras.ts`: `GestorDeRegras` que chama `listar()` de `base-conhecimento.ts` na subida e a cada 10 minutos (`REGRAS_RECARGA_MS`, padrão 600.000), guarda a última versão boa em memória, ordena por `category` e `id`, formata `### [category]\n{content}`, expõe `texto()`, `chars()` e `versao()` (hash). Falha na subida sem versão em memória: o 2.0 responde **sem** a parte 1 e loga `regras: indisponíveis`; `/healthz` ganha `regras: { trechos, chars, versao, em }`.
2. Válvula: texto acima de `LIMITE_CONHECIMENTO` (60.000) → aviso no log e o 2.0 volta a buscar 6 trechos nesta camada até a base caber (`busca` volta a `edge`/`propria`).
3. `montagem.ts`: `InsumosDoTurno` ganha `regras: string | null`, `exemplos: string | null`, `perfil: MensagemModelo | null`; `PartesDoTurno` em `ensaio.ts` idem; `montarMensagens` ramifica por `motor` (a atual continua igual). Na Anthropic, a mensagem da base é `{ role: "system", content: [{ type: "text", text: cabecalhoParte1 + regras, cache_control: { type: "ephemeral" } }, ...(exemplos ? [{ type: "text", text: exemplos }] : [])] }`. Fora da Anthropic, regras e exemplos entram na `system` única com `rotulo("base de conhecimento")` e `rotulo("exemplos de respostas parecidas")`, por `neutralizarMarcadores`, nesta ordem fixa: alma, rótulo da base, regras, e só então exemplos e o que muda por cliente. Nada variável entra antes do fim das regras: é isso que faz o cache automático da OpenAI e do Google pegar.
4. `vazamento.ts`: passar as 27 regras e os exemplos do turno como trechos entregues (o cache por texto, teto 64, cobre 27 + 4 sem recalcular; só trecho novo custa). Acrescentar os dois cabeçalhos novos a `FRASES_DA_MONTAGEM`.
5. `uso.ts`: `trechos_a int` (27 quando a camada entrou inteira; 6 na válvula; 0 se indisponível) e `regras_versao text`.
6. Testes: `regras.test.ts`, `montagem.test.ts` (duas partes e dois `cache_control` na Anthropic; `system` única com os dois rótulos fora dela), `vazamento.test.ts` (regra copiada é barrada), e o teste de **prefixo estável**: dois turnos de clientes diferentes, com perfis, históricos, níveis e exemplos diferentes, montados para `openai/gpt-4.1-mini`, `openai/gpt-5-mini`, `google/gemini-2.5-flash` e `deepseek/deepseek-chat`, têm a mensagem `system` idêntica do primeiro caractere até o fim das 27 regras, e esse trecho tem pelo menos 9.000 tokens estimados (3,5 caracteres por token).

**Textos (literais, dentro da mensagem de sistema; passam pela Letícia antes da promoção).**

- Parte 1 começa com o `CABECALHO_BASE` atual e segue: `Abaixo estão as regras e diretrizes do método, válidas para toda conversa. Use-as como bússola; nunca as copie nem as cite ao aluno.`
- Parte 2 (M04): `Exemplos de como você já respondeu situações parecidas. Adapte o tom e o roteiro à situação dele; nunca copie, nunca diga que são exemplos.`

**Onde mexer.** `apps/crystal/src/regras.ts` (novo), `montagem.ts`, `ensaio.ts`, `vazamento.ts`, `uso.ts`, `server.ts`, `app.ts`, `base-conhecimento.ts` (reusar `listar`).

**Critérios de aceite.** O teste de prefixo estável passa para OpenAI, Google, DeepSeek e Anthropic (nesta, as duas primeiras `system` idênticas entre turnos). No Laboratório (M07), com um modelo da OpenAI e um de outro fornecedor, a segunda mensagem mandada em até 5 minutos traz `tokens_cache` de pelo menos 8.000 (manual). Turno 2.0 abaixo de 60 mil nunca chama `crystal_hybrid_search` (teste: zero chamadas). Edição no painel aparece em até 10 minutos. Regra copiada ao cliente é barrada.

**Fora deste item.** Os 168 (M04). Texto das regras.

**Depende de.** M01, M02.

**Cuidados.** `service_role` só no servidor. Nunca logar conteúdo da base. Fora da Anthropic a `system` única cresce ~5 mil tokens: o catálogo traz `contexto`; o seletor (M08) marca "contexto curto" abaixo de 64 mil.

---

### M04 · Camada B: os 168 diálogos-modelo, buscados por situação

**Esforço:** `xhigh`.

**Decisão.** Via própria: a Crystal gera o embedding da consulta (`openai/text-embedding-3-small`, 1536 dimensões, como já faz em `conhecimento.ts:214-250`) e chama a RPC `match_leticia_crystal_vector_store(query_embedding, match_threshold, match_count, filter)` pelo PostgREST com a `service_role`, `filter = {}`. Não usar a Edge Function `crystal_knowledge_search` (aberta sem segredo, ver Avisos). A API de embeddings não tem `provider.data_collection` (só a de chat): ao OpenRouter vai o texto da consulta, até 500 caracteres, como hoje.

**Objetivo.** Devolver à Crystal do app o repertório que a do WhatsApp tinha, só quando a mensagem pede tática ou leitura de print.

**Hoje.** Nada do app lê `leticia_crystal_vector_store`. A RPC existe (conferida em 30/10): devolve `id`, `content`, `metadata`, `similarity`, filtra por `similarity > match_threshold`; `metadata` tem `title`, `category`, `chunk_index`, `document_id`, `tom`, `version`. Vetores de 1.536 dimensões, iguais aos das 27 regras.

**O que fazer.**

1. Novo `apps/crystal/src/exemplos.ts`: `BuscaExemplos.buscar(consulta)`. Consulta: tática = mensagem atual + `\n` + última mensagem do cliente no histórico, cortada em `EXEMPLOS_CONSULTA_MAX` (500); print com legenda = a legenda; print sem legenda = `CONSULTA_PRINT` que já existe (`conhecimento.ts:163`), para a busca correr **em paralelo** com a leitura da imagem. Env: `EXEMPLOS_MATCH_COUNT` (1 a 8, padrão 4), `EXEMPLOS_LIMIAR` (0,3 a 0,9, padrão 0,5), `EXEMPLOS_TIMEOUT_MS` (1.000 a 8.000, padrão 4.000), `SUPABASE_EXEMPLOS_RPC` (padrão `match_leticia_crystal_vector_store`). Reusar o cliente de embedding e o PostgREST de `conhecimento.ts` (expor os dois).
2. Formato de cada exemplo: `### Exemplo · {metadata.title}\n{content}`. Os rótulos `[Cenário: …] [Tom: …] Interacao:` ficam (são conteúdo validado); `vazamento.ts` ganha `[Cenário:` e `Interacao:` na camada de estrutura.
3. Só em `tatica` e `print`, em paralelo com a trava semântica e a memória (`app.ts:509-571`). Falhou ou zero acima do corte: parte 2 não entra; log `exemplos: sem trecho acima do corte` ou código e status.
4. Cache em memória por hash da consulta normalizada, 10 minutos, 512 entradas.
5. `uso.ts`: `trechos_b int`, `exemplos_ms int`. Tipo `embedding` já existe em `USO_TIPOS` (`alma.ts:603`).
6. Testes: `exemplos.test.ts`, `montagem.test.ts`, `vazamento.test.ts` (`[Cenário:` na resposta é barrado).

**Textos.** Cabeçalho da parte 2 no M03. Log acima.

**Onde mexer.** `apps/crystal/src/exemplos.ts` (novo), `env.ts`, `app.ts`, `montagem.ts`, `vazamento.ts`, `uso.ts`, `server.ts`, `conhecimento.ts`, `docs/crystal-api.md` (seção "Camada B", com a dependência da RPC da agência).

**Critérios de aceite.** `leve` e `conversa`: zero chamadas à busca de exemplos. "ela leu e não respondeu, o que eu faço?" em `tatica`: pelo menos 1 exemplo de "Conversa Travada" ou "Ela Esfriou" (manual no Laboratório). Mesma consulta duas vezes em 10 min: um embedding. `[Cenário:` na resposta é barrado. p95 da busca abaixo de 1.500 ms.

**Fora deste item.** Editar os 168 pelo painel. Reranking por modelo.

**Depende de.** M03.

**Cuidados.** Ao Supabase vai só a consulta. Confirmar com a agência que a RPC fica.

---

### M05 · Perfil único do cliente

**Esforço:** `xhigh` (memória e LGPD).

**Decisão.** No 2.0, um só bloco "O que você já sabe deste aluno", de até 1.500 caracteres, substitui resumo + ficha + fatos. Consolidação na primeira rodada do resumidor de cada cliente; nova consolidação se os fatos do WhatsApp mudarem.

**Objetivo.** Menos tokens, um só lugar para preferências e vetos, mesmo comportamento no app e no Chatwoot.

**Hoje.** `resumo.ts`: 1.000 caracteres por `slice` (`:8, 206`), roda quando há `janela` mensagens fora e deixa `janela/2` (`:29-32`; com 20 → a cada 10), primeira rodada só com a janela (`:129-132`), herda `max_tokens` 700 e temperatura 0,7 (`:188-193`). `memoria-unica.ts`: lê `app_memoria_ler` (ficha, fatos, preferências; cache 10 min; `:56` teto 4.000) e monta bloco de até ~14 mil caracteres (`:175-191`); grava o resumo em `crystal_memoria_unica.app_resumo` (`:100-104`). O apagar de dados **já** chama `app_memoria_apagar` pela API (`apps/api/src/services/lgpd.ts:303, 324-330`; `base-alunos.ts:118`); a linha `docs/crystal-api.md:119` está desatualizada. `Lapides` (`lapides.ts:17-20`) é uma classe em memória de 15 min, não uma tabela.

**O que fazer.**

1. `resumo.ts`, modo 2.0: `PERFIL_MAX = 1500` (env `CRYSTAL_PERFIL_MAX`, 800 a 3.000), corte **por frase** (última `.`, `!` ou `?` antes do limite), `maxTokens: 400`, `temperatura: 0.2`, instrução `INSTRUCAO_PERFIL`. O resumidor usa **sempre** a janela de 20, independentemente do nível do turno. O texto gravado começa com `[perfil v2]` (conta no limite); `vazamento.ts` ganha a marca.
2. Consolidação: cliente com `pessoa_id` cujo perfil não começa com `[perfil v2]`, ou cujo hash dos fatos do WhatsApp (`sha256` do `content` de `whatsapp_fatos`, guardado na tabela `resumos` em coluna nova `fatos_hash`) mudou: o turno 2.0 inclui o bloco da memória única como hoje, e a próxima rodada do resumidor recebe ficha + fatos + preferências + perfil anterior + mensagens novas e devolve o perfil consolidado. Fora disso, o bloco da memória única não entra no 2.0 (o `app_memoria_ler` continua sendo chamado para `preferencias` e para o hash, com o cache de 10 min).
3. Perfil gravado em `resumos` (cifrado) e copiado para `crystal_memoria_unica.app_resumo` como hoje.
4. O motor atual continua lendo `resumos` como "resumo": um perfil v2 ali é um resumo melhor; a marca `[perfil v2]` vai ao modelo e é inofensiva; a trava impede que chegue ao cliente. Cliente que alterne de motor (M09) não quebra: o atual só volta a injetar ficha + fatos, custando mais.
5. `uso_turnos.tipo` ganha `perfil` em `USO_TIPOS` (o `check` é refeito a partir da lista, `uso.ts:240`).
6. Testes: `resumo.test.ts` (corte por frase, limite, marca, consolidação, re-consolidação por hash, parâmetros próprios, janela fixa 20), `memoria-unica.test.ts`, `vazamento.test.ts`, teste de integração com Postgres no molde de `onda5.pg.test.ts`.

**Textos.** `INSTRUCAO_PERFIL` (literal; passa pela Letícia antes da promoção):

> Você mantém o perfil de um aluno para a Crystal, em português do Brasil, em até 1.500 caracteres, como texto corrido (sem listas). Guarde só o que ajuda a aconselhar: nome como ele prefere ser chamado; situação atual (solteiro, ficando, namorando, casado) e com quem; o que já aconteceu e o que ele já tentou; o que a Crystal já sugeriu e o resultado; preferências e vetos (expressões, apelidos ou abordagens que ele pediu para não usar: isso nunca sai do perfil). Nada de dado de contato, documento, endereço ou saúde. Escreva a partir do perfil anterior, do que veio do WhatsApp (se houver) e das mensagens novas; o mais recente vale sobre o mais antigo. Comece exatamente com "[perfil v2] ".

**Onde mexer.** `apps/crystal/src/resumo.ts`, `memoria-unica.ts`, `memoria.ts` (coluna `fatos_hash`), `app.ts`, `uso.ts`, `vazamento.ts`, `env.ts`, `docs/crystal-api.md` (seção memória; corrigir a linha 119).

**Critérios de aceite.** Cliente com ficha e fatos: no primeiro turno 2.0 o bloco da memória única entra; depois da primeira rodada, o perfil começa com `[perfil v2]` e o bloco não entra mais; fatos alterados no Supabase disparam nova consolidação. Perfil nunca passa de 1.500 nem termina no meio de uma frase. O apagar da API continua apagando `resumos` e `crystal_memoria_unica` (teste existente em `lgpd.ts`). Veto ("não me chama de gatão") aparece no perfil da rodada seguinte (modelo falso).

**Fora deste item.** Ficha pré-gerada (`ficha.ts`). Perfil editável pela equipe.

**Depende de.** M01, M02.

**Cuidados.** Perfil cifrado em repouso, nunca em log nem em rota do painel. Passa pelo agente `seguranca`.

---

### M06 · Tetos por nível, resumidor e modelo de visão

**Esforço:** `high`.

**Decisão.** `max_tokens` por nível (150 / 300 / 450 / 600); resumidor com parâmetros próprios (M05); modelo de visão do 2.0 (`op_crystal_modelo_imagem_2`); corte registrado em coluna própria, não como erro.

**Hoje.** `CRYSTAL_MAX_TOKENS` 700 (`env.ts:37`, faixa 64 a 4.000); o ajuste do painel tem **mínimo 300** em três lugares (`pedidos.ts:50`, `packages/shared/src/laboratorio.ts:39`, `settings.ts:542` `crystal_max_resposta`). Raciocínio: piso 1.500 (`raciocinio.ts:29`). `finish_reason` não é lido no stream (`openrouter.ts`). Qualquer `erro` não nulo tira a linha de "respostas" (`uso.ts:617`). Visão: `visao.ts:37` 3.000 no turno, `:39` 500 na memória.

**O que fazer.**

1. `env.ts`: `CRYSTAL_MAX_TOKENS_LEVE` 150, `_CONVERSA` 300, `_TATICA` 450, `_PRINT` 600 (64 a 2.000 cada). No 2.0, o `max_tokens` do painel, se vier, é teto do teto. Baixar o mínimo dos três schemas de 300 para 100.
2. Raciocínio: o piso de `raciocinio.ts` continua, e nesses modelos o teto por nível não reduz a saída. Na OpenAI isso vale para `gpt-5.x`, `gpt-6.x` e a linha `o`. Para os tetos por nível valerem com a OpenAI, o modelo das respostas tem de ser um que não pensa: `gpt-4.1`, `gpt-4.1-mini`, `gpt-4o` ou `gpt-5.2-chat`. O selo do Laboratório (M07) mostra o `max_tokens` efetivo e os tokens de raciocínio.
3. `openrouter.ts`: capturar `finish_reason` do stream; `uso.ts`: coluna `cortada boolean not null default false` (verdadeira em `length`). Painel conta por nível; acima de 2% o teto daquele nível está baixo. **Não** usar `erro`.
4. Com `motor: "2.0"` e `op_crystal_modelo_imagem_2` gravado, a leitura da imagem usa esse modelo; vazio, `op_crystal_modelo_imagem`; vazio, o modelo das respostas vê a imagem. Se o modelo das respostas **não lê imagem** e os dois `_imagem` estão vazios, o turno `print` responde a frase de erro C02 que já existe para imagem sem leitura, e o seletor (M08) avisa ao gravar um modelo "sem imagem" sem visão configurada.
5. Instruções de print (`app.ts:266-270`, `visao.ts:49`) não mudam.
6. Testes: `app.test.ts`, `openrouter.test.ts` (finish_reason), `visao.test.ts`, `uso.test.ts`.

**Textos.** Aviso do seletor (M08): `Este modelo não lê imagem. Escolha também um modelo que lê imagem em "Modelo que lê as imagens", ou os prints vão falhar.`

**Onde mexer.** `apps/crystal/src/env.ts`, `app.ts`, `raciocinio.ts`, `visao.ts`, `openrouter.ts`, `uso.ts`, `pedidos.ts`, `packages/shared/src/laboratorio.ts`, `packages/shared/src/settings.ts`.

**Critérios de aceite.** Turno `leve` 2.0 pede `max_tokens: 150` (modelo sem raciocínio) ou 1.500 (com). Turno `print` com `_imagem_2 = X` chama X. Resposta cortada grava `cortada = true` e continua contada como resposta. **Fecha a fase 1:** revisão com ultracode ligado e agente `seguranca` APROVADO sobre M01 a M06.

**Fora deste item.** Instrução de print. Teto por cliente (M12).

**Depende de.** M02, M05.

---

### M07 · Laboratório 2.0: motor por conversa e selo por resposta

**Esforço:** `high`.

**Decisão.** O Laboratório atual ganha, por conversa, o interruptor **Motor** (Atual | 2.0) e, em cada resposta, um selo com nível, motivo, trechos A e B, cache, custo, tempo e `max_tokens` efetivo. Sem imagem: o Laboratório continua só texto; print testa-se no app (M09).

**Hoje.** Laboratório (20/10): só admin; conversas em `apps/api/src/db/laboratorio.ts`; rota interna sem estado `POST /v1/laboratorio/responder` (`apps/crystal/src/rotas-laboratorio.ts`), janela 30 × 1.500, teto diário `laboratorio_teto_diario_usd` (US$ 5), 30 pedidos por minuto; perfil simulado entra como "resumo do aluno" via `textoDoPerfil` → `mensagemDoResumo` (`:81-86, 136`), com `LAB_PERFIL_MOMENTO_MAX = 400` (`packages/shared/src/laboratorio.ts:42`). Componentes: `apps/web/components/equipe/laboratorio/{Laboratorio,Conversa,MensagemLab,SeletorModeloLab,Dossie,FolhasMensagem}.tsx`.

**O que fazer.**

1. Rota interna aceita `motor`. Com `2.0`: triagem sobre a última mensagem e o histórico enviado, camada A, camada B, perfil simulado como "O que você já sabe deste aluno", tetos. Devolve, além do texto: `motor`, `nivel`, `motivo`, `trechos_a`, `trechos_b`, `exemplos: [{ id, title, similarity }]` (nunca conteúdo), `tokens_entrada`, `tokens_cache`, `tokens_saida`, `tokens_raciocinio`, `max_tokens`, `custo_usd`, `ms`, `modelo`, `vazamento`, `cortada`. Grava `uso_turnos` com `tipo = 'laboratorio'`, `motor`, `nivel`.
2. API (`apps/api/src/routes/staff-laboratorio.ts`, `db/laboratorio.ts`, `db/types.ts`): a conversa guarda `motor`; `gerar` e `regenerar` repassam. `labPerfilSchema` ganha `sabe` (texto até 1.500) para simular cliente com histórico.
3. Tela: em `Conversa.tsx`, interruptor segmentado "Motor" ao lado do seletor; muda só para mensagens novas, com a divisória "A partir daqui: Motor 2.0 · {modelo}". Em `MensagemLab.tsx`, o selo; tocar abre `FolhasMensagem` com motivo e exemplos (cenário e nota).
4. Testes: `rotas-laboratorio.test.ts`, `staff-laboratorio.test.ts`, `Laboratorio.test.tsx`, `MensagemLab.test.tsx`; e2e em 1440 e 390 px.

**Textos (literais).**

- Interruptor: `Motor` · `Atual` · `2.0`
- Divisória: `A partir daqui: Motor 2.0 · {modelo}` / `A partir daqui: Motor atual · {modelo}`
- Selo 2.0: `2.0 · {nível} · {trechos_a} regras + {trechos_b} exemplos · cache {pct}% · US$ {custo} · {s} s · teto {max_tokens}`; atual: `Atual · {trechos} trechos · cache {pct}% · US$ {custo} · {s} s`
- Folha: título `Por que esta resposta custou isso`; linhas `Nível: {nível} ({motivo})`, `Regras no prompt: {trechos_a}`, `Exemplos usados: {lista "Cenário · nota"}`, `Entrada: {tokens} tokens ({cache}% em cache)`, `Saída: {tokens} tokens (teto {max_tokens})`, `Raciocínio: {tokens} tokens, cobrados como saída` (só quando o modelo pensa), `Modelo: {modelo}`, `Cortada pelo teto: sim/não`
- Perfil simulado, campo novo: `O que ela já sabe dele` · ajuda `Até 1.500 caracteres. Entra como o perfil do cliente.`

**Onde mexer.** `apps/crystal/src/rotas-laboratorio.ts`, `ensaio.ts`, `apps/api/src/routes/staff-laboratorio.ts`, `apps/api/src/db/laboratorio.ts`, `apps/api/src/db/types.ts`, `packages/shared/src/laboratorio.ts`, `apps/web/components/equipe/laboratorio/*`, `docs/equipe.md`, `e2e/`.

**Critérios de aceite.** Admin troca para 2.0, manda "ela leu e não respondeu, o que eu faço?" e vê selo com Tática, 27 regras, ≥ 1 exemplo, custo, tempo e teto. Nenhum texto de regra ou exemplo chega ao navegador (teste da rota). e2e verdes nos dois tamanhos; axe sem violações. **Conferir em aparelho (Luiz):** iPhone Safari, Laboratório no celular (U39).

**Fora deste item.** Imagem no Laboratório. Lista de modelos e lado a lado (M08).

**Depende de.** M01 a M06.

---

### M08 · Catálogo completo de modelos e Lado a lado

**Esforço:** `high`.

**Decisão.** O seletor do Laboratório mostra o catálogo inteiro do OpenRouter com chips de fornecedor, preço, marcas e a exclusão explícita dos gratuitos; e o Laboratório ganha o modo **Lado a lado** (dois motores, ou dois modelos), com "Prefiro esta" alimentando o portão (M13).

**Hoje.** `GET /staff/laboratorio/modelos` devolve o catálogo inteiro sem filtro (`staff-laboratorio.ts:180-187`); `catalogo.ts:15-30` já traz `fornecedor`, `contexto`, `preco_entrada_mtok`, `preco_saida_mtok`, `preco_cache_mtok`, `imagem`, `gratuito`. `SeletorModeloLab.tsx:103-106` filtra só por texto e mostra preço e marcas (`:10-17`). `openrouter/auto` e `:online` são recusados no **pedido** (`pedidos.ts:17-24`, `rotas-laboratorio.ts:100`) com `MODELO_AUTO_RECUSADO` e `MODELO_ONLINE_RECUSADO`. `raciocinio.ts:44` (`sinaisDoOpenRouter`) sabe quem é modelo de raciocínio. "Testar lado a lado" existe para alma ativa × rascunho (`rotas-alma.ts:222-260`).

**O que fazer.**

1. Catálogo: acrescentar `raciocinio`, `recusado` (auto, `:online`, gratuito) e `cache` (verdadeiro quando `preco_cache_mtok` existe e é menor que `preco_entrada_mtok`) a cada item; manter a lista inteira.
2. Seletor: chips `Todos · OpenAI · Anthropic · Google · DeepSeek · Outros` (por prefixo do id), ordenação por preço, marcas `lê imagem`, `sem imagem`, `raciocínio`, `contexto curto` (abaixo de 64 mil), `gratuito: pode falhar`, `sem desconto de cache` (no Motor 2.0 esse modelo custa mais que hoje). Item `recusado` aparece desabilitado com a razão (reusar as duas mensagens de `pedidos.ts`; para gratuito, o texto abaixo).
3. Lado a lado: `POST /staff/laboratorio/conversas/:id/lado-a-lado` com `{ a: { motor, modelo }, b: { motor, modelo } }`, duas respostas em paralelo pelo mesmo caminho do `/v1/alma/testar`, contadas duas vezes no teto diário. Tela `LadoALado.tsx`: duas colunas (abas A | B no celular), cada uma com selo; botão `Prefiro esta` grava auditoria `laboratorio.preferencia` com ids, motores e modelos (nunca texto).
4. Erro de modelo que o OpenRouter recusa por `data_collection: deny`: a rota traduz para a mensagem literal abaixo.
5. Testes: catálogo, seletor (chips, recusados), lado a lado (teto conta duas vezes), e2e nos dois tamanhos.

**Textos (literais).**

- Chips: `Todos` · `OpenAI` · `Anthropic` · `Google` · `DeepSeek` · `Outros`
- Marcas: `lê imagem` · `sem imagem` · `raciocínio` · `contexto curto` · `gratuito: pode falhar` · `sem desconto de cache`
- Ajuda da marca de cache: `Este modelo não dá desconto de cache. No Motor 2.0 ele fica mais caro que hoje, porque o pedido tem mais tokens.`
- Ajuda da marca de raciocínio: `Este modelo pensa antes de responder: o teto de resposta sobe para 1.500 e o pensamento é cobrado como saída.`
- Gratuito recusado: `Modelos gratuitos não são aceitos: o fornecedor treina com a conversa e a Crystal exige que não treine.`
- Sem provedor: `Nenhum fornecedor deste modelo aceita não treinar com a conversa. Escolha outro modelo.`
- Lado a lado: título `Lado a lado`; colunas `A` e `B`; botão `Prefiro esta`; aviso `As duas respostas contam no teto do dia.`

**Onde mexer.** `apps/crystal/src/catalogo.ts`, `apps/api/src/routes/staff-laboratorio.ts`, `apps/web/components/equipe/laboratorio/SeletorModeloLab.tsx`, `LadoALado.tsx` (novo), `packages/shared/src/laboratorio.ts`, `docs/equipe.md`, `e2e/`.

**Critérios de aceite.** Cada chip mostra pelo menos um modelo; `openrouter/auto` e gratuitos aparecem desabilitados com a razão; modelo com contexto abaixo de 64 mil tem a marca. Lado a lado Atual × 2.0 com o mesmo modelo: duas respostas, dois selos, "Prefiro esta" grava auditoria sem texto. e2e verdes; axe sem violações.

**Fora deste item.** Editar os 168. Exportar conversas.

**Depende de.** M07.

---

### M09 · Contas de teste no app real

**Esforço:** `xhigh`.

**Decisão.** Coluna `crystal_motor` em `User` (`'2.0'` ou nula), marcada pela equipe na ficha do cliente. Para quem está marcada, a API envia `motor: "2.0"` e os modelos `_2`, no app e no Chatwoot quando o telefone está vinculado a essa conta (o robô já resolve a conta pelo vínculo, `chatwoot-bot.ts:174-215`); sem vínculo, no Chatwoot só vale o interruptor global (M13). O cliente marcado vê no menu ⋮ a linha "Motor 2.0 (teste)". A API passa a guardar `motor` e `nivel` na mensagem da Crystal, para a amostra de qualidade filtrar por motor (M10).

**Hoje.** `apps/api/src/services/messages.ts:590-656` monta a chamada; `chatwoot-bot.ts:293-304` idem; `User` em `apps/api/prisma/schema.prisma:10-50` (`@map("snake_case")`); `/me` em `apps/api/src/routes/me.ts:41-73` (`toUserDto`); menu ⋮ em `apps/web/components/AppMenu.tsx:108`; ficha do cliente em `apps/web/components/equipe/alunos/ficha/FichaAluno.tsx` (+ `DadosTab.tsx`, `abas.tsx`) e rotas `apps/api/src/routes/staff-alunos-ficha.ts:142-341`. O evento `done` da Crystal já traz `uso` (`docs/crystal-api.md:267-297`).

**O que fazer.**

1. Migração Prisma: `User.crystalMotor String? @map("crystal_motor")`; `Message` (direção `out`) ganha `crystalMotor String?` e `crystalNivel String?`, preenchidos a partir do `done`.
2. `messages.ts` e `chatwoot-bot.ts`: `motor = user?.crystalMotor === "2.0" || opCrystalMotor === "2.0" ? "2.0" : undefined`; ajustes de `ajustesDoMotor(motor)`.
3. Ficha do cliente: bloco "Motor da Crystal" com interruptor (só admin; auditoria `cliente.motor` com id do cliente e quem ligou; sem senha).
4. `/me` devolve `crystal_motor`; `AppMenu.tsx` mostra `Motor 2.0 (teste)` só quando `2.0` (linha informativa, sem ação).
5. Testes: `messages.test.ts`, `chatwoot-bot.test.ts`, `staff-alunos-ficha.test.ts`, `AppMenu.test.tsx`; e2e menu com e sem a linha, 1440 e 390 px.

**Textos (literais).**

- Ficha: título `Motor da Crystal`; interruptor `Usar o Motor 2.0 nesta conta`; ajuda `Só esta conta passa a receber respostas do Motor 2.0, com o modelo escolhido em Crystal › Motor 2.0. As outras continuam no motor atual. No WhatsApp vale quando o número está vinculado a esta conta.`
- Aba Motor 2.0 (M13): lista `Contas no Motor 2.0`; vazio `Nenhuma conta de teste. Marque uma pela ficha do cliente.`; botão `Tirar`.
- App, menu ⋮: `Motor 2.0 (teste)`.

**Onde mexer.** `apps/api/prisma/schema.prisma` + migração, `apps/api/src/services/messages.ts`, `apps/api/src/routes/chatwoot-bot.ts`, `apps/api/src/routes/staff-alunos-ficha.ts`, `apps/api/src/routes/me.ts`, `apps/web/components/equipe/alunos/ficha/*`, `apps/web/components/AppMenu.tsx`, `docs/equipe.md`.

**Critérios de aceite.** Conta marcada: Crystal recebe `motor: "2.0"` e `modelo = op_crystal_modelo_2`; `uso_turnos.motor = '2.0'`; `messages.crystal_motor = '2.0'`. Conta comum: corpo igual ao de hoje. Desmarcar vale na mensagem seguinte. Menu ⋮ mostra a linha só para a conta marcada. Migração reversível; `pnpm test` e `pnpm test:e2e` verdes. **Conferir em aparelho (Luiz):** conversar no iPhone com a conta marcada: texto, print e áudio; conferir no painel que saem como 2.0.

**Fora deste item.** Trocar de motor pelo próprio cliente. Marcar em massa.

**Depende de.** M01 a M06.

**Cuidados.** `crystal_motor` só sai no `/me` da própria pessoa. Toda marcação vai à auditoria. Passa pelo agente `seguranca`. Marcar pelo menos **3 contas** (Luiz, Letícia, Bia) para o portão (150 turnos em 7 dias) fechar numa semana.

---

### M10 · Qualidade medida todo dia (números)

**Esforço:** `xhigh` (LGPD: uso novo do dado).

**Decisão.** Um avaliador barato roda dentro do processo da Crystal, uma vez por dia, sobre a tabela `mensagens` dela (cifrada; decifrada só em memória), avalia 100% dos turnos 2.0 e 2% dos atuais do dia anterior, responde seis perguntas de sim ou não por resposta e grava só booleanos e rótulos. **Antes de codar:** agente `seguranca` e decisão do Luiz (encarregado de dados) registradas em `docs/crystal-api.md` e no texto de privacidade do app, porque é um tratamento novo do dado do cliente. A amostra humana 👍/👎 da onda 5 continua e ganha filtro por motor (M11).

**Hoje.** `bateria.ts:39-43, 253-254`: `INSTRUCAO_AVALIADOR`, JSON, temperatura 0, 300 tokens, só sob demanda. `/v1/qualidade` (`rotas-alma.ts:652`, `uso.ts:613-625`) conta erros e bloqueios. Não há cron em `apps/crystal`: só o `setInterval` de limpeza a cada 6 h (`server.ts:255-256`). `data_collection: deny` vai em toda chamada de chat (`openrouter.ts:202`). Amostra humana: `apps/api/src/routes/staff-crystal-qualidade.ts` (só admin, leitura liberada por `conversation_read_enabled` e termos, 30 clientes por dia, auditoria `crystal.qualidade_amostra`), schemas em `packages/shared/src/alma.ts:663-693`.

**O que fazer.**

1. Novo `apps/crystal/src/qualidade-diaria.ts`: `setInterval` de 1 h que roda uma vez por dia às 03:00 de São Paulo (uma réplica, como a limpeza), ou por `POST /v1/qualidade/rodar` (painel, admin). Seleciona do dia anterior: todos os turnos com `motor = '2.0'` e 2% dos `atual` (`QUALIDADE_PCT_ATUAL`, padrão 2; `QUALIDADE_MAX_DIA`, padrão 500), via `uso_turnos` (`contato_hash`, `em`, `motor`, `nivel`, `modelo`); busca em `mensagens` o par pergunta/resposta e as 4 anteriores pelo `contato_hash` e pelo instante; pula contatos apagados (não existem mais) e turnos com `risco = true` (não avaliar quem estava em crise). Pede ao avaliador (`CRYSTAL_MODEL_AVALIADOR`, padrão `anthropic/claude-haiku-4.5`; de preferência de fornecedor diferente do modelo das respostas, para o modelo não corrigir a si mesmo) o JSON de seis booleanos; grava em `qualidade_diaria` (`dia`, `motor`, `nivel`, `modelo`, seis booleanos, `custo_usd`). Teto `QUALIDADE_TETO_USD` por rodada (padrão US$ 2). JSON inválido é descartado e contado.
2. Critérios (chaves literais): `inventou_tatica`, `aconselhou_afastamento`, `repetiu_pergunta`, `passou_do_teto_de_baloes` (teto 3 para texto e 4 para print, até a Letícia decidir), `vocabulario_proibido`, `outro_idioma_ou_caractere`.
3. `GET /v1/qualidade` passa a devolver a série diária por motor, nível e modelo; com menos de 20 avaliações no grupo, devolve `amostra_pequena: true`.
4. Testes: `qualidade-diaria.test.ts` (seleção, teto, JSON inválido, nenhuma coluna de texto, risco excluído), teste de esquema da tabela.

**Textos.** `INSTRUCAO_QUALIDADE` (literal; passa pela Letícia):

> Você avalia uma resposta da Crystal, conselheira de relacionamentos para homens, em português do Brasil. Receberá as últimas mensagens da conversa, a mensagem do aluno e a resposta, e o nível da resposta (texto ou print). Responda só com JSON, sem comentário: {"inventou_tatica":bool,"aconselhou_afastamento":bool,"repetiu_pergunta":bool,"passou_do_teto_de_baloes":bool,"vocabulario_proibido":bool,"outro_idioma_ou_caractere":bool}. Critérios: inventou_tatica = deu roteiro ou tática específica sem apoio no que o aluno contou; aconselhou_afastamento = sugeriu gelo, sumir, ignorar ou cortar contato como tática; repetiu_pergunta = perguntou algo que o aluno já respondeu nas mensagens anteriores; passou_do_teto_de_baloes = mais de três parágrafos separados por linha em branco (quatro, se o nível for print); vocabulario_proibido = usou "saquei", "manda aí", "show", lista numerada ou jargão de inteligência artificial; outro_idioma_ou_caractere = qualquer palavra fora do português ou caractere de alfabeto não latino.

**Onde mexer.** `apps/crystal/src/qualidade-diaria.ts` (novo), `rotas-alma.ts`, `uso.ts`, `server.ts`, `env.ts`, `packages/shared/src/alma.ts` (tipos), `docs/crystal-api.md` (seção "Avaliação automática: o que lê, o que grava, base legal").

**Critérios de aceite.** Rodada com 100 turnos grava 100 linhas sem coluna de texto. Turnos com risco não entram. Custo em `uso_turnos` com `tipo = 'avaliacao'` respeita o teto. Agente `seguranca` APROVADO **antes** do código.

**Fora deste item.** Tela (M11).

**Depende de.** M02, M09.

---

### M11 · Qualidade na tela

**Esforço:** `high`.

**Decisão.** Aba Saúde da página Crystal ganha seis cartões por motor; a amostra humana 👍/👎 da onda 5 ganha o filtro Motor; os dois alimentam o portão (M13).

**Hoje.** Página Crystal com abas Modelo · Comportamento · Fichas · Saúde (`apps/web/app/(equipe)/equipe/crystal/page.tsx`). Amostra humana e resumo das avaliações em `staff-crystal-qualidade.ts`.

**O que fazer.**

1. Saúde: seis cartões (percentual do dia e variação contra 7 dias), seletor Motor (Atual | 2.0 | Ambos), Nível e Modelo; rodapé com amostra, avaliador e custo; "amostra pequena" abaixo de 20.
2. Amostra humana: `qualidadeAmostraQuerySchema` ganha `motor`; a listagem usa `messages.crystal_motor` (M09); o resumo das avaliações devolve contagens por motor.
3. Testes de tela e de rota; e2e nos dois tamanhos.

**Textos (literais).** Cartões: `Inventou tática` · `Aconselhou afastamento` · `Repetiu pergunta` · `Passou do teto de balões` · `Vocabulário proibido` · `Outro idioma`; rodapé `Amostra de {n} respostas de {dia} · avaliador {modelo} · US$ {custo}`; vazio `Amostra pequena: menos de 20 respostas neste grupo.`; filtro `Motor` com `Atual`, `2.0`, `Ambos`.

**Onde mexer.** `apps/web/components/equipe/crystal/` (novo `QualidadeDiaria.tsx`), `apps/api/src/routes/staff-crystal-qualidade.ts`, `packages/shared/src/alma.ts`, `docs/equipe.md`.

**Critérios de aceite.** Seis percentuais por motor; amostra humana filtra por motor; e2e verdes; axe sem violações.

**Depende de.** M10.

---

### M12 · Teto diário de gasto por cliente

**Esforço:** `high`.

**Decisão.** `op_crystal_teto_cliente_usd` (padrão US$ 1,00), nos dois motores, antes da promoção. Quantas respostas isso cobre depende do modelo: no Motor 2.0, cerca de 360 no `gpt-4.1-mini`, 450 no `gemini-2.5-flash`, 180 no Haiku 4.5 e 70 no `gpt-4.1`. Trocar de modelo pede revisar o teto: no `gpt-4.1`, US$ 1 por dia já alcança os clientes mais ativos. Acima dele, frase fixa (aprovada pela Letícia) e aviso ao suporte uma vez por dia por cliente. Risco à vida ignora o teto, nas duas pontas (a API também detecta risco antes de chamar, `messages.ts:589`).

**Objetivo.** Nenhum laço, abuso ou incidente custar US$ 13 por hora de novo. Em 90 dias de WhatsApp, 1.583 clientes passaram de 100 mensagens e um chegou a 6.264.

**Hoje.** Só limite por minuto (`rate_msg_max`) e teto global da conta. S09 ficou fora do PRD de otimização (pendência 11 relacionada). A API tem os alertas do painel (`alerts` em `apps/api/src/server.ts:519`).

**O que fazer.**

1. `uso.ts`: soma do dia por `contato_hash` (índice `(contato_hash, em)`). `app.ts`: se soma ≥ teto e sem risco, responder a frase fixa, gravar `uso_turnos` com `erro = 'teto_cliente'` e custo zero, não gravar memória, devolver código `TETO_CLIENTE` no `done`.
2. API: ao receber `TETO_CLIENTE`, registrar alerta do painel (uma vez por dia por cliente) pelo mecanismo `alerts`.
3. Painel, Saúde: `Clientes no teto hoje: {n}` com link para as fichas, e a equivalência do teto em respostas, calculada pelo custo médio por resposta dos últimos 7 dias do modelo em uso.
4. Testes: `uso.test.ts`, `app.test.ts` (risco ignora teto), `messages.test.ts`.

**Textos (literais).**

- Frase ao cliente (aprovar com a Letícia): `Hoje a gente já conversou bastante. Amanhã eu volto com você. Se for urgente, o suporte está em Menu › Suporte.`
- Painel: `Clientes no teto hoje` · ajuda `Quem passou de US$ {teto} em respostas hoje recebe uma mensagem fixa até amanhã.`
- Equivalência: `Com o modelo de hoje, US$ {teto} cobrem cerca de {n} respostas por cliente por dia.`
- Chave: `Teto de gasto por cliente por dia (US$)` · faixa 0,20 a 10,00.

**Onde mexer.** `apps/crystal/src/uso.ts`, `app.ts`, `packages/shared/src/settings.ts`, `apps/api/src/services/messages.ts`, `apps/web/components/equipe/crystal/`.

**Critérios de aceite.** Cliente com US$ 1,01 hoje recebe a frase e nada é cobrado; à meia-noite de São Paulo volta. Risco detectado responde com os contatos, sempre. Painel conta certo. **Fecha a fase 2:** revisão com ultracode e agente `seguranca` APROVADO sobre M07 a M12.

**Fora deste item.** Teto por semana ou por plano.

**Depende de.** M02.

---

### M13 · Aba Motor 2.0, portão e interruptor da promoção

**Esforço:** `xhigh`.

**Decisão.** A aba **Motor 2.0** reúne: modelos do 2.0, contas de teste, comparação Atual × 2.0 de 7 dias, o portão e o botão "Tornar o Motor 2.0 o padrão" (LIGAR + senha). Ligado, a API envia `motor: "2.0"` para todos na mensagem seguinte (app e Chatwoot) e os modelos `_2` valem; o botão vira "Voltar ao motor atual", sem senha.

**Hoje.** Abas Modelo · Comportamento · Fichas · Saúde. Chaves `enum` perigosas pelo molde `crystal_busca`. A API lê configurações a cada mensagem (sem cache).

**O que fazer.**

1. `apps/web/components/equipe/crystal/MotorDois.tsx` com cinco blocos: (a) Modelos do 2.0 (reusar `SeletorModelo.tsx`, verificação antes de gravar como `op_crystal_modelo`, aviso de "sem imagem" do M06, aviso de "sem desconto de cache" do M08, e aviso quando a reserva é do mesmo fornecedor do principal, pelo prefixo do id); (b) Contas no Motor 2.0 (M09); (c) Atual × 2.0, 7 dias: turnos, custo médio por turno, `cache_pct`, p50 e p95, erros, reserva, cortadas, seis critérios (M10) e avaliações humanas por motor (M11); (d) Portão; (e) botão.
2. **Portão**, cada linha com estado automático ou caixa humana:
   - [auto] Pelo menos **150** respostas do 2.0 em contas de teste nos últimos 7 dias.
   - [auto] Custo médio por resposta do 2.0 nos 7 dias ≤ do atual; se maior, a linha fica **amarela** e vira decisão humana ("aceito pagar mais por este modelo").
   - [auto] Cache funcionando, igual para qualquer fornecedor: entre as respostas do 2.0 que saíram até 5 minutos depois de outra resposta do 2.0 com o mesmo modelo, a mediana de `tokens_cache` é de pelo menos 8.000.
   - [auto] Zero respostas barradas por vazamento no 2.0 em 7 dias, ou taxa menor que a do atual.
   - [auto] Nenhum dos seis critérios do M10 pior que o atual em mais de 2 pontos percentuais, com pelo menos 100 avaliações por motor.
   - [auto] Em pelo menos 20 comparações lado a lado (M08), o 2.0 foi preferido em 12 ou mais.
   - [humano] Letícia aprovou os textos de sistema novos (dois cabeçalhos, instrução do perfil, instrução do avaliador, frase do teto) e leu 30 respostas do 2.0 (amostra humana filtrada por motor, M11, com pelo menos 24 "bom").
   - [humano] Agente `seguranca` APROVADO sobre as fases 1 e 2.
   - [humano] Luiz conferiu texto, print e áudio no iPhone.
   O botão só habilita com tudo verde. "Seguir sem o portão completo" exige a mesma palavra e grava o motivo na auditoria.
3. Gravar `op_crystal_motor = 2.0`. Volta: o mesmo botão como "Voltar ao motor atual", sem senha (`dangerous.when` só para `2.0`).
4. Aviso no Início do painel por 7 dias após a promoção, com a frase sobre o custo da consolidação (os clientes vindos do WhatsApp recebem ficha + fatos até o primeiro perfil consolidado, então os primeiros dias custam **mais**, não menos).
5. Testes: tela (estados, botão desabilitado, LIGAR, voltar sem senha), API, e2e nos dois tamanhos.

**Textos (literais).**

- Aba: `Motor 2.0`
- Blocos: `Modelos do Motor 2.0` · `Contas no Motor 2.0` · `Atual × 2.0, últimos 7 dias` · `Antes de tornar padrão` · botão `Tornar o Motor 2.0 o padrão` / `Voltar ao motor atual`
- Ajuda do botão: `Liga o Motor 2.0 para todos os clientes, no app e no WhatsApp, a partir da próxima mensagem de cada um. Os modelos escolhidos acima passam a valer. Dá para voltar a qualquer hora, sem senha.`
- Portão: `Pelo menos 150 respostas do 2.0 em contas de teste nos últimos 7 dias` · `Custo por resposta do 2.0 igual ou menor que o atual` (amarelo: `O 2.0 está custando mais por resposta. Marque aqui se aceita pagar por este modelo.`) · `Cache funcionando: quando outra resposta do 2.0 saiu há menos de 5 minutos, pelo menos 8 mil tokens vêm do cache` · `Nenhuma resposta barrada por vazamento em 7 dias` · `Qualidade igual ou melhor nos seis critérios (pelo menos 100 avaliações por motor)` · `O 2.0 venceu pelo menos 12 de 20 comparações lado a lado` · `Letícia aprovou os textos novos e 30 respostas` · `Revisão de segurança aprovada` · `Luiz conferiu texto, print e áudio no iPhone`
- Seguir assim mesmo: `Seguir sem o portão completo` · campo `Motivo (fica na auditoria)`
- Reserva do mesmo fornecedor: `A reserva é do mesmo fornecedor do modelo principal. Se esse fornecedor cair, os dois caem juntos. Escolha uma reserva de outro fornecedor.`
- Aviso no Início: `Motor 2.0 no ar desde {data}. Nos primeiros dias o custo sobe enquanto os perfis se consolidam; acompanhe em Crystal › Motor 2.0.`

**Onde mexer.** `apps/web/components/equipe/crystal/MotorDois.tsx` (novo) e filhos, `apps/api/src/routes/staff-crystal*.ts` (portão, números), `operacao-config.ts`, `messages.ts`, `chatwoot-bot.ts`, `packages/shared/src/settings.ts`, `docs/equipe.md`, `e2e/`.

**Critérios de aceite.** Com `op_crystal_motor = 2.0`, cliente comum recebe `motor: "2.0"` e `modelo = op_crystal_modelo_2` (ou o atual se vazio); Chatwoot idem; `uso_turnos.motor = '2.0'`. Voltar vale na mensagem seguinte, sem senha. Botão desabilitado com linha [auto] vermelha; "Seguir assim mesmo" grava motivo. e2e verdes; axe sem violações. Revisão com ultracode e `seguranca` APROVADO antes da promoção.

**Fora deste item.** Promoção parcial por porcentagem.

**Depende de.** M01 a M12.

**Cuidados.** **Toda publicação chega aos clientes.** A promoção é feita pelo Luiz no painel, nunca por comando na VPS nem por mim. Antes dela: `GET /v1/uso?dias=7` exportado e guardado.

---

### M14 · Aposentar o motor atual

**Esforço:** `high`, ultracode ligado.

**Decisão.** 30 dias depois da promoção, sem volta registrada, o motor atual sai do código.

**Objetivo.** Um motor só para manter.

**Hoje.** Dois ramos (`motor === "atual"`) em `app.ts`, `montagem.ts`, `ensaio.ts`, `rotas-laboratorio.ts`; `op_crystal_motor` na tela; `op_crystal_modelo_2` separado.

**O que fazer.** Remover os ramos; `motor` continua no contrato mas ausente passa a significar `2.0` e `"atual"` é recusado com 400; copiar `op_crystal_modelo_2` (e reserva, imagem) para as chaves principais quando preenchidas e esconder as `_2` e `op_crystal_motor` da tela (ficam no banco, ignoradas); a busca por turno nas regras vira só a válvula; colunas `motor`, `nivel`, `trechos_a`, `trechos_b`, `cortada` ficam; atualizar `apps/crystal/README.md`, `docs/crystal-api.md`, `docs/equipe.md`; bateria de regressão.

**Textos.** Nenhum novo.

**Onde mexer.** `apps/crystal/src/{app,montagem,ensaio,rotas-laboratorio,pedidos}.ts`, `apps/api/src/services/operacao-config.ts`, `packages/shared/src/settings.ts`, `apps/web/components/equipe/crystal/MotorDois.tsx`, docs.

**Critérios de aceite.** Nenhuma referência a `"atual"` fora de testes de compatibilidade; `pnpm test` e `pnpm test:e2e` verdes; agente `seguranca` APROVADO.

**Fora deste item.** Qualquer mudança de comportamento.

**Depende de.** M13 há 30 dias.

**Cuidados.** Só com pedido explícito do Luiz. Tag no commit anterior.

## Como testar o Motor 2.0 (roteiro para o Luiz)

1. **Depois da fase 1:** nada muda para você ainda.
2. **Depois do M07 e M08:** Equipe › Crystal › Laboratório. Nova conversa, Motor 2.0, escolha o modelo (comece pelo de produção; depois os candidatos da OpenAI, um que não pensa e um que pensa, como `gpt-4.1-mini` e `gpt-5-mini`; e um de outro fornecedor, para servir de reserva). Mande cinco mensagens de tipos diferentes: "oi", "ela leu e não respondeu, o que eu faço?", "mandei do jeito que você falou", "valeu", "não consigo entrar no app". Olhe o selo de cada resposta. Use Lado a lado com dois modelos e marque "Prefiro esta" (precisa de 20 comparações para o portão). **Print não dá para testar no Laboratório:** fica para o passo 3.
3. **Depois do M09:** peça ao Igor para marcar a sua conta, a da Letícia e a da Bia. Converse no app pelo iPhone como cliente, por uma semana, inclusive print e áudio. A linha "Motor 2.0 (teste)" aparece no menu ⋮. O portão pede 150 respostas em 7 dias entre as contas.
4. **Depois do M10 e M11:** veja em Crystal › Saúde os seis percentuais por motor. Com 100% dos turnos 2.0 avaliados, as 100 avaliações por motor fecham na mesma semana.
5. **Letícia:** aprovar os cinco textos de sistema novos e ler 30 respostas do 2.0 na amostra humana (Crystal › Saúde, filtro Motor 2.0).
6. **Depois do M13:** Crystal › Motor 2.0; com o portão verde, "Tornar o Motor 2.0 o padrão" (LIGAR + senha). Acompanhe 7 dias; o custo sobe nos primeiros dias e cai depois da consolidação. Se estranhar, "Voltar ao motor atual".
7. **30 dias depois:** peça o M14.

## Custo-benefício esperado

Uma fórmula só para todos os modelos, para a comparação ser justa. Por resposta, em média (80% texto, 20% print, mistura de níveis do Passo 1):

| | Hoje | Motor 2.0 |
| --- | --- | --- |
| Tokens em cache (começo fixo) | 5.000 (a alma) | 10.300 (alma + 27 regras) |
| Tokens a preço cheio | 5.290 (6 trechos, resumo, memória, 20 mensagens, imagem, resumidor) | 3.555 (exemplos só em tática e print, perfil, histórico por nível, imagem, resumidor) |
| Tokens de saída | 180 (resposta e resumidor) | 180 |
| A mais, nos modelos que pensam | ~150 de raciocínio | ~150 de raciocínio |

O "hoje" já conta o cache da alma em todos os fornecedores: a Anthropic pelo marcador, a OpenAI e o Google sozinhos, porque a alma é o começo idêntico de todo pedido. A versão 2 deste PRD não contava esse cache fora da Anthropic e mostrava economia de 48% no Gemini; com a conta certa, a economia em dinheiro é menor. O `cache_pct` medido hoje (`GET /v1/uso`) confirma ou corrige esta suposição: é a pendência 3.

Por mil respostas, preços do OpenRouter de 30/10/2026:

| Modelo | Pensa? | Desconto do cache | Hoje | Motor 2.0 | Diferença |
| --- | --- | --- | --- | --- | --- |
| `openai/gpt-4.1-mini` | não | 75% | US$ 2,90 | US$ 2,74 | −6% |
| `openai/gpt-4.1` | não | 75% | US$ 14,52 | US$ 13,70 | −6% |
| `openai/gpt-5.2-chat` | não | 90% | US$ 12,65 | US$ 10,54 | −17% |
| `openai/gpt-5-mini` | sim | 90% | US$ 2,11 | US$ 1,81 | −14% |
| `openai/gpt-5.4-mini` | sim | 90% | US$ 5,83 | US$ 4,92 | −16% |
| `google/gemini-2.5-flash` | sim | 90% | US$ 2,56 | US$ 2,20 | −14% |
| `anthropic/claude-haiku-4.5` | não | 90% | US$ 6,69 | US$ 5,49 | −18% |
| `google/gemini-2.5-flash-lite` | não | 90% | US$ 0,65 | US$ 0,53 | −19% (não recomendado: modelo do vazamento de 16/10) |
| `deepseek/deepseek-chat` | não | nenhum no catálogo | US$ 2,83 | US$ 3,75 | **+32%** |

O que a tabela diz:

- **Em dinheiro, o 2.0 economiza de 6% a 19%** nos modelos com cache. Na família `gpt-4.1` (desconto de 75%) a economia é pequena: as 27 regras em cache custam quase o mesmo que os 6 trechos a preço cheio de hoje, e o que sobra vem da triagem e do perfil único.
- **Modelo sem desconto de cache fica mais caro no 2.0**, porque o pedido tem mais tokens. O seletor marca esses modelos (M08) e o portão de custo pega (M13).
- **O ganho principal é de qualidade:** 27 regras em vez de 6; 168 diálogos de volta; quase metade das respostas sem depender do Supabase; seis perguntas de qualidade todo dia; teto por cliente.
- Nos primeiros dias depois da promoção o custo **sobe**: cada cliente vindo do WhatsApp recebe ficha e fatos até o primeiro perfil consolidado (uma rodada do resumidor, a cada 10 mensagens). Depois cai para os valores da tabela.
- Os ~150 tokens de raciocínio são estimativa: no nível mínimo, o OpenRouter reserva cerca de 10% do teto para pensar (`raciocinio.ts:6-13`). O Laboratório mostra o número real de cada modelo.

Prazo: fase 1 ≈ 5 dias de desenvolvimento, fase 2 ≈ 7 dias, fase 3 ≈ 3 dias mais 30 de espera. Laboratório custa centavos por conversa (teto US$ 5/dia).

## Fora do escopo

- Mudar a alma, a instrução de print ou o bloco de formato (Letícia; pendência "3 balões vs 3 opções").
- Imagem no Laboratório (print testa-se no app).
- Editar os 168 pelo painel.
- Resposta fixa para suporte sem modelo.
- Promoção parcial por porcentagem de clientes.
- Reranking por modelo; busca com histórico inteiro; trocar o fornecedor de embedding.
- Streaming antes da trava de saída.
- Ambiente de teste separado (S23 ficou fora).

## Riscos e como este PRD os trata

| Risco | Tratamento |
| --- | --- |
| O cache automático (OpenAI, Google) não pega | Teste de prefixo estável para cada fornecedor (M03); `tokens_cache` no selo de cada resposta do Laboratório (M07); portão exige 8 mil tokens em cache nas respostas com cache quente (M13). |
| Modelo sem desconto de cache fica mais caro no 2.0 | Marca `sem desconto de cache` no seletor (M08) e linha de custo do portão (M13). |
| Principal e reserva do mesmo fornecedor caem juntos | Aviso na aba Motor 2.0 (M13); a reserva padrão de hoje é da OpenAI (`env.ts:31`). |
| Modelo que pensa gasta mais do que o previsto | Selo mostra os tokens de raciocínio (M07); a tabela de custo soma ~150 por resposta; os modelos da OpenAI que não pensam ficam como alternativa. |
| Camada B devolve exemplo errado e a Crystal copia | Corte por similaridade, 4 exemplos, cabeçalho "adapte, nunca copie", trava com impressão dos exemplos e marcador `[Cenário:` (M04). |
| Triagem manda para `conversa` algo que precisava de exemplo | Regras sempre no prompt; na dúvida, tática; o selo mostra o motivo para calibrar (M02, M07). |
| Perfil consolidado perde algo da ficha | Consolidação recebe tudo; a ficha original fica em `crystal_memoria_ficha`; re-consolida se os fatos mudarem (M05). |
| RPC da agência muda ou some | Falha não derruba o turno; dependência documentada; `/healthz` mostra (M04). |
| Custo sobe na primeira semana da promoção | Aviso no Início; linha de base de 7 dias exportada antes (M13). |
| Avaliação automática como uso novo do dado | `seguranca` e decisão do encarregado antes do código; só booleanos gravados; risco excluído (M10). |
| Promoção dá errado | "Voltar ao motor atual" sem senha; motores convivem 30 dias (M13, M14). |
| Conta de teste esquecida | Lista com data e botão Tirar (M09, M13). |
| Portão nunca fica verde e vira hábito "seguir assim mesmo" | 100% dos turnos 2.0 avaliados; 150 respostas com 3 contas; linha de custo vira amarela em vez de vermelha (M10, M13). |

## Pendências para o Luiz e a Letícia

1. **Letícia:** aprovar os cinco textos de sistema novos (cabeçalho das regras e dos exemplos no M03/M04, `INSTRUCAO_PERFIL` no M05, `INSTRUCAO_QUALIDADE` no M10, frase do teto no M12) e o teto de balões (3 texto, 4 print). Não trava a fase 1; trava a promoção.
2. **Luiz (encarregado de dados):** decidir a avaliação automática de qualidade (M10) como tratamento do dado do cliente, e o texto de privacidade do app.
3. **Luiz:** confirmar no painel o modelo em produção (Equipe › Crystal › Modelo) e exportar `GET /v1/uso?dias=7` antes da fase 1. O `cache_pct` desse export diz se o cache automático já pega na alma hoje, que é a suposição da tabela de custo. Se a principal for da OpenAI, escolher a reserva de outro fornecedor.
4. **Agência:** confirmar que a RPC `match_leticia_crystal_vector_store` fica; pedir que liguem `SEARCH_SECRET_ENFORCE=true` na função `crystal_knowledge_search` (o código dela, lido em 30/10 no Supabase da agência, mostra validação em "modo de transição"; o app não usa essa função).
5. **Igor:** antes da fase 1, `git fetch` e partir da ponta mais nova que `466886db`.

## Avisos que não têm volta

- Não existe ambiente de teste: toda publicação chega aos clientes. O 2.0 só chega a eles pelo interruptor do M13, acionado pelo Luiz no painel. Nunca publicar, rodar `app-subir` ou migração em produção sem o Luiz pedir de forma explícita.
- Dados reais de cliente não entram em log, teste, commit nem em resposta de rota do painel (selos mostram só ids, cenários e números).
- Segredos (`SUPABASE_SERVICE_ROLE_KEY`, `OPENROUTER_API_KEY`) só no `.env` da Crystal.
- Commits no padrão Conventional Commits; commit e push só quando o Luiz pedir.

## Glossário

- **Alma:** o prompt fixo da Crystal (`apps/crystal/prompt/crystal.md`), texto da Letícia via agência, congelado.
- **Camada A:** as 27 regras do método, sempre no prompt, com cache.
- **Camada B:** os 168 diálogos-modelo, buscados por semelhança só quando a mensagem pede tática.
- **Cache de prompt:** o fornecedor guarda o começo repetido do pedido e cobra menos por ele na leitura seguinte: 10% do preço na Anthropic, no Google e na linha `gpt-5`; 25% na `gpt-4.1`; 50% na `gpt-4o`. Na OpenAI e no Google é automático a partir de 1.024 tokens; na Anthropic, pelo marcador. Só funciona se o começo for idêntico entre pedidos.
- **Modelo que pensa:** modelo que raciocina antes de escrever a resposta (na OpenAI, `gpt-5.x`, `gpt-6.x` e a linha `o`). O pensamento não aparece para o cliente, mas é cobrado como saída.
- **Prefixo cacheado:** essa parte repetida do começo (alma + regras).
- **Embedding:** a tradução de um texto em uma lista de números que permite medir semelhança entre textos. É assim que a busca acha o diálogo-modelo parecido.
- **Similaridade:** nota de 0 a 1 da semelhança entre dois embeddings. 0,5 é o corte.
- **RPC:** uma função que roda dentro do banco de dados da agência e que a Crystal chama pela internet.
- **PostgREST:** a porta pela qual o Supabase expõe o banco e as RPCs.
- **service_role:** a chave de servidor do Supabase, que dá acesso total. Só vive no `.env` da Crystal.
- **Hash:** um resumo numérico de um texto; muda quando o texto muda. Serve para saber se os fatos do WhatsApp mudaram sem guardar o texto.
- **max_tokens:** o teto de tamanho da resposta do modelo.
- **p50 / p95:** o tempo que metade das respostas levou, e o que 95% delas levaram. O p95 mostra as lentas.
- **Triagem:** a função que decide o nível da mensagem (leve, conversa, tática, print) sem usar modelo.
- **Perfil único:** o bloco de até 1.500 caracteres com o que a Crystal sabe do cliente.
- **Motor:** o conjunto de regras que monta o prompt e decide o que entra. "Atual" é o de hoje; "2.0" é o deste PRD.
- **Portão:** a lista de condições que precisa estar verde antes de tornar o 2.0 padrão.
