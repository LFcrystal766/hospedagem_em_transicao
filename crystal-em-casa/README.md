# Crystal em casa: a VPS do app

Frente separada da migração do site. Aqui é o **app da Crystal** (agente em
Python + n8n) saindo da infraestrutura da agência (Academia Lendária) para uma
VPS nossa. O site WordPress continua no plano dos três degraus, em
`../PROXIMOS-PASSOS.md`. As duas frentes só se cruzam na zona DNS do Cloudflare.

O checklist interativo está no artefato
[Crystal em Casa](https://claude.ai/artifact/C6yKAGUMgK9pqRaTeZ7M4W) (25 itens,
fase 1). Esta pasta guarda o material da agência e o que a sessão do Claude
precisa para agir.

## Material da agência (10/09/2026)

| Arquivo | O que é |
|---|---|
| `guia-implantacao-stack.html` | Guia "Crystal AI · Implantação da Stack": fases, requisitos, capacidade medida, contas, corte |
| `stacks-exemplo/` | Os 7 arquivos do Docker Swarm (Traefik, Portainer, Postgres, Redis, editor, webhook, worker do n8n) + MCP opcional, com placeholders |

Nenhum arquivo tem segredo: os valores a trocar estão em MAIÚSCULAS ou como
`seudominio.com.br`. Ao usar, trocar por `crystalnowpp.com.br` e gerar a senha
do banco e a chave de criptografia do n8n **uma vez**, iguais em todos os
arquivos, guardadas em cofre. A chave nunca muda depois de o n8n estar em uso.

## O que o guia exige e o checklist resume

- Agente em 4 contêineres (API na porta 8000, worker de entrada, worker de envio
  com **1 réplica fixa**, Redis próprio). O corte é reapontar o webhook do LendChat.
- Supabase: **transferência de projeto** entre organizações. Convite de Owner
  para `agencia@academialendaria.ai` na organização nova (plano Pro). Conexão do
  agente pelo **Session Pooler, porta 5432** (o Transaction Pooler 6543 derruba).
- GitHub: repositório privado, imagem no `ghcr.io`, token `write:packages`,
  build com `--platform linux/amd64` (Mac gera ARM), tag por versão, nunca `latest`.
- Traefik **v2** (não v3). Nomes que precisam bater: rede `network_swarm_public`,
  entrada `websecure`, emissor `letsencryptresolver`.
- n8n 1.123.10+, modo fila, limpeza automática de execuções, heap do Node em
  ~75% do limite do contêiner.
- Fase 1 termina com os 16 pontos de "Base pronta" verdadeiros; aí avisa a
  agência e a fase 2 começa (código, transferência do Supabase, imagem, ensaio, corte).

## Situação em 29/09/2026

| Item | Estado |
|---|---|
| VPS | **Contratada.** Hostinger KVM 4: 4 vCPU, 16 GB, 200 GB, Ubuntu 24.04, Boston (EUA), IP `177.7.61.136`. Porta 80 ainda fechada (nada instalado) |
| DNS `painel`, `editor`, `webhook` | **Feito em 29/09**, pelo painel: A → `177.7.61.136`, cinza. Conferido de fora (AdGuard DoH) |
| Docker + Swarm, rede, volumes, label do nó | **Próximo.** Pelo Web console da Hostinger |
| Stacks 00 a 06 | Faltam |
| Supabase Pro + convite | Falta. Antes, perguntar à agência o compute size do projeto |
| GitHub, Netlify, Telegram | Faltam |
| Respostas da agência | Compute size do Supabase, dono da conta OpenRouter, quem monta a fase 1 |

Boston em vez de São Paulo não fere o guia: o tempo do atendimento é dominado
pela resposta do modelo, não pela rede. Vale conferir a região do projeto do
Supabase quando ele for transferido, para o banco não ficar em outro continente
que a VPS.

## Conferir o DNS a qualquer hora, sem token

```bash
scripts/cloudflare-crystal-vps-dns.sh conferir
```

Resolve os três nomes por DNS-over-HTTPS e confere se apontam para o IP da VPS
e se `server.` (Stape) continua cinza. Sai 0 quando os três estão certos.
