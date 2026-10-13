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
| App na VPS (`177.7.61.136`) | **`sha-3773e2e`** desde 13/10 18:44 UTC (correção do painel que derrubava a API por falta de memória; volta `sha-0e2f79d`). Antes, `sha-0e2f79d`, publicado em 13/10 14:13 UTC. É o `sha-5a5b198` de 10/10 (modelo por fornecedor com tabela de gasto de 7 dias, "Ligações da Crystal", avisos programados com prévia, correções da bateria do painel) **mais as fichas**. Volta: `bash bootstrap-vps.sh app-subir sha-74092e0`. Backup feito antes, cópia cifrada no R2. |
| Painel (Operação) | `op_memoria_unica = on`, `op_whatsapp_silencio = on`, **sem modelo salvo** (a Crystal usa o padrão da imagem). |
| Supabase | `app_memoria_ficha.sql` aplicado em 13/10 (migração `app_memoria_ficha_20261012`): tabela com RLS, 6 funções só para `service_role`, 0 linhas. A função de teste `zz_teste_cabecalho_20261009` foi apagada pelo dono em 13/10. |
| Chatwoot | v4.18.0-ce em `atendimento.`, canal do app ligado (`CHAT_TRANSPORT=chatwoot`). |
| Compras | Assiny → nosso n8n → `crystal_compras` no Supabase → app liberado. Sem agência desde 09/10. |
| Site | Degrau 1 feito (DNS no Cloudflare, cinza). Degrau 2 não começou; chamado AZAN #RAI-374885. |
| OpenRouter | Saldo US$ 47,79 por volta de 15h UTC e US$ 32,87 às 18h50 UTC de 13/10 (US$ 15 em ~4 h). Conferir a origem (pilotos das fichas ou uso dos alunos) e recarregar antes de zerar: sem saldo, a Crystal para. |
| `bootstrap-vps.sh` | Versão atual: commit `c0379c9`, sha256 `770983400c98d05bd98065e7efc515dc48de5b9ccc4e91ae9a2c505c47ad7d6d` (tem o `crystal-conferir` corrigido e o `painel-diagnostico`). |

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
3. **Painel novo (onda 4, caminho A): pronto para publicar.** `painel/onda4` em `22a65c1`, CI verde (run
   38425864762), imagem **`sha-22a65c1`** (a `sha-06aaa0a` teve CI vermelho: não usar). Tem a T2, as fichas, 16
   correções da QA (`auditorias/2026-10-13/onda4-qa.md`) e a correção do painel intermitente (com o índice em
   `IF NOT EXISTS`, ensaiado). Esperando o dono: escolher a madrugada (02:00–05:00) e responder a pendência 20 do
   PRD (o suporte pode desligar e religar aluno? hoje pode). Para entrega própria: números de Mensagens e "Sem usar
   o app" em Métricas, cinco chaves de Configurações e o cartão "Coerência legal". Roteiro:
   `crystal-em-casa/publicar-prd.md`, "Publicação do painel novo (onda 4)"; ordem obrigatória: API parada →
   migração + backfill da auditoria → API nova.
4. **Fichas dos alunos.** SQL e imagem no ar. Falta o dono rodar, em Operação › Crystal › "Ficha completa de cada
   aluno": "Prever custo"; piloto de 20 com `openai/gpt-4.1-mini` (12 meses, teto US$ 5); outro de 20 com
   `anthropic/claude-haiku-4.5` (mesmo alcance e teto). Comparar fichas e custo.

5. **Mensagens: números do "não" (pedido do dono 13/10).** Em cada envio: entregues e não entregues (com o motivo),
   abertas e não abertas, cliques e não clicaram (sem botão, o painel diz isso), na lista Enviadas e no detalhe, e
   filtros "Não abriu"/"Não clicou" na tabela por aluno. Agente trabalhando em `painel/onda4` (sobre `22a65c1`);
   ao terminar, CI e imagem nova: **a etiqueta da onda 4 muda** e é ela que vai para a madrugada. Só vale para
   mensagens enviadas pelo painel novo (os avisos antigos não registraram entrega nem clique).
6. **Alma da Crystal no painel (onda 5, pedido do dono 13/10).** Decisões: **superadmin** edita, testa e publica;
   acompanhar com bateria de perguntas-padrão, amostra de conversas reais (👍/👎 e nota) e números do dia a dia;
   editáveis: a alma, as regras de formato e a base de conhecimento. Fatos levantados: a alma é
   `apps/crystal/prompt/crystal.md` (~17 mil caracteres, dentro da imagem: hoje mudar = publicar imagem nova); as
   regras de formato são o `BLOCO_FORMATO` em `apps/crystal/src/prompt.ts`; a base é a tabela
   `leticia_crystal_hybrid_search` do Supabase (27 trechos: 9 regras de ouro, exemplos, diretrizes e estágios), buscada
   pela Edge Function `crystal_hybrid_search` (embedding `openai/text-embedding-3-small`, 1536, pelo OpenRouter com o
   segredo `OPENROUTER_API_KEY_CRYSTAL` da função: **conferir de quem é essa conta**; se for da agência, a busca depende
   dela). Não existe papel superadmin (papéis: aluno, suporte, técnico, admin): proposta é uma lista de e-mails numa
   variável da API (`SUPERADMIN_EMAILS`), que só se muda na VPS. Construção em orquestração, sobre `painel/onda4`,
   numa branch `painel/onda5-alma`; nada publicado.
7. **Aluno liberado à mão (pedido da Letícia, 13/10, 1 ano).** Conferido no Supabase: não está em nenhuma base (nem
   compras, nem base da agência; por e-mail e por telefone). Caminho: no painel atual, Equipe › Alunos › "Nova conta
   local" (e-mail, nome; WhatsApp opcional) dá acesso na hora, sem prazo; depois da onda 4, na ficha dele, Ações ›
   Acesso (só admin, pede a senha de novo) com "Acesso até" 13/10/2027. O painel novo já tem conta local com "Acesso
   até" (o login é recusado depois da data). E-mail e telefone do aluno ficam fora do repositório.

8. **Limite semanal de imagens (pedido da Giseli/Igor, 13/10, para a madrugada).** 25 imagens por aluno por semana,
   zera todo domingo 00:00 de Brasília; passou do limite, a imagem não vai para o modelo e a Crystal manda mensagem com
   botão para o checkout de mais imagens (com texto junto, responde ao texto sem a imagem). Saldo de imagens extras
   que não zera, lançado à mão na ficha (admin e suporte, auditado); crédito automático pela Assiny fica para depois.
   Configurável no painel: limite (0 = sem limite), link do checkout, texto. Agente construindo na worktree
   `/home/user/cw-imagens` (branch `painel/onda4-imagens`), que no fim junta com `painel/onda4` e publica lá: **a
   etiqueta da onda 4 muda de novo**. Falta do dono: o link do checkout e quantas imagens cada compra dá.

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

## 5. Pendências antigas

- Giseli desligar o webhook da Assiny que ainda aponta para a agência.
- Decisão da migração final do site (degrau 2; resposta da AZAN).
- Sessão "Adicionar novo usuário Crystal" (outro sistema) esperando o dono.
- Branch `qa/painel-2026-10-10` do app pode ser apagada pelo dono no GitHub.
- A VPS pede reinício (atualização de kernel): fazer na janela 02:00–05:00, de preferência junto com a onda 4.

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
