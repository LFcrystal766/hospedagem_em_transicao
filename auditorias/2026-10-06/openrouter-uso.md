# Uso do OpenRouter, lido de dentro da VPS em 06/10/2026

Consulta feita de dentro do contêiner `app_crystal`, com a chave que já está lá
(`/api/v1/key` e `/api/v1/credits`). A chave não saiu da VPS. O relatório por
chave e modelo (`/api/v1/activity`) respondeu 403: só chave de gerenciamento lê.

| Medida | Valor |
|---|---|
| Uso da chave da Crystal, total | US$ 0,067 |
| Uso da chave da Crystal, este mês | US$ 0,061 |
| Limite da chave | nenhum |
| Créditos comprados na conta | US$ 6.220 |
| Créditos consumidos na conta | US$ 6.176 |
| Saldo | cerca de US$ 44 |

## Leitura

- A chave do app gastou centavos. 99,99% do consumo da conta veio de outra chave,
  quase certamente a Crystal antiga da agência (LendChat/n8n). Onde o dinheiro vai só
  aparece em openrouter.ai/activity, filtrando por chave.
- Com US$ 44 de saldo, se o outro consumidor continuar ativo o OpenRouter passa a
  responder 402 e a nossa Crystal para com "sem crédito". Recarregar ou ligar a
  recarga automática. A vigia avisa quando o saldo fica abaixo do LIMITE dado no
  `vigia-config`.
- A chave da Crystal está sem limite: pôr limite mensal em openrouter.ai/settings/keys
  (contenção se vazar).

## O que mudou no código (branch `otimizacao/custo-modelo`, commit `16596eb`)

- Cada turno e cada resumo escrevem no log `modelo: uso do turno|resumo` com
  modelo, tokens de entrada, de cache, de saída, de raciocínio, custo em US$ e ms.
  Só números. `bash bootstrap-vps.sh app-custo [HORAS]` soma e projeta 30 dias.
- Prompt fixo marcado com `cache_control` (Anthropic via OpenRouter). Abaixo de
  4.096 tokens fixos o Haiku 4.5 não cacheia nada; o ganho vem com a base de
  conhecimento da agência.
- `CRYSTAL_MODEL_RESUMO`: modelo próprio para o resumidor em segundo plano.

## Preços (OpenRouter, por milhão de tokens, 06/10)

| Modelo | Entrada | Cache | Saída |
|---|---|---|---|
| anthropic/claude-haiku-4.5 (atual) | 1,00 | 0,10 | 5,00 |
| anthropic/claude-sonnet-5.5 | 2,00 | 0,20 | 10,00 |
| openai/gpt-4.1-mini (reserva) | 0,40 | 0,10 | 1,60 |
| openai/gpt-5.4-nano | 0,20 | 0,02 | 1,25 |
| google/gemini-3.8-flash | 0,75 | 0,075 | 3,75 |
