# Painel intermitente: prova na VPS (13/10, tarde)

Saídas coladas pelo dono (resumidas; sem dado de aluno).

## crystal-conferir (bootstrap `182a12e`): TUDO LIGADO

- Produção em `sha-0e2f79d`. Painel sem modelo salvo: vale o padrão da imagem (modelo `anthropic/claude-haiku-4.5`,
  reserva `openai/gpt-4.1-mini`). Canal do app: `crystal` (direto).
- OpenRouter: chave aceita, saldo US$ 47,79, 461 modelos na lista; modelo e reserva existem e leem imagem.
- Pergunta como aluno: respondeu o claude-haiku-4.5 em 4,3 s (US$ 0,0029); reserva sozinha em 1,8 s (US$ 0,0022).
- Base de conhecimento entrou no turno (6 trechos); Supabase: login e `app_memoria_ler` respondem.

## painel-diagnostico 24 (bootstrap `c0379c9`)

- **A API foi morta por falta de memória 3 vezes em 16 horas** (`task: non-zero exit (137)`: há 16 h, 3 h e 55 min).
  O kernel registrou `Memory cgroup out of memory: Killed process (node) ... anon-rss: ~976 MB` com o limite de 1 GiB
  do serviço. Cada morte derruba a API (painel **e** conversa dos alunos) até o Swarm subir outra.
- Memória agora (logo depois de subir): API 196 MiB de 1 GiB; Crystal 103 MiB de 384 MiB (CPU 51%).
- Bate com a medição local da correção (`otimizacao/painel-rapido`): o painel de 30 dias usava ~780 MB e 45–77 s de
  CPU; depois, ~200 MB e 1,8 s. A tela atualiza a cada 60 s e o resultado guardado também durava 60 s.
- A seção 3 (leitura de 24 h de log) não terminou: o terminal do navegador perdeu a conexão. Os comandos colados
  depois (backup, `app-subir sha-3773e2e`, `crystal-conferir`) provavelmente não rodaram. Para a próxima: usar
  `painel-diagnostico` com 6 h e rodar dentro de `tmux`.
