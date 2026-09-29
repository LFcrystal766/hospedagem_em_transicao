# Mensagem para o grupo com a agência (Tuan), 29/09/2026

Contexto do grupo: Tuan Medeiros é o contato técnico da Academia Lendária.
Em 20/09 a Crystal caiu por certificado SSL vencido na infra deles. Em 21/09 o
Igor perguntou de backup (número reserva + app). Em 28/09 o Tuan perguntou se
o webhook do app foi criado para eles fazerem a conexão.

Revisada em 29/09, depois de ler o código do app (`LFcrystal766/crystal-web-chat`).
O agente da agência só conversa com o LendChat: recebe o webhook dele e responde
pela API dele. O app espera outro formato (`docs/crystal-api.md` do app). Por isso
o parágrafo do webhook agora pergunta como o agente atende um canal que não é o
LendChat, e diz o que o app manda e espera. Endereços conferidos às 02:57 de
29/09: health 200, POST sem segredo 403, `editor./healthz` 200, `painel.` 200.
O repositório `crystal-ia` continua vazio.

29/09, depois: OpenRouter confirmado como conta nossa (o Luiz tem o acesso).
Nenhuma chave existente pode ser apagada antes do corte: uma delas é a do
agente em produção. A pergunta 2 virou pedido de confirmação de qual é.

---

Bom dia, Tuan. Tudo bem?

Do nosso lado, a fase 1 da migração está pronta, seguindo o guia e os arquivos que vocês mandaram:

- VPS Hostinger KVM 4 (4 vCPU, 16 GB, 200 GB), Ubuntu 24.04
- Swarm ativo, rede network_swarm_public, Traefik v2.11.3 com certificado válido em painel., editor. e webhook.crystalnowpp.com.br
- Portainer, Postgres 16, Redis 7 e n8n 1.123.10 em modo fila (editor, webhook e worker), tudo 1/1, limpeza de execuções ligada, chave do n8n no cofre
- Supabase: organização no plano Pro, convite de Owner enviado pra agencia@academialendaria.ai
- GitHub: repositório privado LFcrystal766/crystal-ia, já com convite de colaborador pra agencia@academialendaria.ai (podem subir o código direto). O e-mail da nossa conta, caso precisem, é crystal@leticiafelisberto.com
- Registry ghcr.io com token de publicação, já cadastrado no Portainer
- Netlify: conta criada, esperando o código do dashboard
- Telegram: bot e grupo de alertas prontos, com o ID do grupo

Então podem mandar o código pro repositório e aceitar o convite do Supabase quando quiserem, que a gente entra na fase 2.

Uma dica que pode servir pra outros clientes de vocês: o Docker 29 recusa a API 1.24 do Traefik v2, e o Traefik sobe sem enxergar serviço nenhum. Resolvemos com "min-api-version": "1.24" no daemon.json, sem mexer nos arquivos de vocês.

Três coisas pra alinhar junto:

1. Supabase: qual o compute size do projeto da Crystal hoje? Pra eu ajustar a organização de destino antes da transferência, se precisar.
2. OpenRouter: a conta é nossa e estou com acesso. Na fase 2 eu crio uma chave nova só pra VPS; a atual de vocês segue até o corte. Me confirma qual chave é a que o agente usa hoje, pra eu não mexer nela.
3. Região do projeto do Supabase: a VPS ficou em Boston (EUA). Se o banco estiver em outro continente, vale alinhar antes.

Sobre o webhook do app: deixamos um endereço fixo no n8n novo, já no ar.
POST https://webhook.crystalnowpp.com.br/webhook/crystal-app, autenticado pelo header X-Webhook-Secret (te mando o valor no privado). Teste sem segredo: GET https://webhook.crystalnowpp.com.br/webhook/crystal-app/health

Pra fechar a conexão, preciso entender três pontos do lado de vocês:

a) Pelo guia, o agente recebe o webhook do LendChat e responde pela API do LendChat. Pra atender o app, a ideia é o agente receber a mensagem do app e devolver a resposta direto? Ou vocês pensaram em outro caminho?
b) O app manda contact_id, conversation_id e o texto da mensagem, e espera o texto da resposta no retorno. Mensagem que a Crystal manda por iniciativa própria chega no app assinada (HMAC), com id do evento, horário, contato, tipo e conteúdo. Te mando o documento com o formato. Se o de vocês for diferente, a gente adapta do nosso lado.
c) O login do app confere CPF + e-mail na base de clientes. Essa base é a do Supabase da Crystal? E qual identificador do cliente o agente usa: telefone ou o id do Supabase?

---

## Situação

Enviada ao Tuan pelo Luiz (o Luiz diz "ontem", em 29/09). Sem resposta até
29/09. Qual versão foi enviada não está registrado aqui.

Propriedade: código, prompts e base de conhecimento da Crystal são nossos
(confirmado pelo Luiz em 29/09). Não precisa perguntar à agência.

## Cobrança (para mandar se não houver resposta até 01/10)

Oi, Tuan. Tudo certo? Retomando a mensagem de ontem: do nosso lado a fase 1
está pronta, só esperando vocês pra começar a fase 2.

Somei uma pergunta às que mandei:

4. Prompts da Crystal: vocês conseguem mandar já o prompt e a base de
conhecimento que ela usa hoje? Queremos testar o app com o mesmo jeito dela
enquanto a fase 2 não começa.

Consegue me dar uma previsão de quando o código sobe pro repositório?
