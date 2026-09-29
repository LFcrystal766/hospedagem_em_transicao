# E-mail para a agência: três perguntas antes de fechar a fase 1

Para: o contato da Academia Lendária que conduz a migração da Crystal
Assunto: Crystal em infraestrutura própria: base no ar e três perguntas

---

Oi, pessoal.

A base da fase 1 já está no ar, seguindo o guia "Implantação da Stack" e os
arquivos da pasta stacks-exemplo que vocês mandaram:

- VPS Hostinger KVM 4 (4 vCPU, 16 GB, 200 GB), Ubuntu 24.04
- Docker Swarm ativo, rede `network_swarm_public`, Traefik v2.11.3 com
  certificado válido em painel., editor. e webhook.crystalnowpp.com.br
- Portainer, Postgres 16, Redis 7 e n8n 1.123.10 em modo fila (editor,
  webhook e worker), todos 1/1, com limpeza automática de execuções ligada
- Chave de criptografia do n8n gerada e guardada em cofre

Uma observação técnica que pode ser útil para outros clientes de vocês: o
Docker atual (29.x) recusa a API 1.24 que o Traefik v2 usa, e o Traefik sobe
sem enxergar nenhum serviço. Resolvemos com `"min-api-version": "1.24"` no
daemon.json, sem mexer nos arquivos de vocês.

Antes de criar as contas, preciso de três respostas:

1. **Supabase.** Qual o compute size do projeto da Crystal hoje? Quero saber
   se o plano Pro básico cobre ou se o projeto exige um compute maior, para
   contratar a organização de destino já no tamanho certo.

2. **OpenRouter.** O guia diz "conta já existente". Ela está no nome de vocês
   ou no nosso? Se for de vocês, criamos a nossa e vocês só reapontam a chave
   na fase 2.

3. **Região.** Em que região está o projeto do Supabase? A VPS ficou em Boston
   (EUA). Se o projeto estiver em outro continente, vale conversar antes da
   transferência.

Assim que responderem, crio a organização no Supabase e mando o convite de
Owner para agencia@academialendaria.ai, junto com o e-mail do GitHub para o
acesso ao código.

Abraço,
Luiz
