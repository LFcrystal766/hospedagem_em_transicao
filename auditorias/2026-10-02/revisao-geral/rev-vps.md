# Revisão de infraestrutura e bash: VPS da Crystal (02/10/2026)

Revisão linha a linha, sem modificar nada, de:

| Arquivo | Linhas |
|---|---:|
| `crystal-em-casa/bootstrap-vps.sh` | 2107 |
| `crystal-em-casa/stacks-app/01-portainer-restrito.yaml` | 92 |
| `crystal-em-casa/stacks-app/10-crystal-app.yaml` | 206 |
| `crystal-em-casa/stacks-app/20-atendimento.yaml` | 183 |
| `crystal-em-casa/stacks-exemplo/00..07-*.yaml` (8 arquivos da agência) | 1197 |
| `crystal-em-casa/n8n/crystal-provisoria.json` | 409 |
| `crystal-em-casa/n8n/webhook-crystal-app.json` | 168 |
| `scripts/cloudflare-degrau2.sh` | 495 |
| `scripts/cloudflare-crystal-vps-dns.sh` | 165 |
| `scripts/auditoria-so-leitura.sh` | 175 |
| **Total: 17 arquivos** | **5197** |

Convenção de argumentos conferida em todas as chamadas: o dispatcher passa `"$@"` com
`$1` = comando e `$2` = primeiro argumento (`app_subir app-subir TAG`, `preparar preparar
EMAIL`, `app_definir app-definir NOME`); `backup-chave`, `backup-link` e `painel-restringir`
fazem `shift` antes e as funções leem `$1`; `atendimento_configurar` faz `shift` dentro.
Funções internas (`app_gerar_segredos TAG`, `app_gravar NOME VALOR`, `esperar_stack STACK
[SEG]`, `deploy ARQ STACK`) usam `$1`/`$2` direto. Não encontrei argumento deslocado.

## Verificações automáticas

- `bash -n` nos 4 scripts: **OK** nos quatro.
- `shellcheck -S style` (ShellCheck instalado em `/usr/bin/shellcheck`): **0 erros, 1 warning,
  35 notas**. A contagem por código bate com a de `04-shellcheck-yaml.log` (rodada anterior
  desta pasta). Resumo por código e, logo abaixo, a lista por linha:

| Código | Qtd | Onde | Veredito |
|---|---:|---|---|
| SC2015 (`A && B \|\| C` não é if/else) | 25 | bootstrap (18), degrau2 (6), vps-dns (3) | Falso positivo em todos: o `B` é sempre `ok`/`aviso` (um `echo`), que nunca falha |
| SC2001 (usar `${var//}`) | 3 | bootstrap:247,252; degrau2:177 | Estilo |
| SC2086 (aspas) | 2 | bootstrap:1021 (`$k` de lista fixa), 1483 (`set -- $linha`, saída do docker) | Inofensivo, mas 1483 merece `read -r nome rep` em vez de `set --` |
| SC2018/SC2019 (`tr A-Z`) | 4 | bootstrap:921,928 | Estilo (`[:upper:]`) |
| SC2034 (`i` não usado) | 1 | degrau2:459 | Estilo (`for _ in`) |

Linhas apontadas (formato `arquivo:linha:código`):
`bootstrap-vps.sh` 167:SC2015, 247:SC2001, 252:SC2001, 415:SC2015, 421:SC2015, 615:SC2015,
627:SC2015, 628:SC2015, 632:SC2015, 633:SC2015, 921:SC2019+SC2018, 928:SC2018+SC2019,
1021:SC2086, 1098:SC2015, 1156:SC2015, 1334:SC2015, 1431:SC2015, 1483:SC2086, 1595:SC2015,
1642:SC2015, 1853:SC2015, 2021:SC2015 ·
`cloudflare-crystal-vps-dns.sh` 76:SC2015, 103:SC2015, 143:SC2015 ·
`cloudflare-degrau2.sh` 177:SC2001, 269:SC2015, 273:SC2015, 303:SC2015, 306:SC2015,
422:SC2015, 449:SC2015, 459:SC2034 ·
`auditoria-so-leitura.sh`: nenhum apontamento.
Dos SC2015, dois merecem nota mesmo sendo seguros: `415` (`[ -t 0 ] && [ -t 1 ] || falha`) e
`1156` são testes encadeados, não `echo`; o resultado é o pretendido, mas um `if` deixaria
explícito.

Ferramentas de que os scripts dependem e onde a falta aparece: `jq` e `curl` (Cloudflare,
sem checagem explícita: a falha vira "GET x: " vazio, ver B7), `python3` (bootstrap em 12
pontos, presente no Ubuntu 24), `age`/`age-keygen` (instalado pelo `backup-chave`, e `backup`
confere com `command -v`), `openssl`, `getent`, `ss`, `sshd -T`, `less` (conferido em
`segredos`/`app_segredos`/`atendimento_segredos`, **não** conferido em `backup_chave`).

## Resumo por gravidade

| Gravidade | Qtd |
|---|---:|
| Crítico | 0 |
| Alto | 2 |
| Médio | 17 |
| Baixo | 15 |
| Observação | 11 |

---

## ALTO

### A1. `env_file` não tira os segredos do spec do Swarm
**Onde:** `stacks-app/10-crystal-app.yaml:43,93,136,161`; `stacks-app/20-atendimento.yaml:41,101,128,150`;
`bootstrap-vps.sh:1024-1065` (api.env, crystal.env, postgres.env), `1597-1639` (chatwoot.env,
redis.env); cabeçalhos "Segredo nenhum" em `10-crystal-app.yaml:19-23` e `20-atendimento.yaml:20-23`;
e, herdado da agência, `02/04/05/06/07-*.yaml` com `N8N_ENCRYPTION_KEY` e
`DB_POSTGRESDB_PASSWORD` em `environment:` (o `preparar`, linhas 210-214, só troca o valor).

**Descrição:** `docker stack deploy` resolve o `env_file` **no cliente** e grava cada
`NOME=valor` em `TaskTemplate.ContainerSpec.Env`. Na prática `env_file:` e `environment:`
produzem o mesmo spec: `docker service inspect crystal_app_app_api` e a tela "Env" do
Portainer mostram ENCRYPTION_KEY, JWT_SECRET, CPF_SALT, OTP_PEPPER, VAPID_PRIVATE_KEY,
SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY, CHATWOOT_*_TOKEN/SECRET, REVIEW_ACCOUNTS (CPF e
código), SMTP_PASSWORD, SECRET_KEY_BASE, ACTIVE_RECORD_ENCRYPTION_*, POSTGRES_PASSWORD e
REDIS_PASSWORD, além de ficarem no raft do Swarm (histórico de versões do serviço). A regra do
projeto ("nunca para o spec do serviço Swarm") não está sendo cumprida, e o risco prático é
alguém colar a saída de um `docker service inspect` em chat ou em `auditorias/`.

**Confirmar na VPS (sem colar a saída em chat):**
`docker service inspect crystal_app_app_api --format '{{json .Spec.TaskTemplate.ContainerSpec.Env}}' | grep -c ENCRYPTION_KEY`
(1 = confirmado).

**Correção:** usar `secrets:` do Swarm (`docker secret create` a partir dos arquivos 600) e
montar em `/run/secrets`: Postgres aceita `POSTGRES_PASSWORD_FILE`, o n8n aceita o sufixo
`_FILE` em qualquer variável (`N8N_ENCRYPTION_KEY_FILE`, `DB_POSTGRESDB_PASSWORD_FILE`), o
Redis pode ler o arquivo no `command`; para o app e o Chatwoot, uma linha no entrypoint que
exporte `NOME=$(cat /run/secrets/NOME)`. Enquanto isso, corrigir os cabeçalhos dos dois YAML e
tratar a saída de `docker service inspect` como segredo.

### A2. Redis do n8n sem senha numa rede compartilhada com o app e o Chatwoot
**Onde:** `stacks-exemplo/03-n8n-redis.yaml:39,41-42` (herdado sem alteração pelo
`preparar`); `bootstrap-vps.sh:1966-1967` (credencial `"password": ""`); `02-n8n-postgres.yaml:45-46`
(mesma rede, com senha).

**Descrição:** `n8n_redis:6379` responde sem autenticação para qualquer contêiner em
`network_swarm_public`: `app_web`, `app_api`, `cw_rails`, `cw_sidekiq`, o próprio n8n. Um
contêiner comprometido (um XSS/RCE no Next.js do `app_web`, por exemplo) faz `FLUSHALL` na
fila do n8n, injeta jobs ou lê o banco 2, onde a Crystal provisória guarda o histórico de
conversa dos alunos por 7 dias (`crystal-provisoria.json:205-210`). O Postgres do n8n tem
senha, mas também está exposto a movimento lateral na mesma rede.

**Correção:** no `preparar`, trocar `command: redis-server --appendonly yes --port 6379` por
`--requirepass` lido de arquivo (como `cw_redis` já faz em `20-atendimento.yaml:151-154`) e
acrescentar `QUEUE_BULL_REDIS_PASSWORD` em 04/05/06; melhor ainda, criar uma rede
`n8n_interno` só para postgres, redis, editor, webhook e worker, deixando na pública só quem
o Traefik roteia.

---

## MÉDIO

### M1. YAML baixados de um branch mutável, sem verificação de integridade
**Onde:** `bootstrap-vps.sh:108` (`REF` padrão `claude/gracious-shannon-6x9l5j`), `185`, `682`,
`857`, `1111`, `1670`, `1947`.
**Descrição:** quando o script roda fora do checkout (caso da cópia em `/root/crystal/`), ele
baixa os stacks e o fluxo do n8n pelo `raw.githubusercontent.com` de um branch de trabalho, e
sobe o resultado com acesso ao `docker.sock` (agente do Portainer). Branch pode ser
reescrito ou apagado; a regra do projeto pede commit fixo. A única checagem é `grep '^services:'`.
**Correção:** `REF` padrão igual a um SHA de commit, e comparar `sha256sum` do arquivo baixado
com uma lista embutida no script (ou exigir rodar de dentro do checkout).

### M2. `backup-fora-config` destrói uma configuração que funcionava se o teste falhar
**Onde:** `bootstrap-vps.sh:462-475`.
**Descrição:** o novo `.backup-fora` é movido por cima do antigo (466) **antes** do envio de
teste; se o teste falha, `rm -f "$FORA_CONF"` (473) apaga o arquivo, inclusive o antigo que
funcionava. A mensagem diz "Nada gravado", mas o cron das 03:30 passa a falhar no R2 até
reconfigurar.
**Correção:** testar lendo do `.novo` (passar o caminho para `fora_ler_conf`) e só `mv` depois
do 200; em falha, apagar só o `.novo`.

### M3. Contagem "?" libera o caminho destrutivo
**Onde:** `bootstrap-vps.sh:828-830` (`recomecar-n8n`), `1260-1262` (`app-recomecar`).
**Descrição:** se o `psql` não responde (contêiner reiniciando, senha errada), `fluxos`/`n`
vira `?` e a condição `[ "$n" = "?" ]` deixa seguir para `stack rm` + `volume rm`. O `--confirmo`
ajuda, mas o guarda contra apagar banco em uso não funciona exatamente quando o banco está
instável.
**Correção:** só aceitar `0`; com `?`, `falha` pedindo para conferir o banco à mão (ou aceitar
`?` apenas quando `docker volume inspect` mostrar o volume inexistente).

### M4. `volume rm` silenciado no `app-recomecar`
**Onde:** `bootstrap-vps.sh:1270-1272`.
**Descrição:** `docker volume rm ... || true`: se o volume ainda está em uso (tarefa demorando
a sair), o Postgres antigo sobrevive com a senha antiga, `.segredos` já foi apagado (1273) e
o `app-subir` seguinte gera senha nova, o initdb não roda (dados existem) e a API fica em
loop de "password authentication failed", sem mensagem que aponte a causa.
**Correção:** repetir o `rm` por até 60 s e `falha` se não conseguir; só então apagar `.segredos`.

### M5. Cron executa uma cópia congelada do script
**Onde:** `bootstrap-vps.sh:348-350` (backup), `1467-1469` (vigia).
**Descrição:** `backup-cron` e `vigia-config` copiam o script para `/root/crystal/bootstrap-vps.sh`
e o cron roda essa cópia. Toda melhoria posterior (por exemplo, o backup do Chatwoot
acrescentado em `a582ab2`) só entra no cron quando alguém lembra de rodar `backup-cron` de novo.
Nada avisa da divergência.
**Correção:** um comando `instalar` que atualiza a cópia e imprime o `sha256sum` das duas, chamado
no fim de `app-subir`/`atendimento-subir`; ou um `status` que compara os hashes e avisa.

### M6. Restrição por IP do `/super_admin` contornável com barra dupla (a confirmar)
**Onde:** `stacks-app/20-atendimento.yaml:86-92`.
**Descrição:** o Traefik v2 casa `PathPrefix(`/super_admin`)` sem normalizar o caminho;
`//super_admin` não casa, cai no router aberto `crystal_atendimento`, e o Rails
(`Journey::Router::Utils.normalize_path` faz `squeeze("/")`) roteia para o console de super
admin. Sobra a senha do super admin, mas a camada de IP é contornada. A confirmar com
`curl -sI https://atendimento.crystalnowpp.com.br//super_admin` de um IP fora da lista
(esperado hoje: 302 para o login do super admin em vez de 403).
**Correção:** regra com regex do gorilla/mux: ``Path(`/{barras:/*}super_admin{resto:.*}`)``
no router `_admin`, mantendo a prioridade 100.

### M7. `priority=1` no único router protegido por lista de IP
**Onde:** `stacks-app/01-portainer-restrito.yaml:67` (herdado de `stacks-exemplo/01-portainer.yaml:69`).
**Descrição:** 1 é a prioridade mais baixa possível. Qualquer router futuro em `websecure`
com regra mais larga (um `HostRegexp` ou `PathPrefix(`/`)` sem Host, comum em exemplos de
Traefik) passa a atender `painel.` e o `ipallowlist` deixa de valer. Hoje não há router assim;
é uma armadilha para o próximo stack.
**Correção:** remover a label de prioridade (o padrão, pelo tamanho da regra, já resolve).

### M8. `FORCE_SSL=false` tira o `Secure` dos cookies do Chatwoot (a confirmar)
**Onde:** `bootstrap-vps.sh:1608-1609`.
**Descrição:** o comentário diz que `FORCE_SSL` redirecionaria em círculo atrás do Traefik, mas
o `ActionDispatch::SSL` usa `request.ssl?`, que lê `X-Forwarded-Proto: https`, cabeçalho que o
Traefik envia. Sem `force_ssl` o Rails não marca a sessão como `Secure` nem manda HSTS: um
acesso acidental por `http://atendimento.` manda o cookie em claro antes do redirect do Traefik.
**Correção:** testar `FORCE_SSL=true` numa janela (um `curl -sI -H 'X-Forwarded-Proto: https'`
dentro da rede confirma que não há loop); se der loop, manter `false` e adicionar um middleware
`headers` no Traefik com `stsseconds` e `sslredirect`, como já existe para o Portainer.

### M9. Tags flutuantes no stack do app
**Onde:** `stacks-app/10-crystal-app.yaml:42` (`postgres:16-alpine`), `:66` (`redis:7-alpine`).
**Descrição:** regra do projeto é versão fixa; `redis:7-alpine` anda por toda a série 7.x e
`postgres:16-alpine` por 16.x. O `20-atendimento.yaml` já faz certo (`pgvector:0.8.7-pg16`,
`redis:7.4.11-alpine`); o Portainer é preso a digest pelo `painel-restringir`.
**Correção:** `postgres:16.10-alpine` (ou a 16.x que estiver rodando, conferindo com `docker
service inspect`) e `redis:7.4.11-alpine`.

### M10. Token do Cloudflare na linha de comando do curl
**Onde:** `scripts/cloudflare-degrau2.sh:68-71,383`; `scripts/cloudflare-crystal-vps-dns.sh:53-56`.
**Descrição:** `-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"` aparece em `ps`/`/proc/*/cmdline`
de qualquer usuário da máquina enquanto o curl roda. O token não vai em URL (ponto 5 do
pedido: ok), mas a regra "segredo nunca em linha de comando" vale também aqui. O próprio
bootstrap já resolve isso para o R2 e o Telegram (`fora_curl`, `vigia_telegram`).
**Correção:** `printf 'header = "Authorization: Bearer %s"\n' "$CLOUDFLARE_API_TOKEN" | curl -K - ...`
numa função `cf_curl` compartilhada.

### M11. `PUT` do ruleset inteiro reconstruído com subconjunto de campos
**Onde:** `scripts/cloudflare-degrau2.sh:190-208` (`regra_na_fase`), `210-222` (`tirar_regra`).
**Descrição:** as regras existentes são reduzidas a `{ref,expression,action,action_parameters,
description,enabled,ratelimit}` e o entrypoint é regravado por completo. Regras criadas no
painel perdem `logging`, `exposed_credential_check`, `position` e qualquer campo novo da API; o
aviso "elas são mantidas" (205) é parcialmente verdadeiro. O backup em `auditorias/` permite
restaurar, mas só à mão.
**Correção:** criar com `POST /zones/{z}/rulesets/{ruleset_id}/rules` e remover com
`DELETE .../rules/{rule_id}`, sem tocar nas demais.

### M12. Traefik grava log e access log em arquivo dentro do contêiner, sem rotação; versão antiga
**Onde:** `stacks-exemplo/00-traefik.yaml:30,72-74` (herdado; o `status` lê esse arquivo em
`bootstrap-vps.sh:796`).
**Descrição:** `/var/log/traefik/*` fica na camada gravável do contêiner e cresce para sempre
(access log de todo pedido). Com disco cheio o Swarm para de agendar tarefas. E `traefik:v2.11.3`
é de meados de 2024; a série 2.11 recebeu patches de segurança depois (a confirmar a última
2.11.x no momento de atualizar).
**Correção:** `--accesslog` para stdout (ou volume + logrotate), `--accesslog.bufferingsize`,
e `--log.filePath` idem; subir para a última `v2.11.x`, lendo as notas.

### M13. Listagem do R2 limitada a 1000 objetos sem paginação
**Onde:** `bootstrap-vps.sh:490,496-500` (`backup-link`), `546,551-561` (`backup-conferir`).
**Descrição:** o S3 devolve as primeiras 1000 chaves em ordem lexicográfica (as mais antigas)
e `IsTruncated` é ignorado. A ~5 arquivos/dia, em uns 7 meses `backup-link` passa a apontar
para um backup velho e `backup-conferir`/`status` passam a dar alarme falso de "último backup
há N h". Não há regra de ciclo de vida: a trava é de 30 dias mas os objetos ficam para sempre.
**Correção:** listar com `prefix=$FORA_PREFIXO/$tipo/$(date -u +%Y/%m)` e cair para o mês
anterior se vazio; ou seguir `NextContinuationToken`. Criar lifecycle rule de 90 dias no bucket.

### M14. Nós Code do n8n com todos os builtins e pacotes da comunidade (herdado)
**Onde:** `stacks-exemplo/04-n8n-editor.yaml:131-134`, `05:126-129`, `06:137-140`, `07:132-135`;
`N8N_RUNNERS_MODE=internal` em todos.
**Descrição:** `NODE_FUNCTION_ALLOW_BUILTIN=*` dá `child_process` e `fs` a qualquer usuário do
editor (ou a quem roubar uma sessão), dentro de um contêiner na rede pública com o Redis sem
senha (A2). `N8N_COMMUNITY_PACKAGES_ENABLED=true` permite instalar código de terceiros.
**Correção:** `NODE_FUNCTION_ALLOW_BUILTIN=crypto,url,buffer`, `N8N_COMMUNITY_PACKAGES_ENABLED=false`
(ou só o que a agência listar), e `N8N_RUNNERS_MODE=external` com o serviço de runner.

### M15. `validar` manda query de teste sem conferir antes se a URL dá 200
**Onde:** `scripts/cloudflare-degrau2.sh:426` (`/crystal-teste?fbclid=...`, sem barra) e `453`
(`http://.../crystal-teste/?fbclid=...`).
**Descrição:** em 13/09 (`auditorias/2026-09-13/evidencias/matriz-http.txt:2,18`) as duas
respondem 200, então hoje o script não repete o 11/09. Mas a regra "URL que responde 301 nunca
recebe fbclid" está garantida só por esse estado do WordPress: se alguém ativar o redirect
canônico da barra ou o redirect http→https no WP, o próprio `validar` envenena o cache do
LiteSpeed. Com `always_use_https` ligado pelo comando `https`, o `http://` da 453 vira 301 na
borda (não no LiteSpeed), o que é inofensivo, mas o script não distingue.
**Correção:** antes de cada URL com query, fazer o mesmo GET sem query; só mandar a query se o
status for 200 (e registrar o pulo).

### M16. `preparar` regrava o Portainer como aberto e só retranca se der certo
**Onde:** `bootstrap-vps.sh:209-223`.
**Descrição:** o laço 209-218 sobrescreve `$STACKS/01-portainer.yaml` com o original (aberto,
`:sts`, agente na rede pública) e depois tenta `painel_gerar`; se o Portainer estiver parado
(`painel-desligar`) ou sem digest, fica um `aviso` e o arquivo aberto no lugar. Um `tudo` ou
`portainer` depois disso desfaz a restrição sem perguntar.
**Correção:** com `.painel-ips` presente e `painel_gerar` falhando, `falha` (ou não tocar no
01 e usar o `.aberto` só sob pedido explícito).

### M17. `preparar`/`painel_gerar` copiam o 01 restrito para `$ORIG` e deixam o `01-portainer.yaml.aberto` sem atualização
**Onde:** `bootstrap-vps.sh:686-689`.
**Descrição:** o `.aberto` é gravado uma vez (quando o arquivo atual ainda não tem
`ipallowlist`) e nunca mais; depois de um `preparar` com e-mail novo o `.aberto` fica com
e-mail/valores velhos. É o arquivo que a mensagem de emergência (750) manda usar.
**Correção:** regravar o `.aberto` a partir de `$ORIG/01-portainer.yaml` (já com sed) a cada
`painel_gerar`.

---

## BAIXO

### B1. Saída silenciosa quando a API do app não existe
**Onde:** `bootstrap-vps.sh:1391`, `1738`, `1941`.
**Descrição:** `tag=$(app_tag_atual)` com `set -e` + `pipefail`: se `docker service inspect`
falha, a atribuição falha e o script sai com código 1 antes do `falha` com a mensagem
amigável (1392, 1739, 1941).
**Correção:** `tag=$(app_tag_atual || true)`.

### B2. Regex de e-mail aceita `|` e `&`, que quebram o sed
**Onde:** `bootstrap-vps.sh:175` (validação) e `210-214` (sed com delimitador `|`; `&` vira o
trecho casado).
**Descrição:** improvável, mas o e-mail entra sem escape no sed e no `acme.email`.
**Correção:** usar a regex de `1193` (`^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$`).

### B3. `.externos.tmp` gravado sem `umask 077`
**Onde:** `bootstrap-vps.sh:2040-2041` (`crystal-provisoria-desligar`).
**Descrição:** único ponto que regrava `.externos` sem passar por `app_gravar`; o `.tmp` nasce
644 com segredos dentro até o `chmod` seguinte. Janela curta e em `/root`, mas inconsistente.
**Correção:** `umask 077` no início da função.

### B4. `falha` dentro de `| while read` só mata o subshell
**Onde:** `scripts/cloudflare-degrau2.sh:139-141`; `scripts/cloudflare-crystal-vps-dns.sh:152-154`.
**Descrição:** se o PATCH que força cinza em `server./mail./ftp.` falhar, `falha` sai do
subshell do pipeline, o script segue e termina com "ok".
**Correção:** `while read -r id; do ...; done < <(echo "$problemas" | jq -r '.[]')`.

### B5. Simulação termina com código 1
**Onde:** `scripts/cloudflare-degrau2.sh:164` (`proxied`), `334` (`cmd_laranja`), `337-341` (`cmd_cinza`).
**Descrição:** o último comando da função é `[ "$APLICAR" -eq 1 ] && ...`; sem `--aplicar` ele
retorna 1 e `exit $RC` propaga. Quem encadear `&& ` depois de uma simulação acha que falhou.
**Correção:** terminar essas funções com `return 0` (ou `|| true`).

### B6. SPF: só o ` +a ` explícito é removido
**Onde:** `scripts/cloudflare-degrau2.sh:176-177`.
**Descrição:** em SPF, `a` sozinho equivale a `+a`. Com `v=spf1 a ip4:... ~all` o script diz
"já está sem +a" e deixa o mecanismo apontando para os IPs do Cloudflare depois do laranja.
**Correção:** `sed -E 's/ \+?a( |$)/\1/'`.

### B7. Falha de rede do curl vira mensagem vazia
**Onde:** `scripts/cloudflare-degrau2.sh:65-82`; `scripts/cloudflare-crystal-vps-dns.sh:50-64`.
**Descrição:** sem `set -e`, um curl que não conecta devolve `r` vazio, `jq -r .success` não
imprime nada e o erro sai como `GET /zones/...: ` sem detalhe.
**Correção:** testar o código de saída do curl em `api` e `falha "curl $?"`.

### B8. `date -d` só funciona no GNU date
**Onde:** `scripts/cloudflare-degrau2.sh:377`; `bootstrap-vps.sh:782` (na VPS, ok).
**Descrição:** `cmd_saude` quebra no macOS do MacBook de onde o degrau 1 foi feito.
**Correção:** `date -u -v-"${min}"M` como fallback, ou documentar "rodar deste ambiente".

### B9. `apt-get update` dentro do grupo após `||` sai em silêncio
**Onde:** `bootstrap-vps.sh:416`, `574`.
**Descrição:** no `{ }` à direita de `||` o `set -e` está ativo; um `update` que falha
(espelho fora) encerra o script sem mensagem.
**Correção:** `apt-get -qq update >/dev/null || falha "apt-get update falhou"`.

### B10. `cw_sidekiq` na rede pública sem necessidade; comentário errado
**Onde:** `stacks-app/20-atendimento.yaml:96-98,107-109`.
**Descrição:** `cw_interno` é uma overlay normal (sem `internal: true`), logo já tem saída
para a internet via `docker_gwbridge`; é por isso que `app_crystal` (só em `app_interno`)
alcança o OpenRouter. Colocar o Sidekiq na pública só o expõe aos outros contêineres.
**Correção:** remover `network_swarm_public` do `cw_sidekiq` e corrigir o comentário.

### B11. Chave do Resend compartilhada entre API e Chatwoot
**Onde:** `bootstrap-vps.sh:1628,1635` (e `1051` para a API).
**Descrição:** o mesmo `RESEND_API_KEY` vai para `api.env` e para `chatwoot.env`
(`SMTP_PASSWORD`). Um Chatwoot comprometido manda e-mail como o domínio do app.
**Correção:** chave própria do Resend para o Chatwoot (escopo de envio, domínio único),
gravada com um `app-definir CHATWOOT_RESEND_KEY`.

### B12. Sem cabeçalhos de segurança em app., api. e atendimento.
**Onde:** `10-crystal-app.yaml:119-127,186-194`; `20-atendimento.yaml:76-94`.
**Descrição:** só o Portainer tem `framedeny`, `nosniff`, HSTS (`01-portainer-restrito.yaml:73-76`).
**Correção:** um middleware `headers` reutilizável (definido uma vez, por exemplo no stack do
Traefik) e `middlewares=...` nos três routers.

### B13. `/metrics` do n8n aberto no editor (herdado)
**Onde:** `stacks-exemplo/04-n8n-editor.yaml:56`.
**Descrição:** `N8N_METRICS=true` serve Prometheus sem autenticação em `https://editor.../metrics`
(contagens de execuções, versões). Nada é monitorado por ele hoje.
**Correção:** `N8N_METRICS=false` até existir coletor.

### B14. Dados pessoais guardados nas execuções do n8n
**Onde:** `n8n/crystal-provisoria.json:401-406` (`saveDataErrorExecution: all`);
`n8n/webhook-crystal-app.json:160-165` (`saveDataSuccessExecution: all`).
**Descrição:** em erro, o fluxo provisório grava o texto do aluno e o `contact_id` por 2
semanas (`EXECUTIONS_DATA_MAX_AGE=336`); o webhook do app grava `bruto`, IP e User-Agent de
toda chamada bem-sucedida. Sem segredo embutido nos dois JSON (credenciais só por id) e nós
razoáveis (validação de tipo/tamanho, `onError` tratado).
**Correção:** `saveDataErrorExecution: none` no provisório (a mensagem já é curta no log do
app) e `saveDataSuccessExecution: none` no webhook, ou reduzir `EXECUTIONS_DATA_MAX_AGE`.

### B15. `esperar_stack` trata `0/0` como pendente
**Onde:** `bootstrap-vps.sh:237`.
**Descrição:** com o Portainer em escala 0 (`painel-desligar`), `painel-restringir` espera
240 s e falha, embora o deploy tenha dado certo.
**Correção:** considerar `0/0` concluído (ou `painel-restringir` religar antes).

---

## OBSERVAÇÕES

- **O1.** `bootstrap-vps.sh:1794-1796,1799-1802`: `canal.secret`, `robo.secret` e
  `robo.access_token` dependem de atributos que não existiam em versões anteriores do Chatwoot
  CE (`Channel::Api` tinha só `identifier`/`hmac_token`). A confirmar que
  `atendimento-configurar` já rodou com sucesso na `v4.18.0-ce`; se der `NoMethodError`, a
  mensagem (1805) não mostra o erro do Ruby.
- **O2.** `bootstrap-vps.sh:1985-1991`: `INSERT` direto em `workflow_history` do n8n; funciona na
  1.123, mas é esquema interno e pode quebrar na próxima versão. Deixar o aviso no comentário e
  revalidar a cada upgrade.
- **O3.** Soma dos `resources.limits.memory` ≈ 20 GB (n8n 12 GB + app 3,4 GB + Chatwoot 4 GB)
  para um KVM 4 de 16 GB; são tetos, não reservas, mas o OOM killer do kernel decide quem
  morre. Vale baixar o worker do n8n (4 GB/concorrência 50 é de sobra para o uso atual).
- **O4.** `stacks-exemplo/00-traefik.yaml:78`: o `:ro` no `docker.sock` não restringe a API
  (conectar no socket já permite tudo); a proteção real é `exposedbydefault=false`. Sem
  `resources.limits` no Traefik nem no Portainer (01 e 01-restrito).
- **O5.** `bootstrap-vps.sh:1754`: senha do admin do Chatwoot = 20 alfanuméricos + `Aa7!`
  fixo; ~119 bits, suficiente, só registrar que os 4 últimos são previsíveis.
- **O6.** `bootstrap-vps.sh:882,885`: o `docker login` guarda o token do ghcr em base64 em
  `/root/.docker/config.json` (600) e `--with-registry-auth` o leva ao raft; documentado na
  própria mensagem. Trocar o token se a VPS for comprometida.
- **O7.** `bootstrap-vps.sh:348`: o cron das 03:30 é na hora da VPS (UTC) = 00:30 BRT; a
  janela combinada do projeto é 02:00-05:00 BRT. Só alinhar o comentário ou o horário.
- **O8.** `scripts/cloudflare-degrau2.sh:229-247` (`foto`): grava o dump completo da zona (TXT
  de verificação, SPF, DKIM) em `auditorias/` versionado. Nada é segredo, mas é inventário
  público do domínio se o repositório um dia ficar público.
- **O9.** Ameaça não coberta: tudo que é "digitado sem aparecer" (`read -rs`, `less -K`) passa
  pelo console web da Hostinger (websocket do hPanel). Para a chave privada do age e a senha
  do Chatwoot, preferir SSH direto.
- **O10.** `bootstrap-vps.sh:1051`: `.externos` inteiro vai para `api.env`, inclusive
  `REVIEW_ACCOUNTS` (CPF + código fixo) e `FCM_SERVICE_ACCOUNT_JSON`; é por desenho, mas amplia
  o impacto de A1.
- **O11.** `stacks-exemplo/02-n8n-postgres.yaml:71` e `NODE_OPTIONS="..."` (04:160, 05:142,
  06:153, 07:148): as aspas ficam literais no valor; funcionam porque o entrypoint do Postgres
  faz `eval` e o Node aceita aspas em `NODE_OPTIONS`. Não mexer sem testar.

---

## O que está BEM feito

- **Segredos fora da linha de comando, de forma consistente:** `fora_curl` e `vigia_telegram`
  com `curl -K -`; `docker login --password-stdin`; CPF e dados do admin por `docker exec -e NOME`
  (sem valor na linha); senha do papel `crystal_agente` e telefone por heredoc do `psql` com
  `\set`; credenciais do n8n por `python3` lendo o ambiente e `cat` no contêiner com `umask 077`;
  `read -rs` em todo segredo digitado; `less -K` para mostrar e sumir; heurística em
  `app_definir` (906-907) que recusa `re_*`, `ghp_*`, `sk-*`, `eyJ*` como nome e manda trocar a chave.
- **Gravação de arquivos sensíveis:** `umask 077` antes de criar, `chmod 600` depois, escrita
  em `.tmp`/`.novo` + `mv` (atômica) em `app_gravar`, `app_definir`, `painel_restringir`,
  `backup_fora_config`; `chmod 700` nas pastas; cron.d com 644 explícito.
- **Guardas contra operação destrutiva:** `--confirmo` obrigatório, contagem de fluxos/usuários
  antes de apagar, regex da tag, validação de IP em Python com `/16` mínimo e `is_global`,
  checagem de placeholder sobrando depois do sed, `grep '^services:'` no download, e-mail e
  telefone validados antes de entrar em SQL.
- **Cloudflare:** nada grava sem `--aplicar`; backup em `auditorias/<data>/cloudflare/` antes de
  cada escrita e releitura depois; `garantir_cinza` para `server./mail./ftp.`; `cert` antes de
  `laranja`; janela 02:00-05:00 BRT com override explícito; `saude` com limiar de 5 % e piso de 10
  pedidos; `conferir` sem token por DoH.
- **Laços de espera todos limitados** (60 s a 600 s), com diagnóstico (`docker service ps`) no
  estouro.
- **Stack do app e do Chatwoot:** redes internas próprias, Postgres com `scram-sha-256`, Redis
  com `noeviction` e, no Chatwoot, `requirepass`; `healthcheck` com `start_period` realista;
  `stop-first` nos serviços que migram banco e `start-first` só no web; `failure_action: rollback`;
  limites de recurso em todos; imagens do Portainer presas a digest; `ipallowlist` por
  `RemoteAddr` (sem confiar em `X-Forwarded-For`, correto com `mode: host`); rede do agente
  `internal: true`; telemetria e signup do Chatwoot desligados; `webhook_url` do Chatwoot
  público de propósito para não desligar a proteção contra SSRF.
- **Backup:** cifrado com `age` para chave pública, privada só no Bitwarden com confirmação dos
  6 últimos caracteres antes de descartar; trava do bucket testada de verdade
  (`backup-testar-trava`); `pg_dump` com `pipefail` e `[ -s ]`; retenção local de 14 dias; o
  `.aberto` do Portainer guardado antes de trancar.
- **Scripts passam limpos** no `bash -n` e no `shellcheck -S style` (só estilo e falsos
  positivos), e o `auditoria-so-leitura.sh` respeita a regra do 301 (as URLs sem barra são
  testadas **sem** query).

## Contagem

17 arquivos, 5197 linhas lidas integralmente (bootstrap em 5 blocos, 2107 linhas). 45 achados:
0 críticos, 2 altos, 17 médios, 15 baixos, 11 observações. Itens marcados "a confirmar": M6,
M8, M12 (versão), O1.
