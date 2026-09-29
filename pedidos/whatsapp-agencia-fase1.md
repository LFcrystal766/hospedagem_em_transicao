# Mensagem para o grupo com a agência (Tuan), 29/09/2026

Contexto do grupo: Tuan Medeiros é o contato técnico da Academia Lendária.
Em 20/09 a Crystal caiu por certificado SSL vencido na infra deles. Em 21/09 o
Igor perguntou de backup (número reserva + app). Em 28/09 o Tuan perguntou se
o webhook do app foi criado para eles fazerem a conexão. A mensagem abaixo
responde com o status da fase 1 e as três perguntas; a linha do webhook é do
Luiz/Igor preencher.

---

Bom dia, Tuan. Tudo bem?

Novidade do nosso lado: a base da fase 1 da migração já está no ar, seguindo o guia e os arquivos que vocês mandaram.

- VPS Hostinger KVM 4 (4 vCPU, 16 GB, 200 GB), Ubuntu 24.04
- Swarm ativo, rede network_swarm_public, Traefik v2.11.3 com certificado válido em painel., editor. e webhook.crystalnowpp.com.br
- Portainer, Postgres 16, Redis 7 e n8n 1.123.10 em modo fila (editor, webhook e worker), tudo 1/1, limpeza de execuções ligada
- Chave do n8n gerada e no cofre

Uma dica que pode servir pra outros clientes de vocês: o Docker 29 recusa a API 1.24 do Traefik v2, e o Traefik sobe sem enxergar serviço nenhum. Resolvemos com "min-api-version": "1.24" no daemon.json, sem mexer nos arquivos de vocês.

Antes de eu criar as contas, três perguntas rápidas:

1. Supabase: qual o compute size do projeto da Crystal hoje? Pra eu contratar a organização de destino já no tamanho certo.
2. OpenRouter: a conta "já existente" está no nome de vocês ou no nosso? Se for de vocês, criamos a nossa e vocês reapontam a chave na fase 2.
3. Região do projeto do Supabase: a VPS ficou em Boston (EUA). Se o banco estiver em outro continente, vale alinhar antes da transferência.

Com as respostas, mando o convite de Owner pra agencia@academialendaria.ai no Supabase e o e-mail do GitHub.

Sobre o webhook do app que você perguntou dia 28: [IGOR/LUIZ: status aqui]
