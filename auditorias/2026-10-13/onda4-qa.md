# Onda 4 do painel: QA por área, correções e fechamento (13/10)

Orquestração `onda4-painel` (9 agentes). App local com OpenRouter e Supabase falsos, dados de demonstração. Nada publicado na VPS.

- Junção: T2 (Mensagens) em `c87acf3`; fichas no painel novo em `36186e6`.
- QA: 39 achados únicos (19 altos/médios, 20 baixos).
- Correção: 16 corrigidos, 5 não corrigidos (motivo abaixo).
- Fechamento: `painel/onda4` em `06aaa0a` no GitHub. CI vermelho no e2e (2 testes de Mensagens); imagem `sha-06aaa0a` gerada, **não publicar**. Conserto e porte da correção do painel intermitente em andamento.

## Corrigidos

- Falta na ficha o bloco "Tentativas de entrada", e o tech recebe 404 na rota (`bea58e4`)
- O tech não vê nem registra pedido do titular na aba Dados (`bea58e4`)
- Exportar CSV com alunos marcados exporta a lista filtrada inteira (`bea58e4`)
- A ficha de conta local vencida não diz que o aluno está barrado (badge "Acesso vencido", motivo no Resumo, "Acesso até" sem data passada: min no campo e 400 na API). A contagem em Ativos e no Início não mudou. (`bea58e4`)
- GET /staff/users e a tela Equipe mostram a support e tech todos os alunos, com e-mail (alta) (`15ec06e (+ ajuste de teste 06aaa0a)`)
- /equipe/equipe não existe (agora existe e /equipe/usuarios redireciona para lá) (`15ec06e`)
- /equipe/canal não redireciona (Canal virou cartão de Integrações e /equipe/canal redireciona) (`86e5052`)
- Contraste AA reprovado na chave técnica dos campos de Configurações e da Crystal (`2712d95`)
- Botão de perigo no tema escuro com contraste 3,99:1 (`2712d95`)
- Envio para um aluno agendado mostra o horário de silêncio, mas o servidor ignora o silêncio para um aluno (`78a2218`)
- Envio imediato barrado pelo limite do dia responde 'Enviada.' sem avisar que não chegou (o toast foi corrigido; o selo "Enviada" do cartão em Enviadas não mudou) (`78a2218`)
- Agendado cancelado aparece como recebido na ficha da aluna e o detalhe oferece 'Reenviar para quem não abriu' (`78a2218`)
- 'Mensagens da equipe por aluno por dia' aceita até 10, mas o PRD fixa de 1 a 5 (`db72953`)
- O cartão do Financeiro em Métricas conta duas vezes o valor vencido (pendente + vencido) no número do título (`db72953`)
- A aba Mensagens de Métricas fica totalmente em branco (parte da tela: agora mostra o texto de vazio) (`db72953`)
- A chave da leitura da conversa (conversation_read_enabled e conversation_read_terms_at) não existe em Configurações (`2fc1851`)

## Não corrigidos (decisão do dono ou entrega própria)

- **O support desliga e religa aluno; pelo PRD isso é só do admin**
  Contraria o PRD em vigor. O ajuste 4 dos "Ajustes que valem para o PRD inteiro" (docs/painel-admin/PRD.md:84) diz que, até o Luiz responder a pendência 20, vale o que o código faz hoje e as telas novas mostram essas ações para o support. A linha 1273 repete: "até a resposta vale o código de hoje". O texto do A04, item 4, é anterior a esse ajuste.
- **Support desliga e religa aluno pela API (PUT /staff/alunos/:id/status)**
  Mesmo caso do achado anterior: ajuste 4 e pendência 20 do PRD. A rota usar `escrita` (admin e support) é o comportamento definido até a decisão do Luiz.
- **A aba Mensagens de Métricas: as métricas em si ('Enviadas, entregues, abertas, cliques', 'Responderam depois') e 'Sem usar o app' em Alunos**
  Não há coletor na consolidação diária para mensagens.envios, mensagens.responderam e alunos.sem_uso, nem no MetricsSource (memória e Prisma) nem no metrics-rollup. Tirar só o campo `depende` mostraria zeros falsos. É funcionalidade nova do A12: três coletores, nas duas implementações, com testes. A parte da tela já foi corrigida (texto de vazio em db72953).
- **Faltam cinco chaves do catálogo do A11 (push_sender_name, push_private_body, alert_recipients, chatwoot_handoff_terms, chatwoot_bot_texts)**
  É funcionalidade nova, não regressão. Cada chave precisa entrar no registro e passar a ser lida em tempo de execução por push.ts, alerts.ts e chatwoot-bot.ts (A11, item 2), o que muda envio de push, alertas e o robô do Chatwoot. Fica para uma entrega própria, com teste em cada serviço.
- **O grupo Ambiente não tem o cartão 'Coerência legal' e os cartões Limites e Notificações estão incompletos**
  É funcionalidade nova. Precisa comparar a política de privacidade publicada com os valores do app e ter os dados do encarregado, que não estão no código. O remetente das notificações depende da chave push_sender_name, que ainda não existe (achado anterior). Fica para uma entrega própria.

## Achados altos e médios (detalhe)

### [media] O support desliga e religa aluno; pelo PRD isso é só do admin

- Área: Início e Alunos (A02, A03, A04 com a aba Dados do A14, A05)
- Onde: apps/api/src/routes/staff-alunos.ts:370 (usa o preHandler `escrita`, que deixa admin e support; deveria ser `soAdmin`); apps/web/components/equipe/alunos/ficha/FichaAluno.tsx e abas.tsx (menu Ações)
- Passos: 1. Entrar como suporte@demo.crystal. 2. Abrir /equipe/alunos/{id} da conta AlunosQA Dois. 3. Abrir Ações, tocar em Desligar, escolher o motivo e confirmar. 4. Abrir Ações de novo e tocar em Religar.
- Esperado: A04, item 4: PUT /staff/students/:id/status é só do admin (requireRole(["admin"])) e o support e o tech recebem 404 para active e para disabled. A04, item 9: Religar e Desligar aparecem só para o admin. No "Fora deste item": "Religar por support" não entra.
- Obtido: O menu do support mostra Desligar e Religar. PUT /staff/alunos/:id/status respondeu 200 para {"status":"disabled","reason":"refund"}, com o toast "Desligado. As sessões foram encerradas.", e depois 200 para {"status":"active"}, com "Religado.".

### [media] Falta na ficha o bloco "Tentativas de entrada", e o tech recebe 404 na rota

- Área: Início e Alunos (A02, A03, A04 com a aba Dados do A14, A05)
- Onde: apps/web/components/equipe/alunos/ficha/abas.tsx (aba Aparelhos e sessões); apps/api/src/routes/staff-sessions.ts:108
- Passos: 1. Fazer um login que falha numa conta local vencida (alunosqa4, resposta 403 LOGIN_INACTIVE) e um login normal em alunosqa5. 2. Abrir a ficha como admin, support e tech e ir para a aba Aparelhos e sessões. 3. Chamar GET /staff/alunos/:id/tentativas com cada papel.
- Esperado: A13, item 11 (citado no A04, item 10): na aba Aparelhos e sessões, visível a toda a equipe, o bloco "Tentativas de entrada" com as 10 últimas (data, resultado em português, aparelho) e o texto de vazio "Nenhuma tentativa nos últimos 30 dias.".
- Obtido: A aba só mostra Sessões e Aparelhos; a tela nunca chama /tentativas. A API tem os dados (por exemplo {"kind":"login_inactive","aparelho":"aparelho não identificado"} e login_ok/otp_sent com "Linux · Chrome"). Para o tech, a rota responde 404 (requireRole admin, support).

### [media] O tech não vê nem registra pedido do titular na aba Dados

- Área: Início e Alunos (A02, A03, A04 com a aba Dados do A14, A05)
- Onde: apps/api/src/routes/staff-alunos-titular.ts:58 (titular = requireRole(["admin","support"])); apps/web/components/equipe/alunos/ficha/DadosTab.tsx
- Passos: 1. Entrar como tech@demo.crystal. 2. Abrir a ficha de qualquer aluno e ir para a aba Dados. 3. Chamar GET /staff/alunos/:id/requests.
- Esperado: A04, item 12, e A14, item 2: a aba Dados é de toda a equipe, com a lista de pedidos e "Registrar pedido" (POST /staff/students/:id/requests, requireArea("alunos"), qualquer papel). Só os botões que não têm volta ficam com o admin.
- Obtido: Para o tech, a aba Dados só mostra "Dados do aluno" e o texto do backup: sem consentimentos, sem pedidos e sem "Registrar pedido". GET /requests responde 404. O comentário do código diz que isso foi escolha ("o técnico recebe 404 aqui"), mas a escolha contraria o PRD.

### [media] Exportar CSV com alunos marcados exporta a lista filtrada inteira

- Área: Início e Alunos (A02, A03, A04 com a aba Dados do A14, A05)
- Onde: apps/web/components/equipe/alunos/lista/AlunosLista.tsx:140-151 (exportarCsv(filtros)); apps/web/lib/alunos-painel.ts:279
- Passos: 1. Entrar como admin e abrir /equipe/alunos (10 alunos). 2. Marcar só 2 alunos. 3. Na barra "2 selecionados", tocar em Exportar CSV.
- Esperado: A03, item 7: a barra de ações age sobre a seleção. Com dois alunos marcados, o CSV leva esses dois (ou a tela deixa claro que exporta a lista filtrada).
- Obtido: A tela chama POST /staff/alunos/export com o corpo {} (só os filtros). O alunos.csv sai com todas as linhas da lista (cabeçalho e 10 alunos) e o toast diz "Lista exportada.". A seleção não entra.

### [media] A ficha de conta local vencida não diz que o aluno está barrado

- Área: Início e Alunos (A02, A03, A04 com a aba Dados do A14, A05)
- Onde: apps/web/components/equipe/alunos/ficha/ResumoTab.tsx e FichaAluno.tsx (badges); apps/web/components/equipe/alunos/NovaContaLocalForm.tsx (data mínima)
- Passos: 1. Como admin, criar uma Nova conta local com "Acesso até" ontem (alunosqa4, com CPF). 2. Tentar entrar com essa conta: a API responde 403 LOGIN_INACTIVE. 3. Abrir a ficha.
- Esperado: A05, item 9: para aluno barrado, a ficha diz o motivo em português. Também não faz sentido aceitar uma data já vencida na criação.
- Obtido: O cabeçalho mostra o badge "Ativo" e "Manual", e a Entrada diz só "Conta local até 12/10/2026". Nada indica que o acesso venceu. O formulário aceitou criar a conta já vencida (local_until 2026-10-12, hoje é 13/10). A conta continua contada em Ativos e em "Alunos ativos" no Início.

### [media] Envio para um aluno agendado mostra o horário de silêncio, mas o servidor ignora o silêncio para um aluno

- Área: Mensagens e Crystal (A06 a A08 e /equipe/crystal, A09 e o que entrou na onda 4)
- Onde: apps/api/src/services/notices.ts:162-163 (ignoraSilencio); apps/web/components/equipe/mensagens/NoticeSteps.tsx:738 (texto do silêncio quando `agenda` é verdadeiro)
- Passos: 1) Admin, Nova mensagem. 2) Alunos escolhidos: só a Mia. 3) Em data e hora. 4) Ler o passo Quando.
- Esperado: A07, item 5: as entregas dentro da janela 22:00–08:00 esperam o fim dela. Só o envio para um aluno feito pela ficha ignora a janela. A tela devia dizer a verdade: ou adia, ou não mostra o aviso de silêncio quando ele não vale.
- Obtido: A tela mostra 'Horário de silêncio: das 22:00 às 08:00. Mensagens nesse período esperam até 08:00.' Mas `ignoraSilencio` devolve true para qualquer `audience.ids` com um aluno, venha ou não da ficha. Um agendamento para 23:00 de um aluno só sai às 23:00, ao contrário do que a tela promete.

### [media] Envio imediato barrado pelo limite do dia responde 'Enviada.' sem avisar que não chegou

- Área: Mensagens e Crystal (A06 a A08 e /equipe/crystal, A09 e o que entrou na onda 4)
- Onde: apps/web/components/equipe/mensagens/NoticeSteps.tsx (toast depois de POST /staff/notices/:id/send para um aluno); apps/api/src/routes/staff-notices.ts (a resposta do send não diz que a entrega foi pulada)
- Passos: 1) Support (390 px) manda uma mensagem 'Agora' para a Nina, que já recebeu 2 mensagens hoje. 2) Confirmar 'Enviar para Nina Mensagem?'. 3) Ler o toast e a aba Enviadas.
- Esperado: A07, itens 3 e 6: a entrega imediata passa pelo limite e vira `skipped/daily_limit`. A tela devia avisar na hora, com o texto 'Limite: {n} alunos já tinham recebido {max} mensagens hoje e ficaram de fora.' ou outro equivalente.
- Obtido: Aparece o toast 'Enviada.' e o cartão fica com o selo 'Enviada', mas Entregues mostra 0 (0%). Só no detalhe aparece '1 alunos já tinham recebido 2 mensagens hoje e ficaram de fora.', e a entrega fica como 'Pulado: limite do dia'. A pessoa da equipe acha que a aluna recebeu.

### [media] Agendado cancelado aparece como recebido na ficha da aluna e o detalhe oferece 'Reenviar para quem não abriu'

- Área: Mensagens e Crystal (A06 a A08 e /equipe/crystal, A09 e o que entrou na onda 4)
- Onde: apps/web/components/equipe/mensagens/MensagensDoAluno.tsx; apps/web/components/equipe/mensagens/DetalheEnvio.tsx; GET /staff/students/:id/messages em apps/api/src/routes/staff-notices.ts (ou staff-students)
- Passos: 1) Admin agenda 'QA-MSG Multi local' para Nina e Mia (hora local, amanhã). 2) Cancelar em Agendadas ('Envio cancelado.'). 3) Abrir a ficha da Nina, aba Mensagens. 4) Abrir o link do envio cancelado.
- Esperado: A06, item 23: `canceled` não aparece em aba nenhuma. A08, item 7: a aba da ficha mostra as mensagens que o aluno recebeu. Um agendado cancelado antes de sair não foi recebido, não foi 'parado' e não tem o que reenviar.
- Obtido: Na ficha: 'QA-MSG Multi local · Mensagem da Crystal · Pulado: envio parado'. No detalhe: selo 'Envio cancelado.', 'Enviadas 2', entregas 'Pulado: envio parado', botões 'Reenviar para quem não abriu' e 'Exportar CSV', e o link 'Voltar para Enviadas'.

### [media] A chave da leitura da conversa (conversation_read_enabled e conversation_read_terms_at) não existe em Configurações: a aba Conversa nunca pode ser ligada

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: packages/shared/src/settings.ts (registro de chaves); apps/web/components/equipe/configuracoes/ConfiguracoesPanel.tsx; apps/api/src/services/students.ts:15
- Passos: 1) Entrar como admin (rui@demo.crystal) e abrir /equipe/configuracoes, grupo Produto. 2) Buscar 'conversa' em 'Buscar configuração'. 3) Fazer GET /staff/settings e procurar a chave.
- Esperado: A11, catálogo, linhas 'Leitura da conversa pela equipe' e 'Termos novos no ar desde' no grupo Produto, só para admin. Ligar pede a palavra LIGAR, a senha e a data obrigatória (sem a data, 400); desligar pede só a senha. Texto da confirmação: 'Ligar a leitura da conversa pela equipe?' (A04, item 13).
- Obtido: Nenhuma das duas chaves aparece na tela nem em GET /staff/settings. A API só lê a chave (apps/api/src/services/students.ts:15), então pelo painel não há como ligar a aba Conversa da ficha.

### [media] Faltam cinco chaves do catálogo do A11 (textos de notificação, destinatários de alertas e textos e gatilhos do robô)

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: packages/shared/src/settings.ts; apps/api/src/services/push.ts, alerts.ts e chatwoot-bot.ts (passo 2 do A11)
- Passos: Como admin, GET /staff/settings (ou abrir /equipe/configuracoes) e comparar com a tabela 'Catálogo de chaves que migram para o painel' do A11.
- Esperado: A11, catálogo: push_sender_name e push_private_body (Produto); alert_recipients, chatwoot_handoff_terms e chatwoot_bot_texts (Técnico), cada uma lida em tempo de execução pelo serviço correspondente (A11, item 2).
- Obtido: Nenhuma das cinco existe no registro nem na tela. O ONDAS.md não diz que ficaram para depois. Em compensação, o registro tem várias op_* da antiga Operação.

### [media] O grupo Ambiente não tem o cartão 'Coerência legal' e os cartões Limites e Notificações estão incompletos

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: apps/api/src/routes/staff-settings.ts:101 (GET /staff/settings/ambiente); apps/web/components/equipe/configuracoes/AmbienteCartoes.tsx
- Passos: Como admin, abrir /equipe/configuracoes, grupo 'Ambiente (só leitura)'; conferir também GET /staff/settings/ambiente.
- Esperado: A11, tabela 'O que fica só como leitura': cartão Coerência legal ('Tudo coerente.' ou 'A política de privacidade diz {x}; o app está com {y}...', mais 'Encarregado de dados: {nome}, {e-mail}'); Limites com 'memória da Crystal guardada por 180 dias'; Notificações com o remetente das notificações.
- Obtido: Não há cartão Coerência legal, e a resposta de /ambiente não traz nada sobre ele. Limites não cita a memória da Crystal e Notificações não mostra o remetente.

### [media] A aba Mensagens de Métricas fica totalmente em branco, e 'Sem usar o app' nunca aparece em Alunos

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: packages/shared/src/metrics.ts:251, 377 e 390 (campo depende); apps/api/src/services/metrics.ts:257; apps/web/components/equipe/metricas/MetricasPanel.tsx (não mostra nada quando a aba fica sem métrica)
- Passos: Como admin ou tech, abrir /equipe/metricas e clicar na aba 'Mensagens' (no computador e no celular). Ver também GET /staff/metrics/mensagens e /staff/metrics/alunos.
- Esperado: A12, catálogo: aba Mensagens com 'Enviadas, entregues, abertas, cliques' e 'Responderam depois' (A06 e A08 já estão integrados, ONDAS onda 2 e 3); aba Alunos com 'Sem usar o app há 7, 30, 90 dias' (users.last_seen_at já existe, A03). Sem dados, o texto 'Ainda não há dados neste período.'
- Obtido: A aba Mensagens mostra só o cabeçalho e as abas, sem nenhum cartão nem texto de vazio. A API devolve disponivel:false para mensagens.envios, mensagens.responderam e alunos.sem_uso, porque ainda trazem 'depende: A06 e A08' e 'depende: A03', que não foram tirados depois da integração.

### [media] O cartão do Financeiro em Métricas conta duas vezes o valor vencido (pendente + vencido) no número do título

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: apps/api/src/services/metrics.ts:109-127 (total soma todas as séries); apps/api/src/db/prisma-metrics.ts:266 e memory-metrics.ts:231 (vencido é subconjunto de pendente)
- Passos: Como admin, abrir /equipe/metricas, aba Financeiro, período de 01/10/2026 a 13/10/2026. Comparar com GET /staff/finance/summary e /staff/finance/entries.
- Esperado: A12, catálogo (Financeiro, 'como o resumo do financeiro'): o número do título reflete o mês. Há um lançamento pago de R$ 1.297,00 e um pendente vencido de R$ 297,00.
- Obtido: Título 'Recebido, pendente, vencido, estornado: R$ 1.891,00' (1.297 + 297 + 297). O mesmo lançamento entra como pendente e como vencido, porque vencido é um pedaço de pendente, e a barra empilhada soma os dois.

### [media] 'Mensagens da equipe por aluno por dia' aceita até 10, mas o PRD fixa de 1 a 5

- Área: Configurações (A11), Métricas (A12), Auditoria (A13) e pedidos do titular (A14), com admin, tech e support (support só para conferir os 404), no computador (1280 px) e no celular (390 px). Scripts e capturas em /tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad/onda4/qa/cfg/ (s1 a s14 e p1 a p8; capturas em shots/). Dados próprios: os alunos locais "CfgQA Titular Um" (dados apagados pelo A14, a conta continua) e "CfgQA Titular Dois" (conta excluída pelo A14). Toda chave que alterei voltou ao valor de antes: alerts_cooldown_min 15, audit_retention_days 730, health_fail_threshold 3, notices_max_per_student_per_day 2, backup_mode auto. A única que ficou gravada pelo painel é rate_msg_max, com o mesmo valor do padrão (500).
- Onde: packages/shared/src/settings.ts:192
- Passos: Como admin, em /equipe/configuracoes > Produto, gravar 7 em 'Mensagens da equipe por aluno por dia' (ou PUT /staff/settings/notices_max_per_student_per_day com value '7').
- Esperado: A11, catálogo: 'número 1 a 5', padrão 2.
- Obtido: Grava 7 (200), e a ajuda diz 'Entre 1 e 10.'. Só 11 é recusado. Voltei o valor para 2.

### [alta] GET /staff/users e a tela Equipe mostram a support e tech todos os alunos, com e-mail

- Área: Transversal: permissões (5 papéis × /equipe e /staff/*), celular 390 px, acessibilidade (axe AA, 44 px, foco, Esc), erros de console
- Onde: apps/api/src/routes/staff-users.ts (GET /staff/users sem filtro role != user); apps/web/app/(equipe)/equipe/usuarios/page.tsx e components/equipe/usuarios/UserList.tsx
- Passos: 1) Entrar como tech@demo.crystal (ou suporte@demo.crystal). 2) Abrir http://localhost:3201/equipe/usuarios, o item 'Equipe' do menu. 3) Ou chamar GET http://localhost:3205/staff/users com o cookie da sessão.
- Esperado: PRD, A03 item 8 (linha 335) e tabela de papéis (linha 115): a lista de Equipe mostra só contas de equipe, e os alunos ficam na área Alunos. PRD, princípio 6: o e-mail do aluno aparece só na ficha. A correção da onda 1 (ONDAS, pendência 3: 'lista e busca sem e-mail nem telefone para nenhum papel') e o A03 tiram o e-mail do aluno do técnico.
- Obtido: A resposta tem 17 itens, 14 deles com role=user (alunos), cada um com email completo, cpf_masked, consent_at e crystal_contact_id, para tech e para support. A tela lista os alunos (Ana, Bruno, Mia...) com o e-mail embaixo do nome. Com isso o tech contorna a correção do A03 e vê o e-mail de todos os alunos.

### [media] Support desliga e religa aluno pela API (PUT /staff/alunos/:id/status)

- Área: Transversal: permissões (5 papéis × /equipe e /staff/*), celular 390 px, acessibilidade (axe AA, 44 px, foco, Esc), erros de console
- Onde: apps/api/src/routes/staff-alunos.ts:66 e :370 (trocar `escrita` por `soAdmin` na rota de status)
- Passos: Como suporte@demo.crystal, chamar PUT /staff/alunos/<id>/status com corpo vazio e depois como tech@demo.crystal. Código: routes/staff-alunos.ts:370 usa o preHandler `escrita` (requireRole admin e support), e não `soAdmin`.
- Esperado: PRD A04, item 4 (linha 386): 'PUT /staff/students/:id/status: só admin; support e tech recebem 404 para active e para disabled'. Critério de aceite na linha 431. A tabela de papéis (linha 109) também diz: 'Só admin: ... desligar e religar'.
- Obtido: Support recebe 400 de validação, ou seja, passou pelo portão de papel; com corpo válido ele desliga e religa. Tech recebe 404. A pendência 1 do ONDAS ('escritas da área Alunos exigem admin ou support') liberou a rota de status junto com as outras escritas e contradiz o PRD. POST /staff/alunos (adicionar aluno) também aceita support, mas isso está coberto pela pendência 20 do PRD, item 3 do A05.

### [media] /equipe/equipe não existe e /equipe/canal não redireciona

- Área: Transversal: permissões (5 papéis × /equipe e /staff/*), celular 390 px, acessibilidade (axe AA, 44 px, foco, Esc), erros de console
- Onde: apps/web/components/equipe/areas.ts (STAFF_NAV, itens equipe e canal); apps/web/app/(equipe)/equipe/usuarios/page.tsx; app/(equipe)/equipe/canal/page.tsx
- Passos: Como admin, abrir http://localhost:3201/equipe/equipe e depois /equipe/canal.
- Esperado: PRD, tabela de papéis (linhas 115 e 117) e mapa do painel (linha 156): Equipe fica em /equipe/equipe, /equipe/usuarios redireciona para lá, Canal vira um cartão de Integrações e /equipe/canal redireciona.
- Obtido: /equipe/equipe responde 404 para todos os papéis. O menu 'Equipe' aponta para /equipe/usuarios, que continua como tela própria. /equipe/canal continua como tela e item de menu separados (areas.ts registra isso como provisório).

### [media] Contraste AA reprovado na chave técnica dos campos de Configurações e da Crystal

- Área: Transversal: permissões (5 papéis × /equipe e /staff/*), celular 390 px, acessibilidade (axe AA, 44 px, foco, Esc), erros de console
- Onde: apps/web/components/equipe/configuracoes/CampoRegistro.tsx:184 (tirar o /70 ou usar ink-2)
- Passos: Como admin ou tech, abrir /equipe/configuracoes ou /equipe/crystal a 390 px ou a 1280 px, no claro e no escuro, e rodar o axe (wcag2aa).
- Esperado: PRD, princípio 10 e critério do A01: o axe passa sem violação séria no claro e no escuro (texto pequeno precisa de 4,5:1).
- Obtido: Violação color-contrast (serious) em 26 nós em Configurações e 3 na Crystal: o texto da chave técnica `text-xs text-ink-muted/70` fica em 2,95:1 no claro (#838f97) e em 3,66:1 no escuro (#75838c).

### [media] Botão de perigo no tema escuro com contraste 3,99:1

- Área: Transversal: permissões (5 papéis × /equipe e /staff/*), celular 390 px, acessibilidade (axe AA, 44 px, foco, Esc), erros de console
- Onde: apps/web/app/globals.css (token --danger no tema escuro, linha 46) e components/equipe/ui/base.tsx:76 (dangerBtn); o mesmo acontece em FotoPanel.tsx:174
- Passos: Como admin, a 390 px no tema escuro, abrir /equipe/senha ou a aba Dados da ficha de um aluno e rodar o axe.
- Esperado: PRD, princípio 10: axe sem violação séria no escuro.
- Obtido: color-contrast (serious) no botão de perigo (`bg-danger text-on-brand`): branco sobre #ff0004 dá 3,99:1. No claro o --danger é #d40003 e passa.

## Achados baixos

- [baixa] Contador "Ficha aberta {n} vezes" do Histórico fica um atrás e cresce a cada recarga (apps/api/src/routes/staff-alunos-ficha.ts:93-101 (views antes do audit.record da linha 145))
- [baixa] No celular, a barra de seleção fica atrás da navegação de baixo (apps/web/components/equipe/alunos/lista/AlunosLista.tsx:271-305 (sticky bottom-2, sem descontar a altura da navegação))
- [baixa] Plural errado e número sem conferir nos textos de seleção e de lotes (apps/web/lib/microcopy-alunos.ts; apps/web/components/equipe/alunos/LotesPanel.tsx)
- [baixa] Filtro "Acesso" (financeiro) ausente para o admin (apps/web/components/equipe/alunos/lista/FiltrosSheet.tsx:12-21; packages/shared/src/students.ts:34)
- [baixa] 'Só aviso' para aluna sem aparelho trava o Enviar sem explicar o motivo (apps/web/components/equipe/mensagens/NoticeSteps.tsx (passo Público e Revisar com kind push_only); apps/api/src/services/notices.ts:230-233)
- [baixa] 'A mensagem como foi enviada' mostra a hora de agora, não a do envio (apps/web/components/equipe/mensagens/Previa.tsx e DetalheEnvio.tsx (a prévia não recebe a data do envio))
- [baixa] Bolha do 'teste para mim' gera 404 em POST /me/notices/:id/opened a cada vez que a equipe abre o chat (apps/web/components/chat/MessageBubble.tsx ou apps/web/lib/use-chat.ts (IntersectionObserver de opened); apps/api/src/routes/me.ts)
- [baixa] Status da Crystal fica em 'Sem notícia' com a Crystal no ar e o /healthz respondendo (apps/api/src/routes/staff-crystal.ts:85-115 (status sem usar o resultado de `saude`); apps/api/src/services/crystal-status.ts)
- [baixa] No celular, o toast do teste continua por cima da prévia no passo Revisar (apps/web/components/equipe/mensagens/NoticeSteps.tsx (data-rodape-fixo e posição do toast))
- [baixa] Confirmação da Manutenção descreve uma tela diferente da que o aluno vê (apps/web/components/equipe/crystal (bloco Manutenção, texto em lib/microcopy-operacao.ts ou microcopy-configuracoes.ts))
- [baixa] O link da auditoria para uma configuração não leva ao campo (apps/web/components/equipe/configuracoes/CampoRegistro.tsx (falta id={item.key}) e ConfiguracoesPanel.tsx (não rola até o hash))
- [baixa] O texto 'Chave: {key}' em cada campo de Configurações tem contraste baixo (apps/web/components/equipe/configuracoes/CampoRegistro.tsx (span text-ink-muted/70))
- [baixa] A confirmação forte de 'Guardar a trilha de auditoria por' tem título truncado e não explica o efeito (apps/web/components/equipe/configuracoes/CampoRegistro.tsx (T.confirmarTitulo e body padrão) e lib/microcopy-configuracoes.ts)
- [baixa] O campo 'Apagar mensagens e mídias depois de' não mostra 'Padrão', 'Alterado por' nem a chave (apps/web/components/equipe/configuracoes/RetencaoCampo.tsx)
- [baixa] Na Auditoria, filtrar com 'De' depois de 'Até' não faz nada e não avisa (apps/web/components/equipe/auditoria/AuditoriaPanel.tsx; apps/api/src/routes/staff-audit.ts (GET sem validar from < to))
- [baixa] O texto de 'Excluir a conta' promete volta pela base também para aluno de conta local (apps/web/lib (microcopy da aba Dados do A14) e a aba Dados da ficha em components/equipe/alunos)
- [baixa] Negação de área no web chega com HTTP 200 e mostra a página 404 só no cliente (apps/web/components/equipe/StaffLayout.tsx (portão só no cliente))
- [baixa] Linhas da lista de Equipe sem anel de foco visível (apps/web/components/equipe/usuarios/UserList.tsx:25)
- [baixa] Checkboxes de seleção de 20×20 px na lista de Alunos (desktop) e links pequenos no login (apps/web/components/equipe/ui/DataTable.tsx (checkbox da linha); app/(auth)/login/equipe e o rodapé do login)
- [baixa] <dl> com filhos inválidos na ficha do aluno (axe definition-list, serious) (apps/web/components/equipe/alunos/ficha/ResumoTab.tsx:35 e ficha/abas.tsx:211)

## Bateria depois das correções

Tudo passou na branch painel/onda4, sem push, HEAD 06aaa0a. pnpm -r typecheck: os 4 pacotes (shared, api, crystal, web) terminaram com Done e sem erro. pnpm -s lint: código de saída 0. Testes de unidade (vitest run): packages/shared com 23 arquivos e 261 testes passando; apps/api com 102 arquivos e 1179 testes passando, mais 3 arquivos e 9 testes pulados (são os *.pg.test.ts, que precisam de Postgres e não rodam neste ambiente); apps/web com 108 arquivos e 819 testes passando; apps/crystal com 12 arquivos e 239 testes passando. Cada correção ganhou teste que falha antes e passa depois; em várias isso foi conferido voltando o código com stash. Não reconstruí o web nem rodei o Playwright: os servidores de QA nas portas 3205, 3201, 8099 e 4555 ficaram como estavam. Ajustei o e2e/equipe.spec.ts à saída do item Canal do menu, mas não rodei esse teste.
