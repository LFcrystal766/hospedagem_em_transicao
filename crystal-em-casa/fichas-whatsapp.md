# Fichas do WhatsApp: a memória completa antes do primeiro acesso (10/10/2026)

> **ATENÇÃO (12/10):** a imagem `sha-3e28974` (branch `otimizacao/etapa-fichas`) foi feita sobre
> `sha-74092e0`, antes da publicação de 10/10 (`sha-5a5b198`). **Não subir essa imagem:** desfaria o
> que entrou em produção depois. A implementação a publicar é a da branch `otimizacao/memoria-ficha`
> (ver PROXIMOS-PASSOS.md e publicar-prd.md). Este arquivo fica como registro do desenho e das partes
> que podem ser portadas (dois modelos, ensaio do piloto, rodada diária). O SQL vale para as duas.

Pedido do dono (10/10): "antes mesmo dos alunos chegarem ao app, você já consiga ter a
memória completa deles no app".

## O que muda

- **Antes:** na primeira mensagem no app, a Crystal trazia só os últimos 7 dias do WhatsApp e
  resumia em até 1.000 caracteres. O aluno esperava até 8 s, e quem não tinha anotações da
  Crystal do WhatsApp (cerca de 3 mil alunos) chegava quase sem memória.
- **Agora:** para cada aluno da base, a nossa Crystal lê o histórico **inteiro** do WhatsApp
  (tabela atual + arquivo da agência) e escreve uma **ficha** de até 4.000 caracteres: quem é,
  situação atual, pessoas, o que já tentou, objetivos, jeito e pendências. A ficha fica no
  Supabase (`crystal_memoria_ficha`, por customer_id) e entra no contexto **já na primeira
  mensagem**, sem espera. Os últimos 7 dias continuam chegando como hoje.
- **Custo-benefício (decisão de 10/10):** conversa curta vai direto ao Gemini 2.5 Flash;
  conversa longa é lida em blocos pelo Gemini 2.5 Flash-Lite (US$ 0,10 por milhão de tokens),
  que anota os fatos, e o Flash escreve a ficha. Preços conferidos no OpenRouter em 10/10.
  Estimativa para a base inteira: **US$ 60 a 80**. Teto de US$ 0,50 por aluno.
- **Ordem (pedido de 10/10):** quem conversou nos últimos 30 dias primeiro (3.740 alunos em
  10/10), do mais recente para o mais antigo. Depois, 90 dias (6.839) e todos (9.642).
- **Manutenção:** a chave "Atualizar as fichas toda madrugada" (03:30, teto de US$ 5 por
  noite) atualiza só quem conversou de novo no WhatsApp e cria a ficha de quem comprou pela
  Assiny. Quem não conversou de novo não gasta nada.

## Onde está cada peça

| Peça | Onde |
|---|---|
| SQL (tabela, fila em fatias, histórico por página, gravar, andamento, amostra) | `supabase/app_memoria_ficha.sql` |
| Teste do SQL (Postgres local com base falsa) | `supabase/testes/` |
| Crystal: `POST /v1/fichas/gerar` e `POST /v1/fichas/ensaio` | app, `apps/crystal/src/ficha.ts` |
| API: lote, teto, rodada diária; rotas `/staff/operacao/fichas` | app, `apps/api/src/services/fichas-lote.ts` |
| Painel: Operação > Crystal > "Fichas do WhatsApp" | app, `apps/web/components/equipe/operacao/FichasLote.tsx` |
| Piloto na VPS | `bootstrap-vps.sh fichas-ensaio [N]` |

Branch do app: `otimizacao/etapa-fichas` (a partir de `otimizacao/memoria-unica`).

## Passo a passo

### 1. OpenRouter (dono, no site)

O saldo de 09/10 (US$ 25,41) não paga a base inteira. Antes do lote grande:

1. Recarregar pelo menos US$ 100 (o piloto de 20 alunos custa menos de US$ 1).
2. Pôr um limite mensal na chave da Crystal em openrouter.ai/settings/keys.

### 2. SQL no Supabase (com o OK do dono)

Rodar `supabase/app_memoria_ficha.sql` inteiro no SQL Editor do "Crystal AI" (ou pelo
conector, com o OK). Ele só cria objetos novos e reescreve duas funções nossas
(`app_memoria_ler`, que passa a devolver a ficha, e `app_memoria_apagar`, que passa a apagar
a ficha também). Nada das tabelas da agência muda. Rodar de novo é seguro.

Atenção: se `app_telefone_chave.sql` ou `app_memoria_unica.sql` forem rodados de novo algum
dia, rodar este logo depois.

### 3. Imagem nova na VPS (dono)

```bash
cd /root/crystal
curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
echo "<sha256>  bootstrap-vps.sh" | sha256sum -c -
bash bootstrap-vps.sh backup
# NÃO: bash bootstrap-vps.sh app-subir sha-3e28974 (ver o aviso no topo)
```

(`<commit>` e `<sha256>` estão no PROXIMOS-PASSOS.md. Conferir antes, na aba Actions do
`crystal-web-chat`, que o `imagens-vps` da branch `otimizacao/etapa-fichas` terminou verde.)

Sem o SQL, nada quebra: a Crystal segue sem ficha e o painel mostra "não disponível".

### 4. Piloto de 20 (dono)

1. `/equipe` > Operação > Crystal > **Fichas do WhatsApp**: "Quem conversou nos últimos 30
   dias", limite **20**, teto **US$ 2** > Gerar fichas.
2. Quando terminar (a tela mostra "pronto" e o gasto), na VPS:
   ```bash
   bash bootstrap-vps.sh fichas-ensaio 20
   less /root/crystal/fichas-ensaio-*.md
   rm /root/crystal/fichas-ensaio-*.md
   ```
   Para cada aluno: a ficha e a mesma mensagem ("Oi Crystal! Lembra de mim?") respondida sem
   memória, só com as anotações (como era até hoje) e com a ficha. O arquivo tem conversa de
   aluno: só o root lê, e é para apagar depois de ler.
3. `bash bootstrap-vps.sh app-custo 2` mostra o custo da ficha por modelo (linha "ficha") e
   se houve raciocínio cobrado (coluna racioc., que deve ficar em 0).

### 5. Lotes (dono, no painel, depois do piloto aprovado)

1. 30 dias, sem limite, teto ≈ custo médio do piloto × 3.740 + 20% de folga.
2. 90 dias, mesmo cálculo para o que falta.
3. Todos.

Se parar no meio (teto, sem crédito, VPS reiniciou), é só gerar de novo: só entra quem falta.
O motivo da parada aparece no resumo do lote.

### 6. Manutenção

Ligar "Atualizar as fichas toda madrugada" na mesma seção.

## Volta

- **Código:** `bash bootstrap-vps.sh app-subir sha-74092e0` (a imagem anterior ignora a ficha).
- **SQL:** ver o cabeçalho de `supabase/app_memoria_ficha.sql` (rodar de novo os dois SQL
  anteriores, nesta ordem, e só então apagar as funções e a tabela). Testado em Postgres local.

## Segurança e LGPD

- A Crystal não tem rota pública: só a API do app chama `/v1/fichas/*`, com a chave do agente.
- Nenhum texto de conversa ou de ficha vai para log, auditoria ou resposta do painel: só
  contagens, custos e códigos de erro. O ensaio do piloto grava o texto só num arquivo 600 na
  VPS.
- As funções SQL são `security definer`, com execute só para a service_role, e a tabela não
  tem grant para ninguém.
- A exclusão da conta pelo aluno apaga a ficha (`app_memoria_apagar`) e deixa a marca
  "apagado": a fila e a rodada diária nunca refazem a ficha de quem pediu para apagar.
- Risco aceito: o que o próprio aluno escreveu no WhatsApp entra na ficha dele e, portanto,
  no contexto das respostas para ele mesmo. Não alcança outro aluno.
- A ficha não guarda CPF, e-mail, telefone, endereço nem dados de pagamento (instrução ao
  modelo); o OpenRouter recebe só texto, com `data_collection: deny`.
