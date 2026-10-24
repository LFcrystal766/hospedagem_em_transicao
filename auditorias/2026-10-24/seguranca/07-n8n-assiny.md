# Fluxos do n8n da Assiny: correções de segurança de 24/10 (merge `f19ef9f`)

Branch `seguranca/n8n-assiny` (3 commits: `f5ac9ab` SQL, `04f379e` fluxos e scripts, `10ecf03` README). Nada de produção foi
alterado; o n8n real só foi lido para comparar. Roteiro de aplicação em `crystal-em-casa/n8n/README.md`.

## O que a Assiny oferece e o limite que fica

Documentação oficial lida em 24/10: **só webhooks**. Não há API pública para consultar transação ou assinatura, não há
assinatura HMAC, não há IPs de saída publicados. A única opção de segurança é "Avançado > Headers personalizados" (até 3
cabeçalhos). Nomes confirmados: `approved_purchase` (status `paid`), `refunded_purchase` (`refunded`) e **`charged_back`**
(`chargedback`). **Achado novo:** `charged_back` não estava na lista de bloqueio da função SQL nem no padrão `REFUND_EVENTS`
da API: um chargeback real seria ignorado nas duas pontas. SQL novo inclui; API corrigida em `3c343df` do app.

Sem confirmação possível na fonte, a defesa é em camadas: dois segredos (caminho secreto + cabeçalho `x-crystal-token`,
403 antes de executar), validação de formato/tamanho/coerência no primeiro nó (400 sem tocar no Supabase), bloqueio só com
compra conhecida no SQL (reembolso forjado não bloqueia ninguém), e-mail com texto fixo e saudação só com letras, resumo
2x/dia com alerta de volume. **Limite que fica:** quem tiver o caminho secreto E o token ainda consegue um
`approved_purchase` forjado com id de produto da lista e liberar um e-mail (mais o e-mail de boas-vindas, de texto fixo).
Não consegue mais bloquear, mandar texto livre pelo remetente oficial, estourar tamanhos nem deixar CPF nas execuções.

## Por achado

| ID | Situação |
|---|---|
| INT-06 (alta) | Corrigido no que é possível sem API/assinatura (acima). IPs da Assiny no Traefik: opcional, depois de uma semana de log em `webhook.` |
| INT-08 | Execuções com sucesso não são guardadas; CPF/metadata/endereço/comissões cortados antes de qualquer nó; `conferir-fluxos.py` exige isso. `EXECUTIONS_DATA_MAX_AGE` 48 h: infra |
| INT-09 | Resposta à Assiny só depois da API e do e-mail; API fora = 500 + Error Workflow; reenvio = `repetido` com `anterior=bloquear` e API chamada de novo; **conciliação 06:10/18:10** (`app_compras_conciliacao`) reenvia bloqueios da janela de 23 h e manda resumo à equipe. Lado do app (`/auth/refresh` reconsulta a base 1×/dia) feito em `c69c496` |
| INT-16 | Evento desconhecido gravado como `ignorado_evento` sem dado pessoal; limites de `nome`/`telefone`/`transacao`; `charged_back` na lista |
| INT-17 | Só primeiro nome, só letras, até 60; e-mail fora do texto; `Idempotency-Key` por transação |
| INT-01 (n8n) | Credencial própria "API imagens" (`IMAGENS_WEBHOOK_SECRET`); fluxo manda Bearer + `transaction.updated_at` como a API exige hoje |
| INT-07 | Menor privilégio: papel Postgres `n8n_compras` (nologin, membro de `authenticator`, executa só `app_compra_evento` e `app_compras_conciliacao`, sem tabela); o script gera o JWT do papel sem guardar o segredo; credencial Custom Auth; Resend com chave só do n8n. Apagar a credencial antiga (service_role) e rotacionar: dono |
| INT-14, INT-21 | Não são n8n |

## Comparação com o que está no ar (só leitura)

Fluxo ativo = versão de 13/10 (10 nós, igual ao `compra-assiny.json` do commit `b449e66`), com caminho de sufixo secreto e
**sem autenticação por cabeçalho**. Responde 200 à Assiny antes de chamar a API. O JSON novo volta a exigir o cabeçalho; a
sequência do README configura o cabeçalho na Assiny antes da troca (o fluxo antigo o ignora), sem janela de 403.

## Credenciais e variáveis novas (nomes)

Credenciais no n8n: `Assiny · x-crystal-token`, `Supabase · n8n compras` (Custom Auth), `Resend · n8n`, `API reembolso`,
`API imagens`. Arquivo `/root/crystal/n8n-compras.segredos` (0600): `ASSINY_N8N_TOKEN`, `N8N_SUPABASE_MODO`,
`N8N_SUPABASE_CHAVE`, `N8N_SUPABASE_APIKEY`, `N8N_RESEND_CHAVE`, `N8N_PRODUTO_TESTE`. Papel Postgres `n8n_compras`; função
nova `app_compras_conciliacao(int,int,int)`. E-mail da equipe no nó "Configuração" dos fluxos de conciliação e de erro.

## Validações

SQL rodado num Postgres 16 local com base falsa (`anon`/`authenticated`/`service_role`/`authenticator`): idempotente;
teste `supabase/testes/app_compras_seguranca_n8n.teste.sql` (forjado ignorado, repetido, chargeback da agência bloqueia,
desconhecido sem dado pessoal, limites, conciliação, privilégios do papel). JSON dos 3 fluxos válidos; `conferir-fluxos.py`
passa; nós de código executados num harness em Node. Ressalva: Switch v3.2, Custom Auth e Respond→Stop and Error foram
escritos a partir da documentação do n8n, não executados num n8n real; o passo 7 do README (teste de ponta a ponta na VPS)
é o que confirma.
