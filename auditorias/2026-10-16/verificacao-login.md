# Verificação geral do login dos alunos (16/10/2026, fim da tarde)

Pedido do dono depois de alguns alunos dizerem que "não encontram o cadastro". Só leitura, sem dado pessoal aqui.

- **Supabase:** 24 h de `app_verificar_login_email`, de 12 a 57 chamadas por hora, todas HTTP 200.
- **API:** `POST /auth/login` com e-mail inexistente responde 404 `LOGIN_NOT_FOUND` em ~0,7 s.
- **Compras:** chegando pelo nosso n8n desde 10/10 (Recuperação) e 12/10 (produto principal): 39, 39, 43, 35 e 31
  por dia de 12 a 16/10; 155 ativas, 33 reembolsadas, 1 cancelada em `crystal_compras`. Nenhum evento
  `ignorado_produto`.
- **Base antiga (agência):** clientes novos até 12/10 00:23 (depois disso só a nossa tabela recebe compras); os
  acessos ainda são atualizados (último hoje 17:21), sinal de que o webhook antigo da agência continua ligado.
- **Função de login em produção ≠ arquivo do repositório:** desde 11/10 ("fim dos lotes") quem tem assinatura ativa
  ou pendente na base (em `leticia_crystal_active_accesses` ou `leticia_crystal_subscriptions`, com fim no futuro) ou
  compra ativa na nossa tabela é `liberado = true`; `is_in_rollout` não conta mais; reembolso pela nossa tabela
  bloqueia. Cópia fiel em `crystal-em-casa/supabase/app_verificar_login_email.producao-20261016.sql`.
- **Ponto de atenção:** 3 produtos da lista `crystal_compras_produtos` nunca mandaram evento ao nosso n8n:
  "Crystal + Todos os Cursos Letícia Felisberto", "Crystal - Do Oi ao Encontro" e "CRYSTAL - A nova Melhor Amiga dos
  Homens - Trimestral". Se algum deles ainda vende, o webhook da Assiny pode não estar apontado para o nosso n8n e
  esses compradores não entram (nem na base antiga, que parou em 12/10). Conferir na Assiny.
- Casos do dia: 3 trocas de e-mail feitas pela função (todas `trocado`); 1 aluno "sem cadastro" estava liberado;
  2 alunos não aparecem em lugar nenhum (nem e-mail parecido): pedir o comprovante (produto e transação).
