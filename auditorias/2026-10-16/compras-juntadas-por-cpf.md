# Compras juntadas num cadastro só, na base antiga (16/10/2026, noite)

Pedido do dono: um aluno não conseguia entrar; "altere o e-mail dele e verifique". Sem dado pessoal aqui.

- **O que aconteceu:** na base antiga (agência), `leticia_crystal_customers` tem 1 cadastro por CPF. Um mesmo CPF
  apareceu em 25 assinaturas de pessoas diferentes (nomes e e-mails diferentes em `raw_data->'data'->'client'`), e a
  integração da agência juntou todas num cadastro só, que ficou com o e-mail e o nome da última compra (20/09). O login
  (`app_verificar_login_email`) procura pelo e-mail do cadastro, então só quem comprou por último entra; os outros
  ouvem "não encontramos seu cadastro".
- **Por que não trocar o e-mail do cadastro:** trocaria a conta de quem entra hoje (a última compradora) e daria a
  esse aluno a conta e a conversa de outra pessoa (a identidade da conta no app é o id do cadastro).
- **O que foi feito com o aluno do pedido:** linha nova em `crystal_compras` (status `active`, produto
  "Liberação manual", `transacao` `manual-20261016-assinatura-agencia-23678`, que aponta para a assinatura dele na
  base antiga). Conferido em consulta separada: o login acha a conta nova, `liberado = true`. Ele entra com o e-mail
  da compra e ganha uma conta só dele. Volta: `delete from crystal_compras where transacao =
  'manual-20261016-assinatura-agencia-23678';`.
- **Tamanho do problema** (assinaturas `active`/`pending` com fim no futuro, cujo e-mail do comprador não está em
  nenhum cadastro nem em `crystal_compras` ativa):
  - 10.376 assinaturas válidas; antes da correção acima, 37 compras com e-mail que o login não acha (33 ativas,
    4 pendentes), em 19 cadastros: 19 no cadastro do CPF repetido e 18 isolados. Depois dela, 36.
  - **18 no mesmo cadastro do CPF repetido**: pessoas diferentes, pagaram e não entram. Correção proposta: a mesma
    linha em `crystal_compras` para cada uma (aguarda o "sim" do dono).
  - 18 casos isolados (1 por cadastro): na maioria a mesma pessoa com outro e-mail ou um e-mail trocado depois (as
    trocas feitas pela `app_aluno_trocar_email` aparecem aqui), e essa pessoa entra pelo e-mail do cadastro. Não
    mexer sem pedido.
- **Daqui para frente:** compras novas chegam pelo nosso n8n em `crystal_compras`, uma linha por compra e por e-mail;
  o problema é só da base antiga (até 12/10).
