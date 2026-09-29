#!/usr/bin/env bash
# Sobe a fundação da Crystal na VPS (Hostinger KVM 4): Traefik, Portainer e o
# n8n em modo fila, a partir dos stacks-exemplo da agência, já com o domínio
# crystalnowpp.com.br e os segredos gerados na própria máquina.
#
# Roda NA VPS, como root. Uso:
#   bash bootstrap-vps.sh preparar SEU_EMAIL   baixa os yaml, gera os segredos (uma vez só)
#                                              e grava os arquivos prontos em /root/crystal/stacks
#   bash bootstrap-vps.sh docker-api           Docker 29 recusa o Traefik v2 (API 1.24): grava
#                                              min-api-version=1.24 no daemon.json e reinicia o Docker
#   bash bootstrap-vps.sh traefik              sobe 00 e espera ficar 1/1
#   bash bootstrap-vps.sh portainer            sobe 01
#   bash bootstrap-vps.sh bancos               sobe 02 e 03
#   bash bootstrap-vps.sh n8n                  sobe 04, 05 e 06
#   bash bootstrap-vps.sh tudo                 os quatro acima, na ordem
#   bash bootstrap-vps.sh status               serviços + HTTPS dos três nomes
#   bash bootstrap-vps.sh segredos             mostra a senha do banco e a chave do n8n,
#                                              pra copiar pro cofre (Bitwarden). Não colar em chat
#   bash bootstrap-vps.sh backup               pg_dump do banco do n8n em /root/crystal/backups
#                                              (guarda 14 dias). A chave do n8n NÃO vai junto
#   bash bootstrap-vps.sh backup-cron          agenda o backup todo dia às 03:30 (hora da VPS)
#   bash bootstrap-vps.sh backup-chave         gera a chave dos backups: a privada aparece só no
#                                              less (vai pro Bitwarden), a pública fica na VPS
#   bash bootstrap-vps.sh backup-fora-config   dados do R2 (segredo sem aparecer), testa e agenda:
#                                              cada backup sobe cifrado para o Cloudflare R2
#   bash bootstrap-vps.sh backup-conferir      lista o que está no R2 e há quanto tempo foi o último
#   bash bootstrap-vps.sh backup-testar-trava  tenta apagar um arquivo de teste no R2: tem que ser recusado
#   bash bootstrap-vps.sh backup-link [TIPO]   link de 10 min para baixar o backup mais novo (teste de
#                                              restauração no Mac). TIPO: n8n_queue (padrão), crystal_web_chat
#   bash bootstrap-vps.sh seguranca            atualização de segurança automática, fail2ban no SSH
#                                              e relatório (senha no SSH, root, portas, pendências)
#   bash bootstrap-vps.sh firewall             ufw: só 22, 80 e 443 de fora. As portas do Swarm
#                                              (2377, 7946, 4789) deixam de ficar públicas
#   bash bootstrap-vps.sh painel-restringir IP [IP ...]
#                                              painel. (Portainer) só para esses IPs; o resto
#                                              leva 403. Agente numa rede interna e imagens
#                                              presas na versão que roda. Sem IP: mostra a lista
#   bash bootstrap-vps.sh painel-desligar      tira o Portainer do ar (painel-ligar volta)
#   bash bootstrap-vps.sh recomecar-n8n EMAIL --confirmo
#                                              só ANTES de o n8n ter fluxo salvo: apaga o banco
#                                              do n8n e refaz com segredos novos
#
# App da Crystal (crystal-web-chat), em app. e api.crystalnowpp.com.br:
#   bash bootstrap-vps.sh app-ghcr             docker login no ghcr.io (token read:packages,
#                                              digitado sem aparecer). As imagens são privadas
#   bash bootstrap-vps.sh app-resend           pergunta a chave do Resend (sem aparecer) e o
#                                              remetente. Nada vai na linha de comando
#   bash bootstrap-vps.sh app-definir NOME     grava um valor externo (RESEND_API_KEY, EMAIL_FROM,
#                                              CRYSTAL_API_URL, ...). Sem NOME, lista os aceitos
#   bash bootstrap-vps.sh app-subir TAG        gera segredos (uma vez só), monta api.env e sobe
#                                              a stack crystal_app com a tag (ex.: sha-2b3dd56)
#   bash bootstrap-vps.sh app-status           serviços do app + HTTPS de app. e api.
#   bash bootstrap-vps.sh app-admin            cria o primeiro admin (CPF digitado sem aparecer,
#                                              não fica em spec, log nem histórico)
#   bash bootstrap-vps.sh app-segredos         mostra os segredos do app pra copiar pro cofre
#   bash bootstrap-vps.sh crystal-provisoria   Crystal provisória no n8n com o OpenRouter (pede a
#                                              chave sem aparecer) e o app apontando pra ela
#   bash bootstrap-vps.sh crystal-provisoria-teste      uma pergunta de teste, pela API do app
#   bash bootstrap-vps.sh crystal-provisoria-desligar   volta o app à Crystal simulada
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
#                                              só com o banco do app VAZIO: apaga o banco e
#                                              troca todos os segredos do app (vazaram?)
#
# Onde ficam as coisas:
#   /root/crystal/.segredos      senha do banco e chave de criptografia (chmod 600).
#                                NUNCA apagar nem regenerar: a chave do n8n não
#                                pode mudar depois de em uso
#   /root/crystal/stacks/*.yaml  arquivos prontos, com segredo dentro (chmod 600)
#   /root/crystal/originais/     os yaml da agência, sem alteração
#   /root/crystal/.painel-ips    IPs que entram no painel. (um por linha)
#   /root/crystal/app/.segredos  segredos do app (chmod 600). ENCRYPTION_KEY e CPF_SALT
#                                nunca podem mudar: sem eles o banco do app fica ilegível
#   /root/crystal/app/.externos  valores de fora (Resend, Crystal, base de clientes)
#   /root/crystal/app/*.env      o que a API e o Postgres do app leem (regerados a cada subida)
#
# O que ele NÃO faz: não instala Docker, não inicia o Swarm, não cria rede nem
# volumes. Isso já foi feito à mão em 29/09 e o script só confere.

set -euo pipefail

DOMINIO=crystalnowpp.com.br
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/${REF:-claude/gracious-shannon-6x9l5j}/crystal-em-casa/stacks-exemplo}"
BASE="${CRYSTAL_DIR:-/root/crystal}"
ORIG="$BASE/originais"
STACKS="$BASE/stacks"
SEGREDOS="$BASE/.segredos"
PAINEL_IPS_ARQ="$BASE/.painel-ips"
ARQUIVOS=(00-traefik.yaml 01-portainer.yaml 02-n8n-postgres.yaml 03-n8n-redis.yaml 04-n8n-editor.yaml 05-n8n-webhook.yaml 06-n8n-worker.yaml)
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CMD="${1:-}"
falha() { echo "ERRO: $*" >&2; exit 2; }
ok() { echo "  ok $*"; }
aviso() { echo "  ! $*"; }

[ -n "$CMD" ] || { awk 'NR==1{next} /^#/{print; next} {exit}' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

# ------------------------------------------------------------------ fundação
conferir_fundacao() {
  command -v docker >/dev/null || falha "docker não está instalado"
  [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = "active" ] || falha "Swarm não está ativo (docker swarm init)"
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager"
  docker network inspect network_swarm_public --format '{{.Driver}}' 2>/dev/null | grep -q overlay \
    || falha "rede network_swarm_public (overlay) não existe"
  for v in volume_swarm_certificates portainer_data n8n_postgres_data n8n_redis_data; do
    docker volume inspect "$v" >/dev/null 2>&1 || falha "volume $v não existe"
  done
  local no; no=$(docker node ls --format '{{.Hostname}}' | head -1)
  if ! docker node inspect "$no" --format '{{.Spec.Labels}}' | grep -q 'app:n8n'; then
    aviso "nó $no sem o rótulo app=n8n; aplicando"
    docker node update --label-add app=n8n "$no" >/dev/null
  fi
  ok "Swarm ativo, rede overlay, 4 volumes e rótulo app=n8n em $no"
  local min; min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  [ "$min" = "1.24" ] || aviso "o daemon exige API $min e o Traefik v2 usa 1.24: rode 'bash $0 docker-api' antes de subir o Traefik"
}

# ------------------------------------------------------------------ docker-api
# O Traefik v2.11 da agência fala com o Docker pela API 1.24. O Docker 29 exige
# 1.44 por padrão e recusa o Traefik ("client version 1.24 is too old"): sem
# isso o Traefik não descobre serviço nenhum e não pede certificado. A saída
# documentada é baixar o piso do daemon em /etc/docker/daemon.json.
docker_api() {
  local min; min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  if [ "$min" = "1.24" ]; then ok "daemon já aceita API 1.24"; return 0; fi
  echo "  piso atual do daemon: $min. Gravando min-api-version=1.24 em /etc/docker/daemon.json"
  python3 - <<'PY'
import json, os
p = '/etc/docker/daemon.json'
d = {}
if os.path.exists(p) and os.path.getsize(p) > 0:
    d = json.load(open(p))
d['min-api-version'] = '1.24'
json.dump(d, open(p, 'w'), indent=2)
PY
  dockerd --validate --config-file=/etc/docker/daemon.json >/dev/null || falha "daemon.json inválido; ver /etc/docker/daemon.json"
  systemctl restart docker
  local t=0
  until docker info >/dev/null 2>&1 || [ $t -ge 60 ]; do sleep 3; t=$((t+3)); done
  min=$(docker version --format '{{.Server.MinAPIVersion}}' 2>/dev/null || echo "?")
  [ "$min" = "1.24" ] && ok "daemon reiniciado, piso da API = 1.24" || falha "piso continua $min"
  echo "  os serviços do Swarm voltam sozinhos em até 1 min. Depois: bash $0 status"
}

# ------------------------------------------------------------------ preparar
preparar() {
  local email="${2:-}"
  [ -n "$email" ] || falha "informe o e-mail do Let's Encrypt: bash bootstrap-vps.sh preparar voce@exemplo.com"
  echo "$email" | grep -Eq '^[^@ ]+@[^@ ]+\.[^@ ]+$' || falha "e-mail inválido: $email"
  conferir_fundacao
  mkdir -p "$ORIG" "$STACKS"
  chmod 700 "$BASE" "$STACKS"

  # 1. Originais: da pasta local se o script estiver dentro do repositório, senão do GitHub
  for a in "${ARQUIVOS[@]}"; do
    if [ -f "$AQUI/stacks-exemplo/$a" ]; then
      cp "$AQUI/stacks-exemplo/$a" "$ORIG/$a"
    else
      curl -fsSL -m 60 "$REPO_RAW/$a" -o "$ORIG/$a" || falha "não baixou $a de $REPO_RAW"
    fi
    grep -q '^services:' "$ORIG/$a" || falha "$a não parece um compose (baixou uma página de erro?)"
  done
  ok "${#ARQUIVOS[@]} originais em $ORIG"

  # 2. Segredos: gerados uma vez, nunca regenerados
  if [ -f "$SEGREDOS" ]; then
    ok "segredos já existem em $SEGREDOS (mantidos)"
  else
    umask 077
    {
      echo "DB_SENHA=$(openssl rand -hex 24)"
      echo "N8N_CHAVE=$(openssl rand -hex 16)"
      echo "CRIADO_EM=$(date -u +%FT%TZ)"
    } > "$SEGREDOS"
    ok "segredos gerados em $SEGREDOS. Copie pro cofre: bash $0 segredos"
  fi
  # shellcheck disable=SC1090
  . "$SEGREDOS"
  [ "${#N8N_CHAVE}" -eq 32 ] || falha "chave do n8n em $SEGREDOS não tem 32 caracteres"

  # 3. Arquivos prontos
  umask 077
  for a in "${ARQUIVOS[@]}"; do
    sed -e "s|seudominio\.com\.br|$DOMINIO|g" \
        -e "s|SEU_EMAIL_AQUI|$email|g" \
        -e "s|SUBSTITUA_PELA_SENHA_DO_BANCO|$DB_SENHA|g" \
        -e "s|SUBSTITUA_PELA_CHAVE_DE_CRIPTOGRAFIA|$N8N_CHAVE|g" \
        "$ORIG/$a" > "$STACKS/$a"
    if grep -nE 'SUBSTITUA|SEU_EMAIL|seudominio' "$STACKS/$a" | grep -vE '^\s*[0-9]+:\s*#' | grep -q .; then
      falha "$a ainda tem placeholder fora de comentário"
    fi
  done
  ok "${#ARQUIVOS[@]} arquivos prontos em $STACKS (chmod 600)"
  # O 01 acima saiu do original, aberto. Se o painel já estava restrito, refaz a trava.
  if [ -s "$PAINEL_IPS_ARQ" ]; then
    painel_gerar || aviso "01-portainer.yaml ficou como o original, ABERTO. Depois de subir: bash $0 painel-restringir IP"
  fi
  echo
  echo "Conferência do que mudou (só linhas com o domínio e o e-mail):"
  grep -hE "Host\(|N8N_HOST=|WEBHOOK_URL=|acme.email=" "$STACKS"/*.yaml | sed 's/^ *//' | sort -u
  echo
  echo "Próximo: bash $0 tudo   (ou traefik, portainer, bancos, n8n, um de cada vez)"
}

# ------------------------------------------------------------------ subir
esperar_stack() { # esperar_stack NOME_DA_STACK [SEGUNDOS]
  local stack=$1 limite=${2:-240} t=0 linhas pendentes
  while :; do
    linhas=$(docker service ls --filter "label=com.docker.stack.namespace=$stack" --format '{{.Name}} {{.Replicas}}')
    [ -n "$linhas" ] || falha "stack $stack não tem serviço nenhum"
    pendentes=$(echo "$linhas" | awk '{split($2,r,"/"); if (r[1]!=r[2] || r[2]=="0") print}')
    # 1/1 não basta logo depois de um deploy: a tarefa antiga ainda conta. Espera
    # também as atualizações em andamento terminarem.
    local s st
    for s in $(echo "$linhas" | awk '{print $1}'); do
      st=$(docker service inspect -f '{{if .UpdateStatus}}{{.UpdateStatus.State}}{{end}}' "$s" 2>/dev/null || true)
      case "$st" in updating|rollback_started|paused) pendentes="$pendentes"$'\n'"$s atualizando" ;; esac
    done
    pendentes=$(echo "$pendentes" | sed '/^$/d')
    if [ -z "$pendentes" ]; then
      echo "$linhas" | sed 's/^/  ok /'
      return 0
    fi
    if [ "$t" -ge "$limite" ]; then
      aviso "passaram ${limite}s e ainda não está 1/1:"
      echo "$pendentes" | sed 's/^/     /'
      echo "  Diagnóstico:"
      echo "$pendentes" | awk '{print $1}' | while read -r s; do
        docker service ps "$s" --no-trunc --format '     {{.Name}} {{.CurrentState}} {{.Error}}' | head -5
      done
      return 1
    fi
    sleep 5; t=$((t+5))
  done
}

deploy() { # deploy ARQUIVO STACK
  [ -f "$STACKS/$1" ] || falha "$STACKS/$1 não existe: rode 'preparar' antes"
  echo "== $2 ($1)"
  docker stack deploy -c "$STACKS/$1" "$2" --detach=true >/dev/null
  esperar_stack "$2"
}

traefik()   { conferir_fundacao; deploy 00-traefik.yaml traefik; }
portainer() { deploy 01-portainer.yaml portainer; echo "  Abra https://painel.$DOMINIO AGORA e crie o admin: o Portainer tranca a criação se demorar"; }
bancos()    { deploy 02-n8n-postgres.yaml n8n_postgres; deploy 03-n8n-redis.yaml n8n_redis; }
n8n()       { deploy 04-n8n-editor.yaml n8n_editor; deploy 05-n8n-webhook.yaml n8n_webhook; deploy 06-n8n-worker.yaml n8n_worker; }
tudo()      { traefik; portainer; bancos; n8n; echo; status; }

# ------------------------------------------------------------------ backup
# O guia da agência pede backup do banco do n8n (fluxos e credenciais) e a
# chave de criptografia guardada SEPARADA. Aqui só o banco; a chave fica no
# cofre. Um dump sem a chave não restaura credenciais, e é por isso que os
# dois nunca andam juntos.
BACKUPS="$BASE/backups"
FORA_CONF="$BASE/.backup-fora"            # conta, bucket e chave do R2 (chmod 600)
FORA_DEST="$BASE/.backup-destinatario"    # chave PÚBLICA do age; a privada fica só no Bitwarden
FORA_PREFIXO=vps-crystal

backup() {
  local dir="$BACKUPS" cid ts novos=()
  mkdir -p "$dir"; chmod 700 "$dir"
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  echo "== backup $ts"
  cid=$(docker ps -q -f name=n8n_postgres_n8n_postgres | head -1)
  [ -n "$cid" ] || falha "contêiner do Postgres do n8n não está rodando"
  local arq="$dir/n8n_queue-$ts.sql.gz"
  umask 077
  docker exec "$cid" pg_dump -U postgres -d n8n_queue --no-owner | gzip > "$arq" || falha "pg_dump falhou"
  [ -s "$arq" ] || falha "dump vazio em $arq"
  ok "backup em $arq ($(du -h "$arq" | cut -f1))"
  novos+=("$arq")
  echo "  Restaurar: gunzip -c ARQ | docker exec -i CID psql -U postgres -d n8n_queue"
  echo "  Lembrete: o backup só restaura credenciais com a N8N_CHAVE do cofre."

  # Banco do app, se a stack crystal_app estiver no ar. Campos cifrados e o
  # hash do CPF só se leem com ENCRYPTION_KEY e CPF_SALT, que ficam no cofre.
  cid=$(docker ps -q -f name=crystal_app_app_postgres | head -1)
  if [ -n "$cid" ]; then
    arq="$dir/crystal_web_chat-$ts.sql.gz"
    docker exec "$cid" pg_dump -U crystal -d crystal_web_chat --no-owner | gzip > "$arq" || falha "pg_dump do app falhou"
    [ -s "$arq" ] || falha "dump do app vazio em $arq"
    ok "backup do app em $arq ($(du -h "$arq" | cut -f1))"
    novos+=("$arq")
  fi
  # Arquivos que os alunos mandam pelo app (imagem, áudio).
  local up=/var/lib/docker/volumes/${APP_STACK}_app_uploads/_data
  if [ -d "$up" ]; then
    arq="$dir/crystal_uploads-$ts.tar.gz"
    tar -C "$up" -czf "$arq" . || falha "tar dos uploads falhou"
    ok "uploads do app em $arq ($(du -h "$arq" | cut -f1))"
    novos+=("$arq")
  fi
  find "$dir" -maxdepth 1 \( -name 'n8n_queue-*' -o -name 'crystal_web_chat-*' -o -name 'crystal_uploads-*' \) -mtime +14 -delete
  echo "  $(find "$dir" -maxdepth 1 -name '*.gz' | wc -l) arquivo(s) na VPS (14 dias)"

  if [ -s "$FORA_CONF" ] && [ -s "$FORA_DEST" ]; then
    backup_fora "${novos[@]}"
  else
    aviso "cópia fora da VPS não configurada (backup-chave e backup-fora-config)"
  fi
}

backup_cron() {
  local linha="30 3 * * * root /usr/bin/bash $BASE/bootstrap-vps.sh backup >> $BACKUPS/backup.log 2>&1"
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"
  cp "$AQUI/$(basename "$0")" "$BASE/bootstrap-vps.sh" 2>/dev/null || true
  printf '%s\n' "$linha" > /etc/cron.d/crystal-backup-n8n
  chmod 644 /etc/cron.d/crystal-backup-n8n
  ok "cron instalado em /etc/cron.d/crystal-backup-n8n: todo dia 03:30, log em $BACKUPS/backup.log"
  if [ -s "$FORA_CONF" ]; then ok "cada backup também vai cifrado para o R2"
  else aviso "só na VPS por enquanto: falta backup-chave e backup-fora-config"; fi
}

# ------------------------------------------------------------------ backup fora da VPS
# Cada arquivo do backup é cifrado aqui com age, para a chave PÚBLICA, e sobe para
# um bucket do Cloudflare R2 com trava (bucket lock) de 30 dias. Quem invadir a
# VPS acha a chave do R2, mas:
#   - não lê os backups: a chave privada nunca fica na VPS;
#   - não apaga nem sobrescreve: a trava do bucket recusa, mesmo com a chave.
# Envio pelo curl (assinatura S3 v4), sem instalar cliente; a chave do R2 vai ao
# curl pela entrada padrão, nunca na linha de comando (que aparece no ps).
fora_ler_conf() {
  [ -s "$FORA_CONF" ] || falha "R2 não configurado: bash $0 backup-fora-config"
  R2_CONTA=$(app_valor "$FORA_CONF" R2_CONTA); R2_BUCKET=$(app_valor "$FORA_CONF" R2_BUCKET)
  R2_CHAVE_ID=$(app_valor "$FORA_CONF" R2_CHAVE_ID); R2_SEGREDO=$(app_valor "$FORA_CONF" R2_SEGREDO)
  R2_URL="${R2_ENDPOINT:-https://$R2_CONTA.r2.cloudflarestorage.com}/$R2_BUCKET"
}

fora_curl() { # fora_curl ARGS... (credenciais pela entrada padrão)
  printf 'user = "%s:%s"\n' "$R2_CHAVE_ID" "$R2_SEGREDO" \
    | curl -K - -s -m 300 --aws-sigv4 "aws:amz:${R2_REGIAO:-auto}:s3" "$@"
}

fora_enviar() { # fora_enviar ARQUIVO CHAVE_NO_BUCKET -> 0 se o R2 confirmou
  local sha code resp
  sha=$(sha256sum "$1" | cut -d' ' -f1)
  resp=$(mktemp)
  code=$(fora_curl -o "$resp" -w '%{http_code}' -T "$1" -H "x-amz-content-sha256: $sha" "$R2_URL/$2") || code=000
  if [ "$code" = 200 ]; then rm -f "$resp"; return 0; fi
  aviso "R2 respondeu $code para $2: $(head -c 300 "$resp" | tr -d '\n')"
  rm -f "$resp"; return 1
}

backup_fora() { # backup_fora ARQUIVO... cifra e envia; falha se algum não subir
  command -v age >/dev/null || falha "age não instalado: bash $0 backup-chave"
  fora_ler_conf
  local dest a obj tmp erros=0
  dest=$(cat "$FORA_DEST")
  echo "== fora da VPS (R2, bucket $R2_BUCKET)"
  for a in "$@"; do
    obj="$FORA_PREFIXO/$(basename "$a" | sed -E 's/-[0-9]{8}T.*//')/$(date -u +%Y/%m)/$(basename "$a").age"
    tmp=$(mktemp "$BACKUPS/.envio.XXXXXX")
    if age -r "$dest" -o "$tmp" "$a" && fora_enviar "$tmp" "$obj"; then
      ok "$obj ($(du -h "$tmp" | cut -f1), cifrado)"
    else
      erros=$((erros+1))
    fi
    rm -f "$tmp"
  done
  [ "$erros" -eq 0 ] || falha "$erros arquivo(s) não subiram para o R2. Ficaram só na VPS"
  date -u +%FT%TZ > "$BACKUPS/.fora-ultimo"
}

backup_chave() {
  if [ -s "$FORA_DEST" ] && [ "${1:-}" != "--nova" ]; then
    ok "já existe chave: $(cat "$FORA_DEST")"
    echo "  Trocar só se a privada se perdeu ou vazou: bash $0 backup-chave --nova"
    echo "  (os backups antigos continuam abrindo só com a chave antiga)"
    return 0
  fi
  [ -t 0 ] && [ -t 1 ] || falha "rode num terminal (a chave aparece só no less)"
  command -v age-keygen >/dev/null || { apt-get -qq update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get -y -qq install age >/dev/null || falha "não instalou o age"; }
  local pub priv fim tent
  # Só em variável: a chave privada nunca é gravada em arquivo na VPS.
  priv=$(age-keygen 2>/dev/null | grep -E '^AGE-SECRET-KEY-1[0-9A-Z]+$' || true)
  pub=$(printf '%s\n' "$priv" | age-keygen -y 2>/dev/null || true)
  [ -n "$priv" ] && echo "$pub" | grep -Eq '^age1[0-9a-z]+$' || falha "age-keygen não gerou a chave"
  for tent in 1 2 3; do
    {
      echo "CHAVE PRIVADA DOS BACKUPS. Copie a linha AGE-SECRET-KEY-... inteira para um item"
      echo "novo no Bitwarden (\"Crystal backup age\"). Sem ela, NENHUM backup abre."
      echo "Ela não fica na VPS: ao fechar (q), some. Não cole em chat nem em e-mail."
      echo
      echo "$priv"
      echo
      echo "(chave pública, que fica na VPS: $pub)"
    } | less -K
    read -rp "Digite os 6 ÚLTIMOS caracteres da chave, lendo do Bitwarden: " fim
    fim=$(echo "$fim" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    if [ "${#fim}" -eq 6 ] && [ "${priv: -6}" = "$fim" ]; then
      umask 077; echo "$pub" > "$FORA_DEST"; chmod 600 "$FORA_DEST"
      priv=""
      ok "chave pública gravada em $FORA_DEST; a privada só no Bitwarden"
      echo "Próximo: bash $0 backup-fora-config"
      return 0
    fi
    aviso "não confere. Mostrando de novo ($tent de 3)"
  done
  priv=""
  falha "nada gravado. Rode de novo quando der para salvar no Bitwarden"
}

backup_fora_config() {
  [ -s "$FORA_DEST" ] || falha "primeiro: bash $0 backup-chave"
  [ -t 0 ] || falha "rode num terminal"
  local conta bucket id seg t
  echo "Dados do R2 (Cloudflare > R2). O segredo não aparece enquanto você digita."
  read -rp "Account ID (32 caracteres, na página inicial do R2): " conta
  echo "$conta" | grep -Eq '^[0-9a-f]{32}$' || falha "Account ID inválido"
  read -rp "Nome do bucket [crystal-backups]: " bucket; bucket=${bucket:-crystal-backups}
  echo "$bucket" | grep -Eq '^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$' || falha "nome de bucket inválido"
  read -rp "Access Key ID (32 caracteres): " id
  echo "$id" | grep -Eq '^[0-9a-f]{32}$' || falha "Access Key ID inválido (é o de 32 caracteres, não o token de 40)"
  read -rsp "Secret Access Key (64 caracteres, não aparece): " seg; echo
  echo "$seg" | grep -Eq '^[0-9a-f]{64}$' || { seg=""; falha "Secret Access Key inválida (64 caracteres hexadecimais)"; }
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"
  umask 077
  printf 'R2_CONTA=%s\nR2_BUCKET=%s\nR2_CHAVE_ID=%s\nR2_SEGREDO=%s\n' "$conta" "$bucket" "$id" "$seg" > "$FORA_CONF.novo"
  seg=""
  echo "== teste de envio"
  local conf_ok=0
  mv "$FORA_CONF.novo" "$FORA_CONF"; chmod 600 "$FORA_CONF"
  fora_ler_conf
  t=$(mktemp "$BACKUPS/.teste.XXXXXX")
  echo "teste $(date -u +%FT%TZ)" | age -r "$(cat "$FORA_DEST")" -o "$t"
  fora_enviar "$t" "$FORA_PREFIXO/teste/$(date -u +%Y%m%dT%H%M%SZ).age" && conf_ok=1
  rm -f "$t"
  if [ "$conf_ok" -ne 1 ]; then
    rm -f "$FORA_CONF"
    falha "o envio de teste falhou (Account ID, bucket ou chave?). Nada gravado; rode de novo"
  fi
  ok "R2 aceitou o envio; dados gravados em $FORA_CONF"
  backup_cron
  echo "Próximo: bash $0 backup   (faz um backup agora e manda pro R2)"
}

# Link temporário (10 min) para baixar o backup mais novo de um tipo, para o teste
# de restauração no Mac sem passar pelo painel. O link só baixa aquele arquivo, que
# está cifrado; mesmo assim, não colar em chat.
backup_link() {
  local tipo="${1:-n8n_queue}" xml code
  echo "$tipo" | grep -Eq '^(n8n_queue|crystal_web_chat|crystal_uploads)$' || falha "tipo: n8n_queue, crystal_web_chat ou crystal_uploads"
  fora_ler_conf
  xml=$(mktemp)
  code=$(fora_curl -o "$xml" -w '%{http_code}' "$R2_URL?list-type=2&prefix=$FORA_PREFIXO") || code=000
  if [ "$code" != 200 ]; then aviso "listagem do R2 respondeu $code"; rm -f "$xml"; exit 1; fi
  R2_URL="$R2_URL" R2_CHAVE_ID="$R2_CHAVE_ID" R2_SEGREDO="$R2_SEGREDO" R2_REGIAO="${R2_REGIAO:-auto}" \
    python3 - "$xml" "$FORA_PREFIXO/$tipo/" <<'PY'
import datetime, hashlib, hmac, os, sys, urllib.parse, xml.etree.ElementTree as ET
ns = {'s': 'http://s3.amazonaws.com/doc/2006-03-01/'}
chaves = sorted(c.find('s:Key', ns).text for c in ET.parse(sys.argv[1]).getroot().findall('s:Contents', ns)
                if c.find('s:Key', ns).text.startswith(sys.argv[2]))
if not chaves:
    sys.exit("ERRO: nenhum backup desse tipo no R2")
chave = chaves[-1]
base = urllib.parse.urlsplit(os.environ['R2_URL'])
host, caminho = base.netloc, base.path + '/' + urllib.parse.quote(chave, safe='/')
agora = datetime.datetime.now(datetime.timezone.utc)
data, carimbo = agora.strftime('%Y%m%d'), agora.strftime('%Y%m%dT%H%M%SZ')
escopo = f"{data}/{os.environ['R2_REGIAO']}/s3/aws4_request"
q = {'X-Amz-Algorithm': 'AWS4-HMAC-SHA256', 'X-Amz-Credential': f"{os.environ['R2_CHAVE_ID']}/{escopo}",
     'X-Amz-Date': carimbo, 'X-Amz-Expires': '600', 'X-Amz-SignedHeaders': 'host'}
qs = '&'.join(f"{urllib.parse.quote(k, safe='')}={urllib.parse.quote(v, safe='')}" for k, v in sorted(q.items()))
canon = '\n'.join(['GET', caminho, qs, f'host:{host}', '', 'host', 'UNSIGNED-PAYLOAD'])
assinar = '\n'.join(['AWS4-HMAC-SHA256', carimbo, escopo, hashlib.sha256(canon.encode()).hexdigest()])
k = ('AWS4' + os.environ['R2_SEGREDO']).encode()
for parte in (data, os.environ['R2_REGIAO'], 's3', 'aws4_request'):
    k = hmac.new(k, parte.encode(), hashlib.sha256).digest()
sig = hmac.new(k, assinar.encode(), hashlib.sha256).hexdigest()
nome = chave.rsplit('/', 1)[-1]
print(f"Backup: {chave}")
print("Link válido por 10 minutos. No Terminal do Mac, cole a linha abaixo INTEIRA (não cole em chat):")
print()
print(f"curl -fo ~/Downloads/{nome} '{base.scheme}://{host}{caminho}?{qs}&X-Amz-Signature={sig}'")
PY
  rm -f "$xml"
}

# Prova a trava do bucket: sobe um arquivo de teste e tenta apagá-lo com a própria
# chave da VPS (que tem permissão de apagar). Com a trava, o R2 recusa.
backup_testar_trava() {
  fora_ler_conf
  local t obj code
  t=$(mktemp "$BACKUPS/.teste.XXXXXX")
  echo "teste da trava $(date -u +%FT%TZ)" | age -r "$(cat "$FORA_DEST")" -o "$t"
  obj="$FORA_PREFIXO/teste/trava-$(date -u +%Y%m%dT%H%M%SZ).age"
  fora_enviar "$t" "$obj" || { rm -f "$t"; falha "não subiu o arquivo de teste"; }
  rm -f "$t"
  code=$(fora_curl -o /dev/null -w '%{http_code}' -X DELETE "$R2_URL/$obj") || code=000
  case "$code" in
    200|204) aviso "o R2 APAGOU o arquivo (resposta $code): a trava NÃO está valendo. Conferir Settings > Bucket lock rules (prefixo vazio, 30 dias)"; exit 1 ;;
    000) aviso "sem resposta do R2; rode de novo" ; exit 1 ;;
    *) ok "o R2 recusou apagar (resposta $code): a trava está valendo. Quem invadir a VPS não apaga os backups" ;;
  esac
}

backup_conferir() {
  fora_ler_conf
  local xml code
  xml=$(mktemp)
  code=$(fora_curl -o "$xml" -w '%{http_code}' "$R2_URL?list-type=2&prefix=$FORA_PREFIXO") || code=000
  if [ "$code" != 200 ]; then aviso "listagem do R2 respondeu $code: $(head -c 300 "$xml")"; rm -f "$xml"; exit 1; fi
  python3 - "$xml" <<'PY'
import sys, datetime, xml.etree.ElementTree as ET
ns = {'s': 'http://s3.amazonaws.com/doc/2006-03-01/'}
itens = [(c.find('s:Key', ns).text, int(c.find('s:Size', ns).text), c.find('s:LastModified', ns).text)
         for c in ET.parse(sys.argv[1]).getroot().findall('s:Contents', ns)]
itens.sort(key=lambda i: i[2])
print(f"  {len(itens)} objeto(s) no R2 (a listagem mostra até 1000)")
for k, t, m in itens[-9:]:
    print(f"  {m[:19].replace('T', ' ')}  {t/1024:9.1f} KB  {k}")
reais = [i for i in itens if '/teste/' not in i[0]]
if reais:
    ult = datetime.datetime.fromisoformat(reais[-1][2].replace('Z', '+00:00'))
    h = (datetime.datetime.now(datetime.timezone.utc) - ult).total_seconds() / 3600
    print(("  ok" if h < 26 else "  !") + f" último backup no R2 há {h:.0f} h")
else:
    print("  ! nenhum backup de verdade no R2 ainda")
PY
  rm -f "$xml"
}

# ------------------------------------------------------------------ firewall
# Nó único: ninguém de fora precisa falar com o Swarm. O Docker publica 80 e
# 443 por conta própria (passa por cima do ufw), então o que o ufw realmente
# fecha são as portas do Swarm e qualquer coisa que subir por engano. O Web
# console da Hostinger continua funcionando mesmo se o SSH for bloqueado.
firewall() {
  command -v ufw >/dev/null || { apt-get -qq update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get -y -qq install ufw >/dev/null; }
  ufw default deny incoming >/dev/null
  ufw default allow outgoing >/dev/null
  ufw allow 22/tcp comment 'ssh' >/dev/null
  ufw allow 80/tcp comment 'traefik http' >/dev/null
  ufw allow 443/tcp comment 'traefik https' >/dev/null
  ufw --force enable >/dev/null
  ok "ufw ativo: entrada só 22, 80 e 443"
  ufw status | sed 's/^/  /'
  echo "  Conferir de fora: as três URLs em HTTPS continuam respondendo (bash $0 status)."
}

# ------------------------------------------------------------------ seguranca
# Proteções da máquina contra ataque e malware que não mexem em nenhum serviço:
#   - atualização de segurança automática do Ubuntu (sem reiniciar sozinho);
#   - fail2ban no SSH: 5 tentativas erradas em 10 min bloqueiam o IP por 1 hora;
#   - relatório do que ainda depende de decisão: senha no SSH, root, portas abertas.
# O Web console da Hostinger continua funcionando mesmo com um IP bloqueado.
seguranca() {
  export DEBIAN_FRONTEND=noninteractive
  echo "== pacotes"
  apt-get -qq update >/dev/null
  apt-get -y -qq install unattended-upgrades fail2ban python3-systemd >/dev/null || falha "não instalou os pacotes"
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<'CFG'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
CFG
  ok "atualização de segurança automática ligada (sem reinício automático)"

  cat > /etc/fail2ban/jail.d/crystal.local <<'CFG'
[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
CFG
  systemctl enable fail2ban >/dev/null 2>&1 || true
  systemctl restart fail2ban || falha "fail2ban não subiu: journalctl -u fail2ban"
  sleep 2
  fail2ban-client status sshd >/dev/null 2>&1 && ok "fail2ban protegendo o SSH" || aviso "fail2ban no ar, mas a regra do SSH não respondeu: fail2ban-client status sshd"

  echo "== o que ainda depende de decisão"
  local pw root
  pw=$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2}')
  root=$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2}')
  if [ "$pw" = "yes" ]; then
    aviso "SSH aceita senha. Mais seguro: só chave. Antes de desligar a senha, confira que sua chave entra"
    aviso "(o Web console da Hostinger continua como porta de emergência)."
  else
    ok "SSH não aceita senha"
  fi
  [ "$root" = "yes" ] && aviso "root entra por SSH com senha; com chave só, use: PermitRootLogin prohibit-password" || ok "root: $root"
  ufw status 2>/dev/null | grep -q "Status: active" && ok "ufw ativo" || aviso "ufw desligado: bash $0 firewall"
  echo "  Portas escutando (de fora só passam 22, 80 e 443; as do Swarm, 2377, 7946 e 4789, o ufw fecha):"
  ss -Htlnp 2>/dev/null | awk '{print $4}' | grep -vE '^(127\.|\[::1\])' | sed -E 's/.*:([0-9]+)$/\1/' | sort -un | tr '\n' ' ' | sed 's/^/    /'; echo
  local up; up=$(apt list --upgradable 2>/dev/null | grep -c -- '-security' || true)
  [ "${up:-0}" -gt 0 ] && aviso "$up pacote(s) de segurança pendentes; a atualização automática aplica hoje à noite" || ok "sem atualização de segurança pendente"
  [ -f /var/run/reboot-required ] && aviso "o Ubuntu pede reinício para aplicar atualização do kernel: agende na madrugada" || true
}

# ------------------------------------------------------------------ painel (Portainer)
# O Portainer manda em todo o Docker da VPS e guarda o token do ghcr. Aberto na
# internet, só a senha o protege (o CE não tem 2FA). painel-restringir sobe o
# stacks-app/01-portainer-restrito.yaml: 403 do Traefik para quem não está na
# lista, agente numa rede interna e imagens presas no digest que já roda.
# IP mudou? Pelo Web console da Hostinger (que não depende de IP), rode de novo
# com o IP novo.
PAINEL_YAML=01-portainer-restrito.yaml

painel_validar() { # painel_validar IP... -> lista normalizada, uma por linha
  python3 - "$@" <<'PY'
import ipaddress, sys
saida = []
for a in sys.argv[1:]:
    try:
        n = ipaddress.ip_network(a.strip(), strict=False)
    except ValueError:
        sys.exit(f"ERRO: '{a}' não é IP nem faixa (ex.: 189.1.2.3 ou 189.1.2.0/24)")
    minimo = 16 if n.version == 4 else 48
    if n.prefixlen < minimo:
        sys.exit(f"ERRO: {n} é larga demais (mínimo /{minimo})")
    if not n.is_global:
        sys.exit(f"ERRO: {n} não é IP público. O seu aparece em https://1.1.1.1/cdn-cgi/trace, na linha ip=")
    if str(n) not in saida:
        saida.append(str(n))
print("\n".join(saida))
PY
}

painel_imagem() { # painel_imagem portainer|agent -> imagem@digest que está rodando
  local img
  img=$(docker service inspect "portainer_$1" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || true)
  echo "$img" | grep -Eq '^(docker\.io/)?portainer/(portainer-ce|agent):[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}$' || return 1
  echo "$img"
}

painel_gerar() { # grava $STACKS/01-portainer.yaml restrito, a partir do modelo e da lista
  [ -s "$PAINEL_IPS_ARQ" ] || { aviso "sem lista de IPs em $PAINEL_IPS_ARQ"; return 1; }
  local pimg aimg ips
  pimg=$(painel_imagem portainer) || { aviso "serviço portainer_portainer não encontrado com imagem@digest: suba antes com 'bash $0 portainer'"; return 1; }
  aimg=$(painel_imagem agent) || { aviso "serviço portainer_agent não encontrado com imagem@digest"; return 1; }
  ips=$(paste -sd, "$PAINEL_IPS_ARQ")
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  if [ -f "$AQUI/stacks-app/$PAINEL_YAML" ]; then
    cp "$AQUI/stacks-app/$PAINEL_YAML" "$ORIG/$PAINEL_YAML"
  else
    curl -fsSL -m 60 "$APP_RAW/$PAINEL_YAML" -o "$ORIG/$PAINEL_YAML" || { aviso "não baixou $PAINEL_YAML de $APP_RAW"; return 1; }
  fi
  grep -q 'ipallowlist.sourcerange=PAINEL_IPS' "$ORIG/$PAINEL_YAML" || { aviso "$PAINEL_YAML não é o modelo esperado"; return 1; }
  umask 077
  # Guarda a versão aberta uma vez, para voltar atrás se precisar.
  if [ -f "$STACKS/01-portainer.yaml" ] && ! grep -q ipallowlist "$STACKS/01-portainer.yaml"; then
    cp "$STACKS/01-portainer.yaml" "$STACKS/01-portainer.yaml.aberto"
  fi
  sed -e "s|PAINEL_IPS|$ips|g" -e "s|PORTAINER_IMG|$pimg|g" -e "s|AGENT_IMG|$aimg|g" \
    "$ORIG/$PAINEL_YAML" > "$STACKS/01-portainer.yaml"
  chmod 600 "$STACKS/01-portainer.yaml"
  if grep -nE 'PAINEL_IPS|PORTAINER_IMG|AGENT_IMG' "$STACKS/01-portainer.yaml" | grep -vE '^\s*[0-9]+:\s*#' | grep -q .; then
    aviso "marcador sobrando em $STACKS/01-portainer.yaml"; return 1
  fi
  ok "01-portainer.yaml restrito: $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  ok "imagens presas: $pimg e $aimg"
}

painel_restringir() {
  if [ $# -eq 0 ]; then
    if [ -s "$PAINEL_IPS_ARQ" ]; then
      echo "painel. liberado só para:"; sed 's/^/  /' "$PAINEL_IPS_ARQ"
    else
      echo "painel. está aberto para qualquer IP."
    fi
    echo
    echo "Para liberar: no computador de quem vai usar o painel, abra https://1.1.1.1/cdn-cgi/trace"
    echo "e copie o número da linha ip=. Depois: bash $0 painel-restringir ESSE_IP [OUTRO_IP ...]"
    echo "A lista nova SUBSTITUI a anterior (ponha todos de uma vez)."
    return 0
  fi
  local lista
  lista=$(painel_validar "$@") || exit 2
  umask 077
  printf '%s\n' "$lista" > "$PAINEL_IPS_ARQ.novo"
  mv "$PAINEL_IPS_ARQ.novo" "$PAINEL_IPS_ARQ"
  painel_gerar || exit 2
  echo "== portainer (o painel fica fora do ar por uns segundos)"
  docker stack deploy -c "$STACKS/01-portainer.yaml" portainer --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack portainer 240 || exit 1
  painel_conferir
}

painel_conferir() {
  echo "== conferindo (o Traefik leva até 30 s para ler a regra nova)"
  local code="" t=0 cid
  while :; do
    code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://painel.$DOMINIO/" 2>/dev/null) || true
    [ "$code" = "403" ] || [ $t -ge 60 ] && break
    sleep 5; t=$((t+5))
  done
  if [ "$code" = "403" ]; then
    ok "https://painel.$DOMINIO -> 403 para quem não está na lista (a própria VPS é um deles)"
  else
    aviso "https://painel.$DOMINIO -> ${code:-000} vindo da VPS; o esperado era 403. Ver: docker service logs --tail 50 traefik_traefik"
  fi
  # Um contêiner da rede pública (o n8n) não pode mais chegar ao agente.
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  if [ -n "$cid" ]; then
    if docker exec "$cid" node -e "const s=require('net').connect(9001,'portainer_agent');s.on('connect',()=>process.exit(0));s.on('error',()=>process.exit(1));setTimeout(()=>process.exit(1),4000)" >/dev/null 2>&1; then
      aviso "o n8n ainda alcança o agente do Portainer (porta 9001)"
    else
      ok "o n8n não alcança mais o agente do Portainer"
    fi
  fi
  echo "  Agora, de um IP liberado: abra https://painel.$DOMINIO, entre, e confira que o ambiente"
  echo "  'primary' aparece como up. Se não aparecer: docker service logs --tail 50 portainer_portainer"
  echo "  Voltar ao aberto (só em emergência): docker stack deploy -c $STACKS/01-portainer.yaml.aberto portainer"
}

painel_desligar() {
  docker service scale portainer_portainer=0 --detach=false >/dev/null || falha "não desligou"
  ok "Portainer fora do ar (o agente segue, na rede interna). Religar: bash $0 painel-ligar"
}

painel_ligar() {
  docker service scale portainer_portainer=1 --detach=false >/dev/null || falha "não ligou"
  ok "Portainer no ar"
  [ -s "$PAINEL_IPS_ARQ" ] || aviso "painel. aberto para qualquer IP: bash $0 painel-restringir"
}

# ------------------------------------------------------------------ status
status() {
  echo "== Serviços"
  docker service ls --format '{{.Name}} {{.Replicas}} {{.Image}}' | awk '{printf "  %-28s %-5s %s\n",$1,$2,$3}'
  echo
  echo "== HTTPS pelos nomes públicos (certificado tem que ser válido, sem -k)"
  for h in painel editor webhook; do
    local code
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$h.$DOMINIO/" 2>/dev/null) || true
    code=${code:-000}
    case "$h:$code" in
      painel:403) ok "https://$h.$DOMINIO -> 403 (restrito por IP; a VPS não está na lista)" ;;
      *:200|*:301|*:302|*:401|*:404) ok "https://$h.$DOMINIO -> $code" ;;
      *:000) aviso "https://$h.$DOMINIO sem resposta ou certificado inválido (Traefik ainda emitindo? DNS? porta 443 fechada?)" ;;
      *) aviso "https://$h.$DOMINIO -> $code" ;;
    esac
  done
  if [ -s "$FORA_CONF" ] && [ -s "$BACKUPS/.fora-ultimo" ]; then
    local h; h=$(( ($(date +%s) - $(date -d "$(cat "$BACKUPS/.fora-ultimo")" +%s)) / 3600 ))
    if [ "$h" -lt 26 ]; then ok "último backup no R2 há ${h} h"; else aviso "último backup no R2 há ${h} h: ver $BACKUPS/backup.log"; fi
  else
    aviso "backup fora da VPS não configurado (backup-chave, backup-fora-config)"
  fi
  if [ -s "$PAINEL_IPS_ARQ" ]; then
    echo "  painel. liberado só para: $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  else
    aviso "painel. (Portainer) aberto para qualquer IP: bash $0 painel-restringir"
  fi
  echo
  echo "== Últimas linhas do Traefik sobre certificado (o log vai pra arquivo dentro do contêiner)"
  local cid; cid=$(docker ps -q -f name=traefik_traefik | head -1)
  if [ -n "$cid" ]; then
    docker exec "$cid" tail -200 /var/log/traefik/traefik.log 2>/dev/null | grep -iE 'acme|certif|error' | tail -8 || echo "  (nada sobre certificado no log ainda)"
  else
    aviso "contêiner do Traefik não encontrado"
  fi
}

segredos() {
  [ -f "$SEGREDOS" ] || falha "ainda não há segredos: rode 'preparar'"
  # Abre no less (tela alternativa): ao apertar q, os valores somem da tela e
  # não ficam no histórico do terminal. É pra copiar direto pro cofre.
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Copie DB_SENHA e N8N_CHAVE pro Bitwarden, em itens separados."
      echo "Aperte q pra fechar: os valores somem da tela e não vão pro histórico."
      echo "A chave N8N_CHAVE nunca pode mudar depois de o n8n ter fluxo salvo."
      echo
      grep -E '^(DB_SENHA|N8N_CHAVE)=' "$SEGREDOS"
    } | less -K
  else
    grep -E '^(DB_SENHA|N8N_CHAVE)=' "$SEGREDOS"
  fi
}

# Só serve ANTES de o n8n ter qualquer fluxo ou credencial salva. Apaga o banco
# do n8n, os segredos e refaz tudo com segredos novos. Uso:
#   bash bootstrap-vps.sh recomecar-n8n SEU_EMAIL --confirmo
recomecar_n8n() {
  local email="${2:-}" conf="${3:-}"
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do n8n. Se for isso mesmo: bash $0 recomecar-n8n SEU_EMAIL --confirmo"
  [ -n "$email" ] || falha "informe o e-mail do Let's Encrypt"
  if docker service ls --format '{{.Name}}' | grep -q '^n8n_editor$'; then
    local fluxos
    fluxos=$(docker exec "$(docker ps -q -f name=n8n_postgres_n8n_postgres | head -1)" \
      psql -U postgres -d n8n_queue -tAc 'select count(*) from workflow_entity' 2>/dev/null || echo "?")
    [ "$fluxos" = "0" ] || [ "$fluxos" = "?" ] || falha "o n8n já tem $fluxos fluxo(s) salvos. Trocar a chave agora os tornaria ilegíveis. Não recomece"
  fi
  echo "== removendo stacks do n8n"
  docker stack rm n8n_worker n8n_webhook n8n_editor n8n_redis n8n_postgres 2>/dev/null || true
  local t=0
  while docker ps -q -f name=n8n_ | grep -q . && [ $t -lt 90 ]; do sleep 3; t=$((t+3)); done
  echo "== recriando os volumes do n8n (banco antigo apagado)"
  docker volume rm n8n_postgres_data n8n_redis_data >/dev/null
  docker volume create n8n_postgres_data >/dev/null
  docker volume create n8n_redis_data >/dev/null
  rm -f "$SEGREDOS"
  preparar preparar "$email"
  # O Traefik também é regravado (e-mail do ACME). Se a conta ACME já existe no
  # acme.json, o e-mail antigo fica; não importa: o Let's Encrypt não manda mais
  # aviso de vencimento por e-mail desde 2025 e o Traefik renova sozinho.
  docker stack deploy -c "$STACKS/00-traefik.yaml" traefik --detach=true >/dev/null
  bancos; n8n; echo; status
}

# ================================================================== APP
# crystal-web-chat: PWA em app., API em api., Postgres e Redis próprios.
# Imagens privadas no ghcr.io, construídas pelo GitHub Actions do repositório
# do app. Segredos gerados aqui, uma vez só, e nunca impressos fora do less.
APP_DIR="$BASE/app"
APP_SEG="$APP_DIR/.segredos"
APP_EXT="$APP_DIR/.externos"
APP_YAML=10-crystal-app.yaml
APP_RAW="${APP_RAW:-${REPO_RAW%/stacks-exemplo}/stacks-app}"
APP_IMG=ghcr.io/lfcrystal766/crystal-web-chat
APP_STACK=crystal_app
# Nomes que o app-definir aceita. Os marcados com * são segredo (não ecoam).
APP_EXTERNOS=(RESEND_API_KEY* EMAIL_FROM CRYSTAL_API_URL CRYSTAL_API_KEY* CRYSTAL_API_PATH
  CRYSTAL_API_AUTH_HEADER CRYSTAL_API_REPLY_FIELD CRYSTAL_ONBOARDING_URL DIRECTORY_API_URL
  DIRECTORY_API_KEY* DIRECTORY_API_PATH DIRECTORY_API_AUTH_HEADER META_ACCESS_TOKEN*
  META_PHONE_NUMBER_ID ALERT_WEBHOOK_URL* SENTRY_DSN VAPID_SUBJECT
  CHAT_TRANSPORT CHATWOOT_BASE_URL CHATWOOT_INBOX_IDENTIFIER CHATWOOT_INBOX_HMAC_TOKEN*
  CHATWOOT_WEBHOOK_SECRET* CHANNEL_REPLY_TIMEOUT_MS
  SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY* SUPABASE_LOGIN_RPC)

app_valor() { # app_valor ARQUIVO NOME -> valor (sem imprimir nada se não houver)
  [ -f "$1" ] || return 0
  grep -E "^$2=" "$1" | tail -1 | cut -d= -f2- || true
}

app_ghcr() {
  local u t
  read -rp "Usuário do GitHub dono das imagens [LFcrystal766]: " u; u=${u:-LFcrystal766}
  echo "Token do GitHub com read:packages (o write:packages do cofre também serve)."
  read -rsp "Cole e dê Enter (não aparece na tela): " t; echo
  [ -n "$t" ] || falha "token vazio"
  printf '%s' "$t" | docker login ghcr.io -u "$u" --password-stdin >/dev/null || falha "login no ghcr.io recusado"
  unset t
  ok "docker login ghcr.io como $u"
  echo "  O Docker guarda a credencial em /root/.docker/config.json. Se o token vencer, rode de novo."
}

app_definir() {
  local nome="${2:-}" item secreto=0 aceito=0 v
  if [ -z "$nome" ]; then
    echo "Nomes aceitos (* = segredo, digitado sem aparecer):"
    printf '  %s\n' "${APP_EXTERNOS[@]}"
    echo "Já definidos: $( [ -f "$APP_EXT" ] && cut -d= -f1 "$APP_EXT" | tr '\n' ' ')"
    return 0
  fi
  for item in "${APP_EXTERNOS[@]}"; do
    if [ "${item%\*}" = "$nome" ]; then
      aceito=1
      if [ "$item" != "$nome" ]; then secreto=1; fi
    fi
  done
  if [ "$aceito" -ne 1 ]; then
    # Nunca repetir o que foi digitado: quase sempre é um segredo colado no
    # lugar do nome, e aí ele iria pra tela e pra captura do terminal.
    case "$nome" in
      re_*|ghp_*|github_pat_*|sk-*|sk_*|eyJ*)
        falha "isso parece uma CHAVE, não um nome. A chave nunca vai na linha de comando. Rode só: bash $0 app-definir RESEND_API_KEY  e cole a chave quando ele perguntar. Troque essa chave no painel de origem: ela ficou no histórico do terminal (limpe com: history -c && history -w)" ;;
      *)
        falha "o primeiro argumento tem que ser um NOME da lista (ex.: RESEND_API_KEY). Rode 'bash $0 app-definir' pra ver a lista" ;;
    esac
  fi
  if [ "$secreto" -eq 1 ]; then
    read -rsp "$nome (não aparece na tela): " v; echo
  else
    read -rp "$nome: " v
  fi
  [ -n "$v" ] || falha "valor vazio; nada gravado"
  case "$v" in *$'\n'*|*$'\r'*) falha "valor com quebra de linha" ;; esac
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  umask 077
  touch "$APP_EXT"
  grep -vE "^$nome=" "$APP_EXT" > "$APP_EXT.tmp" || true
  printf '%s=%s\n' "$nome" "$v" >> "$APP_EXT.tmp"
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  unset v
  ok "$nome gravado em $APP_EXT. Vale na próxima 'app-subir'"
}

# Guiado, sem argumento nenhum: pergunta a chave do Resend (sem eco) e o
# remetente. Existe pra ninguém precisar escrever valor na linha de comando.
app_resend() {
  echo "Chave de API do Resend: cole quando aparecer o pedido abaixo e dê Enter."
  app_definir app-definir RESEND_API_KEY
  echo
  echo "Remetente, com domínio verificado no Resend. Sugestão: Crystal <acesso@$DOMINIO>"
  app_definir app-definir EMAIL_FROM
  echo
  echo "Já definidos: $(cut -d= -f1 "$APP_EXT" | tr '\n' ' ')"
}

app_gerar_segredos() { # app_gerar_segredos TAG
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  umask 077
  if [ ! -f "$APP_SEG" ]; then
    {
      echo "APP_DB_SENHA=$(openssl rand -hex 24)"
      echo "ENCRYPTION_KEY=$(openssl rand -hex 32)"
      for k in JWT_SECRET WEBHOOK_SECRET CPF_SALT OTP_PEPPER; do
        echo "$k=$(openssl rand -base64 48 | tr -d '\n')"
      done
      echo "CRIADO_EM=$(date -u +%FT%TZ)"
    } > "$APP_SEG"
    ok "segredos do app gerados em $APP_SEG. Copie pro cofre: bash $0 app-segredos"
  else
    ok "segredos do app já existem em $APP_SEG (mantidos)"
  fi
  # VAPID (push web): gerado com a própria biblioteca do app, dentro da imagem.
  if [ -z "$(app_valor "$APP_SEG" VAPID_PUBLIC_KEY)" ]; then
    local chaves
    chaves=$(docker run --rm -w /app/apps/api --entrypoint node "$APP_IMG-api:$1" -e \
      'const k=require("web-push").generateVAPIDKeys();console.log("VAPID_PUBLIC_KEY="+k.publicKey+"\nVAPID_PRIVATE_KEY="+k.privateKey)') \
      || falha "não gerou as chaves VAPID com a imagem $APP_IMG-api:$1"
    echo "$chaves" | grep -qE '^VAPID_PRIVATE_KEY=.{20,}' || falha "chaves VAPID vieram vazias"
    echo "$chaves" >> "$APP_SEG"
    unset chaves
    ok "chaves VAPID do push web geradas"
  fi
  chmod 600 "$APP_SEG"
}

app_gerar_env() {
  local senha mock=0 k
  senha=$(app_valor "$APP_SEG" APP_DB_SENHA)
  [ -n "$senha" ] || falha "APP_DB_SENHA ausente em $APP_SEG"
  for k in RESEND_API_KEY EMAIL_FROM; do
    [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "$k não definido. Em produção o app manda o código de login por e-mail (Resend). Rode: bash $0 app-definir $k"
  done
  # Com o canal da inbox (CHAT_TRANSPORT=chatwoot) a Crystal não usa CRYSTAL_API_*.
  local chaves="CRYSTAL_API_URL CRYSTAL_API_KEY DIRECTORY_API_URL DIRECTORY_API_KEY"
  if [ "$(app_valor "$APP_EXT" CHAT_TRANSPORT)" = "chatwoot" ]; then
    chaves="DIRECTORY_API_URL DIRECTORY_API_KEY"
    for k in CHATWOOT_BASE_URL CHATWOOT_INBOX_IDENTIFIER CHATWOOT_WEBHOOK_SECRET; do
      [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "CHAT_TRANSPORT=chatwoot sem $k. Rode: bash $0 app-definir $k"
    done
  fi
  # Base de alunos no Supabase dispensa a DIRECTORY_API_*.
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    chaves=$(echo "$chaves" | sed 's/DIRECTORY_API_URL//; s/DIRECTORY_API_KEY//')
  fi
  for k in $chaves; do
    [ -n "$(app_valor "$APP_EXT" $k)" ] || mock=1
  done
  umask 077
  {
    echo "POSTGRES_DB=crystal_web_chat"
    echo "POSTGRES_USER=crystal"
    echo "POSTGRES_PASSWORD=$senha"
    echo "POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256"
  } > "$APP_DIR/postgres.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    echo "NODE_ENV=production"
    echo "HOST=0.0.0.0"
    echo "PORT=3001"
    # Traefik publica 80/443 em modo host e acrescenta o IP real no X-Forwarded-For.
    echo "TRUST_PROXY=1"
    echo "WEB_ORIGIN=https://app.$DOMINIO"
    echo "DATABASE_URL=postgresql://crystal:$senha@app_postgres:5432/crystal_web_chat"
    echo "REDIS_URL=redis://app_redis:6379"
    echo "UPLOAD_DIR=/app/uploads"
    echo "DEMO_SEED=0"
    echo "ALLOW_MOCK_INTEGRATIONS=$mock"
    echo "OTP_MODE=email"
    echo "SUGGESTIONS_MODE=shadow"
    echo "WEBHOOK_AUTH_MODE=hmac"
    echo "SENTRY_ENVIRONMENT=production"
    [ -n "$(app_valor "$APP_EXT" VAPID_SUBJECT)" ] || echo "VAPID_SUBJECT=mailto:crystal@leticiafelisberto.com"
    grep -E '^(ENCRYPTION_KEY|JWT_SECRET|WEBHOOK_SECRET|CPF_SALT|OTP_PEPPER|VAPID_PUBLIC_KEY|VAPID_PRIVATE_KEY)=' "$APP_SEG"
    cat "$APP_EXT"
  } > "$APP_DIR/api.env"
  chmod 600 "$APP_DIR/postgres.env" "$APP_DIR/api.env"
  unset senha
  if [ "$mock" -eq 1 ]; then
    aviso "Crystal e/ou base de clientes ainda sem endereço: API sobe com a Crystal SIMULADA e só entra quem"
    aviso "for criado aqui (app-admin). Quando a agência passar os endereços: app-definir + app-subir de novo"
  else
    ok "Crystal e base de clientes reais configuradas (ALLOW_MOCK_INTEGRATIONS=0)"
  fi
}

app_subir() {
  local tag="${2:-}"
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' \
    || falha "informe a tag das imagens: bash $0 app-subir sha-XXXXXXX (veja em GitHub > crystal-web-chat > Actions > imagens-vps)"
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager do Swarm"
  docker network inspect network_swarm_public >/dev/null 2>&1 || falha "rede network_swarm_public não existe"
  docker service ls --format '{{.Name}}' | grep -q '^traefik_traefik$' || aviso "Traefik não encontrado: sem ele app. e api. não respondem"

  echo "== imagens $tag"
  docker pull -q "$APP_IMG-api:$tag" >/dev/null && docker pull -q "$APP_IMG-web:$tag" >/dev/null \
    || falha "não baixou as imagens $tag. Rodou 'bash $0 app-ghcr'? O build terminou no GitHub?"
  ok "$APP_IMG-api:$tag e -web:$tag baixadas"

  echo "== segredos e ambiente"
  app_gerar_segredos "$tag"
  app_gerar_env

  echo "== stack"
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  if [ -f "$AQUI/stacks-app/$APP_YAML" ]; then
    cp "$AQUI/stacks-app/$APP_YAML" "$ORIG/$APP_YAML"
  else
    curl -fsSL -m 60 "$APP_RAW/$APP_YAML" -o "$ORIG/$APP_YAML" || falha "não baixou $APP_YAML de $APP_RAW"
  fi
  grep -q '^services:' "$ORIG/$APP_YAML" || falha "$APP_YAML não parece um compose"
  umask 077
  sed -e "s|APP_TAG|$tag|g" -e "s|APP_ENV_DIR|$APP_DIR|g" "$ORIG/$APP_YAML" > "$STACKS/$APP_YAML"
  grep -nE 'APP_TAG|APP_ENV_DIR' "$STACKS/$APP_YAML" | grep -vE '^\s*[0-9]+:\s*#' | grep -q . && falha "marcador sobrando em $APP_YAML"
  docker stack deploy --with-registry-auth -c "$STACKS/$APP_YAML" "$APP_STACK" --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack "$APP_STACK" 420 || { echo "  Logs da API: docker service logs --tail 80 ${APP_STACK}_app_api"; exit 1; }
  echo
  app_status
}

app_status() {
  echo "== Serviços do app"
  docker service ls --filter "label=com.docker.stack.namespace=$APP_STACK" --format '{{.Name}} {{.Replicas}} {{.Image}}' \
    | awk '{printf "  %-26s %-5s %s\n",$1,$2,$3}'
  echo
  echo "== HTTPS (certificado tem que ser válido, sem -k)"
  local u code
  for u in "https://app.$DOMINIO/" "https://api.$DOMINIO/healthz"; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u" 2>/dev/null) || true
    code=${code:-000}
    case "$code" in
      200) ok "$u -> 200" ;;
      000) aviso "$u sem resposta ou certificado inválido (DNS do nome existe e está cinza? Traefik ainda emitindo?)" ;;
      *) aviso "$u -> $code" ;;
    esac
  done
}

# O CPF passa só pelo ambiente de um 'docker exec' que termina em seguida: não
# entra no spec do serviço (que o Swarm guarda com histórico), nem em log,
# nem no histórico do shell.
app_admin() {
  local cid cpf email nome
  cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$cid" ] || falha "a API do app não está rodando: bash $0 app-subir TAG"
  read -rsp "CPF do primeiro admin, só números (não aparece): " cpf; echo
  cpf=$(printf '%s' "$cpf" | tr -cd '0-9')
  [ "${#cpf}" -eq 11 ] || falha "CPF precisa de 11 dígitos"
  read -rp "E-mail do admin (recebe o código de login): " email
  echo "$email" | grep -Eq '^[^@ :]+@[^@ :]+\.[^@ :]+$' || falha "e-mail inválido"
  read -rp "Nome do admin: " nome
  [ -n "$nome" ] && [ "${nome#*:}" = "$nome" ] || falha "nome vazio ou com ':'"
  docker exec -i -w /app/apps/api "$cid" sh -c 'cat > .admin-bootstrap.ts' <<'TS'
import { PrismaClient } from "@prisma/client";
import { createPrismaRepos } from "./src/db/prisma";
import { loadEnv } from "./src/env";
import { bootstrapAdmin } from "./src/seed";

const env = loadEnv();
const prisma = new PrismaClient();
try {
  const r = await bootstrapAdmin(createPrismaRepos(prisma), env);
  if (!r) console.log("ADMIN_BOOTSTRAP vazio, nada feito");
  else if (r.created) console.log(`admin criado (CPF terminado em ${r.cpfLast4})`);
  else console.log("já existe admin ativo; nada feito");
} finally {
  await prisma.$disconnect();
}
TS
  ADMIN_BOOTSTRAP="$cpf:$email:$nome" docker exec -e ADMIN_BOOTSTRAP -w /app/apps/api "$cid" \
    ./node_modules/.bin/tsx .admin-bootstrap.ts || { docker exec "$cid" rm -f /app/apps/api/.admin-bootstrap.ts; falha "bootstrap do admin falhou"; }
  docker exec "$cid" rm -f /app/apps/api/.admin-bootstrap.ts
  unset cpf
  echo "  Próximo: entrar em https://app.$DOMINIO com esse CPF e e-mail (o código chega pelo Resend)."
}

# Troca TODOS os segredos do app recriando o banco dele do zero. Só enquanto o
# banco não tem ninguém cadastrado: com usuário dentro, ENCRYPTION_KEY e
# CPF_SALT novos deixariam os dados ilegíveis. Mantém .externos (Resend etc.).
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
app_recomecar() {
  local tag="${2:-}" conf="${3:-}" cid n
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do app e troca os segredos. Se for isso: bash $0 app-recomecar TAG --confirmo"
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "informe a tag: bash $0 app-recomecar sha-XXXXXXX --confirmo"
  cid=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1)
  if [ -n "$cid" ]; then
    n=$(docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc 'select count(*) from users' 2>/dev/null || echo "?")
    n=$(echo "$n" | tr -d '[:space:]')
    [ "$n" = "0" ] || [ "$n" = "?" ] || falha "o banco do app já tem $n usuário(s). Trocar ENCRYPTION_KEY e CPF_SALT agora os tornaria ilegíveis. Não recomece"
  fi
  echo "== removendo a stack $APP_STACK"
  docker stack rm "$APP_STACK" >/dev/null 2>&1 || true
  local t=0
  while docker ps -aq -f "label=com.docker.stack.namespace=$APP_STACK" | grep -q . && [ $t -lt 120 ]; do sleep 3; t=$((t+3)); done
  sleep 5
  echo "== apagando os volumes do app (banco vazio)"
  for v in app_postgres_data app_redis_data app_uploads; do
    docker volume rm "${APP_STACK}_$v" >/dev/null 2>&1 || true
  done
  rm -f "$APP_SEG" "$APP_DIR/api.env" "$APP_DIR/postgres.env"
  ok "segredos antigos apagados; $APP_EXT mantido"
  app_subir app-subir "$tag"
}

# ------------------------------------------------------------------ Crystal provisória
# Fluxo do n8n (n8n/crystal-provisoria.json) que responde no app usando o
# OpenRouter, até a agência entregar o agente. Importa credenciais e fluxo
# pela linha de comando do n8n, ativa, reinicia o n8n e aponta o app para ele.
# Não abre o app para alunos: a base de clientes continua simulada.
N8N_WF_ID=crystalProvisor1
app_gravar() { # app_gravar NOME VALOR (sem eco)
  umask 077; touch "$APP_EXT"
  grep -vE "^$1=" "$APP_EXT" > "$APP_EXT.tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$APP_EXT.tmp"
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
}

app_tag_atual() {
  docker service inspect ${APP_STACK}_app_api --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null \
    | sed -E 's/@sha256:.*//; s/.*://'
}

n8n_reiniciar() {
  local s
  for s in n8n_editor_n8n_editor n8n_webhook_n8n_webhook n8n_worker_n8n_worker; do
    docker service inspect "$s" >/dev/null 2>&1 || continue
    echo "  reiniciando $s (até 2 min)"
    docker service update --force --detach=false "$s" >/dev/null 2>&1 || aviso "$s não confirmou a reinicialização; conferir com: docker service ls"
  done
}

crystal_provisoria() {
  local cid wf chave orkey tag
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  [ -n "$cid" ] || falha "o editor do n8n não está rodando"
  tag=$(app_tag_atual); [ -n "$tag" ] || falha "o app não está no ar: rode 'app-subir TAG' antes"

  mkdir -p "$ORIG"; wf="$ORIG/crystal-provisoria.json"
  if [ -f "$AQUI/n8n/crystal-provisoria.json" ]; then
    cp "$AQUI/n8n/crystal-provisoria.json" "$wf"
  else
    curl -fsSL -m 60 "${REPO_RAW%/stacks-exemplo}/n8n/crystal-provisoria.json" -o "$wf" || falha "não baixou o fluxo crystal-provisoria.json"
  fi
  grep -q "\"$N8N_WF_ID\"" "$wf" || falha "o fluxo baixado não é o esperado"

  echo "Use uma chave NOVA do OpenRouter, só pra isto: Keys > Create Key, nome 'Crystal provisória',"
  echo "com limite de crédito (ex.: 10 dólares). NUNCA a chave que o agente da agência usa hoje."
  read -rsp "Chave do OpenRouter (começa com sk-or-, não aparece na tela): " orkey; echo
  case "$orkey" in sk-or-*) ;; *) unset orkey; falha "isso não parece uma chave do OpenRouter (começa com sk-or-). Nada foi gravado" ;; esac
  chave=$(app_valor "$APP_EXT" CRYSTAL_API_KEY)
  [ -n "$chave" ] || chave=$(openssl rand -hex 32)

  echo "== credenciais no n8n (webhook, OpenRouter, Redis banco 2)"
  CHAVE="$chave" ORKEY="$orkey" python3 - <<'PY' | docker exec -i "$cid" sh -c 'umask 077; cat > /tmp/crystal-cred.json'
import json, os
print(json.dumps([
  {"id": "crystalProvKey01", "name": "Crystal provisória · chave do app", "type": "httpHeaderAuth",
   "data": {"name": "x-api-key", "value": os.environ["CHAVE"]}},
  {"id": "crystalProvORkey", "name": "OpenRouter · Crystal provisória", "type": "httpHeaderAuth",
   "data": {"name": "Authorization", "value": "Bearer " + os.environ["ORKEY"]}},
  {"id": "crystalProvRedis", "name": "Redis do n8n · banco 2 (Crystal provisória)", "type": "redis",
   "data": {"host": "n8n_redis", "port": 6379, "database": 2, "password": ""}},
]))
PY
  unset orkey
  if ! docker exec "$cid" n8n import:credentials --input=/tmp/crystal-cred.json >/dev/null 2>&1; then
    docker exec "$cid" rm -f /tmp/crystal-cred.json; falha "o n8n recusou as credenciais"
  fi
  docker exec "$cid" rm -f /tmp/crystal-cred.json
  ok "3 credenciais gravadas (cifradas pela chave do n8n)"

  echo "== fluxo"
  docker exec -i "$cid" sh -c 'cat > /tmp/crystal-wf.json' < "$wf"
  docker exec "$cid" n8n import:workflow --input=/tmp/crystal-wf.json >/dev/null 2>&1 || falha "o n8n recusou o fluxo"
  docker exec "$cid" rm -f /tmp/crystal-wf.json
  # O n8n 1.123 só ativa uma versão que exista no histórico, e o import pela
  # linha de comando não cria essa versão. Grava (ou atualiza) a versão atual.
  local pg; pg=$(docker ps -q -f name=n8n_postgres_n8n_postgres | head -1)
  [ -n "$pg" ] || falha "o Postgres do n8n não está rodando"
  docker exec -i "$pg" psql -v ON_ERROR_STOP=1 -q -U postgres -d n8n_queue >/dev/null <<SQL || falha "não gravou a versão do fluxo no histórico do n8n"
INSERT INTO workflow_history ("versionId", "workflowId", nodes, connections, authors, name, "createdAt", "updatedAt")
SELECT "versionId", id, nodes, connections, 'bootstrap-vps', name, now(), now()
  FROM workflow_entity WHERE id = '$N8N_WF_ID'
ON CONFLICT ("versionId") DO UPDATE
  SET nodes = EXCLUDED.nodes, connections = EXCLUDED.connections, name = EXCLUDED.name, "updatedAt" = now();
SQL
  docker exec "$cid" n8n update:workflow --id="$N8N_WF_ID" --active=true >/dev/null 2>&1 || falha "não ativou o fluxo"
  docker exec "$pg" psql -U postgres -d n8n_queue -tAc "select active::text from workflow_entity where id='$N8N_WF_ID'" | grep -q true \
    || falha "o fluxo não ficou ativo no banco do n8n"
  ok "fluxo '$N8N_WF_ID' importado e ativo"
  n8n_reiniciar

  echo "== app apontando para a Crystal provisória"
  app_gravar CRYSTAL_API_URL "https://webhook.$DOMINIO/webhook"
  app_gravar CRYSTAL_API_PATH "/crystal-provisoria"
  app_gravar CRYSTAL_API_AUTH_HEADER "x-api-key"
  app_gravar CRYSTAL_API_REPLY_FIELD "text"
  app_gravar CRYSTAL_API_KEY "$chave"
  unset chave
  app_subir app-subir "$tag"

  echo
  echo "== teste: a API do app pergunta à Crystal provisória"
  local api t=0
  while :; do
    api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    [ -n "$api" ] && docker exec "$api" sh -c '[ -n "$CRYSTAL_API_URL" ]' 2>/dev/null && break
    [ $t -ge 120 ] && break; sleep 5; t=$((t+5))
  done
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { "x-api-key": process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => { const t = await r.text(); console.log("  status", r.status, "->", t.slice(0, 160)); process.exit(r.ok ? 0 : 1); })
      .catch(e => { console.log("  falhou:", e.name); process.exit(1); });' \
    && ok "Crystal provisória respondendo. Teste no app: https://app.$DOMINIO" \
    || aviso "não respondeu ainda. O n8n pode levar 1 min depois de reiniciar: rode 'bash $0 crystal-provisoria-teste'"
}

crystal_provisoria_teste() {
  local api; api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "a API do app não está rodando"
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { "x-api-key": process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => console.log("  status", r.status, "->", (await r.text()).slice(0, 160)))
      .catch(e => console.log("  falhou:", e.name));'
}

# Volta o app para a Crystal simulada e desativa o fluxo. Não apaga as credenciais.
crystal_provisoria_desligar() {
  local cid tag
  tag=$(app_tag_atual); [ -n "$tag" ] || falha "o app não está no ar"
  grep -vE '^CRYSTAL_API_(URL|PATH|AUTH_HEADER|REPLY_FIELD|KEY)=' "$APP_EXT" > "$APP_EXT.tmp" || true
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  app_subir app-subir "$tag"
  cid=$(docker ps -q -f name=n8n_editor_n8n_editor | head -1)
  if [ -n "$cid" ]; then
    docker exec "$cid" n8n update:workflow --id="$N8N_WF_ID" --active=false >/dev/null 2>&1 && n8n_reiniciar
  fi
  ok "app de volta à Crystal simulada; fluxo desativado"
}

app_segredos() {
  [ -f "$APP_SEG" ] || falha "ainda não há segredos do app: rode 'app-subir'"
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Segredos do app. Copie CADA LINHA direto pro Bitwarden. Aperte q pra fechar."
      echo "NÃO cole em chat, e-mail ou print: segredo que sai daqui tem que ser trocado."
      echo "ENCRYPTION_KEY e CPF_SALT nunca podem mudar: sem eles o banco do app fica ilegível."
      echo
      grep -vE '^CRIADO_EM=' "$APP_SEG"
    } | less -K
  else
    grep -vE '^CRIADO_EM=' "$APP_SEG"
  fi
}

case "$CMD" in
  app-ghcr) app_ghcr ;;
  app-definir) app_definir "$@" ;;
  app-resend) app_resend ;;
  app-subir) app_subir "$@" ;;
  app-status) app_status ;;
  app-admin) app_admin ;;
  app-segredos) app_segredos ;;
  app-recomecar) app_recomecar "$@" ;;
  crystal-provisoria) crystal_provisoria ;;
  crystal-provisoria-teste) crystal_provisoria_teste ;;
  crystal-provisoria-desligar) crystal_provisoria_desligar ;;
  preparar) preparar "$@" ;;
  recomecar-n8n) recomecar_n8n "$@" ;;
  docker-api) docker_api ;;
  backup) backup ;;
  backup-cron) backup_cron ;;
  backup-chave) shift; backup_chave "$@" ;;
  backup-fora-config) backup_fora_config ;;
  backup-conferir) backup_conferir ;;
  backup-testar-trava) backup_testar_trava ;;
  backup-link) shift; backup_link "$@" ;;
  firewall) firewall ;;
  seguranca) seguranca ;;
  painel-restringir) shift; painel_restringir "$@" ;;
  painel-desligar) painel_desligar ;;
  painel-ligar) painel_ligar ;;
  traefik|portainer|bancos|n8n|tudo|status|segredos) "$CMD" ;;
  *) falha "comando desconhecido: $CMD" ;;
esac
