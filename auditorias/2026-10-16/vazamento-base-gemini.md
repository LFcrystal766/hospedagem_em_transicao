# Crystal mandou a base de conhecimento ao aluno (16/10/2026, noite)

Relato da equipe com vídeo (tela do app, conversa com a Crystal): várias bolhas seguidas com o texto interno da base
de conhecimento ("Base de conhecimento para esta mensagem", `[principio_central_de_tom]`, "1. PRINCÍPIO CENTRAL DE
TOM", "2. O EQUILÍBRIO CERTO DE TOM", "O que EVITAR"), e o aluno perguntando por que ela não respondia.

- **Causa provável:** o modelo do painel estava em `google/gemini-2.5-flash-lite` (visto no `crystal-conferir` de
  16/10 20:25 UTC; padrão da imagem e de antes: `anthropic/claude-haiku-4.5`). A Crystal manda várias mensagens de
  sistema (prompt fixo, trechos da base, resumo, memória, data/hora, anexo, risco); modelos não Anthropic tratam mal
  sistema no meio da conversa e o Flash-Lite devolveu os trechos como resposta.
- **Contenção imediata:** voltar o modelo para `anthropic/claude-haiku-4.5` no painel (Operação › Crystal › Modelo) e
  conferir com `crystal-conferir`.
- **O que vazou:** o texto de orientação de tom da base (material de método da Letícia), não segredo técnico, chave
  ou dado de aluno.
- **Correção no código (agente, 16/10):** trava na saída que descarta resposta com marcador interno e tenta a reserva;
  para modelos não Anthropic, uma mensagem de sistema só. Em `painel/onda4`, com merge em `painel/onda5-alma`; sai na
  próxima imagem (depende da cobrança do GitHub).
- **Medir o alcance (VPS, só leitura):** ver o comando em `CONTINUAR-EM-OUTRA-CONTA.md`, item 17.
