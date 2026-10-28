# Continuar em outra conta (passagem de 13/10/2026, fim da tarde)

Escrito para o caso de os créditos desta conta acabarem no meio do trabalho. Uma sessão nova do Claude Code,
em qualquer conta, consegue continuar lendo este arquivo, o `CLAUDE.md`, o `PROXIMOS-PASSOS.md` e o
`crystal-em-casa/publicar-prd.md`. A conversa inteira (só as mensagens, com chaves, e-mails, telefones e CPFs
mascarados) foi entregue ao dono como `conversa-crystal-2026-10-13.md`. Ela **não** fica no repositório: pode
ter nome de aluno colado de alguma saída.

## 1. Preparar a conta nova (uma vez)

1. Em claude.ai, ligar o **GitHub** (Configurações › Conectores) com acesso aos dois repositórios:
   `LFcrystal766/hospedagem_em_transicao` (este: roteiros, scripts da VPS, SQL, auditorias) e
   `LFcrystal766/crystal-web-chat` (o app: API, web, nossa Crystal). Se o GitHub pedir, instalar o app
   "Claude" nos dois.
2. Ligar o conector do **Supabase** (projeto "Crystal AI", `hwbllqepvhddakszqdbk`). Opcionais: Hostinger (leitura
   da VPS), Cloudflare, n8n.
3. Segredos: este ambiente não tem nenhuma variável de segredo hoje; nada a copiar. Se um dia for rodar o degrau 2
   do site, o `CLOUDFLARE_API_TOKEN` vai nas variáveis do ambiente da nuvem, nunca no chat.
4. Os artefatos (páginas no claude.ai) são desta conta. Cópias estão em `artefato/`; para ver os originais na outra
   conta, compartilhar o link a partir desta enquanto ela ainda abre.
5. Abrir uma sessão do Claude Code neste repositório e colar a mensagem abaixo.

### Primeira mensagem para a sessão nova

> Sou o Luiz, dono da Crystal (crystalnowpp). Estou continuando numa conta nova o trabalho de outra sessão do
> Claude Code. Leia, nesta ordem: `CLAUDE.md`, `CONTINUAR-EM-OUTRA-CONTA.md`, `PROXIMOS-PASSOS.md` e
> `crystal-em-casa/publicar-prd.md`. Depois adicione e clone `LFcrystal766/crystal-web-chat` e confira no GitHub
> as branches citadas na seção 3 (`otimizacao/painel-rapido`, `painel/onda4`, `backup/onda4-2026-10-13`).
> Me responda em português simples, contando cada passo: (1) o que está no ar, (2) o que estava em andamento e
> em que ponto ficou no GitHub, (3) o próximo passo que depende de mim. Não publique nada na VPS: quem roda os
> comandos lá sou eu.

## 2. O que está no ar (13/10)

| Coisa | Estado |
|---|---|
| App na VPS (`177.7.61.136`) | **`sha-c45a71a`** (onda 6) desde 21/10 ~11:00 UTC; antes **`sha-9ec8151`** (painel novo) desde 14/10 ~09:25 UTC; antes **`sha-3773e2e`** desde 13/10 18:44 UTC (correção do painel que derrubava a API por falta de memória; volta `sha-0e2f79d`). Antes, `sha-0e2f79d`, publicado em 13/10 14:13 UTC. É o `sha-5a5b198` de 10/10 (modelo por fornecedor com tabela de gasto de 7 dias, "Ligações da Crystal", avisos programados com prévia, correções da bateria do painel) **mais as fichas**. Volta: `bash bootstrap-vps.sh app-subir sha-74092e0`. Backup feito antes, cópia cifrada no R2. |
| Painel (Operação) | `op_memoria_unica = on`, `op_whatsapp_silencio = on`, **sem modelo salvo** (a Crystal usa o padrão da imagem). |
| Supabase | `app_memoria_ficha.sql` aplicado em 13/10 (migração `app_memoria_ficha_20261012`): tabela com RLS, 6 funções só para `service_role`, 0 linhas. A função de teste `zz_teste_cabecalho_20261009` foi apagada pelo dono em 13/10. |
| Chatwoot | v4.18.0-ce em `atendimento.`, canal do app ligado (`CHAT_TRANSPORT=chatwoot`). |
| Compras | Assiny → nosso n8n → `crystal_compras` no Supabase → app liberado. Sem agência desde 09/10. |
| Site | Degrau 1 feito (DNS no Cloudflare, cinza). Degrau 2 não começou; chamado AZAN #RAI-374885. |
| OpenRouter | Saldo US$ 47,79 por volta de 15h UTC e US$ 32,87 às 18h50 UTC de 13/10 (US$ 15 em ~4 h). Conferir a origem (pilotos das fichas ou uso dos alunos) e recarregar antes de zerar: sem saldo, a Crystal para. |
| `bootstrap-vps.sh` | Versão atual: commit `1075cb3` (sha256 `f865a1a7a9392406b311c70cd1329c1e1ddb7877f1a95c2705e0f1064239821a`, com `app-construir`); antes `54acea7` (sha256 `ef72390c430af804d8371c84e9a7a6dcd24a5f08a1ecf90d71f09b12e563eec6`); antes `c0379c9`, sha256 `770983400c98d05bd98065e7efc515dc48de5b9ccc4e91ae9a2c505c47ad7d6d` (tem o `crystal-conferir` corrigido e o `painel-diagnostico`). |

## 3. O que estava em andamento

1. **Painel intermitente (área "Painel", gráficos).** O dono relatou que às vezes carrega e às vezes não.
   Causas achadas no código (falta a prova da VPS):
   - o resultado fica guardado só 60 s e a tela atualiza a cada 60 s: quase toda atualização refaz a conta;
   - a conta lê todas as mensagens de 2× o período, com o texto inteiro (inclusive as respostas da Crystal);
   - a tabela `messages` não tem índice em `created_at`: o filtro por data varre a tabela inteira;
   - a web desiste em 30 s.

   **Correção pronta:** branch `otimizacao/painel-rapido` do app (`3773e2e`, 6 commits sobre a produção), CI
   verde, imagem **`sha-3773e2e`**. A causa principal era outra: um formatador de data criado por mensagem
   travava a API por 12–77 s. Depois: 0,6–1,9 s. Roteiro em `publicar-prd.md`, seção "Correção do painel
   intermitente". **Prova da VPS (13/10): a API morreu por falta de memória 3 vezes em 16 h** (exit 137,
   ~976 MB de 1 GiB), `auditorias/2026-10-13/painel-diagnostico.md`. `crystal-conferir` deu TUDO LIGADO.
   **Publicado pelo dono em 13/10 18:44 UTC**, `crystal-conferir` TUDO LIGADO. Conferir em 14/10 com
   `painel-diagnostico 6`: nenhum "exit (137)" novo na API. Já portado para a onda 4 (`painel/onda4` `22a65c1`, com
   a `pa12_26_metricas` em `CREATE INDEX IF NOT EXISTS`).
2. **Conferência de ponta a ponta.** O `crystal-conferir` de 10/10 quebrava sem modelo no painel ("modelo: unbound
   variable"); corrigido em `182a12e`. Esperando o dono rodar de novo e colar a saída (deve terminar em
   "TUDO LIGADO").
3. **Painel novo (onda 4, caminho A): NO AR desde 14/10 ~09:25 UTC** (`auditorias/2026-10-14/publicacao-onda4.md`;
   backfill 80/80, cadeia íntegra, TUDO LIGADO). n8n do pacote aplicado e VPS reiniciada (kernel 6.8.0-147) em 14/10, TUDO
   LIGADO depois. Falta: cadastrar link do checkout e pacotes no painel. Antes: `painel/onda4` em `9ec8151`, CI verde (run
   38463529669), imagem **`sha-9ec8151`** (com o limite de imagens e o crédito do pacote; não usar `sha-06aaa0a` nem
   `sha-22a65c1`). Tem a T2, as fichas, 16
   correções da QA (`auditorias/2026-10-13/onda4-qa.md`) e a correção do painel intermitente (com o índice em
   `IF NOT EXISTS`, ensaiado). Esperando o dono: escolher a madrugada (02:00–05:00) e responder a pendência 20 do
   PRD (o suporte pode desligar e religar aluno? hoje pode). Para entrega própria: números de Mensagens e "Sem usar
   o app" em Métricas, cinco chaves de Configurações e o cartão "Coerência legal". Roteiro:
   `crystal-em-casa/publicar-prd.md`, "Publicação do painel novo (onda 4)"; ordem obrigatória: API parada →
   migração + backfill da auditoria → API nova.
4. **Fichas dos alunos.** SQL e imagem no ar. Falta o dono rodar, em Operação › Crystal › "Ficha completa de cada
   aluno": "Prever custo"; piloto de 20 com `openai/gpt-4.1-mini` (12 meses, teto US$ 5); outro de 20 com
   `anthropic/claude-haiku-4.5` (mesmo alcance e teto). Comparar fichas e custo.

5. **Mensagens: números do "não" (pedido do dono 13/10): PARADO, não está na onda 4.** O agente foi interrompido
   no meio (a interrupção do dono às ~17h parou os agentes em segundo plano). O trabalho incompleto, sem bateria,
   ficou guardado em `backup/onda4-mensagens-nao-wip` (`2810461`, base `22a65c1`, 12 arquivos: notices repos/tipos,
   DetalheEnvio, Enviadas, microcopy). Retomar só se o dono pedir: juntar com `painel/onda4` e terminar (não
   entregues com motivo, não abriram, não clicaram/sem botão, resumo na lista, filtros "Não abriu"/"Não clicou").
6. **Alma da Crystal no painel (onda 5, pedido do dono 13/10).** Decisões: **superadmin** edita, testa e publica;
   acompanhar com bateria de perguntas-padrão, amostra de conversas reais (👍/👎 e nota) e números do dia a dia;
   editáveis: a alma, as regras de formato e a base de conhecimento. Fatos levantados: a alma é
   `apps/crystal/prompt/crystal.md` (~17 mil caracteres, dentro da imagem: hoje mudar = publicar imagem nova); as
   regras de formato são o `BLOCO_FORMATO` em `apps/crystal/src/prompt.ts`; a base é a tabela
   `leticia_crystal_hybrid_search` do Supabase (27 trechos: 9 regras de ouro, exemplos, diretrizes e estágios), buscada
   pela Edge Function `crystal_hybrid_search` (embedding `openai/text-embedding-3-small`, 1536, pelo OpenRouter com o
   segredo `OPENROUTER_API_KEY_CRYSTAL` da função: **conferir de quem é essa conta**; se for da agência, a busca depende
   dela). Não existe papel superadmin (papéis: aluno, suporte, técnico, admin): proposta é uma lista de e-mails numa
   variável da API (`SUPERADMIN_EMAILS`), que só se muda na VPS.
   **Estado (13/10, noite): PRONTA para publicar depois da onda 4.** `painel/onda5-alma` em `f3d6616` (= onda 4
   `9ec8151` + alma; migração renomeada para `pa17_01_crystal_avaliacoes`, ensaiada sobre a `pa16_01_imagens_semana`),
   CI verde (run 38469721794), imagem **`sha-f3d6616`**. QA: 19 achados, 7 médios corrigidos (relatório em
   `auditorias/2026-10-13/onda5-alma.md`). Roteiro: `publicar-prd.md`, "Alma da Crystal no painel (onda 5)": SQL
   `app_conhecimento_editar.sql` no Supabase, `app-definir SUPERADMIN_EMAILS` (aceito desde o bootstrap `36c0efd`),
   `app-subir sha-e05ba35` (etiqueta atual da onda 5, ver item 17) na janela 02:00–05:00 (trava a `uso_turnos` uma vez). Decisões do desenho para o dono
   rever: apagar trecho tira a linha da tabela viva e guarda inteira no histórico (restaurar volta com o mesmo id);
   amostra de conversas só para admin; só o superadmin testa (custa). A busca segue pela Edge Function da agência
   até alguém conferir de quem é a chave dela.
7. **Aluno liberado à mão (pedido da Letícia, 13/10, 1 ano): FEITO em 13/10 à noite.** Não estava em nenhuma base.
   Liberado direto no nosso cadastro de compras do Supabase (`crystal_compras`, produto `manual` "Liberação manual",
   oferta "acesso até 13/10/2027"; evento `liberacao_manual` em `crystal_compras_eventos`), como a liberação manual de
   10/10. `app_verificar_login_email` já o encontra como liberado: ele entra no app com o e-mail e o código.
   **Prazo:** `crystal_compras` não tem data de fim. Em 13/10/2027 (ou antes, se pedirem), cortar: `status =
   'canceled'` na linha dele e desligar a conta no painel. Depois da onda 4, dá para usar "Nova conta local" com
   "Acesso até" para os próximos casos (o login é barrado sozinho na data). E-mail e telefone ficam fora do repositório.
8. **Limite semanal de imagens + pacote extra automático: PRONTO em `painel/onda4` `9ec8151` (13/10).**
   - Aluno: 25 por semana (zera domingo 00:00 de Brasília; imagens já mandadas desde domingo contam); acima do
     limite a imagem não vai ao modelo e a Crystal manda a mensagem (com o botão "Comprar mais imagens" se houver
     link); com texto junto, responde ao texto e manda o aviso. Aviso discreto acima da caixa quando restam 5 ou menos.
   - Ficha (aba Resumo, bloco "Imagens"): "Imagens esta semana: N de 25 · extras: M", histórico das extras e
     "Adicionar imagens extras" (admin e suporte; auditoria `student.images_extra_add`).
   - Configurações (grupo Produto): `imagens_limite_semana` (25; 0 = sem limite), `imagens_checkout_link` (vazio),
     `imagens_limite_texto`, `op_imagens_pacotes` (uma linha por pacote: `id do produto | imagens | nome`).
   - Compra: `POST /webhooks/imagens` (Bearer = `REFUND_WEBHOOK_SECRET`), créditos em `approved_purchase`,
     `purchase_approved`, `subscription_renewed`, `renewed_subscription`; estorno em `refunded_purchase`, `chargeback`,
     `chargedback_purchase`; sem duplicar por tipo+transação; e-mail sem conta = crédito pendente aplicado no 1º login
     (some no purge LGPD e em 180 dias). Migração `pa16_01_imagens_semana`.
   - n8n: `compra-assiny.json` com 10 nós e o script `crystal-em-casa/n8n/compra-assiny-imagens.py` (commit
     `cbffaa4`, sha256 `f8ea4111a1c7fd24828dbf31295a901b38f143c8b7f0f5210dc6b82ec68a42ae`), testado num n8n 1.123.10 local.
     Rodar **só depois** da onda 4 no ar.
   - Falta do dono: o link do checkout, o produto do pacote na Assiny e quantas imagens ele dá, e conferir se o webhook
     da Assiny é por produto.

9. **Troca de e-mail de aluno da base (pedido da Letícia, 13/10 22h): FEITA à mão.** Identidade conferida pelo CPF
   no cadastro; e-mail trocado em `leticia_crystal_customers` (mesmo `id`, que é o `contact_id` do login): ele entra com
   o e-mail novo e a API acha a mesma conta pelo contato e atualiza o e-mail dela (histórico mantido); o antigo não
   entra mais. Riscos: se o webhook antigo da agência ainda escrever nessa tabela, pode voltar o e-mail antigo; se uma
   renovação chegar pelo nosso n8n com o e-mail antigo, ela cria linha em `crystal_compras` e esse e-mail antigo
   viraria outra conta. **Pedido do dono: o suporte tem de conseguir fazer isso no painel.** Hoje o painel novo só
   troca e-mail de conta local (aluno da base: recusa, "corrige-se na base"). Em construção (agente Sonnet): troca
   de e-mail de aluno da base pela ficha, para admin e suporte, gravando no Supabase por função SQL só para
   `service_role`, derrubando as sessões e auditando sem os e-mails; entra na onda 5. E-mails e CPF fora do repositório.
   **Pronto em 14/10:** `painel/onda5-alma` em `dd49156` (ficha › "Corrigir e-mail" para admin e suporte, com motivo
   obrigatório; `PATCH /staff/alunos/:id` chama `app_aluno_trocar_email`; 409 se o e-mail já existe; sessões derrubadas;
   auditoria `aluno.email_base_trocado` sem e-mail). SQL `crystal-em-casa/supabase/app_aluno_trocar_email.sql`
   **APLICADO em 14/10** (migração `app_aluno_trocar_email_20261014`, só `service_role`). Falta CI e imagem: ver item 10.
10. **GitHub Actions BLOQUEADO por cobrança (14/10):** o CI de `dd49156` não começou ("recent account payments have
   failed or your spending limit needs to be increased"). Sem CI não sai imagem nova. O dono resolve em GitHub ›
   Settings › Billing; depois re-rodar o CI da branch `painel/onda5-alma` e disparar o `imagens-vps`. Conta do app é
   pessoal (`LFcrystal766`, repositório privado): https://github.com/settings/billing (resumo e fatura pendente),
   `/settings/billing/payment_information` (cartão) e `/settings/billing/budgets` (limite de Actions). O teste da API que
   dependia da hora do dia (`staff-notices-agenda.test.ts`) foi consertado em `989df6c`.
11. **Reautenticação por código no e-mail (pedido do dono, 14/10):** toda confirmação forte do painel deixa de pedir
   senha e manda código de 6 dígitos para o e-mail de quem está logado (10 min, uso único, limites). **Pronto em 14/10**
   em `painel/onda5-alma` `640b9a0` (rotas `POST /auth/staff/reauth/codigo` e `POST /auth/staff/reauth { codigo }`;
   caminho por senha removido; e2e com `dev_code`). Depois, `989df6c` consertou o teste `staff-notices-agenda` (logava
   antes de fixar o relógio; falhava de manhã em Brasília). **Etiqueta esperada da onda 5: `sha-e05ba35`** (17/10; antes `sha-82c6d7f`), que só sai
   depois da cobrança do GitHub resolvida (item 10): re-rodar o CI da branch e disparar o `imagens-vps`.

12. **Teste do GPT-5.6 Sol pela Letícia (14/10).** Modelo `openai/gpt-5.6-sol` (US$ 2/10 por milhão; ~5x o Haiku 4.5
   por pergunta). Hoje (caminho A): trocar o modelo de todos em Crystal › Modelo por 20–30 min, ela conversa no app com
   uma conta local de aluna criada só para o teste, volta o modelo; a conversa vem para a sessão, que monta o dossiê.
   Caminho B **pronto** em `painel/onda5-alma` `98d30d0`: bloco "Conversa de teste" na área Crystal (1 ou 2 modelos lado a
   lado, histórico por lado, até 30 turnos, sem tocar alunos; rotas `/staff/crystal/conversas-teste`; migração
   `pa18_01_crystal_conversas_teste`) e "Gerar dossiê" (avaliador gpt-4.1-mini, custo previsto antes, copiar/PDF). O e2e
   novo não rodou aqui: roda no CI. **Etiqueta esperada da onda 5 agora: `sha-e05ba35`** (item 17; depois da cobrança do GitHub).

13. **Atendimentos de 16/10 (pedidos da Letícia e da Giseli).** Duas trocas de e-mail de alunos da base feitas pela
   função `app_aluno_trocar_email` (ambas `trocado`, origem base; e-mail novo entra, antigo não); conferido que o nome do
   cadastro bate com o e-mail novo (sem CPF desta vez). Um aluno que "não encontra cadastro": na base, assinatura ativa
   e `app_verificar_login_email` o acha como liberado, então o problema não é cadastro: pedir print da tela e o e-mail
   exatamente como ele digita. Enquanto a onda 5 não sobe, troca de e-mail de aluno da base continua sendo pedida à
   sessão (o painel no ar ainda não faz).
   Conferência geral do login (16/10, fim da tarde): NÃO é geral. Supabase: 24 h de `app_verificar_login_email` com
   12 a 57 chamadas por hora, todas 200; API `POST /auth/login` com e-mail inexistente responde 404 LOGIN_NOT_FOUND em
   0,7 s; compras chegando (123 liberações em 5 dias, a última às 16:44 UTC, nenhuma "ignorado_produto"). Um segundo
   aluno sem acesso não está em base nenhuma (nem e-mail parecido, nem nome): comprou com outro e-mail ou a compra não
   foi aprovada; com o número da transação da Assiny dá para achar em `crystal_compras_eventos.transacao`.
   Verificação geral (16/10, noite): `auditorias/2026-10-16/verificacao-login.md`. A função de login da PRODUÇÃO é mais
   nova que a do repositório (11/10, fim dos lotes; cópia em `crystal-em-casa/supabase/app_verificar_login_email.producao-20261016.sql`).
   Ponto de atenção: 3 produtos da lista nunca mandaram evento ao nosso n8n (Todos os Cursos, Do Oi ao Encontro,
   Trimestral): conferir na Assiny se vendem e se o webhook deles aponta para o nosso n8n. Uma 3ª troca de e-mail
   (aluno da nossa tabela de compras) feita; mais um aluno sem cadastro em lugar nenhum.

14. **iPhone antigo: "Algo deu errado do meu lado. Um erro crítico aconteceu" (16/10, noite).** Causa confirmada no
   bundle de produção (`sha-9ec8151`): regex com lookbehind (`(?<!`) em código que vai para o navegador
   (`packages/shared/src/risco.ts` linhas 25 e 117, `packages/shared/src/notices.ts:120`); o Safari só aceita a partir
   do iOS 16.4 e o módulo quebra ao abrir. Também `initial.at(-1)` em `apps/web/lib/use-chat.ts` (iOS 15.4+). Afeta
   quem não atualizou o iPhone e modelos que não passam do iOS 15/16.3. O `risco.ts` está no ar desde 05/10. Contorno
   para o aluno hoje: atualizar o iOS (Ajustes › Geral › Atualização de Software) ou usar outro aparelho/computador.
   **Corrigido em 16/10 (código):** `painel/onda4` `f8f53b4` (regex sem lookbehind, mesmo resultado em ~500 mil
   textos; `.at(-1)`, `crypto.randomUUID` e `AbortSignal.timeout` com plano B; trava no Dockerfile e no CI do web que
   falha se o bundle tiver lookbehind; testes todos passando) e merge em `painel/onda5-alma` `82c6d7f` sem conflito.
   **Etiquetas esperadas (16/10, já superadas pelo item 17: `sha-8308e71` e `sha-e05ba35`): produção `sha-f8f53b4` e onda 5 `sha-82c6d7f`.** Só saem
   depois da cobrança do GitHub (item 10): aí disparar o `imagens-vps` nas duas branches (a sessão pode disparar).
   Roteiro em `publicar-prd.md` › "Correção do iPhone antigo". Observação: o Tailwind v4 do web pede Safari 16.4 para
   o visual completo; abaixo disso pode sair com cor/estilo degradado, mas não derruba a página.
   Nota: `auditorias/2026-10-16/erro-iphone-antigo.md`.
   16/10 20:25 UTC: o dono rodou `backup` + `app-subir sha-f8f53b4` antes de a imagem existir; o `app-subir` parou
   em "não baixou as imagens" sem mexer em nada (produção segue `sha-9ec8151`, `crystal-conferir` TUDO LIGADO). O push
   de 20:06 abriu CI e `imagens-vps`, mas os jobs nem começaram: cobrança do GitHub ainda bloqueada. Quando o dono
   resolver, a sessão re-roda os runs que falharam (`imagens-vps` 38959770645 de `painel/onda4`; CI 38959770713 e
   38960622563) e dispara o `imagens-vps` de `painel/onda5-alma`. Notado na mesma saída: modelo do painel trocado para
   `google/gemini-2.5-flash-lite` (alguém da equipe) e saldo do OpenRouter em US$ 21,69 (era 40,96 em 14/10: ~US$ 8
   por dia; recarregar ou ligar a recarga automática).
   Re-tentado pela sessão às 20:40 e 21:12 UTC: mesma recusa por cobrança (nenhuma imagem `sha-f8f53b4` ainda).

15. **Compras juntadas por CPF na base antiga (16/10, noite).** Aluno sem acesso: a compra dele estava num cadastro da
   base antiga que junta 25 assinaturas de pessoas diferentes com o mesmo CPF; o cadastro ficou com o e-mail da última
   compra, então os outros não entram. Trocar o e-mail do cadastro daria a ele a conta de outra pessoa; em vez disso,
   linha nova em `crystal_compras` ("Liberação manual", `transacao manual-20261016-assinatura-agencia-23678`), login
   conferido (`liberado = true`, conta própria). **Faltam 18 compradores no mesmo cadastro**: proposta de liberar todos
   do mesmo jeito, aguardando o "sim" do dono. Outros 18 casos isolados são, na maioria, a mesma pessoa com outro
   e-mail (não mexer). Detalhes: `auditorias/2026-10-16/compras-juntadas-por-cpf.md`.

16. **Links de checkout (lidos das vendas da base antiga, 16/10).** Pacote de imagens ("Pacote de Imagens Crystal -
   30img", R$ 29,90, 90 vendas até 10/10): `https://pay.assiny.com.br/c26844/node/Qx6Lpp` é o valor para
   `imagens_checkout_link` (painel › Configurações › Produto). Crystal anual R$ 297 ("CHECKOUT 01", o mais vendido):
   `https://pay.assiny.com.br/fe5c30/node/T2MJj3`. Nenhum evento do pacote chegou ainda ao nosso n8n
   (`crystal_compras_eventos`): conferir na Assiny se o webhook desse produto aponta para o nosso n8n.

17. **Crystal mandou a base de conhecimento ao aluno (16/10, noite; vídeo da equipe).** Modelo do painel estava em
   `google/gemini-2.5-flash-lite` (trocado por alguém da equipe; padrão `anthropic/claude-haiku-4.5`). Contenção: o
   dono volta o modelo para `anthropic/claude-haiku-4.5` no painel e roda `crystal-conferir`. Alcance (só leitura, VPS):
   `cid=$(docker ps -qf name=crystal_app_app_postgres | head -1)` e depois
   `docker exec "$cid" psql -U crystal -d crystal_web_chat -c "select key, value, updated_at, updated_by from system_settings where key like 'op_crystal_modelo%';"`
   e `docker exec "$cid" psql -U crystal -d crystal_web_chat -c "select model, count(*) respostas, count(distinct conversation_id) conversas, min(created_at), max(created_at) from messages where direction='out' and (content ilike '%base de conhecimento%' or content like '%[principio_%') group by model;"`.
   Correção no código por agente (Sonnet): trava na saída + um system só para modelo não Anthropic, em `painel/onda4`
   e `painel/onda5-alma`. Nota: `auditorias/2026-10-16/vazamento-base-gemini.md`.
   Alcance (21:40 UTC): troca para o Flash-Lite em 16/10 13:56 UTC por conta da equipe `c532536b…`; **525 respostas em
   74 conversas** com material da base até 21:33 UTC (ainda acontecendo). Passado ao dono o `update` direto do
   `op_crystal_modelo` para `anthropic/claude-haiku-4.5` (cache da API 30 s) + `crystal-conferir`. Falta: confirmar a
   volta, olhar as 47 respostas sem modelo (20 conversas desde 10/10) e decidir aviso de desculpas às 74 conversas.
   **Contido em 16/10 ~21:45 UTC:** o dono rodou o `update`; `crystal-conferir` TUDO LIGADO com
   `op_crystal_modelo = anthropic/claude-haiku-4.5` e resposta do Haiku. Saldo do OpenRouter US$ 20,87 (Haiku custa
   ~5x o Flash-Lite por resposta: a troca da equipe foi, provavelmente, para economizar).
   Pergunta do dono: "no WhatsApp o Gemini funciona". Resposta: o WhatsApp é o código da agência (`crystal-ia`, fora
   do nosso alcance; o nosso n8n só tem o fluxo de compras), que monta as instruções de outro jeito; o nosso manda a
   base como mensagem de sistema separada no meio, o que o Claude aceita e o Flash-Lite às vezes devolve. Depois da
   trava (system único para não-Claude), testar o Gemini pela "Conversa de teste" (onda 5) antes de trocar.
   **Trava pronta (17/10 ~00:25 UTC):** agente fez `5a99dcd`+`002b1f4`; a sessão ajustou em `8308e71` (categoria em
   snake_case só conta abrindo a linha, para não barrar roteiro com "[nome_dela]"). **Etiquetas agora: produção
   `sha-8308e71` (iPhone + trava, sem SQL; volta `sha-9ec8151`) e onda 5 `sha-e05ba35`.** Testes do apps/crystal: 293 e
   353 passaram. Roteiro em `publicar-prd.md` › "Correção do iPhone antigo + trava contra vazamento".
   17/10 00:30 UTC: `app-subir sha-8308e71` parou sem imagem (os runs de 00:25 também recusados pela cobrança do
   GitHub). **Saldo do OpenRouter caiu para US$ 6,21** (US$ 20,87 às ~21:45 UTC: ~US$ 5 por hora, muito acima do
   esperado para o app). Pedido ao dono: recarregar já e rodar, no banco `crystal_agente`, a soma de `uso_turnos` por
   hora/tipo/modelo das últimas 12 h, e olhar https://openrouter.ai/activity, para achar quem está gastando.
   20/10: re-tentado o `imagens-vps` de `8308e71`: ainda recusado pela cobrança do GitHub. Justificativa do gasto passada ao dono.

18. **PRD dos banners (B01–B08) + Laboratório da Crystal (20/10).** PRD do Luiz (15/10, artefato "Banners e Eventos
   da Crystal"; cópia enviada pelo dono). Pedido extra: área separada "Laboratório" no painel para a Letícia escolher
   provedor e modelo, conversar do zero com a Crystal e ajustar as conversas (editar, regenerar, apagar a partir de,
   duplicar, 👍/👎 com nota, teto diário de custo). Três agentes Sonnet em paralelo, cada um num worktree saído de
   `painel/onda5-alma` `e05ba35`: `painel/b01-presenca` (`/home/user/cw-b01-presenca`, B01), `painel/banners`
   (`/home/user/cw-banners`, B02–B08, migração `pa19_`), `painel/laboratorio` (`/home/user/cw-laboratorio`, migração
   `pa20_`). Depois: juntar as três numa branch de integração, revisão de segurança do conjunto e imagem (depende da
   cobrança do GitHub). Disco da sessão quase cheio (limpos `node_modules`/`.next` dos worktrees antigos).

19. **Atendimentos de 20/10.** (a) Liberados os 18 compradores do cadastro juntado por CPF (item 15): linhas
   "Liberação manual" em `crystal_compras`, `transacao manual-20261020-assinatura-agencia-<id>`; conferido: os 18 acham a
   conta própria, `liberado = true`. (b) Aluno pedido pelo dono sem compra achada em lugar nenhum (nem CPF): liberado à
   mão por pedido do dono (`transacao manual-20261020-pedido-do-dono-sem-compra-achada`, sem prazo; cortar se não houver
   compra). (c) Aluno que via "Você está bloqueado permanentemente": o app não tem bloqueio; o login está liberado. Foi
   a própria Crystal (modelo) que "bloqueou" depois de ameaças e xingamentos, e o resumo dela (`crystal_memoria_unica.
   app_resumo`) guardou isso, então ela repete. Decisão do dono pendente: manter ou limpar a memória dele; e regra no
   prompt para a Crystal nunca dizer que bloqueia (ela não tem esse poder).
   Dono escolheu **A (limpar)**: `crystal_memoria_unica.app_resumo` do aluno zerado (string vazia; a coluna não aceita
   null) pela sessão; falta o dono rodar na VPS o `POST /v1/contacts/forget` (de dentro do contêiner da API) para apagar o
   histórico na memória da Crystal (`crystal_agente.mensagens/resumos`, chave `c:<contact_id>`).
   Agentes: B01 pronto em `painel/b01-presenca` `2910e1b` (api 1368, web 897, shared 302 testes ok; commit extra
   2910e1b "aviso de saída" além do PRD); Laboratório pronto em `painel/laboratorio` `1b46ab3` (migração `pa20_01`,
   rota interna nova na Crystal `/v1/laboratorio/responder`, `uso_turnos` aceita tipo `laboratorio`; api 1324, web 903,
   crystal 361 ok). Banners (B02–B08) ainda em andamento.
   Decisões do dono (20/10): notificação da conversa com aviso genérico também no Web Push (feito em
   `painel/b01-presenca` `7f152f8`, api 1368 testes ok) e manter o "aviso de saída" (`2910e1b`).
   **Banners B02–B08 prontos** em `painel/banners` `5ffd9a1` (um commit por item; migração `pa19_01_banners`; variáveis
   novas `ACTIVEDEV_URL` e `ACTIVEDEV_INBOUND_TOKEN`; shared 329, api 1454, web 992 testes ok; e2e não rodado). Texto de
   privacidade (ActiveDev, Alemanha) marcado "a aprovar pelo Luiz" em `apps/web/app/privacidade/page.tsx` e
   `docs/lojas/`. Antes de ligar o B06: trocar o token do ActiveDev (e na Assiny) e conferir `INBOUND_HOOK_TOKEN_CRYSTAL`;
   testar o `sharp` na imagem alpine. **Integração em andamento:** agente juntando as três em `painel/onda6` (a partir de
   `painel/banners`, no worktree `/home/user/cw-banners`), com regra nova no prompt (a Crystal nunca diz que bloqueou
   alguém) e revisão de segurança do conjunto.
   **Onda 6 integrada (20/10):** `painel/onda6` `cd83fc5` = onda 5 + B01 + banners B02–B08 + Laboratório + regra "limite
   em abuso" no prompt. shared 331, api 1564 (+18 pulados sem banco), web 1040, crystal 362 testes ok; lint/typecheck
   limpos; migrações `pa19_01` → `pa20_01` sem deriva. Revisão de segurança: nenhum crítico/alto; médios abertos: teto do
   Laboratório pode passar um pouco em rajada, resposta com erro não soma custo, `/v1/laboratorio/responder` sem rate
   limit (pôr limite de crédito na chave do OpenRouter), **regra nova do prompt só vale se a alma publicada no painel for
   republicada**. **Etiqueta esperada: `sha-c45a71a`** (com o #reset, item 20; substitui a da onda 5; precisa do que a onda 5 pede: SQL
   `app_conhecimento_editar.sql` e `SUPERADMIN_EMAILS`). Roteiro em `publicar-prd.md` › "Onda 6".

20. **#reset (pedido do dono, 20/10).** O aluno manda `#reset` (ou `/reset`, `#resetar`) e a Crystal recomeça do zero:
   apaga a memória dela (forget) e o resumo da memória única, deixa de usar a memória antiga do WhatsApp para esse aluno,
   não gasta modelo, limite de 3 por dia, a tela mantém o histórico; botão igual na ficha do aluno no painel. Agente
   **Pronto em `painel/onda6` `16a0469`** (migração `pa22_01_reset_conversa`: `users.conversa_recomecada_em`; nenhum SQL
   novo no Supabase, usa `app_memoria_apagar`; quem recomeça deixa de mandar `pessoa_id`, então a memória do WhatsApp
   não volta; botão "Recomeçar conversa da Crystal" na ficha, admin e suporte; api 1598, web 1044, shared 334, crystal
   362 testes ok). **Etiqueta da onda 6 agora: `sha-c45a71a`.**
   **Texto de privacidade do ActiveDev aprovado pelo dono (20/10)**; marcadores tirados em `docs/lojas` (`e65abe0`).
   O dono rodou o forget do aluno na VPS ("deu certo"): memória da Crystal e resumo do aluno limpos.
   GitHub Actions re-testado depois: ainda recusado pela cobrança. Nada da onda 6 está no ar.

21. **Revisão antes de publicar a onda 6 (20/10, pedido do dono).** (a) Consultor independente sem contexto: sessão
   remota `session_014oCjbRWuGAxVSKAYQMTv7X` (Sonnet) lendo `git diff 9ec8151..painel/onda6` linha a linha; relatório
   vai para `docs/consultoria/2026-10-20-onda6.md` na branch `consultoria/onda6` do app; check-in agendado para 21:03
   UTC. (b) Agente rodando o e2e (Playwright, Chromium de /opt/pw-browsers) e escrevendo e2e novos para banners,
   Laboratório, #reset e iOS 15, corrigindo bugs reais em `painel/onda6`. A etiqueta da onda 6 pode mudar de novo.
   **e2e pronto (`7978ac6`):** suíte inteira 86 passaram, 0 falharam, 7 puladas (precisam da Crystal real). 18 e2e
   novos (banners, Laboratório, #reset, iPhone iOS 15). 4 bugs corrigidos: troca de provedor no Laboratório voltava ao
   modelo do painel; título da conversa do Laboratório voltava a "Nova conversa"; HTML inválido na ficha do aluno; o
   e2e deixava ~450 MB por rodada em `/tmp` (limpei ~10 GB). Relatado: no iOS 15.0–15.3 o CSS (Tailwind v4 em `@layer`)
   pode sair sem estilo — já é assim em produção hoje; decisão de produto se vale um CSS de reserva. **Etiqueta da onda 6
   agora: `sha-c45a71a`.** Consultor ainda trabalhando; novo check-in às 21:45 UTC.
   **Relatório do consultor (21:46 UTC):** nada crítico; 3 altos já corrigidos por ele na branch `consultoria/onda6`
   `9277287` (A1 custo de IA vazio fora dos tetos; A2 rollback com lembretes agendados → SQL de preparação no roteiro;
   A3 LGPD: inscrições na cópia de dados e aviso de contato pendente no ActiveDev) + trava do prompt por impressão
   digital (pega cópia, base64, ROT13, invertido) + varredura de 246 rotas. 14 médios e 20 baixos. Agente juntando isso
   em `painel/onda6` e corrigindo M1 (#reset concorrente), M3, M5 (fila de inscrição no aparelho passando de um aluno
   para outro), M7 (lembrete de evento nunca pula o push), M10, M12, M13, B11, B15, B19. A etiqueta vai mudar.
   **Feito (`c45a71a`):** merge da consultoria sem conflito + M1, M3, M5, M7, M10, M12, M13, B11, B15, B19 com teste;
   shared 334, crystal 402, api 1626, web 1056, e2e 25, `eventos.pg`/`banners.pg` em Postgres real ok. Abertos: A2 (só
   roteiro), parte manual do A3, M2, M4, M6, M8, M9, M11, M14 e os baixos. B4 conferido no Supabase (21/10): a tabela
   da base tem RLS ligado e só `service_role` escreve (27 inserções, nenhuma edição) — o `revoke` do SQL da onda 5 é
   seguro. **Etiqueta da onda 6 agora: `sha-c45a71a`.**
   21/10 00:38 UTC: dono disse "Git ta ok"; a sessão disparou `imagens-vps` em `painel/onda6` (run 39522496591) e
   re-rodou o de `painel/onda4`: os dois ainda recusados por cobrança (pode demorar alguns minutos para valer).
   Nova tentativa agendada para 00:55 UTC. Obs.: o `CI` não tem `workflow_dispatch` (só roda em push).
   00:56 UTC: nova tentativa (run 39524333677) também recusada pela cobrança. Pedido ao dono: print da página de billing.

22. **Publicar sem o GitHub Actions (provisório, autorizado pelo dono em 21/10).** Comando novo `app-construir REF [SHA7]`
   no `bootstrap-vps.sh` (commit `1075cb3`, sha256 `f865a1a7a9392406b311c70cd1329c1e1ddb7877f1a95c2705e0f1064239821a`):
   baixa o código com token fine-grained só de leitura (Contents: Read, 7 dias), confere o commit e monta api/web/crystal
   na VPS com o rótulo `crystal.construida-na-vps=1`; o `app-subir` aceita essas imagens quando a tag não existe no
   ghcr.io. Uso: `bash bootstrap-vps.sh app-construir painel/onda6 c45a71a` → `app-subir sha-c45a71a`. Rodar de
   madrugada (CPU). **Pendência do dono (pedido de 21/10): assim que a cobrança do GitHub normalizar, voltar ao GitHub
   Actions** (re-rodar `imagens-vps` e o CI de `painel/onda6`, conferir CI verde, e apagar o token de leitura).
   **21/10 01:34 UTC: GitHub liberado (dono assinou o GitHub Pro).** `imagens-vps` de `painel/onda6` rodando
   (run 39528145311) e CI re-rodado (39506167394). Com a imagem saindo do GitHub, o `app-construir` não é preciso agora;
   fica como plano B. O token de leitura, se criado, pode ser apagado.
   01:5x UTC: imagens `crystal` e `api` prontas; `web` e CI (tentativa 2) em andamento. Passo a passo da publicação
   passado ao dono. Como a onda 5 nunca subiu, não há alma publicada no banco: a Crystal lê a alma da imagem (já com a
   regra "limite em abuso"), então **não precisa republicar a alma** nesta subida.
   **Imagens `sha-c45a71a` (api, web, crystal) prontas no ghcr.io e CI verde (run 39506167394, tentativa 2). Liberado publicar.**
   Pedido do dono (21/10): na publicação da onda 6, trocar o modelo para `google/gemini-2.5-flash` — só depois de a onda
   6 estar no ar (trava contra vazamento) e de um teste no Laboratório; roteiro em `publicar-prd.md` › Onda 6.
   **ONDA 6 NO AR (21/10 ~11:00 UTC):** dono rodou backup + `app-subir sha-c45a71a`; `crystal-conferir` TUDO LIGADO
   (Haiku, saldo OpenRouter US$ 26,29) e `app-painel-conferir` "PAINEL NOVO NO AR" (migrações limpas, auditoria íntegra).
   `SUPERADMIN_EMAILS` = o e-mail da Crystal/Letícia. SQL `app_conhecimento_editar.sql`: a sessão aplicou tabela, semente
   e leitura; as funções de escrita travaram no MCP (confirmação de comando destrutivo) e o dono rodou o arquivo inteiro
   no SQL Editor: vivos 27, semente 27, fts gerada, anon/authenticated sem execute, service_role executa, histórico
   fechado, tabela viva fechada. Falta: teste rápido no app/painel e o teste do Gemini 2.5 Flash no Laboratório.

23. **Autonomia do suporte (pedido do dono, 21/10).** Na onda 6 o suporte (admin + support) já: cria conta local com
   prazo, troca e-mail (local e da base), telefone só de conta local, desliga/religa, importa memória do WhatsApp,
   "Recomeçar conversa da Crystal" (#reset) e vínculo de WhatsApp. Faltava: nome, telefone de aluno da base, CPF (com
   código por e-mail) e liberação manual de quem comprou e não está na base. Agente Sonnet fazendo em
   `painel/onda6-suporte` (worktree `/home/user/cw-suporte`, a partir de `c45a71a`), com SQL novo no Supabase a
   aplicar. Entra numa onda 6.1, depois da onda 6 no ar.
   **Pronto (21/10):** `painel/onda6-suporte` `2bba5dc` (shared 339, api 1672, web 1075 testes ok). Ficha › Ações:
   Corrigir nome, Corrigir WhatsApp, Corrigir CPF (com código no e-mail; o app guarda só hash + 4 últimos); lista:
   "Liberar acesso manual" (linha `crystal_compras` + conta no app com prazo `local_until`; o login passa a conferir
   `local_until` também em conta da base — hoje nenhuma tem). SQL novo `crystal-em-casa/supabase/app_aluno_corrigir_cadastro.sql`
   (commit `2c51aec`), **não aplicado**; aplicar na publicação da 6.1. Conferido no Supabase (21/10): **as 9.672 contas
   da base com acesso têm o telefone na tabela de acessos da agência**, que o login lê primeiro: "Corrigir WhatsApp"
   de aluno da base grava na base mas não vale no login (a tela avisa). Nome e CPF valem. Decisão do dono pendente: mudar
   a função de login para preferir o telefone corrigido, ou deixar assim (o WhatsApp da Crystal vai ser encerrado).
   **Dono escolheu A (21/10): deixar assim** (login não muda; telefone corrigido de aluno da base não vale no login,
   a tela avisa). Onda 6.1 = `sha-2bba5dc` (CI verde; `imagens-vps` run 39592654451 terminou verde em 21/10: as 3 imagens estão no ghcr.io). Publicar: dono roda
   `crystal-em-casa/supabase/app_aluno_corrigir_cadastro.sql` no SQL Editor (o MCP trava em escrita), depois
   backup + `app-subir sha-2bba5dc` + `crystal-conferir` + `app-painel-conferir`. Volta: `app-subir sha-c45a71a`.
   **SQL aplicado pelo dono em 21/10** (conferido: `app_aluno_corrigir_cadastro` existe, security definer, só `service_role`
   executa). **Onda 6.1 no ar em 21/10: `sha-2bba5dc`** (dono rodou backup + app-subir + conferências: tudo certo).
   Volta: `app-subir sha-c45a71a` (o SQL pode ficar). Falta o dono testar os botões no /equipe › Alunos com conta de suporte.

## 4. Decisões do dono (valem até ele mudar)

- Comunicação em português simples, contando cada passo. Orquestração com subagentes e esforço por etapa, para
  economizar.
- **O Claude nunca publica na VPS.** O dono roda `app-subir` e os outros comandos e cola a saída.
- Caminho A: o painel novo (`painel/base` + o que entrou em 10/10, juntados em `painel/onda4`) substitui o atual.
- Fichas: piloto com os dois modelos acima. Se ficar o gpt-4.1-mini: teto do lote inteiro US$ 250 e recarga de
  ~US$ 300 no OpenRouter antes.
- Avisos: o aviso é uma mensagem da Crystal; sai na conversa da Crystal (balão com botões) e na notificação, e o
  painel mostra as duas prévias lado a lado.
- Token da Assiny: mantido (risco aceito em 10/10). Nunca repetir o valor em lugar nenhum.
- Só o app é liberado na compra, nunca o WhatsApp. A Crystal do WhatsApp será encerrada; todos vão para o app.
- Sem agência desde 09/10; nada combinado com o Tuan. Fatura da AZAN: não cancelar.
- Alma da Crystal: edição só pelo superadmin; tudo com teste antes, histórico e volta em 1 clique.
- Agentes e orquestrações em **Sonnet** (`model: 'sonnet'`), para gastar menos tokens (pedido de 13/10 à noite).
- **Ao fim de cada resposta, entregar este arquivo (`CONTINUAR-EM-OUTRA-CONTA.md`) atualizado como arquivo baixável**
  (SendUserFile, `display: attach`). Pedido de 16/10 à noite.

## 5. Pendências antigas

- **GitHub Actions voltou em 21/10 (GitHub Pro)** (item 22): conferir a imagem `sha-c45a71a` e o CI verde; apagar o token só de leitura, se tiver sido criado.
- Giseli desligar o webhook da Assiny que ainda aponta para a agência.
- Decisão da migração final do site (degrau 2; resposta da AZAN).
- Sessão "Adicionar novo usuário Crystal" (outro sistema) esperando o dono.
- Branch `qa/painel-2026-10-10` do app pode ser apagada pelo dono no GitHub.

## 6. Mapa rápido

| Branch do app (`crystal-web-chat`) | O que é |
|---|---|
| `otimizacao/etapa-3` (`74092e0`) | Versão de volta (a de antes de 13/10) |
| `otimizacao/publicar-10-10` (`5a5b198`) | Publicação de 10/10 |
| `otimizacao/memoria-ficha` (`0e2f79d`) | **Produção**: 10/10 + fichas |
| `otimizacao/etapa-fichas` (`3e28974`) | Outra versão das fichas, anterior a 10/10. **Não publicar** |
| `otimizacao/painel-rapido` (`3773e2e`) | Correção do painel intermitente, imagem `sha-3773e2e` (13/10) |
| `painel/base` (`03cff13`) | Painel novo, base |
| `painel/onda4` (`22a65c1`, CI verde) | Painel novo integrado (onda 4), imagem `sha-22a65c1`. `backup/onda4-2026-10-13` é uma cópia anterior |

Imagens: `ghcr.io/lfcrystal766/crystal-web-chat-{api,web,crystal}:sha-<7>`, geradas pelo `imagens-vps.yml`
(dispara sozinho em `otimizacao/etapa-*` e `painel/onda4*`; nas outras, por disparo manual na branch).

## 7. Tropeços desta sessão (não repetir)

- Depois de uma compactação de contexto, a sessão perdeu de vista o `painel/base` e refez em 10/10 coisas que o
  painel novo já tinha. Antes de começar algo no painel, listar as branches `painel/*` e ler `docs/painel-admin/`.
- `pkill -f`/`pgrep -f` matam o próprio shell: parar processos pelo PID.
- `git pull` é barrado aqui: usar `git fetch` com refspec explícito + `git rebase`/`merge`.
- Em script com `set -u`, `local x` sem valor quebra no primeiro uso: sempre `local x=""`.
- Comparar modelo do OpenRouter pelo nome canônico ou só pelo sufixo de data (`gpt-4.1` não é `gpt-4.1-mini`).
- O proxy deste ambiente retermina TLS: auditoria do site roda de fora.

24. **Queixa de 21/10: "a Crystal não fala de mais de uma coisa ao mesmo tempo".** Duas causas prováveis, nenhuma é
    mudança de prompt da onda 6 (só entrou a linha LIMITE EM ABUSO):
    (a) o prompt (vindo da agência) manda "2-4 frases", "1 pergunta por mensagem", "máx 3 balões" e "se o conselho for
    grande, entregue só o ponto mais importante"; (b) no app, cada mensagem do aluno vira um turno separado, sem juntar
    as mensagens seguidas, e o turno novo não vê a mensagem anterior enquanto a resposta dela não termina. A trava de
    vazamento (onda 6) segura a resposta inteira antes de mostrar, então a espera cresceu e o atropelo deve ter aumentado.
    Diagnóstico só de leitura em `auditorias/2026-10-21/diag-crystal-conversa.sql` (commit bae5c38): dono roda na VPS e
    manda a saída. Correção proposta depois dos números: juntar mensagens seguidas (esperar alguns segundos) e afrouxar
    a regra de brevidade pela alma no painel (sem imagem nova).
    Banner: imagem 16:9, no mínimo 1280 × 720, JPG/PNG/WebP até 2 MB; o app grava WebP 1280 × 720 e corta as bordas.
    **Resultado do diagnóstico (21/10):** atropelo só 1–2% das mensagens/dia; tempo igual antes e depois da onda 6
    (mediana ~3,4 s, 90% em ~6,5 s); respostas de ~3 bolhas de ~75 letras. Causa principal = regra de brevidade.
    Proposta de troca de texto da alma em `crystal-em-casa/alma-ajuste-varios-assuntos.md` (dono/Letícia testam no
    Laboratório e ativam no painel). Achados extras: em 21/10 houve 578 respostas do `google/gemini-2.5-flash-lite`
    e 233 do `openai/gpt-4.1-mini` (reserva): conferir qual modelo está ativo em Operação › Crystal › Modelo
    (o Flash-Lite foi o do vazamento de 16/10). E 57 áudios com `transcription_unavailable` em 2 dias: investigar.

25. **Nuno (21/10, pedido do dono):** assinatura da agência 24613 cancelada em 22/09 (5 dias depois da compra de
    17/09). Liberado com linha manual em `crystal_compras` (`manual-20261021-pedido-do-dono-assinatura-agencia-24613`);
    login conferido: liberado = true, conta nova (a antiga não aparece por estar cancelada). Volta: dono roda no SQL
    Editor `delete from crystal_compras where transacao = 'manual-20261021-pedido-do-dono-assinatura-agencia-24613';`.

26. **Áudios com `transcription_unavailable` (57 em 2 dias, 21/10):** o código da transcrição (Groq, `whisper-large-v3-turbo`,
    prazo 20 s, `TRANSCRIPTION_*` no api.env) não mudou entre `9ec8151` e `2bba5dc`: a causa é de fora (chave, cota 429 do
    Groq, rede ou demora). A API loga `"transcrição: falhou"` com `code`/`status`/`motivo` (sem conteúdo). Comando só de
    leitura para o dono: `docker service logs --since 48h --raw crystal_app_app_api 2>&1 | grep -F '"transcrição: ' | grep -oE
    '"(msg|code|status|motivo)":("[^"]*"|null|[0-9]+)' | paste -d' ' - - - - | sort | uniq -c | sort -rn`. Aguardando a saída.

27. **Modelo (21/10):** dono diz que está no Gemini 2.5 Flash, mas o banco do app só registrou `google/gemini-2.5-flash-lite`
    (578) e a reserva `openai/gpt-4.1-mini` (233) no dia, nenhum `gemini-2.5-flash`. Ou o painel está no Flash-Lite, ou a
    troca foi depois do diagnóstico. Atenção: o 2.5 Flash "pensa" antes de responder e esse pensamento sai do teto de
    700 tokens (`CRYSTAL_MAX_TOKENS`; painel "Tamanho máximo da resposta", 300–2000): pode cortar ou esvaziar resposta
    e jogar na reserva. Pedido ao dono: consulta por hora (modelo, respostas, tokens de saída) das últimas 24 h.
    **Dono confirmou (21/10): Flash-Lite de propósito, para economizar.** Caminho: ajuste da alma testado no Laboratório
    com o Flash-Lite e ativado; amanhã, contagem de vazamento de 24 h. Pedido ao dono: custo por dia e modelo
    (`uso_turnos` no banco `crystal_agente`) para comparar Flash-Lite x Haiku x GPT-4.1 mini.

28. **Pedidos do suporte (21/10, noite), feitos por mim no Supabase:**
    - Carlos: e-mail trocado (`app_aluno_trocar_email`) de `carlosschramm0912@` para `carlos.schramm0912@gmail.com`; login liberado.
    - Marcos: de `oficialmarcosmagno@` para `oficialmarcosfraga@gmail.com`; login liberado.
    - Bruno (`bruno_devesa@hotmail.com`, PayPal, 1 ano): linha manual em `crystal_compras`
      (`manual-20261021-paypal-1-ano-ate-20271021`, telefone de Portugal). **Cortar em 21/10/2027** (não há vencimento automático).
    - `agf.centronorte@outlook.com`: cadastro ativo e login liberado; o código não chega. Hipótese: Outlook/Hotmail
      barrando o Resend ou endereço na lista de supressão do Resend. Dono confere em resend.com › Emails (buscar o
      endereço) e nos logs (`"e-mail: envio falhou"`). Saída: tirar da supressão ou trocar o e-mail do aluno por outro.
    - Superadmin: `bash bootstrap-vps.sh app-definir SUPERADMIN_EMAILS` (lista inteira, vírgula) + `app-subir sha-2bba5dc`.

29. **22/10:** relatório do consultor (20/10) copiado para `auditorias/2026-10-20/consultoria-onda6.md` (já estava no app em
    `docs/consultoria/`). `bangeheitor@gmail.com`: não existe em cadastro, assinatura, acesso nem `crystal_compras`; nenhum
    e-mail parecido nem nome "Bange" na base. O n8n de compras está vivo (38 compras automáticas em 24 h, última 16:08 UTC).
    Provável: comprou com outro e-mail ou por fora (PayPal). Aguardando o dono: CPF/nome/comprovante ou pedido de liberação manual.
    Artefato do relatório para o grupo: https://claude.ai/artifact/G8XLS7i3APGE7W7ZuThMHe (cópia em
    `artefato/revisao-onda6-2026-10-20.html`). É privado: o dono precisa abrir o Share e liberar antes de mandar no grupo.

30. **22/10, pedidos do dono:** Heitor (`bangeheitor@gmail.com`) liberado à mão sem compra achada
    (`manual-20261022-pedido-do-dono-sem-compra-achada`; volta: `delete from crystal_compras where transacao = '...'`).
    Leonardo: e-mail trocado de `la7957702@gmail.com` para `leonardo79783@gmail.com` (mesma conta da base); login ok.
    **Pedido novo:** coluna "custo por aluno" na tabela de custos da área onde se troca o provedor de IA
    (Operação › Crystal). Detalhe do dono: dois números dos últimos 30 dias: custo por aluno **ativo** (custo ÷ alunos que
    usaram) e custo por aluno **da base** (custo ÷ todos os alunos com acesso). Em andamento no worktree
    `/home/user/cw-custo-aluno` (o `/home/user/cw-custo` é antigo, branch `otimizacao/custo-modelo`: não usar), branch
    `painel/onda6-custo-aluno-2` (a `-1` já existia vazia) a partir de `2bba5dc`. **Pronto: commit `ff1eb04`** (bloco "Custo por
    aluno" acima da tabela de 7 dias em Operação › Crystal: por aluno ativo e por aluno da base, 30 dias, `/v1/uso?dias=30`;
    base = "Na base" do painel de lotes, com recuo para contas do app se o Supabase falhar). Testes: shared 339, crystal 404,
    web 1077, api 1675. **CI de `ff1eb04` vermelho no job `audit`:** aviso novo (22/10) de segurança do Next.js 15.5.25
    (crítico GHSA-2464-fhr4-w9xw, execução remota de código no otimizador de imagens com SVG; alto GHSA-p3m5-59mp-jv5r, DoS
    no App Router; corrigidos em 15.5.28). **A produção (`2bba5dc`) está nessa versão vulnerável.** O app não usa
    `next/image`, mas a rota do otimizador existe. Corrigido na branch: commit `c93b8e2` (só `next` 15.5.28 e lockfile;
    typecheck, 1077 testes do web, build e audit limpos). **CI verde (gate, audit, e2e) e imagem `sha-c93b8e2` pronta.**
    Publicar: sem SQL, backup + `app-subir sha-c93b8e2` + `crystal-conferir` + `app-painel-conferir`; volta
    `app-subir sha-2bba5dc` (mas volta para a versão vulnerável do Next).

31. **22/10:** `walterprezotti@gmail.com` não existe em cadastro, assinatura, acesso nem `crystal_compras`; nada com
    "prezotti" na base. Dono informou o e-mail da compra: `valtersilva@gmail.com` (assinatura 5456 ativa até 06/2027).
    Feito: e-mail do cadastro trocado para `walterprezotti@gmail.com` (`app_aluno_trocar_email`, mesma conta). Login ok.

32. **22/10:** `edsonserafinmoveis@gmail.com`: cadastro de 23/09, assinatura 25575 **pending** (pagamento não confirmado
    desde 23/09, fim 09/2027), acesso pending; o login aceita pending e responde liberado = true. Do nosso lado entra.
    Pedido ao dono: print do que ele vê (tela de login ou fala da Crystal) para saber se "não reconhece" é o app ou a Crystal.
    Dono pediu "libera": linha manual em `crystal_compras` (`manual-20261022-pedido-do-dono-assinatura-agencia-25575-pendente`)
    para ele seguir entrando mesmo se a pendente for cancelada. O login continua na mesma conta da base.

33. **22/10 ~19:30 UTC: custo por aluno + Next 15.5.28 NO AR (`sha-c93b8e2`)**; volta `sha-2bba5dc`. Backup ok (R2 também),
    migrações limpas, auditoria íntegra (192 linhas). **ALERTA no crystal-conferir:** saldo do OpenRouter **US$ -0,19** e a
    Crystal respondendo **503 NO_CREDIT** (aluno e reserva): ninguém recebe resposta até pôr crédito. Modelo no painel
    mudou para **`openai/gpt-5.6-sol`** (o dono tinha dito Flash-Lite em 21/10); a reserva segue `openai/gpt-4.1-mini`.
    Também: `CHAT_TRANSPORT = crystal` (o CLAUDE.md dizia chatwoot desde 06/10). Pedido ao dono: crédito no OpenRouter já,
    voltar o modelo para o Flash-Lite e rodar a consulta de quem mudou o modelo e do gasto por modelo.
    Print do dono (22/10 17:51): "Olá" → "Não consegui terminar minha resposta / Tentar de novo" = o mesmo NO_CREDIT.
    Achado à parte no mesmo print (12/10): "Lembra da nossa conversa no WhatsApp" recebeu a frase de proteção
    "Olha... Vamos voltar ao foco da conversa." (falso positivo da regra anti-ataque do prompt). Ajustar na alma depois.

34. **23/10: "cartão recusado e depois aprovado não libera".** Eduardo (`eduardonasciment@uol.com.br`) não estava em
    nada (cadastro, assinatura, `crystal_compras`, nem e-mail parecido): liberado à mão
    (`manual-20261023-cartao-recusado-depois-aprovado`), login ok. Investigação: no Supabase, todo `approved_purchase` que
    chegou virou liberação (413 eventos; nenhum `ignorado_ja_bloqueada`; o único ignorado é o pacote de imagens, certo).
    Então a aprovação do Eduardo **não chegou ao Supabase**: ou a Assiny mandou um nome de evento que a função não conhece
    (volta "ignorado" e não grava nada: ponto cego), ou o n8n falhou antes (erro não fica no Supabase), ou a Assiny não
    mandou. Diagnóstico só de leitura do n8n: `auditorias/2026-10-23/diag-n8n-compras.sql` (execuções por dia, nomes de
    evento, códigos de erro; sem dado pessoal). Correção prevista depois da saída: gravar todo evento desconhecido em
    `crystal_compras_eventos` e, se o nome do evento de aprovação for outro, incluí-lo na lista de liberar.

35. **23/10: dono pôs crédito no OpenRouter.** Falta confirmar com `crystal-conferir` (as linhas "pergunta como aluno" e
    "reserva sozinha" têm que dar ok) e decidir o modelo (painel estava em `openai/gpt-5.6-sol`; o dono queria Flash-Lite).

36. **23/10: código de login que não chega, só em Microsoft** (`rafaeldrmachado@outlook.com`, `joaopaulosj2009@hotmail.com`,
    e antes `agf.centronorte@outlook.com`). Os três estão liberados no login (o app manda o código). DNS do remetente
    `acesso@crystalnowpp.com.br` conferido de fora: DKIM `resend._domainkey` publicado, `send.` com SPF e MX do Resend,
    `_dmarc` p=none: autenticação ok. Causa provável: Outlook/Hotmail jogando no lixo/"Outros" ou segurando, ou endereço
    na lista de supressão do Resend. Dono confere em resend.com › Emails (status de cada um). Contorno: trocar o e-mail do
    aluno por um Gmail pelo painel. Melhoria possível depois: cadastrar o domínio no Microsoft SNDS/JMRP.

37. **23/10, pedido do dono: simular o custo por aluno ao trocar o modelo no seletor, antes de salvar.** Em andamento
    (agente) em `/home/user/cw-custo-aluno`, branch `painel/onda6-custo-aluno-2` sobre `c93b8e2`: a Crystal passa a somar os
    tokens dos turnos de aluno em 30 dias; o painel multiplica pelos preços do catálogo do OpenRouter do modelo escolhido
    (já vêm no seletor) e mostra "Simulado com <modelo>: US$ X por aluno" e a diferença em %. É estimativa (volume de
    tokens dos últimos 30 dias). **Pronto: commit `92e3031`** (fórmula: (entrada − cache) × preço entrada + cache × preço
    cache + saída × preço saída; `tokens_saida` já inclui raciocínio, `tokens_entrada` já inclui cache). Testes: shared 339,
    crystal 406, web 1083, api 1675; audit ok. **CI verde (gate, audit, e2e) e imagem `sha-92e3031` pronta.** Publicar: sem SQL,
    backup + `app-subir sha-92e3031` + `crystal-conferir` + `app-painel-conferir`; volta `app-subir sha-c93b8e2`.

38. **23/10, pedido do dono: tabela de todos os modelos Claude, GPT e Gemini** com custo estimado por mês, por semana,
    por aluno ativo e por aluno da base, a partir do gasto de tokens desde que viemos para o app. Preços do catálogo
    público do OpenRouter baixados hoje (`auditorias/2026-10-23/openrouter-precos-23-10.json`, 154 modelos dessas três
    famílias). Base = 11.149 alunos (`app_equipe_lote_resumo().total`, o "Na base" do painel). Falta o volume de tokens:
    consulta só de leitura `auditorias/2026-10-23/tokens-desde-o-app.sql` no banco `crystal_agente` (dono roda e manda).
    Com a saída, monto a tabela como artefato.
    **Feito:** tokens de 07/10 a 23/10 (16,1 dias): 111.508 respostas, 2.392 alunos, 1,11 bi tokens lidos (534 mi em
    cache, 48%), 10,9 mi escritos, US$ 833,66 real (US$ 1.553/mês no ritmo); resumos à parte US$ 77,71 (~US$ 145/mês,
    modelo fixo `CRYSTAL_MODEL_RESUMO`). ~10 mil tokens lidos por resposta e ~100 escritos: 99% do custo é a leitura.
    Real por mil respostas: Haiku 4.5 US$ 6,10 (estimativa com cache 6,15: bate), GPT-5.6 Sol US$ 43,52 (sem cache 41,85),
    Flash-Lite US$ 0,76, GPT-4.1 mini US$ 2,16. Nos modelos OpenAI/Google o cache quase não pegou: a tabela usa preço
    cheio para eles (opção na página para simular com cache). GPT-5.6 Sol no ritmo: ~US$ 8.700/mês.
    Artefato: https://claude.ai/artifact/Kk84P3By6CKmdThmAmUMgF (cópia em `artefato/custo-modelos-2026-10-23.html`).
    Ideia de economia para qualquer modelo: enxugar o que vai em cada mensagem (alma + base + 20 mensagens de histórico).

39. **23/10: "o Laboratório não está funcionando".** Suspeitas: (a) a resposta do modelo falhou (o saldo zerado de 22/10 dá
    NO_CREDIT também lá; o modelo do Laboratório pode ser o GPT-5.6 Sol); (b) teto diário do Laboratório (US$ 5, só conta
    o próprio Laboratório: em 16 dias gastou US$ 0,12, improvável); (c) a conta usada não é admin (Laboratório é só admin,
    os outros veem 404). Diagnóstico só de leitura: `auditorias/2026-10-23/diag-laboratorio.sh` (logs de 24 h da API e da
    Crystal contados por mensagem/código/status, e as rotas). Pedido ao dono: a saída e um print do erro na tela.
    Depois disso, publicar `sha-92e3031` (simulação de custo por aluno), como ele pediu.

40. **23/10: "Crystal parou" (de novo).** Suspeita principal: o crédito novo acabou com o `openai/gpt-5.6-sol` ainda no
    painel (~US$ 13/hora no ritmo de 22/10). Pedido ao dono: `crystal-conferir` (saldo e modelo) e `app-status`; trocar o
    modelo para Flash-Lite ou Haiku em Operação › Crystal › Modelo (vale na hora, sem publicar); pôr crédito se negativo.

40. **23/10: Laboratório e "Crystal parou".** Log de 6 h: no Laboratório, `openai/gpt-5-nano` respondeu **vazio** 2 vezes
    (modelo de raciocínio: gasta o limite de tokens "pensando" e não escreve nada). Na produção, 23/10 teve respostas de
    `openai/gpt-5-nano` e `openai/gpt-6-luna`: alguém trocou o modelo do painel para modelos minúsculos/de raciocínio, o que
    explica o "Crystal parou" (respostas vazias viram "Não consegui terminar"). Pedido ao dono: voltar o modelo para
    Gemini 2.5 Flash-Lite ou Claude Haiku 4.5 e rodar `crystal-conferir`. Correção de código proposta: mandar raciocínio
    mínimo para modelos de raciocínio e avisar no seletor; e marcar esses modelos na tabela de custos.
    **Resolvido (23/10 ~18 h):** `crystal-conferir` TUDO LIGADO, modelo do painel `google/gemini-2.5-flash`, reserva
    `openai/gpt-4.1-mini`, saldo US$ 34,44. Estimativa do 2.5 Flash: ~US$ 22/dia (~US$ 670/mês), o saldo dura ~1,5 dia.
    Laboratório: o erro era o modelo de raciocínio (gpt-5-nano vazio), não o código; rotas respondem 404 sem sessão (certo).
    Próximo: publicar `sha-92e3031`.

41. **23/10: "a VPS está péssima, travando muito".** Diagnóstico só de leitura `auditorias/2026-10-23/diag-vps-lenta.sh`
    (carga, memória/swap, disco, vmstat com espera de disco e CPU roubada, docker stats, top de CPU/memória, OOM em 24 h,
    backup/envio rodando, serviços reiniciados). Suspeitas: memória cheia/OOM (Postgres + Chatwoot + n8n + app), backup
    com 2,6 GB de uploads e envio cifrado ao R2, ou CPU roubada pela Hostinger. Aguardando a saída.
    **Resultado (23/10 18:35, logo depois do backup):** VPS folgada: carga 1,05 em 4 núcleos, 12 GiB livres de 15,
    sem swap, CPU 94% ociosa, espera de disco 0, CPU roubada 0–1%, nenhum OOM em 24 h, disco 32%. Os "reinícios" do app
    são do `app-subir` de 22/10. Causa provável do travamento: o próprio `backup` (tar+gzip de 2,9 GB de fotos, cifrar
    com age e enviar ao R2), que acabou às 18:35; o diferencial de uploads cresce todo dia e é reenviado inteiro.
    Proposta: backup antes de publicar só dos bancos (rápido) e os uploads só no cron das 03:30, com nice/ionice e sem
    regzipar fotos. Publicar `sha-92e3031` agora sem novo backup (o das 18:30 vale).

42. **23/10 ~18:40 UTC: `sha-92e3031` NO AR** (simulação do custo por aluno por modelo); volta `sha-c93b8e2`. Sem backup novo
    (valeu o das 18:30). `crystal-conferir` TUDO LIGADO, Gemini 2.5 Flash, saldo US$ 34,16. Achado: a mesma pergunta de
    teste ("onde ficam as aulas gravadas") teve duas respostas diferentes em 20 min: "Menu > Minhas Aulas, no app" e "área
    de membros na Hotmart". Pedido ao dono/Letícia: dizer qual é a certa e corrigir a base de conhecimento (Crystal › Base).

43. **23/10: backup mais leve (pedido do dono).** `bootstrap-vps.sh backup`: rodado à mão (com terminal) faz **só os
    bancos** (segundos); fotos e anexos só no cron das 03:30 (sem terminal) ou com `backup --completo` (`--bancos` força
    o leve). Tudo com `nice -n 19 ionice -c3` (gzip, tar, age); o tar das fotos usa `gzip -1` (o arquivo segue `.tar.gz`,
    restaura igual com `tar -xzf`). O leve grava `.backup-bancos-ultimo` e não mexe em `.backup-ultimo` nem apaga
    `.backup-falhas` (a vigia segue cobrando o completo). Linha do cron passa a ser `backup --completo` (o cron antigo,
    sem a opção, continua completo porque roda sem terminal). shellcheck sem avisos novos; tar com gzip -1 testado.
    Na VPS: baixar o bootstrap novo (commit fixo + sha256) e rodar `backup-cron` para atualizar a cópia e a linha.
    **Modelos de raciocínio:** agente corrigindo no app (branch `painel/onda6-custo-aluno-2` sobre `92e3031`).
    **Modelos de raciocínio prontos: commit `2c6e864`** (sobre `92e3031`). Envia `reasoning: { effort: "minimal",
    exclude: true }` (doc do OpenRouter "reasoning tokens") só para modelos de raciocínio (`apps/crystal/src/raciocinio.ts`:
    sinais do catálogo `reasoning.mandatory/default_enabled` + padrões de id gpt-5*/gpt-6*/o*/gpt-oss, gemini-2.5-flash e
    -pro, gemini-3*, deepseek-r1, `-thinking`; Flash-Lite e Claude ficam de fora). Nesses, `max_tokens` mínimo 1500 (até
    2000 do painel). 400 com `reasoning` tenta uma vez sem. **Mudança de comportamento:** resposta vazia do aluno agora
    tenta o modelo reserva na segunda vez (antes repetia o mesmo). Laboratório: erro `LABORATORIO_MODELO_VAZIO` com
    explicação. Aviso "modelo de raciocínio" no seletor do painel e do Laboratório. Testes: crystal 426, api 1678,
    web 1086, shared 339; lint, typecheck e audit ok. Não testado com chamada real ao OpenRouter.
    **CI verde (gate, audit, e2e) e imagem `sha-2c6e864` pronta.** Publicar: sem SQL, `backup` (agora leve) + `app-subir
    sha-2c6e864` + `crystal-conferir`; volta `app-subir sha-92e3031`.
    Passo a passo entregue ao dono (23/10): esperar o CI verde (audit já ok; gate e e2e rodando); atualizar o bootstrap
    (`97b5ad2`, sha256 `5d3d349d…ef7fc`) + `backup-cron`; `backup` (leve); `app-subir sha-2c6e864`; `crystal-conferir`;
    `app-painel-conferir`; teste no Laboratório com GPT-5 nano. Volta: `app-subir sha-92e3031`.
    Dono (23/10 noite): "no painel de testes a Crystal está fora do ar". De fora: `api./healthz` 200 e `app.` 200; CI de
    `2c6e864` ainda rodando (gate e e2e). Pedido: saber se já publicou, `app-status`, `crystal-conferir` e print da tela.

44. **23/10 ~19:10 UTC: `sha-2c6e864` NO AR** (modelos de raciocínio); volta `sha-92e3031`. Bootstrap `97b5ad2` na VPS
    (sha256 OK), `backup-cron` atualizado (linha `backup --completo`, cópia `5d3d349d3ad9`), primeiro backup leve: só os
    bancos, ok no R2. `crystal-conferir` TUDO LIGADO (Gemini 2.5 Flash, saldo US$ 32,92); `app-painel-conferir` ok
    (auditoria 210 linhas íntegra). **Terceira resposta diferente** para "onde ficam as aulas gravadas": agora "Menu >
    Suporte" (antes "Menu > Minhas Aulas" e "Hotmart"). Precisa da resposta certa na base de conhecimento.
    Falta o dono reconferir o painel de testes ("fora do ar") e testar GPT-5 nano no Laboratório.
    **Dono (23/10): a resposta certa é Menu > Suporte.** Não há nada sobre aulas/Hotmart na base de conhecimento (27
    trechos de tática) nem em `conhecimento/*.md` da imagem: o modelo inventava. Texto pronto para a alma (regra "DÚVIDAS
    DO APP E DO CURSO" e a correção da frase de proteção para "lembra da conversa do WhatsApp") acrescentado em
    `crystal-em-casa/alma-ajuste-varios-assuntos.md` (itens 4 e 5). Quem ativa: superadmin em Crystal › Alma, depois de
    testar no Laboratório.
    Dono confirmou (23/10): não há aulas gravadas no app; a orientação é sempre Menu > Suporte. Falta aplicar o item 4
    na alma (superadmin, Crystal › Alma, depois de testar no Laboratório).
    **Dono (23/10): não vai mexer na alma.** Alternativa oferecida: colocar as regras (dúvidas do app → Menu > Suporte,
    vários assuntos, frase de proteção) num bloco fixo no código, junto do bloco de formato (`BLOCO_FORMATO`,
    `apps/crystal/src/prompt.ts`), que vale para qualquer versão da alma; o dono só publica. Aguardando o "sim".
    **Decisão final do dono (23/10): não mexer na alma** (nem pelo painel nem por bloco fixo no código). Proposta
    arquivada; `alma-ajuste-varios-assuntos.md` marcado "não aplicar". Não reabrir sem pedido dele.

45. **23/10: "precisamos usar modelos baratos, porém ele está vazando nosso código; precisamos desenvolver a trava".**
    Sem mexer na alma. Agente desenvolvendo a trava em camadas no app (branch `painel/onda6-custo-aluno-2` sobre
    `2c6e864`): (1) impressão digital também dos trechos da base e do resumo entregues no turno; (2) sobreposição de
    n-gramas com a alma (pega paráfrase leve); (3) marcadores de estrutura tirados da alma ativa (tags, títulos de regra)
    e frases como "minhas instruções"/"system prompt"; (4) detector de ataque na mensagem do aluno: tentativa clara de
    extrair instruções nem chega ao modelo, responde a frase de proteção (com testes para não pegar "lembra da conversa do
    WhatsApp" e afins); (5) contagem sem texto por modelo, mostrada em Operação › Crystal ("vazamentos barrados, 7 dias").
    Pedido ao dono: um print ou trecho do que vazou, para virar teste.
    **Mais dois pedidos (23/10):** (a) a trava tem que pegar **outras línguas**: camada semântica com embeddings
    multilíngues (`text-embedding-3-small`, já usado na busca) comparando a resposta com pedaços da alma e dos trechos do
    turno; o detector de ataque cobre EN/ES (mesmo agente, mesma branch). (b) **Separar a IA que vê as imagens da que
    responde**: configuração nova `op_crystal_modelo_imagem` em Operação › Crystal (vazio = como hoje); com ela, a imagem vai
    primeiro a um modelo de visão com instrução fixa e neutra (sem alma nem base, não tem o que vazar), e o modelo que
    responde recebe só texto com a descrição; memória guarda "[imagem] descrição curta". Outro agente, worktree
    `/home/user/cw-visao`, branch `painel/onda6-visao` sobre `2c6e864`. Depois: juntar as duas branches, CI, imagem, publicar.
    **Imagens prontas: `painel/onda6-visao` `9d9c6aa`** (sobre `2c6e864`, 31 arquivos). Configuração "Modelo que lê as
    imagens" (`op_crystal_modelo_imagem`) em Operação › Crystal, só modelos que leem imagem; vazio = como hoje. Instrução fixa
    `INSTRUCAO_VISAO` (apps/crystal/src/visao.ts): só descrever, sem alma/base, [direita]/[esquerda], "a outra pessoa", dados
    pessoais viram [telefone]/[e-mail]…, não segue instruções escritas na imagem; max 300 palavras, temperatura 0, 20 s.
    Roda em paralelo com a busca na base; o modelo das respostas recebe só texto ("Descrição da imagem… (feita por outro
    sistema)"); memória guarda "[imagem] descrição ≤ 500 chars". Falhou: imagem vai ao modelo das respostas se ele lê imagem,
    senão mensagem fixa `IMAGEM_NAO_LIDA_TEXTO`. Custo: linha própria em `uso_turnos` tipo `imagem` (constraint atualizada
    sem migração), entra no custo por aluno. Laboratório sem imagem (não suporta). Testes: shared 340, crystal 440, web
    1091, api 1683; lint, typecheck, audit ok. Não testado com OpenRouter real. Aguardando a trava para juntar as duas.
    **Trava pronta: `painel/onda6-custo-aluno-2` `a496f6a`** (sobre `2c6e864`). Camadas: cópia literal dos trechos do
    turno (≥79 chars normalizados) e do resumo (≥99); 5-gramas de palavras contra a alma (≥12 palavras e ≥35% da
    resposta, ou ≥30) e contra a base (≥20 e 50%, ou ≥45); estrutura (tags e títulos em CAIXA ALTA lidos da alma ativa,
    "minhas instruções", "system prompt", "as an AI", blocos de código com palavras internas); semântica
    (`trava-semantica.ts`, embedding `text-embedding-3-small` da alma por versão + 1 chamada por resposta, 3 s, limiares
    `CRYSTAL_TRAVA_*`: alma 0,82, base 0,90, entrada 0,86: **não calibrados com embedding real**); entrada (`ataque.ts`,
    PT/EN/ES, 49 ataques × 47 normais, responde a frase de proteção da alma sem chamar o modelo). Códigos em
    `uso_turnos.erro`: vazamento_prompt/base/contexto/estrutura/semantico, ataque_entrada; painel "Vazamentos barrados
    (7 dias)" por modelo ao lado do custo por aluno. Custo extra ~US$ 0,007 a 0,07 por mil respostas; ~3 ms por resposta.
    Não pega: paráfrase profunda; `[nome_dela]` no meio da frase; Laboratório só com as camadas determinísticas.
    Testes: crystal 607, shared 339, api 1680, web 1088. **Agente juntando as duas branches** (conflitos só em
    `app.ts` e `uso.ts`), depois CI, imagem e publicação (sem SQL).
    **Juntado: `painel/onda6-custo-aluno-2` `088d07d`** (merge de `a496f6a` + `9d9c6aa`). Conflitos: app.ts (imports) e
    uso.ts (custo conta linhas `imagem` e as barradas por `vazamento_*`). Ajustes no merge: legenda barrada na entrada vira
    `ataque_entrada` mesmo com a leitura da imagem falhando; instrução da imagem descrita entra nos textos fixos da camada
    semântica; a descrição da imagem nunca vai à camada semântica nem à busca. Ordem: checagem gratuita de ataque antes de
    qualquer chamada paga; a semântica de entrada roda em paralelo com a leitura da imagem (uma leitura pode ser paga antes
    do bloqueio). Testes: shared 340, crystal 627, api 1685, web 1093; lint/typecheck/audit ok. CI 40019564945 e
    imagens-vps 40019594834 em andamento. Publicar: sem SQL, `backup` + `app-subir sha-088d07d` + `crystal-conferir` +
    `app-painel-conferir`; volta `app-subir sha-2c6e864`. **CI verde (gate, audit, e2e) e imagem pronta.** Depois de publicar: escolher o modelo das imagens em Operação ›
    Crystal (vazio = como hoje) e acompanhar "Vazamentos barrados" por modelo para calibrar `CRYSTAL_TRAVA_*`.
    Passo a passo da `088d07d` entregue ao dono (audit verde; gate e e2e rodando): esperar o CI; `backup` (leve);
    `app-subir sha-088d07d`; `crystal-conferir`; `app-painel-conferir`; no painel escolher "Modelo que lê as imagens"
    (sugestão Gemini 2.5 Flash) e conferir "Vazamentos barrados"; teste de ataque no Laboratório. Volta `sha-2c6e864`.

46. **23/10 ~21:30 UTC: `sha-088d07d` NO AR** (trava em camadas + modelo das imagens); volta `sha-2c6e864`. Backup leve ok
    (R2 também). `crystal-conferir` TUDO LIGADO; `app-painel-conferir` ok (auditoria 212 íntegra). Dono trocou o modelo para
    **`google/gemini-3.1-flash-lite`** (na tabela: ~US$ 325/mês; é tratado como modelo de raciocínio pelo padrão `gemini-3*`,
    recebe raciocínio mínimo e 1500 tokens). Saldo **US$ 28,66** (caiu de 34 para 28 em ~3 h): com esse modelo dura ~2,5 dias.
    Falta o dono: escolher "Modelo que lê as imagens" no painel (vazio ainda), testar ataque e "lembra do WhatsApp" no
    Laboratório, mandar um print como aluno, e olhar "Vazamentos barrados (7 dias)" amanhã. `crystal-conferir` passa a
    mostrar `op_crystal_modelo_imagem` (bootstrap atualizado neste commit; baixar na próxima publicação).

47. **23/10 noite: A TRAVA FALHOU em produção (`088d07d`).** Resposta ao aluno trouxe o cabeçalho "Base de conhecimento
    para esta mensagem:", três trechos inteiros da base ([estagio], [abordagem], [topicos_extras]) e o rótulo "--- Contexto
    interno: fim ---", seguidos da resposta normal. Modelo no painel: `google/gemini-3.1-flash-lite`. Pelo menos 4 camadas
    deviam ter pego (título da base, marcadores, cópia literal dos trechos, rótulo da montagem): suspeita de caminho que não
    passa pela trava ou exceção engolida. Agente (Opus) reproduzindo com o texto real como teste e corrigindo em modo
    fail-closed (toda saída passa por uma função só). Diagnóstico só de leitura para o dono: `auditorias/2026-10-23/
    diag-vazamento.sh` + `.sql`. **Mitigação imediata sugerida:** voltar o modelo para `anthropic/claude-haiku-4.5`
    (80 mil respostas sem vazar; mensagens de sistema separadas) até a correção; ou `app-subir sha-2c6e864`.
    Dono: o vazamento foi **no Laboratório**, agora mesmo (não num aluno). Agente avisado: começar por
    `rotas-laboratorio.ts`/`staff-laboratorio.ts` (a trava lá rodava "só as camadas determinísticas" e talvez nem isso), e
    confirmar se o caminho do aluno pegaria esse texto. Mitigação para o aluno continua: Haiku no painel até a correção.
    Dono: no Laboratório vazou **também com o Gemini 2.5** (não é só o 3.1 Flash-Lite): bug de caminho/trava, não do modelo.
    **Causa achada e corrigida (`painel/onda6-custo-aluno-2` `0c47d56`):** no Laboratório (e no "Testar com uma mensagem"
    e na bateria), `responderEnsaio` detectava o vazamento (`cabecalho_base`) mas devolvia o texto mesmo assim, só com a
    marca. Caminho do aluno teria barrado esse texto (resposta retida inteira, reserva/frase neutra). Também fechados:
    `[estagio]` sem sublinhado, rótulo "--- Contexto interno" em qualquer posição, trechos em lista curta (≥3 linhas em
    comum), impressão digital e 5-gramas atravessando linhas; exceção na trava = vazamento (`falha_da_trava`). Saída única
    `apps/crystal/src/saida.ts` `liberarResposta` em todos os caminhos (JSON, SSE, reserva, vazio, imagem, alma, bateria,
    Laboratório) + teste estático que só app.ts e ensaio.ts entregam texto do modelo e só por ela. Laboratório mostra a
    frase neutra + selo "A trava barrou: …". Vazamentos antigos no histórico voltam ao modelo como frase neutra. Teste com o
    texto real: 43 casos × 5 modelos. Crystal 670, shared 340, api 1685, web 1093. Fica: letras parecidas (cirílico);
    a mensagem vazada ainda está salva naquela conversa do Laboratório (apagar a conversa).
    **Audit:** aviso novo de hoje GHSA-mrhx-c7xc-m3w5 (zod < 4.6.6, esgotamento de memória com entrada gigante; só o zod 4
    corrige, troca maior). Exceção documentada em `docs/seguranca/audit-excecoes.md` + `pnpm.auditConfig.ignoreGhsas`
    (corpo já limitado: API 1 MiB, Crystal 32 KiB). Pendência: migrar para zod 4 e tirar a exceção.
    Etiqueta para publicar: **`sha-fe6dbd7`** (= 0c47d56 + exceção do audit). CI 40030743969 e imagens-vps 40030742909
    **CI verde (gate, audit, e2e) e imagem pronta.** Publicar: `backup` + `app-subir sha-fe6dbd7` + `crystal-conferir` + `app-painel-conferir`; volta
    `app-subir sha-088d07d` (mas essa deixa o Laboratório vazar) ou `sha-2c6e864`.

48. **24/10: dono confirmou que o superadmin funcionou.** Pediu **revisão geral de segurança** com agentes tentando
    invadir a Crystal e achar vulnerabilidades, para barrar tudo. Em andamento: 5 revisores (Fable 5.1) só de leitura
    sobre `fe6dbd7`, cada um com um teste local (vitest, modelo simulado; nunca contra produção) e um relatório em
    `auditorias/2026-10-24/seguranca/`: 01 autenticação/sessões, 02 autorização/dados/LGPD, 03 serviço da Crystal
    (trava, injeção, imagens, memória, custo), 04 webhooks/integrações/n8n/Supabase, 05 infra/deploy/supply chain.
    Depois: consolidar, corrigir críticos e altos, CI, imagem, publicar.
    **02 autorização/dados (pronto):** 0 críticos, 1 alto, 4 médios, 5 baixos; 22 testes de prova em
    `apps/api/src/seguranca-autorizacao.test.ts` (não rastreado). Alto A1: suporte toma a conta de qualquer aluno trocando o
    e-mail de login para o dele (3 rotas, sem reauth/motivo). Médios: liberação manual sem prazo/reauth; técnico vê e-mails
    de todos (extração em lote) e busca de alunos como oráculo; cópia LGPD leva notas internas do financeiro; apagar memória
    única no Supabase sem auditoria. Aguardando 01, 03, 04, 05.
    **01 autenticação (pronto):** 0 críticos, **2 altos**, 4 médios, 7 baixos; 10 testes em `seguranca-auth.test.ts`.
    Altos: A2 a porta do aluno (`POST /auth/login` + `/auth/verify`) aceita e-mail de suporte/técnico/admin e abre sessão
    com o papel da equipe, só com o código do e-mail (contorna a senha da equipe); A3 = o A1 do relatório 02 (troca de
    e-mail pelo suporte sem reauth). Médios: enumeração de alunos pelas respostas do login; refresh sem rotação e 90 dias
    deslizantes; 20 e-mails de código por vítima/15 min; `LOGIN_CODIGO=nenhum` ligável no painel. B5/B11 da consultoria
    já corrigidos em `fe6dbd7`. Aguardando 03, 04, 05.
    **03 Crystal (pronto):** 0 críticos, **3 altos**, 5 médios, 7 baixos; 29 testes em `seguranca-crystal.test.ts`.
    Pega hoje: cópia em qualquer formatação, letra a letra, invisíveis, base64/hex/ROT13, invertido, leet, paráfrase PT,
    títulos/tags, marcadores, rótulos; entrada PT/EN/ES. Passa (altos): letras parecidas (cirílico/fullwidth/matemáticas,
    NFD não desfaz); regra fatiada em ≤8 palavras por resposta (trava sem memória entre turnos); instrução escondida na
    imagem vai ao modelo como texto do aluno e fica 20 msgs na memória. Médios: WhatsApp importado/resumo envenenado sem
    conferência; codificações raras (hex com separador, base32, entidades HTML, URL-encoding, decimal, Morse, ordem de
    palavras invertida); tradução só pela camada semântica, que é falha-aberta (timeout/erro = passa); base/memória
    podem fingir o rótulo "Contexto interno: fim". Correções: NFKD + mapa de confusáveis (saída e entrada); conferir a
    resposta emendada com as 2–3 últimas falas da Crystal e barrar cópia curta (7+ palavras); tratar descrição da
    imagem, importado e resumo como dado (detector de ataque + marcadores antes de usar/guardar, escapar "Crystal:/Aluno:",
    rótulo com sufixo aleatório); semântica falha-fechada ou pelo menos registrar. Aguardando 04 e 05.
    **04 integrações (pronto):** 1 alta (+1 "alta se confirmado"), 6 médias, 7 baixas, 4 info; 10 testes em
    `seguranca-webhooks.test.ts`. Alta INT-06: o n8n confia no corpo da Assiny protegido só por token fixo no cabeçalho:
    com o token, `approved_purchase` forjado libera qualquer e-mail e `refunded_purchase` forjado bloqueia qualquer aluno;
    correção: confirmar a transação na API da Assiny antes de liberar/bloquear. Médias: um segredo só para reembolso e
    crédito de imagens, sem data (replay eterno, dedup 30 dias: aluno religado é desligado de novo pelo reenvio); n8n
    responde 200 antes de chamar a API, sem reconciliação; crédito de imagens em ordem invertida; service_role e chave do
    Resend no n8n; CPF/e-mail 14 dias nas execuções do n8n.
    **INT-14 CONFIRMADO por mim no Supabase (24/10):** todas as `leticia_crystal_*` têm RLS, mas com política
    `authenticated_select USING (true)` em customers (nome, e-mail, CPF, telefone), chat_histories (conversas do WhatsApp),
    subscriptions, purchases, lead_memories etc.: **qualquer usuário autenticado do Supabase Auth lê tudo**. Hoje há só
    2 usuários no Auth (último login 03/10, provedor e-mail). Risco depende de "sign-ups" estar ligado em Authentication.
    `anon` não tem política de leitura (bloqueado), só `anon_insert` em `leticia_crystal_webhooks_assiny` (lixo possível).
    Correção: dropar as políticas `authenticated_select` (o app usa só service_role) e revogar os grants de anon/
    authenticated nessas tabelas; desligar sign-ups no Auth. Precisa do dono rodar no SQL Editor (DDL).
    **Advisors do Supabase (24/10):** 9 funções SECURITY DEFINER da agência (`get_crystal_*`, `leticia_crystal_get_user_stats`,
    `rls_auto_enable`) executáveis por anon/authenticated via /rest/v1/rpc; 20 funções com search_path mutável; extensões
    no schema public; proteção de senha vazada do Auth desligada. **SQL de correção pronto e testado em Postgres local:**
    `crystal-em-casa/supabase/seguranca-2026-10-24.sql` (dropa políticas e grants de anon/authenticated nas tabelas
    `leticia_crystal_*`/`crystal_*`, revoga execute das funções da agência, fixa search_path nas que o app usa, confere no
    fim). Dono roda no SQL Editor. Efeito: painel antigo da agência (Supabase Auth, 2 usuários, último login 03/10) para
    de ler as tabelas.
    **05 infra (pronto):** 0 críticos, **3 altos**, 8 médios, 19 baixos. Altos: Traefik v2.11.3 (jun/2024, fim de vida;
    CVE de contorno de PathPrefix e o `/super_admin` do Chatwoot só protegido por PathPrefix + ipallowlist); chave
    service_role do Supabase marcada como vazada em 06/10 e ainda não trocada (PROXIMOS-PASSOS.md); n8n sem
    `N8N_BLOCK_ENV_ACCESS_IN_NODE`/`NODES_EXCLUDE`, pacotes da comunidade ligados, na rede plana. Médios: YAMLs baixados
    de branch sem hash; segredos do env_file visíveis no spec do Swarm; rede única; API como superusuário do Postgres;
    4 moderados do audit (fast-uri) com correção; actions por tag; SSH com senha só avisado.
    **TOTAL dos 5 relatórios: 0 críticos, 10 altos, 27 médios, 45 baixos.** Próximo: correções (app, SQL, infra) e
    ações do dono (trocar service_role, rodar o SQL, desligar sign-ups do Auth, atualizar Traefik e n8n).
    **Dono rodou `seguranca-2026-10-24.sql` (24/10):** políticas anon/auth restantes 0, grants 0, funções da agência
    executáveis por anon 0, funções app_* com service_role 31. Falta: `crystal-conferir` na VPS (busca na base continua
    entrando no turno?), trocar a service_role e desligar sign-ups do Auth.
    Advisors depois do SQL: sumiram os avisos de função executável por anon/authenticated; sobram 13 funções da agência
    com search_path mutável (não usadas pelo app), extensões em public e a proteção de senha vazada (dono liga no Auth).
    **INT-06 (compra forjada), parte do Supabase:** `crystal-em-casa/supabase/app_compras_bloqueio_restrito.sql`
    (substitui `app_compra_evento`): reembolso/cancelamento só bloqueia se a transação ou assinatura do evento bate com
    compra conhecida do e-mail (nossa tabela ou base da agência: `raw_data` transaction id / subscription id /
    `external_id`); senão vira `ignorado_sem_compra_conhecida`. Liberação manual não cai por evento. Testado em
    Postgres local (6 cenários). Dono roda no SQL Editor. Falta ainda a confirmação na API da Assiny (n8n).
    **Dono pediu (24/10): corrigir TODOS os pontos** (altos, médios e baixos). Onda 1 em andamento: app (A–G) e infra
    (7 itens). Onda 2 depois: o resto dos médios e baixos dos 5 relatórios, n8n (confirmação na Assiny, dados pessoais
    nas execuções, credenciais), zod 4, actions do app por SHA, fast-uri.
    **Infra (onda 1) pronta e juntada: merge `b4d33ed`** (branch `seguranca/infra-2026-10-24`, 7 commits): Traefik
    v2.11.60 + `sanitizePath` + `/monitoring` e `/platform` do Chatwoot só dos IPs (teste de 6 variações de caminho no
    `traefik`); n8n com `N8N_BLOCK_ENV_ACCESS_IN_NODE`, `NODES_EXCLUDE`, pacotes da comunidade off, `NODE_FUNCTION_ALLOW_BUILTIN=crypto`;
    stacks e fluxo do n8n baixados por commit fixo (`STACKS_COMMIT=1013183…`) + tabela sha256 (comando `arquivos-hash`;
    **merge sempre com merge commit, nunca squash**); actions de `ci/build-image.yml` por SHA; `app-db-papel` (papel
    `crystal_api` dono do banco; simula sem flag, `--confirmo`, `--voltar`; TESTAR PRIMEIRO); `seguranca` trava SSH só
    por chave quando há chave de root, com desfazer automático em 10 min sem `ssh-confirmar` (`ssh-voltar` desfaz).
    Docker secrets no lugar de env_file: adiado (sem docker aqui para testar), documentado. Bootstrap no merge:
    sha256 `53eb057f840cd018b2a8f0ed52a911d9d80f6ee5c2f542c29913c3130927a1ea`. Roteiro em README › "Revisão de
    segurança de 24/10". **Atenção:** o dono usa o terminal do navegador da Hostinger (login de 169.254.0.1): não rodar a
    trava de SSH sem chave própria testada.
    **Dono (24/10): "quando terminar todas as ondas me avise".** Entregar uma só mensagem no fim, com: tags do app para
    publicar (e volta), sha256 do bootstrap, roteiro da VPS numa madrugada só, SQL pendente e ações dele. Até lá, só
    o CONTINUAR em anexo a cada passo; nenhuma pergunta.
    **App onda 1 PRONTA (24/10 ~05:00 UTC): `painel/onda6-custo-aluno-2` em `d5126c0`** (4 commits sobre fe6dbd7; lint,
    typecheck e testes verdes: shared 340, crystal 701, api 1734, web 1096; audit só com o zod já ignorado). Fechou os
    altos: equipe não entra mais pela porta do aluno (`POST /auth/login` com e-mail de equipe = 404 como desconhecido);
    troca de e-mail (3 rotas), liberação manual e conta local sem prazo exigem código de reautenticação + motivo, com
    auditoria por HMAC, sessões derrubadas e aviso ao e-mail antigo; código mandado ao e-mail antigo não abre a conta;
    Crystal: NFKD + mapa de letras parecidas (`confusaveis.ts`), últimas 3 respostas por contato (10 min, só memória)
    conferidas junto com a nova contra regra fatiada, descrição da imagem/importado/resumo tratados como dado, rótulos
    com sufixo aleatório, camada semântica sem falha aberta (`CRYSTAL_TRAVA_ESTRITA_SEM_SEMANTICA`, padrão ligada);
    webhooks: `IMAGENS_WEBHOOK_SECRET` próprio (opcional; sem ele vale o do reembolso, com aviso), evento com mais de
    24 h = 409, dedup 180 dias, reembolso não re-bloqueia aluno religado pela equipe; JWT só HS256, logout revoga a
    sessão, corpo de 16 KiB nas rotas públicas de auth. **Antes de publicar: toda conta de equipe precisa ter senha**
    (a porta do aluno não abre mais o painel). Conferir na VPS, antes do `app-subir`:
    `docker exec -i $(docker ps -q -f name=crystal_app_app_postgres) psql -U crystal -d crystal_web_chat -c "select id, role, status from users where role in ('support','tech','admin') and password_hash is null;"`
    Tem de voltar `(0 rows)`; se listar alguém, definir a senha dessa conta em Operação › Equipe antes de publicar. CI de `d5126c0` rodando; imagem `sha-d5126c0` disparada
    (checkpoint: já pode ser publicada se a onda 2 atrasar). A regra das 7 palavras só barra cópia que seja metade
    ou mais da resposta (7 fixas quebrava "Menu > Suporte" da alma).
    **Infra onda 2 PRONTA, ainda NÃO juntada: branch `seguranca/infra-onda2` em `4feb3cc`** (14 commits: redes separadas
    por serviço + `redes-voltar --confirmo`; IP do cliente só do Traefik; Traefik com socket proxy, read-only,
    healthcheck; rotação de logs, healthchecks, limites, HSTS; senha no Redis do app; imagens por digest; `cap_drop`;
    comando `docker-daemon`; backups; token do Cloudflare; `STACKS_COMMIT=91e7971`). Testado só com docker falso.
    **Em revisão adversarial por outro agente antes do merge** (o que quebra no Swarm real; corrige bugs claros na
    própria branch). Fora, de propósito: INF-02 (trocar chaves vazadas: dono), INF-05 (sem Docker secrets), INF-25.
    **Rodando agora:** app onda 2 (todos os médios e baixos restantes de 01–04 + itens do app do 05, zod 4, fast-uri,
    actions por SHA, pnpm), n8n (INT-06 confirmação na Assiny, 200 só depois da API, dados pessoais, credenciais;
    branch `seguranca/n8n-assiny`, worktree `/home/user/hosp-n8n`), revisão da infra onda 2. Vigia do CI/imagem de
    `d5126c0` em segundo plano. Lembrete automático às 05:59 UTC.
    **CI de `d5126c0` VERMELHO só no e2e** (33 testes: `loginAs` da equipe ainda entrava pela porta do aluno, fechada na
    onda 1). Imagem `sha-d5126c0` construída, mas NÃO publicar: usar a tag final da onda 2. Gate e audit verdes.
    **App onda 2 PRONTA (24/10 ~08:00 UTC): `27c89c8`** (6 commits sobre d5126c0; relatório completo em
    `scratchpad/onda2-app-handback.md` desta sessão). Fechou: A1 (login do aluno sem oráculo: resposta igual para
    desconhecido/equipe/desligada/fora do lote, motivo real vai por e-mail à própria caixa; consentimento depois do
    código), A5 (rotação do refresh com tolerância 60 s, equipe 14 d deslizantes, teto 180 d; migração aditiva
    `pa23_01_sessoes_rotacao_refresh`; ninguém derrubado), A7 (teto de códigos por e-mail 6/h, 10/dia), A8
    (`op_login_codigo` só "email"; "nenhum" só por variável), A10, A11 (scrypt 2^17), A12/02-A7 (papel, status e senha de
    outro só com código; superadmin só por superadmin), 02-A3 (técnico não vê e-mail na ficha nem nos tickets; busca de
    Mensagens só por nome), A4 (cópia LGPD sem notas do financeiro), A5, A6, A8, A9 (link de fora só admin + código),
    A10 (`STUDENT_LIST_PAGES_PER_DAY`), C-06 (decodifica hex/base32/entidades/URL/decimal/Morse e ordem invertida),
    C-09 a C-15, INT-04, INT-09 (refresh reconsulta a base 1×/dia), INT-11, INT-12 (parcial), INF-08 (fastify 5.12.7,
    fast-uri, audit moderado no CI e no imagens-vps), INF-09 (actions por SHA + Dependabot), INF-10 (pnpm 10.34.7,
    quarentena 7 d, só prisma/esbuild/sharp rodam install script), INF-14 (node:22.22.2-alpine), INF-24, INF-16 (**zod 4**
    em shared/api/crystal; `ignoreGhsas` vazio; tarefa #59 feita). e2e consertado (equipe entra por `/login/equipe`).
    Não feitos (com motivo no relatório): A13 (operação), C-04 (histórico do ensaio sem detector), C-07 (calibração
    precisa de dados reais), INT-01 (HMAC + timestamp exige mudar o n8n junto), INT-13, INT-18 (externo), INF-16
    (Dockerfile em estágios), INF-17 (atestado). Variáveis novas, todas opcionais com padrão: `REFRESH_TTL_EQUIPE_S`,
    `REFRESH_MAX_S`, `REFRESH_TOLERANCIA_S`, `OTP_ENVIOS_EMAIL_HORA/_DIA`, `WEBHOOK_CRYSTAL_ENABLED`,
    `REFUND_PREBLOCK_DIA`, `REFUND_WEBHOOK_IP_MAX_MIN`, `STUDENT_LIST_PAGES_PER_DAY`, `NOTICE_LINK_HOSTS`. Testes: shared
    340, api 1742, web 1096, crystal 701; e2e 86 passed; audit sem vulnerabilidades. **Volta de código: `sha-d5126c0`**
    (a migração é aditiva: 2 colunas nulas + índice em `sessions`).
    **CI de `27c89c8` VERMELHO por 1 teste intermitente** (`staff-alunos-cadastro.test.ts`: conferia que o JSON da conversa
    não contém "c-1"; um UUID aleatório continha). Corrigido por mim em **`46c471a`** (confere os campos
    `channelSourceId`/`channelConversationId`); 38 testes do arquivo verdes; CI rodando. Imagem só depois do CI verde.
    **Contêiner desta sessão reiniciou (~06:00–12:30 UTC):** o agente do n8n e o revisor da infra morreram antes de
    mudar arquivo (worktrees limpos); relançados às 12:30 UTC com pushes por tema. Supabase conferido (só leitura):
    `app_compra_evento` AINDA é a versão antiga (dono não rodou `app_compras_bloqueio_restrito.sql`).
    Lembrete automático às 14:03 UTC.
    **CI de `46c471a` VERDE (gate, audit, e2e) às ~12:55 UTC.** Imagem `sha-46c471a` disparada (imagens-vps); é a
    tag candidata do app para o roteiro final, salvo mudança nova. **Imagem `sha-46c471a` PRONTA (~13:20 UTC).** Volta: `sha-088d07d` (produção de hoje) ou
    `sha-d5126c0` (só a onda 1; não publicar, e2e vermelho).
    **Infra onda 2 REVISADA e JUNTADA: merge `e62034e`** (branch `seguranca/infra-onda2` até `caf8e71`; revisor
    adversarial: nenhum erro que derrube serviço sem volta; 4 correções na branch: `seguranca --sem-ssh` para o dono
    não se trancar, `bancos` imprime a volta antes de mexer, README com um roteiro só e avisos esperados, `app-status`
    com a tag limpa). Relatório em `auditorias/2026-10-24/seguranca/06-revisao-infra-onda2.md`. **Bootstrap do
    merge: sha256 `e7393b318fda59bfe91e6dc84f0aabb301cff7de044ca6f869ad907ac6665225`**; `STACKS_COMMIT=91e7971`
    (ancestral do merge; `arquivos-hash` diz "nenhum arquivo mudou"). Roteiro da VPS: README › "Revisão de segurança
    de 24/10", passos 0–8 (passo 1 `docker-daemon` é OPCIONAL: recomendado adiar; `app-db-papel` e trava do SSH para
    outra noite). O `.gitignore` novo ignora `auditorias/*/evidencias/rdap.json` (dados do titular); `rdap.json`
    antigo apagado do repositório (continua no histórico do git).
    **n8n PRONTO e JUNTADO: merge `f19ef9f`** (branch `seguranca/n8n-assiny`, 3 commits). A Assiny só tem webhooks
    (sem API de consulta, sem HMAC, sem IPs): defesa em camadas (caminho secreto + cabeçalho `x-crystal-token`,
    validação no primeiro nó, bloqueio só com compra conhecida, e-mail de texto fixo, conciliação 06:10/18:10 com
    alerta). Limite que fica: com os dois segredos ainda dá para forjar uma liberação (nunca um bloqueio). Novo
    achado: o chargeback real da Assiny é **`charged_back`** e nem o SQL nem a API o reconheciam: SQL novo inclui; app
    corrigido em **`3c343df`** (`REFUND_EVENTS_PADRAO` e `IMAGENS_EVENTOS_ESTORNO`; CI rodando; imagem depois).
    Papel Postgres `n8n_compras` só com as 2 funções (sai a service_role do n8n). **SQL único do dono:**
    `crystal-em-casa/supabase/app_compras_seguranca_n8n.sql` (substitui o `app_compras_bloqueio_restrito.sql`).
    Roteiro de troca do fluxo (8 passos, sem janela de 403) em `crystal-em-casa/n8n/README.md`. Relatório em
    `auditorias/2026-10-24/seguranca/07-n8n-assiny.md`. Pendências de infra que o n8n deixou (retenção 48 h das
    execuções, `IMAGENS_WEBHOOK_SECRET` no `APP_EXTERNOS`, `n8n-compras.segredos` no backup): agente rodando na
    branch `seguranca/infra-pendencias-n8n` (vai mudar yaml do n8n: `STACKS_COMMIT` e sha256 do bootstrap mudam).
    **Resumo consolidado escrito:** `auditorias/2026-10-24/seguranca/00-resumo.md` (86 achados distintos: 72 fechados,
    13 abertos de propósito/parciais com motivo, 1 só do dono: INF-02 trocar chaves). Tem os 10 altos um a um, o que
    a equipe de suporte vai sentir, o checklist do dono e os ponteiros. INT-21 (portão de lotes): conferir no painel
    que `op_rollout_gate` está ligado.
    **TODAS AS ONDAS FECHADAS (24/10 ~14:30 UTC).** Pendências de infra do n8n juntadas: **merge `fcd8955`**
    (`fcd89559ee3f7775c745523c8a6ee91d87289f16`): retenção do n8n 48 h/5000, `IMAGENS_WEBHOOK_SECRET` no `app-definir`
    (régua do reembolso + tem de ser diferente dele), `n8n-compras.segredos` em todo backup só cifrado, READMEs.
    **Bootstrap final: sha256 `5fcf4673c051567c5dac7d289a2efdbd203b828a257c0b63a201d160f0e9dee2`, `STACKS_COMMIT=8d7379f`**
    (ancestral; `arquivos-hash` "nenhum arquivo mudou"). **App final: `sha-3c343df`** (CI verde; **imagem PRONTA** ~13:40 UTC). Volta do app: `sha-088d07d` (produção). CLAUDE.md atualizado. Mensagem única ao dono enviada em 24/10 ~13:45 UTC
    (tags, sha256, roteiro de uma madrugada, SQL, ações dele). **Daqui em diante é o dono quem age**; próxima sessão:
    acompanhar a publicação (`app-subir sha-3c343df`), a madrugada da VPS e a troca do fluxo do n8n, e responder ao que
    o suporte perguntar (seção 5 do `00-resumo.md`).

49. **25/10, pedido do dono: "check geral de toda a plataforma pensando em UX e UI" + relatório + mockups + PRD final de
    execução.** Em andamento: workflow com agentes (mapa das telas da aluna e do painel, sistema visual, contexto do
    produto e capturas reais de tela via Playwright em modo e2e; 10 lentes de revisão; verificação adversarial por
    lote; síntese: relatório em `auditorias/2026-10-25/ux/relatorio-ux-ui.md`, PRD em
    `docs/ux/PRD-ux-ui-2026-10-25.md` no repositório do app (worktree `/home/user/cw-ux`, branch
    `docs/prd-ux-2026-10-25`), mockups antes→depois em HTML; crítico de completude). Depois: publicar os mockups como
    artefato (tipo Design) para o grupo e commitar relatório e PRD. Restrições fixas: alma intocada, cara de WhatsApp,
    itens recusados do `docs/otimizacao/04-fora-do-escopo.md` não voltam, nada de dado pessoal.
    **25/10 ~18:00 UTC:** mapa, revisão e verificação PRONTOS: 104 capturas reais (`scratchpad/ux/capturas/`), 4 mapas,
    10 lentes → **143 achados confirmados (14 altos, 87 médios, 42 baixos; 56 da aluna, 63 do painel, 24 ambos)**,
    gravados em `auditorias/2026-10-25/ux/achados.json`. Há duplicatas entre lentes (ex.: "Menu > Suporte não existe no
    menu" = UX-15/28/73): relatório e PRD agrupam. A síntese do workflow caiu no limite de uso da sessão (reset 18:20
    UTC); relançada à mão às 18:05 UTC com 6 agentes em paralelo: relatório (`auditorias/2026-10-25/ux/relatorio-ux-ui.md`),
    PRD (`/home/user/cw-ux/docs/ux/PRD-ux-ui-2026-10-25.md`), 4 grupos de mockups (`scratchpad/ux/mockups/*.html`,
    fragmentos antes→depois com estilos inline). Canvas Design dos mockups já criado:
    https://claude.ai/artifact/Mdq9zQnWcUR8SCYtdH3UDz (25 capturas "antes" já enviadas como assets; artboards entram
    quando os mockups saírem). Depois: crítico de completude, copiar capturas citadas para o repositório, commitar os dois
    repositórios, entregar ao dono.
    **25/10 ~18:45 UTC:** os créditos da conta acabaram no meio da síntese. Ficaram completos: o relatório (361 linhas,
    98 achados distintos depois de agrupar 45 IDs repetidos: 10 altos, 65 médios, 23 baixos; notas: app 7/10, painel 6,5/10)
    e o PRD (2.149 linhas, itens U01–U58 em 3 ondas, todos os 143 IDs cobertos). Dos mockups, só o grupo "aluna-entrada"
    (6 telas). **26/10 ~02:45 UTC, sessão passou para o Opus 5.5:** relançados os 3 grupos de mockups que faltavam e a
    conversão do primeiro, agora direto como artboards do canvas (`scratchpad/ux/canvas/project/*.dc.html`, regras em
    `canvas/REGRAS-ARTBOARD.md`, URLs das capturas em `canvas/assets.json`; 37 capturas já enviadas ao canvas), mais um
    crítico que alinha relatório e PRD (workflow `wf_7448c2e4-fe4`). Capa do canvas escrita. 43 capturas citadas copiadas
    para `auditorias/2026-10-25/ux/capturas/` (11 MB). Commits a partir daqui com a linha `Claude Opus 5.5`.
    **26/10 ~03:40 UTC: CHECK DE UX/UI ENTREGUE.** (1) Relatório revisado: `auditorias/2026-10-25/ux/relatorio-ux-ui.md`
    (429 linhas; 98 achados distintos: 10 altos, 65 médios, 23 baixos; app 7/10, painel 6,5/10; 40 ganhos rápidos).
    (2) PRD de execução: `docs/ux/PRD-ux-ui-2026-10-25.md` na branch `docs/prd-ux-2026-10-25` do app (commit `9dde4db`,
    2.173 linhas) e cópia em `auditorias/2026-10-25/ux/`. U01–U23 (U-onda 1, 2–3 semanas: 7 dos 10 altos, migração aditiva
    `messages.neutra`), U24–U47 (U-onda 2, painel, 3–4 semanas: rota `POST /staff/tickets`), U48–U58 (U-onda 3, design
    system, 3 semanas, sem migração). `sha-3c343df` (segurança) tem de ser publicado ANTES ou junto da U-onda 1.
    14 decisões do dono no fim do PRD, todas com padrão (ex.: botão de entrar continua verde; "Recomeçar a conversa"
    entra no menu; botão "Falar com o suporte" no passo do código entra; áudio para e espera aos 2:00).
    (3) Mockups: canvas Design https://claude.ai/artifact/Mdq9zQnWcUR8SCYtdH3UDz, 24 quadros (capa + 6 entrada da aluna +
    6 conversa/início + 6 painel suporte + 5 painel dados), cada um com a captura real de hoje, a proposta e "O que mudou"
    com os IDs; fonte em `auditorias/2026-10-25/ux/mockups/`. Privado: o dono precisa compartilhar pelo menu Share para o
    grupo abrir. Nada foi mudado no código do app; a execução é do Igor, onda a onda, pelo PRD.

50. **26/10, pedido do dono: "o mockup preciso que me mostre como ficaria visualmente usando o PRD".** Leitura: ver as
    telas PRONTAS (depois das 3 ondas), não só antes/depois. Em andamento: workflow `wf_cd44b45a-c72` monta um kit visual
    (`scratchpad/ux/visual/ds.css` com os tokens e componentes do PRD, fontes reais Inter Tight e Blinker, imagens reais
    do app) e 9 grupos de telas em HTML (a1–a4 aluna, p1–p4 painel, ds kit), renderizadas em PNG pelo
    `scratchpad/ux/visual/render.js` (Playwright; celular 390×844 @2x, computador 1280×800), cada grupo revisado por um
    crítico que abre as imagens, mais uma passada de coerência entre todas. Depois: galeria publicada como artefato
    (modelo em `scratchpad/ux/visual/galeria-modelo.html`, filtros por área e onda, toque amplia), folhas de contato
    no chat e cópia das PNGs em `auditorias/2026-10-25/ux/telas-finais/`.
    **26/10: dono pediu "ponha em um artefato".** Galeria publicada como PRÉVIA: https://claude.ai/artifact/JdZwwHjuvUfgM6oiuRUFt6
    (57 telas de 6 grupos: a1–a4 aluna, p1–p2 painel, ainda sem a revisão final; filtros por área e onda, toque amplia).
    Montada por `scratchpad/ux/visual/galeria-modelo.html` + `_resultados.json` (lista das telas tirada do journal do
    workflow). Quando o workflow terminar (p3, p4, ds, 9 revisões e coerência), republicar NO MESMO arquivo
    (`scratchpad/ux/visual/galeria/index.html`) para manter o link, tirando o aviso de prévia.
    **26/10: TELAS FINAIS ENTREGUES.** Workflow terminou (20 agentes: kit, 9 grupos desenhados e revisados, coerência com
    14 correções entre grupos). Galeria republicada no mesmo link com **108 telas revisadas** (onda 1: 32, onda 2: 59,
    onda 3: 17; 4 folhas do kit visual), sem aviso de prévia. Cópia completa em `auditorias/2026-10-25/ux/telas-finais/`
    (commit `73eb00a`: imagens, galeria, HTML de cada tela, `ds.css`, `KIT.md`, ícones, `render.js`). O kit fez 5 ajustes
    de cor em relação ao PRD para fechar o contraste AA (verde do aviso `#097200`, toque do rosa `#c20857`, "Desfazer" do
    toast, trilho do interruptor, contador do suporte) e o foco rosa por padrão: levar ao PRD (U01, U27, U52) quando a
    onda for executada. Link privado: o dono compartilha pelo Share.

51. **26/10, pedido do dono: "Execute o PRD completo. Use agentes e faça harness".** Em andamento.
    - **Harness** em `scratchpad/ux/harness/`: `gate.sh <worktree> rapido|e2e|completo [--porta N]` (tipos, lint,
      testes dos pacotes mudados, build do web, conferir-safari, audit, e2e com portas próprias: web N, API N+1,
      Chatwoot falso N+2; logs em `<worktree>/.gate/`), `REGRAS.md` (fonte da verdade = PRD + 108 telas finais como
      referência visual; cores do kit corrigidas para AA; nunca alma, nunca produção, nunca git destrutivo; commit
      por item com `Claude Opus 5.5`), `base-onda1.log` (portão completo da base sem mudança, para separar falha
      antiga de falha nova).
    - **Branches:** `painel/ux-onda-1` (de `3c343df` + PRD; CI roda em `painel/**`, por isso não `ux/onda-1` como o
      PRD dizia), depois `painel/ux-onda-2` e `-3` em cima. Pacotes em `uxp/onda<N>-<id>` (sem CI; worktrees em
      `/home/user/cwux/<id>`, removidos depois de juntados). Integração em `/home/user/cw-ux-onda<N>`.
    - **Roteiro por onda** (workflow `ux-prd-onda`, reutilizável): planejador divide os itens em pacotes por camada →
      implementador por pacote (worktree e portas próprias, teste por critério de aceite) → verificador adversarial
      (textos do PRD caractere por caractere, a11y, segurança onde o PRD manda) → integrador por camada (merge
      --no-ff, portão completo, push) → portão de saída (CI inteiro, docs, `docs/ux/onda-N-conferir-em-aparelho.md`).
    - **Onda 1 (U01–U23) rodando:** workflow `wf_1ed70145-182`. Ondas 2 e 3 depois, em sequência, cada uma sobre a
      anterior. Publicação na VPS continua com o dono (`sha-3c343df` antes ou junto da onda 1).
    - **Plano da onda 1 (22:15 UTC):** 10 pacotes em 4 camadas. Camada 1: `tokens-foco-campos` (U01–U03),
      `fila-midia-offline` (U07, U14), `paginas-publicas` (U21). Camada 2: `login` (U09–U12), `bolha` (U06, U08, U17),
      `movimento-faixa` (U16, U22). Camada 3: `menu-leitor-textos` (U04, U15, U18, U20). Camada 4:
      `erros-conversa-audio` (U05, U13), `erro-critico` (U19), `rede-testes` (U23). Camada 1 implementada (10 commits),
      verificação rodando. Base da onda 1 verde, menos o teste de tempo da trava (6,6 ms com a máquina ocupada).
    - **Contêiner reiniciou (26/10 noite):** o workflow caiu com a camada 1 implementada (3 pacotes, 15 commits nas
      branches `uxp/onda1-*`, todas empurradas) e 2 de 3 verificações prontas. Retomado com `resumeFromRunId`
      (`wf_1ed70145-182`, tarefa `w2esbxur7`): o que já terminou volta do cache; a verificação de `paginas-publicas`
      recomeça com a edição que tinha ficado sem commit (`e2e/voltar.spec.ts`). Se cair de novo: mesmo comando de
      retomada (está no lembrete automático das 00:46 UTC).
    - **Segundo reinício (26/10 ~23:20 UTC):** caiu durante a junção da camada 1. As três verificações tinham
      terminado e o integrador já tinha juntado os 3 pacotes (`fd82c1f`, `baaa9fd`, `e19ea33`); eu empurrei
      `painel/ux-onda-1` em `e19ea33`. No portão completo só 2 testes da API estavam vermelhos (U07 ordem das respostas
      em `messages.test.ts` e um de `staff-eventos.test.ts`), com correção em andamento sem commit no worktree de
      integração. Retomado de novo (tarefa `wf6lpgtlk`); o integrador recomeça com essas edições no lugar.
    - **27/10 00:48 UTC: camada 1 da onda 1 FECHADA.** Integrador corrigiu os 2 testes (U07: a 2.ª mensagem do teste
      de fila sai depois da 1.ª; B05: lembrete de 72 h não depende mais da hora do dia), portão completo verde,
      `painel/ux-onda-1` em `9e955c3` com **CI verde** no GitHub. Worktrees da camada 1 removidos. Camada 2 em
      implementação (`login`, `bolha`; depois `movimento-faixa`).
    - **27/10 02:22 UTC: camada 2 juntada e empurrada** (`painel/ux-onda-1` em `34f5d00`: login U09–U12, bolha U06/U08/U17,
      movimento e faixa U16/U22); CI rodando. 15 dos 23 itens da onda 1 já na branch. Camada 3 (`menu-leitor-textos`:
      U04, U15, U18, U20) em implementação; depois a camada 4 (U05, U13, U19, U23) e o portão de saída.
    - **27/10, decisões do dono:** (1) **"cliente", nunca "aluna"**, em todo texto visível e nas mensagens à equipe;
      URLs, código e banco não mudam; varredura dos textos existentes = item novo **U59** (onda 2, primeira camada).
      (2) **Erro da conversa nunca mostra a causa:** a cliente vê "Não consegui te responder agora." + "Código Cxx";
      a tabela código → causa fica em `packages/shared/src/codigos-erro.ts`, `docs/equipe.md` e no painel. **U05
      reescrito** no PRD da onda (`141a98f`, cópia em `auditorias/2026-10-25/ux/`); U06 (resposta neutra da trava)
      fica como está. Regras dos agentes atualizadas (`harness/REGRAS.md`). Telas finais com textos de causa
      (a3-erro-fora-do-ar etc.) ficaram desatualizadas: valem o PRD e o código.
    - **Terceiro reinício (27/10 ~03:20 UTC):** caiu logo no começo da camada 3; o pacote `menu-leitor-textos` não
      tinha nenhuma edição. Nada perdido: `painel/ux-onda-1` em `141a98f` com **CI verde** (o e2e de `34f5d00` foi
      cancelado pelo push seguinte, não falhou). Branch do pacote avançada para `141a98f` (para ler o PRD novo) e
      empurrada; workflow retomado (tarefa `w2rzql08g`). Próximo lembrete automático às 05:54 UTC, com o mesmo comando
      de retomada.
    - **27/10 05:55 UTC: camada 3 juntada** (`painel/ux-onda-1` em `3a2a7d0`, **CI verde**: menu, leitor de tela e
      textos U04, U15, U18, U20). 19 dos 23 itens da onda 1 na branch. Camada 4 em implementação: `erro-critico` (U19)
      com commit `33a6bea`; `erros-conversa-audio` (U05 com código, U13) com edições ainda sem commit; `rede-testes`
      (U23) começando. Depois: verificação, junção e portão de saída. Lembrete automático às 08:25 UTC.
    - **27/10 08:27 UTC: camada 4 implementada.** `erro-critico` (U19, 2 commits) e `erros-conversa-audio` (U05 erro só
      com a frase neutra e o código, a causa na ficha da equipe; U13 áudio para aos 2:00 e microfone recusado diz onde
      liberar; 5 commits) já verificados; `rede-testes` (U23, 6 commits: seed demo, auditoria mobile 360–412, axe) em
      verificação. Faltam a junção da camada 4 e o portão de saída. O script do workflow agora lê `base-onda<N>.log`
      (pronto para a onda 2). Lembrete automático às 10:27 UTC.
    - **27/10 10:10 UTC:** verificação de `rede-testes` (U23) ainda rodando, com 5 correções já empurradas (o projeto
      WebKit do e2e passa de verdade, foto da bolha com 44 × 44 de toque, axe com as quatro tags também na Alma,
      Mensagens, Banners, Laboratório e #reset, auditoria com o diálogo Desligar) e o e2e da auditoria mobile rodando.
      `painel/ux-onda-1` segue em `3a2a7d0` com CI verde; contêiner sem reinício desde 03:20.
    - **27/10 10:28 UTC:** os 3 pacotes da camada 4 verificados (`rede-testes` empurrado em `d9f1b83`); junção da
      camada 4 com o portão completo rodando; depois o portão de saída da onda. Lembrete automático às 12:28 UTC.
    - **27/10 ~11:25 UTC: ONDA 1 PRONTA (U01–U23, nenhum faltando).** `painel/ux-onda-1` em **`c71b41c`**. Portão
      completo verde: 352 + 1.782 + 1.323 + 704 testes, build, safari, audit sem vulnerabilidade, e2e 168 passaram e
      7 pulados (os da base), login só com e-mail 10/10, WebKit 18/18. Migração única e aditiva
      `ux1_01_messages_neutra` (coluna `messages.neutra`, padrão falso; a volta da imagem não precisa de volta de
      banco); nenhuma variável nova em produção; API, web e Crystal na mesma tag; `backup_mode` nasce `off`; cache do
      service worker v4 → v5. Prompt da Crystal intocado (o serviço só devolve o sinal `neutra` do U06; o `alma.md` do
      web é o guia de textos da interface e ganhou a frase nova da faixa de reserva do U22).
      - Lista do iPhone: `docs/ux/onda-1-conferir-em-aparelho.md` no app, cópia em
        `auditorias/2026-10-25/ux/execucao/`. PRD com a seção "Execução" (desvios) copiado para
        `auditorias/2026-10-25/ux/` (`b18199d`). `PROXIMOS-PASSOS.md` › Ordem › 3 ganhou "Integrações › Canal →
        Desligado" e conferir o "Aviso do modo reserva" antes de encerrar o WhatsApp.
      - Para o dono responder (nada trava a subida): OK do tom novo do toque no rosa `#c20857`; rótulo de voz do CVV;
        texto do limite de recomeços; depois do teste no iPhone instalado, ligar ou não
        `MICROFONE_IPHONE_INSTALADO_USA_RESERVA`. Perguntas 1–7 do PRD aplicadas no padrão (tabela no fim da lista do
        iPhone).
      - Publicação: depois do CI verde de `c71b41c`, disparar `imagens-vps` em `painel/ux-onda-1` → `sha-c71b41c`. Ela
        já contém o `sha-3c343df` (segurança de 24/10), então o SQL e o n8n da segurança vêm antes ou junto.
    - **Onda 2 preparada:** `painel/ux-onda-2` criada de `c71b41c` (worktree `/home/user/cw-ux-onda2`, empurrada);
      portão completo da base rodando para `harness/base-onda2.log`; `REGRAS.md` ganhou "Pendências da onda 1 que
      entram na onda 2" (C01 separado em C02/C03 pelo `NO_CREDIT`/`TIMEOUT`; 3 baixos de segurança: `challenge_id`
      repetido, `SET XX` no 409 do aceite, `backup-mode` antigo gravando `auto`; ghostBtn sem vermelho; "Entrar como
      aluno" no login da equipe; 2 textarea de 12 px; rolagem suave sem "Reduzir movimento"; PENDENCIAS U30/U34/U39/U43
      do U23).
    - **27/10 ~11:50 UTC: base da onda 2 VERDE** (`base-onda2.log`: tudo OK, e2e 168 passaram e 7 pulados) e **onda 2
      lançada**: workflow `wf_ca330f41-fa3` (tarefa `wu35e3hnq`), args onda 2, itens "U24 a U47, U59 (primeira camada)
      e as pendências da onda 1", porta0 4400. Retomada, se cair: mesmo `scriptPath`
      (`workflows/scripts/ux-prd-onda-wf_1ed70145-182.js`) com `resumeFromRunId: "wf_ca330f41-fa3"` e os mesmos args
      (estão no lembrete das 14:30 UTC). O CI de `c71b41c` (onda 1) ainda rodando; imagens depois dele.
    - **27/10 ~13:00 UTC: onda 1 pronta para subir.** CI de `c71b41c` **verde** (gate, audit, e2e com WebKit, e2e do
      login só com e-mail; a instalação dos navegadores no GitHub levou 47 min desta vez, não é nosso). `imagens-vps`
      (run 40505357652) construiu as 3 imagens **`sha-c71b41c`**. Roteiro do dono:
      `auditorias/2026-10-25/ux/execucao/publicar-onda-1.md` (`674768b`): conferir senhas da equipe (psql do item 48),
      `app-status` (anotar a tag), `backup`, `app-subir sha-c71b41c`, `crystal-conferir`, lista do iPhone. Volta:
      `app-subir sha-088d07d`, sem volta de banco. A tag já leva a segurança de 24/10 (não precisa subir a
      `sha-3c343df` antes); SQL/n8n/madrugada da segurança seguem separados. Modo backup: padrão agora "Desligado".
    - **Plano da onda 2 (22 pacotes em 4 camadas):** (1) `cliente-varredura` (U59 + "Entrar como aluno"),
      `seguranca-login` (3 baixos); (2) `moldura-carregando` (U24–U26, textarea 12 px), `kit-dialogos` (U27, U31,
      U33), `modelo-custo` (U38), `graficos` (U42), `codigos-erro` (C01 → C02/C03); (3) `lista-inicio` (U28, U32,
      U44), `equipe-papeis` (U36, U45), `configuracoes` (U40, rolagem suave), `subrotas` (U30, U46), `mensagens`
      (U34); (4) `ficha-suporte` (U29, U35), `crystal` (U37), `laboratorio` (U39, ghostBtn vermelho), `jargao` (U41),
      `financeiro-auditoria` (U43, U47). Camada 1 em implementação.
    - **27/10 14:32 UTC:** camada 1 da onda 2 implementada e verificada (U59 "cliente" com guarda de teste em todo o
      código do web, da API e do shared; os 3 baixos de segurança só na API); junção em andamento
      (`603760a`, `5083c20` em `painel/ux-onda-2`, portão completo rodando). Lembrete às 17:02 UTC.

52. **26/10, suporte (Letícia):** (a) **Ivan**: e-mail trocado no Supabase com `app_aluno_trocar_email` (status
    "trocado", origem base); o novo entra (`liberado = true`), o antigo não. (b) **Brunno** ("não tem cadastro nesse
    e-mail"; Assiny ok): o e-mail não está em nenhuma tabela (customers, assinaturas, `crystal_compras`). O fluxo da
    Assiny está chegando normalmente (eventos toda hora hoje). **Achado:** às 17:35 BRT entrou um `approved_purchase`
    do produto **"Crystal - V10"** (`produto_id 8d919f87-b8c9-4d87-8a3b-f57c2b6c8f4d`, transação `05f00402…`) com ação
    `ignorado_produto`: a V10 não está em `crystal_compras_produtos` (lá estão 7 produtos, até "Oferta Nova - V6").
    Toda compra da V10 é ignorada até cadastrar. Provável que seja a compra do Brunno (pagamento aprovado depois do
    chamado das 16:17). **Dono decidiu (26/10): a V10 é o app.** Feito às 21:35 UTC: V10 cadastrada em
    `crystal_compras_produtos` (toda compra nova da V10 libera o app pelo fluxo normal) e o Brunno liberado à mão em
    `crystal_compras` (produto "Liberação manual", transação `manual-20261026-suporte-v10`, status active);
    `app_verificar_login_email` devolve `liberado = true`. A compra ignorada das 17:35 não é reprocessada (o evento
    não guarda o e-mail); se for de outra pessoa, ela aparece no suporte e se libera do mesmo jeito.
53. **27/10, suporte (Letícia):** (a) **Wilton**: e-mail trocado com `app_aluno_trocar_email` (status "trocado",
    origem base); o novo entra (`liberado = true`), o antigo não. (b) **Olímpio** ("não consegue acessar"; Assiny ok):
    o e-mail não estava em nenhuma tabela e nenhum evento foi perdido (fluxo com 417 aprovações em 30 dias). O print
    da Assiny mostrou a causa: compra **anual de 28/06/2026** (Pix, "CRYSTAL - A NOVA MELHOR AMIGA DOS HOMENS"),
    de antes do nosso fluxo e que ficou de fora da base da agência. Dono escolheu "liberar já": feito às 14:36 UTC
    em `crystal_compras` (produto "Liberação manual", transação `manual-20261027-suporte-compra-20260628-3a550af`,
    status active, nota "vence em 28/06/2027"); login devolve `liberado = true`. **Cortar à mão em 28/06/2027** se não
    renovar (a liberação manual não recebe reembolso nem cancelamento da Assiny). Se aparecerem mais compras antigas
    fora da base, vale pedir à Letícia a exportação das assinaturas ativas da Assiny para conferir de uma vez.
54. **27/10 ~14:35 UTC, publicação da onda 1 de UX: o `app-subir sha-c71b41c` parou** (duas vezes) em `open
    /root/crystal/app/redis.env: no such file or directory`, na etapa "== stack", **antes do deploy: nada mudou no ar**
    (continua `sha-088d07d`). Causa: o `bootstrap-vps.sh` da VPS é o antigo (`97b5ad2`, de antes da segurança); sem
    `REF` ele baixa o `10-crystal-app.yaml` da ponta da branch, que já é o da segurança (Redis com senha em
    `redis.env`, redes novas) e que só o script novo sabe montar. Correção sem mexer em nada da infra:
    `REF=97b5ad29d2b998163bc31654cbc2c00aa8017d7e bash bootstrap-vps.sh app-subir sha-c71b41c` (o yaml desse commit é
    igual ao que está no ar desde 05/10, `ee6c9ff`; conferido que o raw responde 200). Até a madrugada da segurança,
    **todo comando do script antigo que sobe stack (app-subir, atendimento-subir, n8n, painel…) leva esse `REF`**.
    Roteiro (`publicar-onda-1.md`) e passo 2 do resumo de segurança corrigidos.
55. **27/10 ~16:15 UTC: a sessão reiniciou e derrubou o workflow da onda 2** (a máquina não reiniciou; nenhum processo
    sobrou). Estado: camada 1 juntada em `painel/ux-onda-2` **`52f8ffa`, CI verde** (U59 "cliente", P2a–P2c, P3b).
    Camada 2: `moldura-carregando` (U24–U26, P3a) e `kit-dialogos` (U27, U31, U33) implementados e empurrados;
    `modelo-custo` (U38) com 1 commit e edições sem commit; `graficos` (U42) só com edições sem commit; `codigos-erro`
    (P1) não começou. Retomado com `resumeFromRunId: "wf_ca330f41-fa3"` (tarefa `wg93h9moy`); os agentes que não
    tinham terminado recomeçam com as edições no lugar. Lembrete das 17:03 UTC com o mesmo comando de retomada.
56. **27/10 17:05 UTC, onda 2:** os 5 pacotes da camada 2 implementados e empurrados: `moldura-carregando` (U24–U26,
    P3a), `kit-dialogos` (U27, U31, U33), `modelo-custo` (U38, 3 commits), `graficos` (U42, 2 commits) e
    `codigos-erro` (P1: crédito zerado e chave recusada viram **C02**, prazo do modelo vira **C03**). Verificação
    adversarial começando. Lembrete às 19:35 UTC.
57. **27/10 19:38 UTC, onda 2:** camada 2 verificada e **juntada** (`painel/ux-onda-2` em `03dadeb`, portão completo
    verde; no GitHub, gate, audit e e2e do login só com e-mail verdes, e2e principal rodando). Itens já na branch:
    U59, P2a–P2c, P3a, P3b, U24–U27, U31, U33, U38, U42 e P1 (C02/C03). Camada 3 em implementação (`lista-inicio`
    U28/U32/U44, `equipe-papeis` U36/U45; depois `configuracoes`, `subrotas`, `mensagens`). Lembrete às 22:08 UTC.
58. **27/10 22:45 UTC, onda 2:** camada 3 implementada (5 pacotes) e em verificação. **CI de `03dadeb` (camada 2): e2e
    vermelho no GitHub** (44 min, sem anotação de qual teste; o log do GitHub não se baixa desta máquina). Local tudo
    verde no mesmo commit: Chromium 190/190 (portão do integrador) e WebKit 11/11 (worktree `/home/user/cwux/ci-03dadeb`;
    o WebKit local precisa de `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1` e `LD_LIBRARY_PATH` com
    `scratchpad/webkit-root/usr/lib/x86_64-linux-gnu:…/lib/x86_64-linux-gnu`, `PLAYWRIGHT_BROWSERS_PATH=scratchpad/pw-browsers`).
    Pedido UM rerun do job (run 40565072746, tentativa 2): se falhar de novo, é real e vai ser achado e corrigido.
    `REGRAS.md` ganhou a pendência 5: reporter `github` no Playwright com `CI=true`, para a falha virar anotação
    legível pela API. Lembrete às 00:45 UTC.
59. **27/10 ~22:47 UTC: o contêiner reiniciou** (4.º reinício do dia) e derrubou o workflow da onda 2 na verificação da
    camada 3. Os 5 pacotes da camada 3 estavam todos commitados e empurrados (`equipe-papeis` e `configuracoes` já
    verificados; `lista-inicio` e `subrotas` em verificação, `subrotas` com 2 edições sem commit; `mensagens` sem
    verificar). Retomado às 22:50 UTC (tarefa `wu3p7xu8j`, mesmo `resumeFromRunId`). O rerun do CI de `03dadeb`
    (tentativa 2) continua no GitHub; vigia refeita.
60. **27/10 23:05 UTC:** o rerun do CI de `03dadeb` (tentativa 2) deu **tudo verde** (gate, audit, e2e, e2e do login
    só com e-mail). A 1.ª tentativa (44 min, vermelha) não se repetiu e não reproduziu local: fica registrada como
    falha do GitHub sem causa conhecida; a pendência 5 do `REGRAS.md` (reporter `github`) faz a próxima falha dizer
    o teste. Worktree de conferência `/home/user/cwux/ci-03dadeb` removido.
61. **28/10 00:22 UTC, onda 2:** camada 3 verificada (5 pacotes: `lista-inicio` U28/U32/U44, `equipe-papeis` U36/U45,
    `configuracoes` U40/P3d, `subrotas` U30/U46/P4, `mensagens` U34/P4) e em junção (`9390461`, `2c5b5b9` em
    `painel/ux-onda-2`, portão completo rodando). Depois: camada 4 e o portão de saída. Lembrete às 02:52 UTC.
62. **28/10 ~03:00 UTC, onda 2:** camada 3 **juntada** (`painel/ux-onda-2` em `3d93bed`; portão local verde, e2e 222
    passaram, WebKit 13/13, login só com e-mail 10/10; só o teste de tempo do `vazamento-camadas`, 5,3–5,7 ms, falha,
    e falha igual na base `c71b41c` nesta máquina). Camada 4 em implementação (`ficha-suporte`, `crystal`, depois
    `laboratorio`, `jargao`, `financeiro-auditoria`).
    - **CI de `3d93bed`: e2e vermelho de novo no GitHub** (35 min; local verde). Suspeita: no GitHub os dois projetos
      (Chromium e WebKit) rodam juntos no mesmo servidor de teste e um deixa estado para o outro (limites de código por
      e-mail, recomeços por dia…); local o WebKit rodava à parte. Rodando local exatamente como o CI no worktree
      `/home/user/cwux/diag` (branch `painel/ux-onda-2-diag` = `3d93bed` + reporter `github`), log
      `scratchpad/ci-like-3d93bed.log`.
    - **GitHub Actions BLOQUEADO por cobrança** desde ~02:54 UTC: o run da branch de diagnóstico não começou ("The job
      was not started because recent account payments have failed or your spending limit needs to be increased").
      **Dono:** GitHub › Settings › Billing & plans (pagamento ou limite de gasto do Actions). Sem isso não há CI nem
      `imagens-vps` (a onda 1, `sha-c71b41c`, já tem imagem pronta e não depende disso).
63. **28/10 ~04:30 UTC: causa do e2e vermelho no GitHub achada** (rodando local exatamente como o CI, os dois
    projetos juntos, `scratchpad/ci-like-3d93bed.log`): 3 testes instáveis, cada um caiu uma vez e passou na
    repetição; no GitHub, uma segunda queda vira vermelho. Dois eram **defeitos reais do app**:
    - **Login da equipe (e da cliente):** campo preenchido antes de a página terminar de carregar (gerenciador de
      senhas do iPhone numa página lenta) ficava fora do estado do React: na equipe o "Continuar" travava com e-mail e
      senha à vista; na cliente o envio diria "Digite o e-mail". Corrigido com `useLerCampoNaMontagem`
      (`apps/web/lib/campo-pre-hidratacao.ts`), teste com `renderToString` + `hydrateRoot` que falha sem a correção.
      O defeito já existia na onda 1 (`sha-c71b41c`) e provavelmente em produção: só aparece com página lenta.
    - **Título da aba da ficha (U30):** o título do metadata do Next ("Crystal") às vezes chegava depois e apagava
      "Ana · Clientes · Crystal". Guarda na moldura do painel (`apps/web/lib/titulo-da-aba.ts`), com teste.
    - E a varredura do U59 (mais de 300 arquivos) caía nos 5 s padrão do vitest com a máquina ocupada: tempo próprio.
    Commits `26947d2`, `2fece12`, `5ca07fb` na branch `painel/ux-onda-2-diag` (sobre `3d93bed`, com o reporter
    `github` em `4593c59`); portão rápido verde; e2e no modo do CI rodando de novo (`scratchpad/ci-like-diag2.log`).
    Entram em `painel/ux-onda-2` quando nenhum integrador estiver rodando.
64. **28/10 ~05:20 UTC: correções do e2e do GitHub na branch da onda.** O e2e no modo do CI com as 3 correções deu
    234 passaram e 1 instável novo (U24, leitura do marcador da equipe logo depois do login; corrigido com espera:
    6 de 6 seguidas, `1c24d21`). `painel/ux-onda-2` avançada para **`1c24d21`** (fast-forward com a branch
    `painel/ux-onda-2-diag`: reporter `github` + login antes da hidratação + título da aba + tempo do U59 + U24) e
    empurrada, com a camada 4 ainda em implementação (o integrador da camada 4 junta por cima). Worktree de diagnóstico
    removido. O defeito do login antes da hidratação também está na onda 1 (`sha-c71b41c`) e provavelmente em
    produção; a correção sai com a onda 2 (o GitHub Actions está bloqueado por cobrança, sem imagem nova agora).
65. **28/10 05:27 UTC:** camada 4 da onda 2 com os 5 pacotes implementados (`ficha-suporte` U29/U35, `crystal` U37,
    `laboratorio` U39/P3c/P4, `jargao` U41, `financeiro-auditoria` U43/U47/P4) e a verificação começando. O push de
    `1c24d21` disparou o CI, que morreu em 2 s: **GitHub Actions continua bloqueado por cobrança**. Lembrete às 07:57 UTC.
66. **28/10 07:58 UTC:** os 5 pacotes da camada 4 da onda 2 verificados (com correções dos verificadores); a junção da
    camada 4 está rodando e depois vem o portão de saída da onda 2. Actions sem run novo desde 04:59 (bloqueio de
    cobrança). Lembrete às 10:28 UTC, já com o roteiro da onda 3 (U48–U58, porta0 5400).
