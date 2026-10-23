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
