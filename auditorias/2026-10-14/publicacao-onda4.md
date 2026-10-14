# Publicação do painel novo (onda 4), 14/10/2026 ~09:25 UTC (06:25 de Brasília)

Feita pelo dono na VPS, fora da janela (de manhã cedo, movimento baixo), com o bootstrap `c0379c9`.

- Pré-checagem: produção em `sha-3773e2e`, `crystal-conferir` TUDO LIGADO (saldo OpenRouter US$ 41,38), disco 174 GB
  livres, backup `20261014T092053Z` completo e no R2.
- `app-api-parar --confirmo`: API parada.
- `app-auditoria-backfill sha-9ec8151`: todas as migrações aplicadas (até `pa16_01_imagens_semana`), backfill
  `{"total":80,"preenchidas":80,"ok":true,"conferidas":80,"quebra":null}` em 10 s.
- `app-subir sha-9ec8151`: os três serviços em `sha-9ec8151`, nenhum voltou; app. e api. 200; base de alunos ok.
- `app-painel-conferir`: migrate status limpo, 11 migrações `pa*`, `scheduled_notices` apagada, 80 linhas de
  auditoria com hash, `cadeia_ok: true`, telas novas 200. Três "!" falsos: `/equipe/operacao`, `/equipe/avisos` e
  `/equipe/painel` respondem 200 com `NEXT_REDIRECT;replace;<destino>;307` no corpo (o layout da equipe é de cliente,
  então o Next redireciona pelo corpo, não pelo cabeçalho); conferido daqui que levam a `/equipe/alunos?aba=lotes`,
  `/equipe/mensagens` e `/equipe/metricas`. A conferência passou a aceitar isso (bootstrap seguinte).
- `crystal-conferir` depois: TUDO LIGADO (haiku-4.5 em 2,9 s; reserva gpt-4.1-mini; 6 trechos da base; saldo US$ 41,20).

Falta: configurar as imagens no painel (link do checkout e pacotes), rodar o script do n8n
(`compra-assiny-imagens.py`, commit `8cb2ea9`; o `b449e66` não achava o fluxo por causa do sufixo secreto do webhook), reiniciar a VPS e, em 14/10, `painel-diagnostico 6`.

## n8n: repasse do pacote de imagens (14/10 ~09:38 UTC)

- `compra-assiny-imagens.py` do commit `b449e66` não achou o fluxo: em produção o webhook é `assiny-compras-<sufixo
  secreto>`. Corrigido em `cbffaa4` (acha pelo começo do caminho; o caminho real fica só em memória).
- Com `cbffaa4`: cópia de antes em `/root/crystal/n8n-copias/compra-assiny-20261014-093750.json`; fluxo `qMRPSFT9OAScVUP4`
  importado com o mesmo id e ativo; editor, webhook e worker reiniciados; webhook registrado. Conferido pelo conector do
  n8n: 10 nós, "Responder à Assiny" → "Produto fora da lista?" → "Repassar ao app (pacote de imagens)" para
  `/webhooks/imagens`, ativo.
- O "500 em vez de 403" do teste sem token era esperado: o webhook de produção não pede token no cabeçalho (protegido só
  pelo caminho secreto); o POST vazio roda o fluxo, o Supabase recusa (EVENTO_INVALIDO) e responde 500, sem compra.
  A conferência deixou de exigir o 403 nesse caso (`8cb2ea9`).
