#!/usr/bin/env bash
# Sobe a fundação da Crystal na VPS (Hostinger KVM 4): Traefik, Portainer e o
# n8n em modo fila, a partir dos stacks-exemplo da agência, já com o domínio
# crystalnowpp.com.br e os segredos gerados na própria máquina.
#
# Roda NA VPS, como root. Uso:
#   bash bootstrap-vps.sh preparar SEU_EMAIL   baixa os yaml, gera os segredos (uma vez só)
#                                              e grava os arquivos prontos em /root/crystal/stacks
#   bash bootstrap-vps.sh traefik              sobe 00 e espera ficar 1/1
#   bash bootstrap-vps.sh portainer            sobe 01
#   bash bootstrap-vps.sh bancos               sobe 02 e 03
#   bash bootstrap-vps.sh n8n                  sobe 04, 05 e 06
#   bash bootstrap-vps.sh tudo                 os quatro acima, na ordem
#   bash bootstrap-vps.sh status               serviços + HTTPS dos três nomes
#   bash bootstrap-vps.sh segredos             mostra a senha do banco e a chave do n8n,
#                                              pra copiar pro cofre (Bitwarden). Não colar em chat
#   bash bootstrap-vps.sh recomecar-n8n EMAIL --confirmo
#                                              só ANTES de o n8n ter fluxo salvo: apaga o banco
#                                              do n8n e refaz com segredos novos
#
# Onde ficam as coisas:
#   /root/crystal/.segredos      senha do banco e chave de criptografia (chmod 600).
#                                NUNCA apagar nem regenerar: a chave do n8n não
#                                pode mudar depois de em uso
#   /root/crystal/stacks/*.yaml  arquivos prontos, com segredo dentro (chmod 600)
#   /root/crystal/originais/     os yaml da agência, sem alteração
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

[ -n "$CMD" ] || { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

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

# ------------------------------------------------------------------ status
status() {
  echo "== Serviços"
  docker service ls --format '  {{.Name}}\t{{.Replicas}}\t{{.Image}}' | column -t
  echo
  echo "== HTTPS pelos nomes públicos (certificado tem que ser válido, sem -k)"
  for h in painel editor webhook; do
    local code
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$h.$DOMINIO/" 2>/dev/null); code=${code:-000}
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
  echo "Copie os dois pro cofre (Bitwarden), em itens separados. NÃO cole esta saída em chat nem em documento:"
  grep -E '^(DB_SENHA|N8N_CHAVE)=' "$SEGREDOS" | sed 's/^/  /'
  echo "A chave N8N_CHAVE nunca pode mudar. Sem ela, um backup do banco do n8n não restaura as credenciais."
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

case "$CMD" in
  preparar) preparar "$@" ;;
  recomecar-n8n) recomecar_n8n "$@" ;;
  traefik|portainer|bancos|n8n|tudo|status|segredos) "$CMD" ;;
  *) falha "comando desconhecido: $CMD" ;;
esac
