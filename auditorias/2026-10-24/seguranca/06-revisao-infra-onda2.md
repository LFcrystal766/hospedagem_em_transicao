# Revisão adversarial da infra da onda 2 (24/10, antes do merge `e62034e`)

Pergunta única: o que quebra no Swarm real? Revisão só de leitura, sem docker, com conferência das imagens pela API
HTTP dos registros e leitura do código-fonte das versões exatas (Traefik v2.11.60, docker-socket-proxy v0.5.0,
cliente moby). Resultado: **nenhum erro que derrube serviço sem volta**; 4 pontos que deixariam o dono preso ou
confuso no roteiro, corrigidos na própria branch (`78df7be`, `2441047`, `da05729`, `caf8e71`). Nenhum yaml mudou:
`STACKS_COMMIT=91e7971` e a tabela sha256 continuam válidos. Bootstrap no merge:
`e7393b318fda59bfe91e6dc84f0aabb301cff7de044ca6f869ad907ac6665225`.

## O que foi conferido e está certo

- Imagens: todas as tags existem no Docker Hub (`traefik:v2.11.60`, `tecnativa/docker-socket-proxy:v0.5.0` com
  digest multi-arch amd64, `postgres:16.15-alpine3.24` e `16.15-trixie` iguais aos digests de `16-alpine`/`16` hoje,
  `redis:7.4.11-alpine`/`-bookworm`, `pgvector/pgvector:0.8.7-pg16`, `n8nio/n8n:1.123.10`, `alpine:3.24.3`). Os
  digests do app são lidos em tempo de execução pelo `app-subir`.
- Socket proxy: o provider Swarm do Traefik 2.11 chama `/version`, `/services`, `/networks`, `/tasks` e
  `/nodes/{id}`; o proxy libera exatamente isso (`POST=0`); `DISABLE_IPV6=1` evita o bind em `[::]`; o `HEAD /_ping`
  negado cai para `GET`. Endpoint `tcp://docker_proxy:2375` na rede interna `traefik_socket_docker`, só no manager.
- Traefik read-only: `acme.json` no volume; logs para arquivo tirados; tmpfs em `/tmp`; `traefik healthcheck --ping`
  funciona; `sanitizePath` padrão true; `cap_drop ALL`+`NET_BIND_SERVICE` aceitos pelo `stack deploy`.
- Healthchecks: API, web e Crystal em `node:22.22.2-alpine` (busybox `wget`); Chatwoot `ruby:3.4.4-alpine`;
  `/healthz` existe na API e na Crystal; `REDISCLI_AUTH` no `redis-cli`.
- Crystal read-only: nenhuma escrita em `apps/crystal/src`; o tsx grava o cache em `os.tmpdir()` (tmpfs 64 MB).
- Redis com senha: `REDIS_URL=redis://:SENHA@app_redis:6379` lido por `new IORedis(env.REDIS_URL)`; só a API usa
  Redis; senha gerada no `.segredos`, nunca em log. Transição: segundos de NOAUTH enquanto os dois trocam.
- `TRUST_PROXY`: faixa lida em tempo de execução de `docker network inspect borda_api`; `parseTrustProxy` aceita CIDR.
- HSTS: 1 ano, sem `includeSubDomains` e sem `preload`, só em `atendimento.`, `editor.`, `webhook.`, `painel.`.
- Redes: 6 overlays criadas antes de qualquer deploy; nomes iguais nos yaml (`external: true`); todos os pares que
  precisam conversar continuam na mesma rede; nada precisa de `--attachable`.
- `redes_ajustar` (volta) rodado com o python real sobre os 9 yaml: tudo volta à `network_swarm_public`.
  `docker_daemon_novo` idempotente, não sobrescreve `log-driver` existente, sem `live-restore`.
- Script: `bash -n` e `shellcheck -S warning` limpos; 12 yaml parseiam; tabela `ARQ_SHA256` bate com `91e7971` e
  com o HEAD; todos os comandos do README existem no `case`.
- Recursos: VPS 16 GB (12 GiB livres, 0 OOM em 24 h no diagnóstico de 23/10); nenhuma `reservation`; limites novos
  com folga (Traefik 512M, proxy 64M, Portainer 512M, agente 256M).

## Bugs corrigidos

1. `78df7be`: `seguranca --sem-ssh`. O passo final mandava `seguranca`; com qualquer chave em `authorized_keys`, a
   trava do SSH entraria e esperaria 10 min por `ssh-confirmar` de outra janela, com o dono no terminal da
   Hostinger sem chave própria. Agora o roteiro usa `--sem-ssh`.
2. `2441047`: `bancos` imprime a linha de `rollback` dos 5 serviços do n8n ANTES de tirar o Postgres e o Redis da rede
   antiga (se o deploy do meio falhar, o n8n ficaria sem banco e o script encerraria sem dizer a volta).
3. `da05729`: README da seção de 24/10: um roteiro só (a onda 1 ainda não foi rodada na VPS; o da onda 2 já a inclui;
   só `app-db-papel` fica para outra noite); passo do Traefik avisa que `/monitoring` e `/platform` ainda dão aviso
   até o `atendimento-subir`; `painel-restringir` sem `.painel-ips` só imprime a lista (rodar `portainer`);
   `docker-daemon` marcado opcional; `.sem-somente-leitura` do Traefik exige `preparar` e depois `traefik`.
4. `caf8e71`: `app-status` mostra `tag no ar: sha-XXXXXXX` limpa (com o digest preso a linha ficava ilegível).

## Riscos que ficam (ordem de importância)

1. `docker-daemon --confirmo`: reinicia o Docker num Swarm de um nó (tudo cai 1–2 min). Ganho modesto
   (`no-new-privileges`; rotação de log já está nas stacks). **Recomendação: adiar para outra noite** (opcional no README).
2. Crystal `read_only` não ensaiada em Swarm real: baixo risco; o Swarm desfaz sozinho; volta documentada
   (`.sem-somente-leitura` + `app-subir` na mesma tag). Aceitar.
3. Traefik `read_only` + `cap_drop ALL`: baixo risco; volta automática em 2 min se nenhuma rota responder. Aceitar.
4. Troca das tags do Postgres (`16` → `16.15-trixie`, `16-alpine` → `16.15-alpine3.24`): mesmo digest hoje; backup
   antes. Aceitar.
5. Redis com senha: segundos de erro 500 em login/refresh na troca. Aceitar (madrugada).
6. Quedas por passo: n8n 1–3 min, API 1–2 min, Chatwoot 1–2 min (o Swarm recria a tarefa ao mudar de rede). Aceitar.
7. Soma dos `limits` (≈21 GB) acima da RAM: sem `reservations` não impede agendar; uso real ≈3 GB. Aceitar.
8. `esperar_stack` com `set -e` sai sem frase de "o que fazer" depois de 240 s (pré-existente); a volta de cada passo
   está no README. Aceitar.
9. `redes-voltar` não é byte-idêntico à onda 1 (Sidekiq e agente do Portainer fora da `network_swarm_public`; senha
   do Redis, versões fixas e read-only ficam). Funcionalmente equivalente. Aceitar.
10. `no-new-privileges` para todos: residual pequeno no Chatwoot/Portainer; conferir `status` em 2 min se o passo 1
    for feito. Aceitar.

## Roteiro

Está em `crystal-em-casa/README.md`, seção "Revisão de segurança de 24/10: o que rodar na VPS", passos 0 a 8, com o que
a tela tem de mostrar e a volta de cada passo. Volta geral: `redes-voltar --confirmo`. Para outra noite: `app-db-papel`
e a trava do SSH quando houver chave do dono num aparelho dele.
