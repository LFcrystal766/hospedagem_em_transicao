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
#   bash bootstrap-vps.sh firewall             ufw: só 22, 80 e 443 de fora. As portas do Swarm
#                                              (2377, 7946, 4789) deixam de ficar públicas
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
#
# Onde ficam as coisas:
#   /root/crystal/.segredos      senha do banco e chave de criptografia (chmod 600).
#                                NUNCA apagar nem regenerar: a chave do n8n não
#                                pode mudar depois de em uso
#   /root/crystal/stacks/*.yaml  arquivos prontos, com segredo dentro (chmod 600)
#   /root/crystal/originais/     os yaml da agência, sem alteração
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
backup() {
  local dir="$BASE/backups" cid
  mkdir -p "$dir"; chmod 700 "$dir"
  cid=$(docker ps -q -f name=n8n_postgres_n8n_postgres | head -1)
  [ -n "$cid" ] || falha "contêiner do Postgres do n8n não está rodando"
  local arq="$dir/n8n_queue-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
  umask 077
  docker exec "$cid" pg_dump -U postgres -d n8n_queue --no-owner | gzip > "$arq" || falha "pg_dump falhou"
  [ -s "$arq" ] || falha "dump vazio em $arq"
  ok "backup em $arq ($(du -h "$arq" | cut -f1))"
  find "$dir" -name 'n8n_queue-*.sql.gz' -mtime +14 -delete
  echo "  $(ls "$dir" | wc -l) backup(s) guardados. Restaurar: gunzip -c ARQ | docker exec -i CID psql -U postgres -d n8n_queue"
  echo "  Lembrete: o backup só restaura credenciais com a N8N_CHAVE do cofre."

  # Banco do app, se a stack crystal_app estiver no ar. Campos cifrados e o
  # hash do CPF só se leem com ENCRYPTION_KEY e CPF_SALT, que ficam no cofre.
  cid=$(docker ps -q -f name=crystal_app_app_postgres | head -1)
  if [ -n "$cid" ]; then
    arq="$dir/crystal_web_chat-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
    docker exec "$cid" pg_dump -U crystal -d crystal_web_chat --no-owner | gzip > "$arq" || falha "pg_dump do app falhou"
    [ -s "$arq" ] || falha "dump do app vazio em $arq"
    ok "backup do app em $arq ($(du -h "$arq" | cut -f1))"
    find "$dir" -name 'crystal_web_chat-*.sql.gz' -mtime +14 -delete
  fi
}

backup_cron() {
  local linha="30 3 * * * root /usr/bin/bash $BASE/bootstrap-vps.sh backup >> $BASE/backups/backup.log 2>&1"
  cp "$AQUI/$(basename "$0")" "$BASE/bootstrap-vps.sh" 2>/dev/null || true
  printf '%s\n' "$linha" > /etc/cron.d/crystal-backup-n8n
  chmod 644 /etc/cron.d/crystal-backup-n8n
  ok "cron instalado em /etc/cron.d/crystal-backup-n8n: todo dia 03:30, log em $BASE/backups/backup.log"
  echo "  Fora da VPS: copiar $BASE/backups/ pra outro lugar de tempos em tempos (a VPS sumir leva o backup junto)."
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
    case "$code" in
      200|301|302|401|404) ok "https://$h.$DOMINIO -> $code" ;;
      000) aviso "https://$h.$DOMINIO sem resposta ou certificado inválido (Traefik ainda emitindo? DNS? porta 443 fechada?)" ;;
      *) aviso "https://$h.$DOMINIO -> $code" ;;
    esac
  done
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
  META_PHONE_NUMBER_ID ALERT_WEBHOOK_URL* SENTRY_DSN VAPID_SUBJECT)

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
  for k in CRYSTAL_API_URL CRYSTAL_API_KEY DIRECTORY_API_URL DIRECTORY_API_KEY; do
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

app_segredos() {
  [ -f "$APP_SEG" ] || falha "ainda não há segredos do app: rode 'app-subir'"
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Segredos do app. Copie pro Bitwarden. Aperte q pra fechar."
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
  preparar) preparar "$@" ;;
  recomecar-n8n) recomecar_n8n "$@" ;;
  docker-api) docker_api ;;
  backup) backup ;;
  backup-cron) backup_cron ;;
  firewall) firewall ;;
  traefik|portainer|bancos|n8n|tudo|status|segredos) "$CMD" ;;
  *) falha "comando desconhecido: $CMD" ;;
esac
