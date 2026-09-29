# Mensagem para o grupo com a agência (Tuan), 29/09/2026

Contexto do grupo: Tuan Medeiros é o contato técnico da Academia Lendária.
Em 20/09 a Crystal caiu por certificado SSL vencido na infra deles. Em 21/09 o
Igor perguntou de backup (número reserva + app). Em 28/09 o Tuan perguntou se
o webhook do app foi criado para eles fazerem a conexão. A linha do webhook é
do Luiz/Igor preencher. Versão final, com Supabase e GitHub já feitos.

---

Bom dia, Tuan. Tudo bem?

Do nosso lado, a fase 1 da migração está pronta, seguindo o guia e os arquivos que vocês mandaram:

- VPS Hostinger KVM 4 (4 vCPU, 16 GB, 200 GB), Ubuntu 24.04
- Swarm ativo, rede network_swarm_public, Traefik v2.11.3 com certificado válido em painel., editor. e webhook.crystalnowpp.com.br
- Portainer, Postgres 16, Redis 7 e n8n 1.123.10 em modo fila (editor, webhook e worker), tudo 1/1, limpeza de execuções ligada, chave do n8n no cofre
- Supabase: organização no plano Pro, convite de Owner enviado pra agencia@academialendaria.ai
- GitHub: repositório privado LFcrystal766/crystal-ia. O e-mail da conta, pro convite de vocês, é crystal@leticiafelisberto.com

Então podem mandar o código pro repositório e aceitar o convite do Supabase quando quiserem, que a gente entra na fase 2.

Uma dica que pode servir pra outros clientes de vocês: o Docker 29 recusa a API 1.24 do Traefik v2, e o Traefik sobe sem enxergar serviço nenhum. Resolvemos com "min-api-version": "1.24" no daemon.json, sem mexer nos arquivos de vocês.

Três coisas pra alinhar junto:

1. Supabase: qual o compute size do projeto da Crystal hoje? Pra eu ajustar a organização de destino antes da transferência, se precisar.
2. OpenRouter: a conta "já existente" está no nome de vocês ou no nosso? Se for de vocês, criamos a nossa e vocês reapontam a chave.
3. Região do projeto do Supabase: a VPS ficou em Boston (EUA). Se o banco estiver em outro continente, vale alinhar antes.

Sobre o webhook do app que você perguntou dia 28: [status aqui]
