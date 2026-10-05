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
#   bash bootstrap-vps.sh segredos             mostra a senha do banco, a chave do n8n e a senha do
#                                              Redis, pra copiar pro cofre (Bitwarden). Não colar em chat
#   O Redis do n8n sobe COM senha (N8N_REDIS_SENHA, gerada no preparar; o original da agência não tem).
#   Trocá-la exige redeploy de 03, 04, 05 e 06: bash bootstrap-vps.sh preparar EMAIL && bash bootstrap-vps.sh bancos && bash bootstrap-vps.sh n8n
#   bash bootstrap-vps.sh backup               pg_dump dos bancos (n8n, app, memória da Crystal, Chatwoot)
#                                              e tar incremental dos uploads em /root/crystal/backups
#                                              (14 dias). Parte que falha não para as outras nem o R2;
#                                              no fim, resumo e saída 1. A chave do n8n NÃO vai junto
#   bash bootstrap-vps.sh backup-cron          agenda o backup todo dia às 03:30 (hora da VPS)
#   bash bootstrap-vps.sh backup-chave         gera a chave dos backups: a privada aparece só no
#                                              less (vai pro Bitwarden), a pública fica na VPS
#   bash bootstrap-vps.sh backup-fora-config   dados do R2 (segredo sem aparecer), testa e agenda:
#                                              cada backup sobe cifrado para o Cloudflare R2
#   bash bootstrap-vps.sh backup-conferir      lista o que está no R2 e há quanto tempo foi o último
#   bash bootstrap-vps.sh backup-testar-trava  tenta apagar um arquivo de teste no R2: tem que ser recusado
#   bash bootstrap-vps.sh backup-link [TIPO]   link de 10 min para baixar o backup mais novo (teste de
#                                              restauração no Mac). TIPO: n8n_queue (padrão), crystal_web_chat,
#                                              crystal_agente, crystal_uploads, chatwoot, chatwoot_storage
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
#                                              só com o n8n SEM fluxo nem credencial (conferido no
#                                              banco): pede APAGAR, copia o banco, apaga e refaz
#                                              com segredos novos
#
# App da Crystal (crystal-web-chat), em app. e api.crystalnowpp.com.br:
#   bash bootstrap-vps.sh app-ghcr             docker login no ghcr.io (token read:packages,
#                                              digitado sem aparecer). As imagens são privadas
#   bash bootstrap-vps.sh app-resend           pergunta a chave do Resend (sem aparecer) e o
#                                              remetente. Nada vai na linha de comando
#   bash bootstrap-vps.sh app-definir NOME     grava um valor externo (RESEND_API_KEY, EMAIL_FROM,
#                                              CRYSTAL_API_URL, REFUND_WEBHOOK_SECRET, TRANSCRIPTION_*,
#                                              SUPABASE_*, EQUIPE_EMAIL, RATE_AUTH_*, ...). Confere o
#                                              formato antes de gravar. Sem NOME, lista os aceitos
#   bash bootstrap-vps.sh app-remover NOME     apaga um valor externo que o app não usa mais
#                                              (ex.: CRYSTAL_ONBOARDING_URL depois da etapa 2)
#   bash bootstrap-vps.sh app-subir TAG        gera segredos (uma vez só), monta api.env, confere o
#                                              api.env no boot da imagem, sobe a stack crystal_app com
#                                              a tag (ex.: sha-398e46e) e falha se o Swarm desfizer a
#                                              troca (rollback), mesmo com a tag igual
#   bash bootstrap-vps.sh app-supabase-teste   chama a função de login do Supabase com CPF fictício:
#                                              200 ok, 404 função não existe, 401 chave errada
#   bash bootstrap-vps.sh app-status           serviços do app + HTTPS de app. e api.
#   bash bootstrap-vps.sh app-admin            cria o primeiro admin (CPF digitado sem aparecer,
#                                              não fica em spec, log nem histórico)
#   bash bootstrap-vps.sh app-aluno            cria uma conta LOCAL de aluno, que não passa pela base de
#                                              alunas do Supabase (testadores, equipe; CPF sem aparecer;
#                                              pergunta e-mail, nome e WhatsApp)
#   bash bootstrap-vps.sh vigia-config         liga a vigia do app (a cada 5 min, avisa no Telegram;
#                                              pede o token do bot sem aparecer)
#   bash bootstrap-vps.sh app-segredos         mostra os segredos do app pra copiar pro cofre
#   bash bootstrap-vps.sh app-telefone EMAIL   grava o WhatsApp de uma conta criada aqui (canal da inbox)
#   bash bootstrap-vps.sh app-revisao          cria (uma vez) e mostra a conta de revisão das lojas;
#                                              --nova troca CPF e código
#   bash bootstrap-vps.sh crystal-nossa TAG    a NOSSA Crystal (serviço app_crystal, sem endereço
#                                              público): pede a chave do OpenRouter sem aparecer,
#                                              aponta o app para ela e testa. Volta: crystal-provisoria
#   bash bootstrap-vps.sh crystal-nossa-teste  uma pergunta de teste à nossa Crystal
#   bash bootstrap-vps.sh crystal-provisoria   Crystal provisória no n8n com o OpenRouter (pede a
#                                              chave sem aparecer) e o app apontando pra ela
#   bash bootstrap-vps.sh crystal-provisoria-teste      uma pergunta de teste, pela API do app
#   bash bootstrap-vps.sh crystal-provisoria-desligar   volta o app à Crystal simulada
#
# Atendimento (o nosso Chatwoot, no lugar do LendChat), em atendimento.crystalnowpp.com.br:
#   bash bootstrap-vps.sh atendimento-subir    gera segredos (uma vez só) e sobe o Chatwoot
#                                              (DNS atendimento. cinza antes)
#   bash bootstrap-vps.sh atendimento-configurar TAG
#                                              conta, admin (senha no less), inbox do app e a
#                                              Crystal como robô; grava no app e testa
#   bash bootstrap-vps.sh atendimento-teste    mensagem de teste na inbox; a Crystal responde
#   bash bootstrap-vps.sh atendimento-status   serviços + HTTPS de atendimento.
#   bash bootstrap-vps.sh atendimento-segredos mostra os segredos do Chatwoot pra copiar pro cofre
#   bash bootstrap-vps.sh app-canal chatwoot   o app passa a conversar pelo nosso Chatwoot
#                                              (app-canal crystal volta para a Crystal direto)
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
#                                              só com o banco do app VAZIO (comprovado): pede
#                                              APAGAR, copia bancos e segredos, apaga o banco e
#                                              troca todos os segredos do app (vazaram?)
#
# Publicar a etapa 1 do PRD de Otimização (API sem root, mídia e transcrição, reembolso):
#   curl -fsSL https://raw.githubusercontent.com/LFcrystal766/hospedagem_em_transicao/<commit>/crystal-em-casa/bootstrap-vps.sh -o bootstrap-vps.sh
#   bash bootstrap-vps.sh app-definir REFUND_WEBHOOK_SECRET   gerado com: openssl rand -hex 32 (guardar no Bitwarden)
#   bash bootstrap-vps.sh app-definir TRANSCRIPTION_API_KEY   chave da Groq; URL e modelo já têm padrão no código
#                                              (https://api.groq.com/openai/v1/audio/transcriptions, whisper-large-v3-turbo)
#   CHATWOOT_API_TOKEN: NÃO definir (decisão de 05/10: excluir conta não apaga o contato no Chatwoot)
#   bash bootstrap-vps.sh app-status           anotar a tag atual, para poder voltar
#   bash bootstrap-vps.sh backup               banco do app e uploads antes de trocar a imagem
#   bash bootstrap-vps.sh app-subir sha-XXXXXXX    a tag nova (ajusta o dono do volume de uploads antes)
#   Volta: bash bootstrap-vps.sh app-subir TAG_ANTERIOR
#   Conferir no OpenRouter que CRYSTAL_MODEL (anthropic/claude-haiku-4.5) e CRYSTAL_MODEL_RESERVA
#   (openai/gpt-4.1-mini) leem imagem (os dois leem). Na Assiny, webhook em
#   https://api.crystalnowpp.com.br/webhooks/reembolso, cabeçalho "Authorization: Bearer <segredo>",
#   eventos de reembolso, chargeback e cancelamento, todos os produtos.
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
#   /root/crystal/atendimento/   segredos (.segredos, chmod 600) e .env do Chatwoot.
#                                SECRET_KEY_BASE e ACTIVE_RECORD_ENCRYPTION_* nunca mudam
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
  # Senha do Redis do n8n (revisão de 02/10, A2): o original da agência sobe sem
  # senha numa rede que o app e o Chatwoot também usam. Acrescentada uma vez a
  # segredos antigos; trocar exige redeploy de 03, 04, 05 e 06.
  if ! grep -q '^N8N_REDIS_SENHA=' "$SEGREDOS"; then
    umask 077
    echo "N8N_REDIS_SENHA=$(openssl rand -hex 24)" >> "$SEGREDOS"
    chmod 600 "$SEGREDOS"
    ok "N8N_REDIS_SENHA gerada em $SEGREDOS. Copie pro cofre: bash $0 segredos"
  fi
  # shellcheck disable=SC1090
  . "$SEGREDOS"
  [ "${#N8N_CHAVE}" -eq 32 ] || falha "chave do n8n em $SEGREDOS não tem 32 caracteres"
  printf '%s' "$N8N_REDIS_SENHA" | grep -Eq '^[0-9a-f]{48}$' || falha "N8N_REDIS_SENHA em $SEGREDOS não é hex de 48 caracteres"

  # 3. Arquivos prontos. O 03 ganha --requirepass e o 04/05/06 a senha da fila:
  # a agência não prevê senha no Redis, então entra aqui, não no original.
  umask 077
  for a in "${ARQUIVOS[@]}"; do
    sed -e "s|seudominio\.com\.br|$DOMINIO|g" \
        -e "s|SEU_EMAIL_AQUI|$email|g" \
        -e "s|SUBSTITUA_PELA_SENHA_DO_BANCO|$DB_SENHA|g" \
        -e "s|SUBSTITUA_PELA_CHAVE_DE_CRIPTOGRAFIA|$N8N_CHAVE|g" \
        -e "s|^\( *command: redis-server .*--port 6379\)$|\1 --requirepass $N8N_REDIS_SENHA|" \
        -e "/^ *- QUEUE_BULL_REDIS_PORT=6379$/a\\      - QUEUE_BULL_REDIS_PASSWORD=$N8N_REDIS_SENHA" \
        "$ORIG/$a" > "$STACKS/$a"
    case "$a" in
      03-*) grep -q -- "--requirepass " "$STACKS/$a" || falha "$a: o command do redis não recebeu --requirepass (o original mudou?)" ;;
      04-*|05-*|06-*) grep -q '^ *- QUEUE_BULL_REDIS_PASSWORD=' "$STACKS/$a" || falha "$a: QUEUE_BULL_REDIS_PASSWORD não entrou (o original mudou?)" ;;
    esac
    if grep -nE 'SUBSTITUA|SEU_EMAIL|seudominio' "$STACKS/$a" | grep -vE '^\s*[0-9]+:\s*#' | grep -q .; then
      falha "$a ainda tem placeholder fora de comentário"
    fi
  done
  ok "${#ARQUIVOS[@]} arquivos prontos em $STACKS (chmod 600)"
  # O 01 acima saiu do original, aberto. Se o painel já estava restrito, refaz a trava.
  # Se não conseguir, falha fechado (achado 34): o 01 aberto sai de $STACKS e o
  # 'portainer' se recusa a subir sem a lista.
  if [ -s "$PAINEL_IPS_ARQ" ] && ! painel_gerar; then
    mv -f "$STACKS/01-portainer.yaml" "$STACKS/01-portainer.yaml.aberto"
    echo "  !! não refiz a trava do painel: 01-portainer.yaml (aberto) foi tirado de $STACKS. O Portainer no ar"
    echo "  !! continua como está. Para regravar com a lista: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
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

# Estado da última atualização de um serviço, lido do JSON do docker service inspect
# (nomes de campo da API, sem depender de método em template). Saída:
# "ATUALIZADO_EM ESTADO INICIO" (epoch UTC; ESTADO "-" se nunca houve atualização,
# "ausente" se o serviço não existe).
svc_estado() { # svc_estado SERVIÇO
  { docker service inspect "$1" 2>/dev/null || true; } | python3 -c '
import datetime, json, re, sys
def ep(s):
    if not s:
        return 0
    s = re.sub(r"\.\d+", "", s).replace("Z", "+00:00")
    try:
        return int(datetime.datetime.fromisoformat(s).timestamp())
    except ValueError:
        return 0
try:
    d = json.load(sys.stdin)[0]
except Exception:
    print("0 ausente 0"); sys.exit(0)
u = d.get("UpdateStatus") or {}
print(ep(d.get("UpdatedAt")), u.get("State") or "-", ep(u.get("StartedAt")))' 2>/dev/null || echo "0 ausente 0"
}

# Últimas linhas do contêiner mais novo que morreu num serviço, sem as linhas de
# requisição, e o erro das últimas tarefas.
servico_log_morto() { # servico_log_morto SERVIÇO
  local cid
  docker service ps "$1" --no-trunc --format '{{.Name}} {{.CurrentState}} {{.Error}}' 2>/dev/null | head -4 | sed 's/^/     /' || true
  cid=$(docker ps -a -q --filter "label=com.docker.swarm.service.name=$1" --filter status=exited 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    echo "  -- últimas linhas do contêiner que morreu ($1):"
    docker logs --tail 40 "$cid" 2>&1 | grep -vE '"request completed"|"incoming request"' | sed 's/^/     /' | tail -25 || true
  fi
}

# Depois de QUALQUER deploy: "1/1" e a tag certa não bastam. Se a tarefa nova morre na
# subida, o Swarm volta sozinho ao spec anterior (failure_action: rollback). Com a
# mesma tag (mudança só no .env) a imagem nem muda, e só o UpdateStatus mostra a volta
# (achado 4 da revisão de 05/10). Espera a atualização terminar e falha quando:
#   - o estado é rollback_started/rollback_paused/rollback_completed ou paused, numa
#     atualização que começou depois do deploy (T0). Estado antigo, de um deploy
#     anterior que já voltou, não conta: é o caso do "app-subir TAG_ANTERIOR";
#   - a atualização não termina em 7 min;
#   - com TAG, a imagem do serviço não está nessa tag.
# Mostra o log do contêiner que morreu. Volta 1 se algo falhou (quem chama decide).
conferir_atualizacao() { # conferir_atualizacao T0 TAG|- SERVIÇO...
  local t0=$1 tag=$2 svc upd estado ini pendente agora fim problema img falhou=0
  shift 2
  fim=$(( $(date +%s) + 420 ))
  while :; do
    pendente=0; agora=$(date +%s)
    for svc in "$@"; do
      read -r upd estado ini <<<"$(svc_estado "$svc")"
      case "$estado" in
        updating|rollback_started) pendente=1 ;;
        *) # Spec regravado agora e a atualização ainda não começou: dá até 30 s.
           if [ "$upd" -ge "$t0" ] && [ "$ini" -lt "$t0" ] && [ "$agora" -lt $((t0 + 30)) ]; then pendente=1; fi ;;
      esac
    done
    [ "$pendente" = 0 ] && break
    [ "$agora" -lt "$fim" ] || break
    sleep 5
  done
  for svc in "$@"; do
    read -r upd estado ini <<<"$(svc_estado "$svc")"
    problema=""
    case "$estado" in
      rollback_*|paused) [ "$ini" -lt "$t0" ] || problema="o Swarm desfez a troca (UpdateStatus=$estado): a tarefa nova morreu na subida" ;;
      updating) problema="a atualização não terminou em 7 min" ;;
      ausente) problema="o serviço não existe" ;;
    esac
    if [ -z "$problema" ] && [ "$tag" != "-" ]; then
      img=$(docker service inspect -f '{{.Spec.TaskTemplate.ContainerSpec.Image}}' "$svc" 2>/dev/null || true)
      case "$img" in
        *":$tag"|*":$tag@"*) ;;
        *) problema="NÃO está em $tag (está em ${img##*:}): o Swarm desfez a troca" ;;
      esac
    fi
    [ -n "$problema" ] || continue
    falhou=1
    echo "  !! $svc: $problema"
    servico_log_morto "$svc"
  done
  return "$falhou"
}

deploy() { # deploy ARQUIVO STACK
  [ -f "$STACKS/$1" ] || falha "$STACKS/$1 não existe: rode 'preparar' antes"
  echo "== $2 ($1)"
  local t0 svcs
  t0=$(date +%s)
  docker stack deploy -c "$STACKS/$1" "$2" --detach=true >/dev/null
  sleep 3   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack "$2"
  svcs=$(docker service ls --filter "label=com.docker.stack.namespace=$2" --format '{{.Name}}' 2>/dev/null || true)
  # shellcheck disable=SC2086
  conferir_atualizacao "$t0" - $svcs || falha "a stack $2 não ficou de pé (log acima)"
}

traefik()   { conferir_fundacao; deploy 00-traefik.yaml traefik; }
portainer() {
  # Com lista de IPs, nunca sobe o painel aberto (achado 34).
  if [ -s "$PAINEL_IPS_ARQ" ] && ! grep -q 'ipallowlist.sourcerange=' "$STACKS/01-portainer.yaml" 2>/dev/null; then
    falha "o painel. é restrito ($PAINEL_IPS_ARQ) e $STACKS/01-portainer.yaml está sem a lista. Rode: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  fi
  deploy 01-portainer.yaml portainer
  [ -s "$PAINEL_IPS_ARQ" ] || echo "  Abra https://painel.$DOMINIO AGORA e crie o admin: o Portainer tranca a criação se demorar"
}
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
VOLUMES="${DOCKER_VOLUMES:-/var/lib/docker/volumes}"   # trocável só para teste

# pg_dump de um banco para ARQ.gz. Falha (e apaga o arquivo) se o pg_dump falhar ou
# o dump vier vazio.
backup_pg() { # backup_pg CID USUÁRIO BANCO ARQ
  if docker exec "$1" pg_dump -U "$2" -d "$3" --no-owner | gzip > "$4" \
     && [ "$(gzip -dc "$4" 2>/dev/null | head -c 1 | wc -c)" = 1 ]; then
    ok "$3 em $4 ($(du -h "$4" | cut -f1))"
    return 0
  fi
  rm -f "$4"
  aviso "pg_dump de $3 falhou"
  return 1
}

# Cópia de uma pasta (uploads do app, anexos do Chatwoot) em tar incremental: um
# completo por semana (domingo, ou quando o último completo passou de 6 dias) e, nos
# outros dias, um diferencial contra o último completo. O disco não enche com 14
# completos por dia e cada envio ao R2 fica pequeno (achado 25). Restaurar: extrair o
# -completo e depois o -diferencial mais novo, os dois com --listed-incremental=/dev/null.
# tar sai 1 quando um arquivo mudou durante a leitura (alguém mandando foto às 03:30):
# a cópia vale, com aviso; 2 ou mais é falha (achado 22). Ecoa o arquivo gerado.
backup_tar() { # backup_tar PASTA TIPO TS
  local orig=$1 tipo=$2 ts=$3 base="$BACKUPS/.$2.snar" novo="$BACKUPS/.$2.snar.novo" modo arq rc=0
  if [ ! -s "$base" ] || [ "$(date -u +%u)" = 7 ] || [ -n "$(find "$base" -mtime +6 2>/dev/null)" ]; then
    modo=completo; rm -f "$novo"
  else
    modo=diferencial; cp "$base" "$novo"
  fi
  arq="$BACKUPS/$tipo-$ts-$modo.tar.gz"
  tar -C "$orig" --listed-incremental="$novo" -czf "$arq" . 2>"$BACKUPS/.tar-erros" || rc=$?
  if [ "$rc" -le 1 ] && [ -s "$arq" ]; then
    [ "$rc" = 1 ] && aviso "$tipo: arquivo mudou durante a cópia (tar saiu 1); a cópia vale: $(head -c 200 "$BACKUPS/.tar-erros" | tr '\n' ' ')" >&2
    if [ "$modo" = completo ]; then mv "$novo" "$base"; else rm -f "$novo"; fi
    rm -f "$BACKUPS/.tar-erros"
    echo "$arq"
    return 0
  fi
  aviso "tar de $tipo falhou (saída $rc): $(head -c 300 "$BACKUPS/.tar-erros" | tr '\n' ' ')" >&2
  rm -f "$arq" "$novo" "$BACKUPS/.tar-erros"
  return 1
}

backup() {
  local dir="$BACKUPS" cid ts arq novos=() falhas=() up
  mkdir -p "$dir"; chmod 700 "$dir"
  umask 077
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  echo "== backup $ts"
  # Cada parte é independente (achado 22): a que falha fica registrada e as outras
  # seguem, inclusive o envio ao R2. No fim, código de erro e resumo do que falhou,
  # que a vigia lê de $BACKUPS/.backup-falhas.

  # Banco do n8n. Só restaura credenciais com a N8N_CHAVE do cofre.
  cid=$(docker ps -q -f name=n8n_postgres_n8n_postgres 2>/dev/null | head -1 || true)
  if [ -z "$cid" ]; then
    aviso "contêiner do Postgres do n8n não está rodando"; falhas+=("n8n: Postgres fora do ar")
  else
    arq="$dir/n8n_queue-$ts.sql.gz"
    if backup_pg "$cid" postgres n8n_queue "$arq"; then novos+=("$arq"); else falhas+=("n8n: pg_dump falhou"); fi
  fi

  # Banco do app e a memória da nossa Crystal (crystal_agente, achado 21), se a stack
  # crystal_app estiver no ar. Campos cifrados e o hash do CPF só se leem com
  # ENCRYPTION_KEY e CPF_SALT; a memória, com CRYSTAL_CHAVE_CIFRA. Todas no cofre.
  cid=$(docker ps -q -f name=${APP_STACK}_app_postgres 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    arq="$dir/crystal_web_chat-$ts.sql.gz"
    if backup_pg "$cid" crystal crystal_web_chat "$arq"; then novos+=("$arq"); else falhas+=("app: pg_dump do crystal_web_chat falhou"); fi
    if docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc "select 1 from pg_database where datname = 'crystal_agente'" 2>/dev/null | grep -q 1; then
      arq="$dir/crystal_agente-$ts.sql.gz"
      if backup_pg "$cid" crystal crystal_agente "$arq"; then novos+=("$arq"); else falhas+=("app: pg_dump do crystal_agente (memória da Crystal) falhou"); fi
    fi
  elif docker service inspect "${APP_STACK}_app_postgres" >/dev/null 2>&1; then
    aviso "o serviço do Postgres do app existe mas não está rodando"; falhas+=("app: Postgres fora do ar")
  fi
  # Arquivos que os alunos mandam pelo app (imagem, áudio).
  up=$VOLUMES/${APP_STACK}_app_uploads/_data
  if [ -d "$up" ]; then
    if arq=$(backup_tar "$up" crystal_uploads "$ts"); then
      ok "uploads do app em $arq ($(du -h "$arq" | cut -f1))"; novos+=("$arq")
    else
      falhas+=("app: tar dos uploads falhou")
    fi
  fi
  # O nosso Chatwoot (conversas da equipe e anexos), se estiver no ar. Segredos
  # guardados no banco só se leem com as ACTIVE_RECORD_ENCRYPTION_* do cofre.
  cid=$(docker ps -q -f name=crystal_atendimento_cw_postgres 2>/dev/null | head -1 || true)
  if [ -n "$cid" ]; then
    arq="$dir/chatwoot-$ts.sql.gz"
    if backup_pg "$cid" chatwoot chatwoot "$arq"; then novos+=("$arq"); else falhas+=("Chatwoot: pg_dump falhou"); fi
  elif docker service inspect crystal_atendimento_cw_postgres >/dev/null 2>&1; then
    aviso "o serviço do Postgres do Chatwoot existe mas não está rodando"; falhas+=("Chatwoot: Postgres fora do ar")
  fi
  up=$VOLUMES/crystal_atendimento_cw_storage/_data
  if [ -d "$up" ]; then
    if arq=$(backup_tar "$up" chatwoot_storage "$ts"); then
      ok "anexos do Chatwoot em $arq ($(du -h "$arq" | cut -f1))"; novos+=("$arq")
    else
      falhas+=("Chatwoot: tar dos anexos falhou")
    fi
  fi
  find "$dir" -maxdepth 1 \( -name 'n8n_queue-*' -o -name 'crystal_web_chat-*' -o -name 'crystal_agente-*' -o -name 'crystal_uploads-*' \
    -o -name 'chatwoot-*' -o -name 'chatwoot_storage-*' \) -mtime +14 -delete || true
  echo "  $(find "$dir" -maxdepth 1 -name '*.gz' | wc -l) arquivo(s) na VPS (14 dias)"
  echo "  Restaurar banco: gunzip -c ARQ | docker exec -i CID psql -U USUÁRIO -d BANCO"
  echo "  Restaurar pasta: tar -xzf ...-completo.tar.gz --listed-incremental=/dev/null -C DESTINO, depois o -diferencial mais novo"

  if [ -s "$FORA_CONF" ] && [ -s "$FORA_DEST" ]; then
    if [ ${#novos[@]} -gt 0 ]; then
      backup_fora "${novos[@]}" || falhas+=("R2: nem tudo subiu (ficou só na VPS)")
    fi
  elif [ -s "$BACKUPS/.fora-ultimo" ]; then
    # Já mandava para o R2 e a configuração sumiu: não é "não configurado" (achado 23).
    falhas+=("R2: a cópia fora da VPS parou (falta $FORA_CONF ou $FORA_DEST)")
  else
    aviso "cópia fora da VPS não configurada (backup-chave e backup-fora-config)"
  fi

  if [ ${#falhas[@]} -eq 0 ]; then
    date -u +%FT%TZ > "$BACKUPS/.backup-ultimo"
    rm -f "$BACKUPS/.backup-falhas"
    ok "backup completo"
    return 0
  fi
  printf '%s\n' "${falhas[@]}" > "$BACKUPS/.backup-falhas"
  echo "== backup INCOMPLETO: ${#falhas[@]} parte(s) falharam (o resto foi salvo e enviado)"
  printf '  !! %s\n' "${falhas[@]}"
  exit 1
}

# O cron (backup e vigia) roda a cópia em $BASE/bootstrap-vps.sh. Ela é trocada a cada
# app-subir e atendimento-subir (e no backup-cron e no vigia-config), sem esconder
# erro (achado 24). Troca por mv: o bash lê o script aos poucos, e sobrescrever no
# lugar quebraria um backup ou uma vigia rodando naquele instante.
copia_cron_atualizar() { # copia_cron_atualizar [--criar]
  local origem destino="$BASE/bootstrap-vps.sh"
  origem="$AQUI/$(basename "$0")"
  [ -f "$origem" ] || { aviso "não achei $origem para atualizar a cópia do cron"; return 0; }
  [ "$origem" -ef "$destino" ] && return 0
  [ -f "$destino" ] || [ "${1:-}" = "--criar" ] || return 0
  if [ -f "$destino" ] && cmp -s "$origem" "$destino"; then return 0; fi
  if cp "$origem" "$destino.novo" && chmod 700 "$destino.novo" && mv "$destino.novo" "$destino"; then
    ok "cópia do cron atualizada ($destino, sha256 $(sha256sum "$destino" | cut -c1-12))"
  else
    rm -f "$destino.novo"
    aviso "NÃO atualizei $destino: o backup e a vigia seguem com a versão antiga"
  fi
}

copia_cron_conferir() {
  local origem destino="$BASE/bootstrap-vps.sh" h1 h2
  origem="$AQUI/$(basename "$0")"
  [ -f "$destino" ] || { aviso "cópia do cron ($destino) não existe: bash $0 backup-cron"; return 0; }
  if [ "$origem" -ef "$destino" ]; then ok "rodando a própria cópia do cron"; return 0; fi
  [ -f "$origem" ] || return 0
  h1=$(sha256sum "$origem" | cut -c1-12); h2=$(sha256sum "$destino" | cut -c1-12)
  if [ "$h1" = "$h2" ]; then ok "cópia do cron igual a este script ($h1)"
  else aviso "a cópia do cron ($h2) é diferente deste script ($h1): o backup e a vigia rodam a antiga. Atualize: bash $0 backup-cron"; fi
}

# Horas desde a data UTC gravada num arquivo (ou desde o arquivo .gz mais novo, para
# o primeiro dia depois desta versão). "nunca" se não houver nada.
horas_desde() { # horas_desde ARQUIVO_COM_DATA
  local t=""
  [ -s "$1" ] && t=$(date -d "$(cat "$1")" +%s 2>/dev/null || true)
  if [ -z "$t" ] && [ "$1" = "$BACKUPS/.backup-ultimo" ]; then
    t=$(find "$BACKUPS" -maxdepth 1 -name '*.gz' -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1 || true)
  fi
  if [ -n "$t" ]; then echo $(( ($(date +%s) - t) / 3600 )); else echo nunca; fi
}

backup_cron() {
  local linha="30 3 * * * root /usr/bin/bash $BASE/bootstrap-vps.sh backup >> $BACKUPS/backup.log 2>&1"
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"
  copia_cron_atualizar --criar
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
fora_ler_conf() { # fora_ler_conf [ARQUIVO] (padrão: a configuração gravada)
  local conf="${1:-$FORA_CONF}"
  [ -s "$conf" ] || falha "R2 não configurado: bash $0 backup-fora-config"
  R2_CONTA=$(app_valor "$conf" R2_CONTA); R2_BUCKET=$(app_valor "$conf" R2_BUCKET)
  R2_CHAVE_ID=$(app_valor "$conf" R2_CHAVE_ID); R2_SEGREDO=$(app_valor "$conf" R2_SEGREDO)
  R2_URL="${R2_ENDPOINT:-https://$R2_CONTA.r2.cloudflarestorage.com}/$R2_BUCKET"
}

fora_curl() { # fora_curl ARGS... (credenciais pela entrada padrão)
  printf 'user = "%s:%s"\n' "$R2_CHAVE_ID" "$R2_SEGREDO" \
    | curl -K - -s -m 300 --aws-sigv4 "aws:amz:${R2_REGIAO:-auto}:s3" "$@"
}

fora_enviar() { # fora_enviar ARQUIVO CHAVE_NO_BUCKET -> 0 se o R2 confirmou
  local sha code resp tam
  # Envio num PUT só: o R2 recusa acima de 5 GiB. Avisa antes de travar (achado 25).
  tam=$(stat -c %s "$1" 2>/dev/null || echo 0)
  if [ "$tam" -gt 4900000000 ]; then
    aviso "$2 tem $(du -h "$1" | cut -f1): grande demais para um envio só ao R2 (limite 5 GiB). Ficou só na VPS"
    return 1
  fi
  sha=$(sha256sum "$1" | cut -d' ' -f1)
  resp=$(mktemp)
  code=$(fora_curl -o "$resp" -w '%{http_code}' -T "$1" -H "x-amz-content-sha256: $sha" "$R2_URL/$2") || code=000
  if [ "$code" = 200 ]; then rm -f "$resp"; return 0; fi
  aviso "R2 respondeu $code para $2: $(head -c 300 "$resp" | tr -d '\n')"
  rm -f "$resp"; return 1
}

backup_fora() { # backup_fora ARQUIVO... cifra e envia; volta 1 se algum não subiu
  command -v age >/dev/null || { aviso "age não instalado: bash $0 backup-chave"; return 1; }
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
  if [ "$erros" -gt 0 ]; then
    aviso "$erros arquivo(s) não subiram para o R2. Ficaram só na VPS"
    return 1
  fi
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
  chmod 600 "$FORA_CONF.novo"
  seg=""
  echo "== teste de envio (com os dados novos; a configuração atual segue valendo até o teste passar)"
  local conf_ok=0
  fora_ler_conf "$FORA_CONF.novo"
  t=$(mktemp "$BACKUPS/.teste.XXXXXX")
  echo "teste $(date -u +%FT%TZ)" | age -r "$(cat "$FORA_DEST")" -o "$t"
  fora_enviar "$t" "$FORA_PREFIXO/teste/$(date -u +%Y%m%dT%H%M%SZ).age" && conf_ok=1
  rm -f "$t"
  if [ "$conf_ok" -ne 1 ]; then
    rm -f "$FORA_CONF.novo"
    # Antes, a configuração boa era apagada aqui e o backup parava de ir ao R2 em
    # silêncio (achado 23). Agora ela fica como estava.
    if [ -s "$FORA_CONF" ]; then
      falha "o envio de teste falhou (Account ID, bucket ou chave?). A configuração anterior continua valendo; rode de novo"
    fi
    falha "o envio de teste falhou (Account ID, bucket ou chave?). Nada gravado; rode de novo"
  fi
  mv "$FORA_CONF.novo" "$FORA_CONF"; chmod 600 "$FORA_CONF"
  ok "R2 aceitou o envio; dados gravados em $FORA_CONF"
  backup_cron
  echo "Próximo: bash $0 backup   (faz um backup agora e manda pro R2)"
}

# Link temporário (10 min) para baixar o backup mais novo de um tipo, para o teste
# de restauração no Mac sem passar pelo painel. O link só baixa aquele arquivo, que
# está cifrado; mesmo assim, não colar em chat.
backup_link() {
  local tipo="${1:-n8n_queue}" xml code
  echo "$tipo" | grep -Eq '^(n8n_queue|crystal_web_chat|crystal_agente|crystal_uploads|chatwoot|chatwoot_storage)$' \
    || falha "tipo: n8n_queue, crystal_web_chat, crystal_agente, crystal_uploads, chatwoot ou chatwoot_storage"
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
# Pastas (uploads, anexos) vêm em tar incremental: restaurar pede o último completo
# (ou um antigo, sem sufixo) e o diferencial mais novo depois dele.
if sys.argv[2].rstrip('/').endswith(('crystal_uploads', 'chatwoot_storage')):
    completos = [i for i, c in enumerate(chaves) if '-diferencial' not in c]
    if not completos:
        sys.exit("ERRO: nenhum backup completo desse tipo no R2")
    escolhidas = [chaves[completos[-1]]]
    dif = [c for c in chaves[completos[-1] + 1:] if '-diferencial' in c]
    if dif:
        escolhidas.append(dif[-1])
else:
    escolhidas = [chaves[-1]]
base = urllib.parse.urlsplit(os.environ['R2_URL'])
agora = datetime.datetime.now(datetime.timezone.utc)
data, carimbo = agora.strftime('%Y%m%d'), agora.strftime('%Y%m%dT%H%M%SZ')
escopo = f"{data}/{os.environ['R2_REGIAO']}/s3/aws4_request"
k = ('AWS4' + os.environ['R2_SEGREDO']).encode()
for parte in (data, os.environ['R2_REGIAO'], 's3', 'aws4_request'):
    k = hmac.new(k, parte.encode(), hashlib.sha256).digest()
print("Link válido por 10 minutos. No Terminal do Mac, cole cada linha curl INTEIRA (não cole em chat):")
for chave in escolhidas:
    host, caminho = base.netloc, base.path + '/' + urllib.parse.quote(chave, safe='/')
    q = {'X-Amz-Algorithm': 'AWS4-HMAC-SHA256', 'X-Amz-Credential': f"{os.environ['R2_CHAVE_ID']}/{escopo}",
         'X-Amz-Date': carimbo, 'X-Amz-Expires': '600', 'X-Amz-SignedHeaders': 'host'}
    qs = '&'.join(f"{urllib.parse.quote(kk, safe='')}={urllib.parse.quote(v, safe='')}" for kk, v in sorted(q.items()))
    canon = '\n'.join(['GET', caminho, qs, f'host:{host}', '', 'host', 'UNSIGNED-PAYLOAD'])
    assinar = '\n'.join(['AWS4-HMAC-SHA256', carimbo, escopo, hashlib.sha256(canon.encode()).hexdigest()])
    sig = hmac.new(k, assinar.encode(), hashlib.sha256).hexdigest()
    nome = chave.rsplit('/', 1)[-1]
    print()
    print(f"Backup: {chave}")
    print(f"curl -fo ~/Downloads/{nome} '{base.scheme}://{host}{caminho}?{qs}&X-Amz-Signature={sig}'")
if len(escolhidas) > 1:
    print()
    print("Restaurar: extrair o -completo e depois o -diferencial, os dois com tar --listed-incremental=/dev/null")
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
  # Só a recusa da retenção (403) seguida do arquivo ainda lá (HEAD 200) prova a
  # trava. 5xx, 429 e outros códigos são inconclusivos (achado 69).
  case "$code" in
    200|204) aviso "o R2 APAGOU o arquivo (resposta $code): a trava NÃO está valendo. Conferir Settings > Bucket lock rules (prefixo vazio, 30 dias)"; exit 1 ;;
    000) aviso "sem resposta do R2; rode de novo" ; exit 1 ;;
    403)
      local h
      h=$(fora_curl -o /dev/null -w '%{http_code}' -I "$R2_URL/$obj") || h=000
      if [ "$h" = 200 ]; then
        ok "o R2 recusou apagar (403) e o arquivo continua lá (HEAD 200): a trava está valendo. Quem invadir a VPS não apaga os backups"
      else
        aviso "o R2 recusou apagar (403), mas o HEAD respondeu $h: inconclusivo. Rode de novo"; exit 1
      fi ;;
    *) aviso "o R2 respondeu $code ao apagar: não é a recusa da trava (403). Inconclusivo: rode de novo e, se repetir, conferir Settings > Bucket lock rules"; exit 1 ;;
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

# ------------------------------------------------------------------ portas do Docker
# O Docker publica porta por iptables próprio, por cima do ufw: o "só 22, 80 e 443"
# do ufw não vale para o que um serviço publicar (achado 73). Confere o que está
# publicado em todas as interfaces e aponta o que não for 80 ou 443.
portas_docker_conferir() {
  local extras
  extras=$( { docker service ls --format '{{.Name}} {{.Ports}}' 2>/dev/null; docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null; } \
    | awk '{ n=$1; $1=""; s=$0
             while (match(s, /(\*|0\.0\.0\.0|::|\[::\]):[0-9]+->/)) {
               p=substr(s, RSTART, RLENGTH); sub(/->$/, "", p); sub(/.*:/, "", p)
               if (p != "80" && p != "443") print n " publica a porta " p
               s=substr(s, RSTART + RLENGTH) } }' | sort -u || true)
  if [ -z "$extras" ]; then
    ok "o Docker só publica 80 e 443 (o resto o ufw fecha)"
  else
    printf '%s\n' "$extras" | while read -r l; do aviso "PORTA ABERTA PARA A INTERNET pelo Docker, por cima do ufw: $l"; done
  fi
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
  ok "ufw ativo: entrada só 22, 80 e 443 (o que o Docker publica passa por cima: conferido abaixo)"
  ufw status | sed 's/^/  /'
  portas_docker_conferir
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
  portas_docker_conferir
  echo "  Portas escutando (o ufw deixa 22, 80 e 443; as do Swarm, 2377, 7946 e 4789, ele fecha; porta publicada pelo Docker passa por cima, conferida acima):"
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
  local t0; t0=$(date +%s)
  docker stack deploy -c "$STACKS/01-portainer.yaml" portainer --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack portainer 240 || exit 1
  conferir_atualizacao "$t0" - portainer_portainer portainer_agent || falha "o Portainer não ficou de pé com a lista nova (log acima)"
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
  local h
  h=$(horas_desde "$BACKUPS/.backup-ultimo")
  if [ "$h" != nunca ] && [ "$h" -lt 26 ]; then ok "último backup completo na VPS há ${h} h"; else aviso "último backup completo na VPS: há ${h} h (ver $BACKUPS/backup.log)"; fi
  [ -s "$BACKUPS/.backup-falhas" ] && aviso "último backup com falha: $(paste -sd';' "$BACKUPS/.backup-falhas")"
  if [ -s "$FORA_CONF" ] && [ -s "$BACKUPS/.fora-ultimo" ]; then
    h=$(horas_desde "$BACKUPS/.fora-ultimo")
    if [ "$h" -lt 26 ]; then ok "último backup no R2 há ${h} h"; else aviso "último backup no R2 há ${h} h: ver $BACKUPS/backup.log"; fi
  else
    aviso "backup fora da VPS não configurado (backup-chave, backup-fora-config)"
  fi
  copia_cron_conferir
  # A lista do arquivo não basta: confere a trava no serviço que está no ar (achado 34).
  local trava
  trava=$(docker service inspect portainer_portainer --format '{{index .Spec.Labels "traefik.http.middlewares.portainer-ips.ipallowlist.sourcerange"}}' 2>/dev/null || true)
  if [ -s "$PAINEL_IPS_ARQ" ] && [ -n "$trava" ] && [ "$trava" != "<no value>" ]; then
    ok "painel. liberado só para: $trava (conferido no serviço no ar)"
  elif [ -s "$PAINEL_IPS_ARQ" ]; then
    aviso "a lista de IPs existe, mas o Portainer no ar está SEM a trava: bash $0 painel-restringir $(paste -sd' ' "$PAINEL_IPS_ARQ")"
  else
    aviso "painel. (Portainer) aberto para qualquer IP: bash $0 painel-restringir"
  fi
  portas_docker_conferir
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
      echo "Copie DB_SENHA, N8N_CHAVE e N8N_REDIS_SENHA pro Bitwarden, em itens separados."
      echo "Aperte q pra fechar: os valores somem da tela e não vão pro histórico."
      echo "A chave N8N_CHAVE nunca pode mudar depois de o n8n ter fluxo salvo."
      echo
      grep -E '^(DB_SENHA|N8N_CHAVE|N8N_REDIS_SENHA)=' "$SEGREDOS"
    } | less -K
  else
    # Fora de terminal (cron, pipe, log) os valores iriam parar num arquivo (achado 70).
    falha "rode num terminal: os segredos abrem no less e não ficam em log nem no histórico"
  fi
}

# Só serve ANTES de o n8n ter qualquer fluxo ou credencial salva. Apaga o banco
# do n8n, os segredos e refaz tudo com segredos novos. Uso:
#   bash bootstrap-vps.sh recomecar-n8n SEU_EMAIL --confirmo
recomecar_n8n() {
  local email="${2:-}" conf="${3:-}" pg n tem v ts t=0
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do n8n. Se for isso mesmo: bash $0 recomecar-n8n SEU_EMAIL --confirmo"
  [ -n "$email" ] || falha "informe o e-mail do Let's Encrypt"
  # Trava real (achado 31). A guarda antiga procurava o serviço "n8n_editor", mas o
  # nome é n8n_editor_n8n_editor: nunca conferia nada e apagaria a crystal-provisoria.
  # Agora confere direto no banco e falha fechado: sem o Postgres no ar, ou sem
  # resposta, não dá para provar que está vazio, e nada é apagado.
  pg=$(docker ps -q -f name=n8n_postgres_n8n_postgres 2>/dev/null | head -1 || true)
  [ -n "$pg" ] || falha "o Postgres do n8n não está rodando: não dá para provar que o n8n está sem fluxo. Nada apagado"
  tem=$(docker exec "$pg" psql -U postgres -d n8n_queue -tAc "select to_regclass('public.workflow_entity') is not null" 2>/dev/null | tr -d '[:space:]' || true)
  case "$tem" in
    f) n=0 ;;   # o n8n nunca criou as tabelas
    t) n=$(docker exec "$pg" psql -U postgres -d n8n_queue -tAc 'select (select count(*) from workflow_entity) + (select count(*) from credentials_entity)' 2>/dev/null | tr -d '[:space:]' || true) ;;
    *) n="" ;;
  esac
  [ -n "$n" ] || falha "o banco do n8n não respondeu: não dá para provar que está sem fluxo. Nada apagado"
  [ "$n" = "0" ] || falha "o n8n tem $n fluxo(s)/credencial(is) salvos. Trocar a chave agora os tornaria ilegíveis. Não recomece"
  [ -t 0 ] || falha "rode num terminal: este comando pede confirmação digitada"
  read -rp "Digite APAGAR para apagar o banco do n8n e trocar os segredos dele: " v
  [ "$v" = APAGAR ] || falha "nada apagado"
  # Cópia antes de apagar: o dump e os segredos antigos (a chave abre o dump).
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"; umask 077
  backup_pg "$pg" postgres n8n_queue "$BACKUPS/n8n_queue-antes-recomecar-$ts.sql.gz" || falha "não copiei o banco do n8n antes de apagar. Nada apagado"
  cp -p "$SEGREDOS" "$BASE/.segredos.antes-recomecar-$ts" || falha "não copiei $SEGREDOS. Nada apagado"
  echo "== removendo stacks do n8n"
  docker stack rm n8n_worker n8n_webhook n8n_editor n8n_redis n8n_postgres 2>/dev/null || true
  # O volume só solta quando nenhum contêiner (nem parado) o usa.
  while docker ps -a -q --filter volume=n8n_postgres_data --filter volume=n8n_redis_data 2>/dev/null | grep -q . && [ $t -lt 120 ]; do sleep 3; t=$((t+3)); done
  echo "== recriando os volumes do n8n (banco antigo apagado; cópia em $BACKUPS)"
  for v in n8n_postgres_data n8n_redis_data; do
    if docker volume inspect "$v" >/dev/null 2>&1; then
      docker volume rm "$v" >/dev/null || falha "não apagou o volume $v (ainda em uso?). Os segredos não foram trocados; rode de novo em 1 min"
    fi
  done
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
  CHATWOOT_WEBHOOK_SECRET* CHANNEL_REPLY_TIMEOUT_MS CHATWOOT_ACCOUNT_ID CHATWOOT_BOT_TOKEN* CHATWOOT_BOT_SECRET*
  SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY* SUPABASE_LOGIN_RPC
  REVIEW_ACCOUNTS* OPENROUTER_API_KEY* CRYSTAL_MODEL CRYSTAL_MODEL_RESERVA
  ANDROID_CERT_SHA256 APPLE_TEAM_ID FCM_PROJECT_ID FCM_SERVICE_ACCOUNT_JSON*
  REFUND_WEBHOOK_SECRET* TRANSCRIPTION_API_URL TRANSCRIPTION_API_KEY* TRANSCRIPTION_MODEL
  TRANSCRIPTION_TIMEOUT_MS CHATWOOT_API_TOKEN* EQUIPE_EMAIL
  RATE_AUTH_MAX RATE_AUTH_WINDOW_S OTP_MAX_ATTEMPTS OTP_RESEND_COOLDOWN_S OTP_RESEND_MAX
  RATE_AUTH_IP_MAX UPLOAD_DAILY_MAX CRYSTAL_PRAZO_TOTAL_MS CRYSTAL_TIMEOUT_MS)

# Nome de variável: maiúsculas, números e _. Qualquer outra coisa no lugar do nome
# pode ser uma chave colada errado, e aí nunca é repetida na tela (achado 70).
parece_nome() { printf '%s' "$1" | grep -Eq '^[A-Z][A-Z0-9_]{1,40}$'; }
recusar_nao_nome() { # recusar_nao_nome COMANDO
  falha "isso não é um NOME da lista e pode ser uma CHAVE colada no lugar (re_, gsk_, sb_secret_, sk-or-, eyJ...). Não repito o que foi digitado. A chave nunca vai na linha de comando: rode só 'bash $0 $1 NOME' e cole quando ele perguntar. Se era uma chave, troque-a no painel de origem: ela ficou no histórico do terminal (limpe com: history -c && history -w)"
}
inteiro_entre() { # inteiro_entre VALOR MIN MAX
  printf '%s' "$1" | grep -Eq '^[0-9]{1,9}$' && [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]
}

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
    parece_nome "$nome" || recusar_nao_nome app-definir
    falha "$nome não está na lista de nomes aceitos. Rode 'bash $0 app-definir' pra ver a lista"
  fi
  if [ "$secreto" -eq 1 ]; then
    read -rsp "$nome (não aparece na tela): " v; echo
  else
    read -rp "$nome: " v
  fi
  case "$v" in *$'\r'*) v=${v//$'\r'/} ;; esac   # colado do Windows/Mac com CR no fim
  # Espaço ou tab nas pontas (colar do painel costuma trazer) sai; no meio, fica.
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  [ -n "$v" ] || falha "valor vazio; nada gravado"
  case "$v" in *$'\n'*) falha "valor com quebra de linha" ;; esac
  local base papel
  case "$nome" in
    SUPABASE_URL)
      # Em 05/10 colaram a URL com /rest/v1/ e todo login daria 503: o app acrescenta
      # /rest/v1/rpc/... sozinho. Corta o caminho e avisa (achado 9).
      case "$v" in https://*) ;; *) falha "a URL do Supabase começa com https:// (ex.: https://abcdefghijklmnopqrst.supabase.co). Nada gravado" ;; esac
      base=$(printf '%s' "$v" | sed -E 's;^(https://[^/?#]+).*;\1;')
      if [ "$base" != "$v" ]; then
        aviso "cortei '${v#"$base"}' do fim: vale só https://<ref>.supabase.co (o app acrescenta /rest/v1/rpc/... sozinho)"
        v=$base
      fi
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z')
      printf '%s' "$v" | grep -Eq '^https://[a-z0-9]{20}\.supabase\.co$' \
        || falha "formato: https://<ref de 20 letras e números>.supabase.co (Supabase > Settings > API > Project URL). Nada gravado" ;;
    SUPABASE_SERVICE_ROLE_KEY)
      # A chave anon/publicável é pública e não passa pelo RLS da base: com ela todo
      # login de aluna daria 503. Recusa sem mostrar nada.
      case "$v" in
        sb_publishable_*) v=""; falha "essa é a chave PUBLICÁVEL (sb_publishable_...), que é pública. Aqui vai a SECRETA (sb_secret_...) ou a service_role legada (eyJ...). Nada gravado" ;;
        sb_secret_*) printf '%s' "$v" | grep -Eq '^sb_secret_[A-Za-z0-9_-]{20,}$' || { v=""; falha "chave sb_secret_ incompleta ou com caractere estranho. Nada gravado"; } ;;
        eyJ*)
          papel=$(printf '%s' "$v" | python3 -c 'import base64,json,sys
p=sys.stdin.read().strip().split(".")
try:
    print(json.loads(base64.urlsafe_b64decode(p[1]+"="*(-len(p[1])%4))).get("role",""))
except Exception:
    print("")' 2>/dev/null || true)
          case "$papel" in
            service_role) ;;
            anon) v=""; falha "essa é a chave ANON (pública). Aqui vai a service_role (Settings > API > service_role, ou a nova sb_secret_). Nada gravado" ;;
            *) v=""; falha "JWT sem role service_role (incompleto?). Nada gravado" ;;
          esac ;;
        *) v=""; falha "formato inesperado: a chave começa com sb_secret_ (nova) ou eyJ (service_role legada). Nada gravado" ;;
      esac ;;
    SUPABASE_LOGIN_RPC)
      printf '%s' "$v" | grep -Eq '^[a-z_][a-z0-9_]{0,62}$' || falha "nome da função em minúsculas, números e _ (padrão: app_verificar_login). Nada gravado" ;;
    VAPID_SUBJECT)
      printf '%s' "$v" | grep -Eq '^(mailto:[^@ ]+@[^@ ]+\.[^@ ]+|https://[^ ]+)$' || falha "formato: mailto:alguem@dominio.com ou https://... Nada gravado" ;;
    SENTRY_DSN)
      printf '%s' "$v" | grep -Eq '^https://[A-Za-z0-9]+@[A-Za-z0-9.-]+(:[0-9]+)?/[0-9]+$' \
        || falha "formato do DSN: https://CHAVE@oNNN.ingest.sentry.io/NNN (Sentry > Settings > Client Keys). Nada gravado" ;;
    ALERT_WEBHOOK_URL)
      printf '%s' "$v" | grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^ ]*)?$' || { v=""; falha "a URL do alerta tem que ser https://, sem espaço. Nada gravado"; } ;;
    CHANNEL_REPLY_TIMEOUT_MS)
      inteiro_entre "$v" 5000 600000 || falha "só inteiro entre 5000 e 600000 (milissegundos; padrão 180000). Nada gravado" ;;
    RATE_AUTH_MAX)
      inteiro_entre "$v" 1 10000 || falha "só inteiro entre 1 e 10000 (tentativas por janela; padrão 5). Nada gravado" ;;
    RATE_AUTH_IP_MAX)
      inteiro_entre "$v" 1 100000 || falha "só inteiro entre 1 e 100000 (tentativas por IP na janela; padrão 50). Nada gravado" ;;
    UPLOAD_DAILY_MAX)
      inteiro_entre "$v" 1 100000 || falha "só inteiro entre 1 e 100000 (uploads por aluna por dia; padrão 200). Nada gravado" ;;
    CRYSTAL_PRAZO_TOTAL_MS|CRYSTAL_TIMEOUT_MS)
      inteiro_entre "$v" 5000 600000 || falha "só inteiro entre 5000 e 600000 (milissegundos; padrões 50000 e 45000; o prazo total da Crystal tem de ficar abaixo dos 60 s da API). Nada gravado" ;;
    RATE_AUTH_WINDOW_S)
      inteiro_entre "$v" 10 86400 || falha "só inteiro entre 10 e 86400 (segundos; padrão 900). Nada gravado" ;;
    OTP_MAX_ATTEMPTS|OTP_RESEND_MAX)
      inteiro_entre "$v" 1 20 || falha "só inteiro entre 1 e 20. Nada gravado" ;;
    OTP_RESEND_COOLDOWN_S)
      inteiro_entre "$v" 10 3600 || falha "só inteiro entre 10 e 3600 (segundos; padrão 60). Nada gravado" ;;
    EQUIPE_EMAIL)
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z')
      printf '%s' "$v" | grep -Eq '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$' || falha "e-mail inválido. Nada gravado" ;;
    CHAT_TRANSPORT)
      v=$(printf '%s' "$v" | tr 'A-Z' 'a-z' | tr -d ' ')
      case "$v" in crystal|chatwoot) ;; *) falha "digite só crystal (a nossa Crystal direto) ou chatwoot (pelo nosso Chatwoot; prefira: app-canal chatwoot). Nada gravado" ;; esac ;;
    ANDROID_CERT_SHA256)
      v=$(printf '%s' "$v" | tr 'a-f' 'A-F' | tr -d ' ')
      printf '%s' "$v" | grep -Eq '^([0-9A-F]{2}(:[0-9A-F]{2}){31})(,[0-9A-F]{2}(:[0-9A-F]{2}){31})*$' \
        || falha "formato: AA:BB:...(32 pares), várias separadas por vírgula (Play Console > Integridade do app)" ;;
    APPLE_TEAM_ID)
      v=$(printf '%s' "$v" | tr 'a-z' 'A-Z')
      printf '%s' "$v" | grep -Eq '^[A-Z0-9]{10}$' || falha "o Team ID tem 10 letras/números (developer.apple.com > Membership)" ;;
    FCM_PROJECT_ID)
      printf '%s' "$v" | grep -Eq '^[a-z][a-z0-9-]{4,28}[a-z0-9]$' || falha "ID do projeto do Firebase (ex.: crystal-app-1a2b3), não o nome" ;;
    FCM_SERVICE_ACCOUNT_JSON)
      # Base64 do JSON da conta de serviço. Confere o formato sem mostrar nada.
      printf '%s' "$v" | python3 -c 'import base64,json,sys
d=json.loads(base64.b64decode(sys.stdin.read().strip(), validate=True))
assert d.get("type")=="service_account" and d.get("client_email") and "PRIVATE KEY" in d.get("private_key","")' 2>/dev/null \
        || falha "esperado o JSON da conta de serviço em base64, numa linha só (no Mac: base64 -i chave.json | tr -d '\\n' | pbcopy). Nada gravado" ;;
    REFUND_WEBHOOK_SECRET)
      # Assina o webhook de reembolso: tem que ser longo e variado, nunca uma palavra.
      [ "$(printf '%s' "$v" | wc -c)" -ge 32 ] && [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l)" -ge 10 ] \
        || falha "segredo fraco (mínimo 32 bytes e 10 caracteres diferentes). Gere com: openssl rand -hex 32  e cole o resultado. Nada gravado" ;;
    TRANSCRIPTION_API_URL)
      case "$v" in https://?*) ;; *) falha "a URL da transcrição tem que começar com https://. Nada gravado" ;; esac ;;
    TRANSCRIPTION_TIMEOUT_MS)
      printf '%s' "$v" | grep -Eq '^[0-9]{4,6}$' && [ "$v" -ge 1000 ] && [ "$v" -le 120000 ] \
        || falha "só inteiro entre 1000 e 120000 (milissegundos). Nada gravado" ;;
  esac
  mkdir -p "$APP_DIR"; chmod 700 "$APP_DIR"
  umask 077
  touch "$APP_EXT"
  grep -vE "^$nome=" "$APP_EXT" > "$APP_EXT.tmp" || true
  printf '%s=%s\n' "$nome" "$v" >> "$APP_EXT.tmp"
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  unset v
  ok "$nome gravado em $APP_EXT. Vale na próxima 'app-subir'"
}

# Apaga um valor do .externos (ex.: CRYSTAL_ONBOARDING_URL, que a etapa 2 do PRD
# deixou de usar). Só nomes da lista; nunca segredo gerado pelo app-subir.
app_remover() {
  local nome="${2:-}"   # $1 é o próprio "app-remover" (o dispatch passa "$@")
  [ -n "$nome" ] || falha "uso: bash $0 app-remover NOME"
  parece_nome "$nome" || recusar_nao_nome app-remover   # nunca repete o argumento (achado 70)
  printf '%s\n' "${APP_EXTERNOS[@]}" | sed 's/\*$//' | grep -qx "$nome" \
    || falha "$nome não é um valor externo (bash $0 app-definir lista os aceitos)"
  [ -s "$APP_EXT" ] || { aviso "$APP_EXT não existe; nada a apagar"; return 0; }
  if ! grep -qE "^$nome=" "$APP_EXT"; then aviso "$nome não estava em $APP_EXT"; return 0; fi
  umask 077
  grep -vE "^$nome=" "$APP_EXT" > "$APP_EXT.tmp" || true
  mv "$APP_EXT.tmp" "$APP_EXT"; chmod 600 "$APP_EXT"
  ok "$nome apagado de $APP_EXT. Vale na próxima 'app-subir'"
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
  # Nossa Crystal: chave entre app e Crystal, cifra da memória (NUNCA muda depois
  # de a Crystal ter guardado conversa) e senha do papel crystal_agente no Postgres.
  if [ -z "$(app_valor "$APP_SEG" CRYSTAL_CHAVE_CIFRA)" ]; then
    {
      echo "CRYSTAL_AGENTE_KEY=$(openssl rand -hex 32)"
      echo "CRYSTAL_CHAVE_CIFRA=$(openssl rand -hex 32)"
      echo "CRYSTAL_DB_SENHA=$(openssl rand -hex 24)"
    } >> "$APP_SEG"
    ok "segredos da nossa Crystal gerados (copie pro cofre: bash $0 app-segredos)"
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
  # O robô do Chatwoot pergunta à Crystal pela CRYSTAL_API_*: sem ela a API não sobe
  # (achado 33; aconteceria depois de um crystal-provisoria-desligar).
  if [ -n "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)$(app_valor "$APP_EXT" CHATWOOT_BOT_SECRET)$(app_valor "$APP_EXT" CHATWOOT_ACCOUNT_ID)" ]; then
    for k in CRYSTAL_API_URL CRYSTAL_API_KEY; do
      [ -n "$(app_valor "$APP_EXT" $k)" ] || falha "o robô do Chatwoot (CHATWOOT_BOT_*) precisa de $k e ela não está definida. Rode: bash $0 crystal-nossa TAG"
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
    # Menor privilégio: a chave do OpenRouter e o modelo são só da Crystal;
    # o vínculo com as lojas é só do web.
    grep -vE '^(OPENROUTER_API_KEY|CRYSTAL_MODEL|CRYSTAL_MODEL_RESERVA|ANDROID_CERT_SHA256|APPLE_TEAM_ID)=' "$APP_EXT" || true
  } > "$APP_DIR/api.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    echo "NODE_ENV=production"
    echo "DATABASE_URL=postgresql://crystal_agente:$(app_valor "$APP_SEG" CRYSTAL_DB_SENHA)@app_postgres:5432/crystal_agente"
    grep -E '^(CRYSTAL_AGENTE_KEY|CRYSTAL_CHAVE_CIFRA)=' "$APP_SEG"
    grep -E '^(OPENROUTER_API_KEY|CRYSTAL_MODEL|CRYSTAL_MODEL_RESERVA)=' "$APP_EXT" || true
  } > "$APP_DIR/crystal.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada app-subir."
    # Públicos (vão no /.well-known do app): impressões do certificado Android e Team ID da Apple.
    grep -E '^(ANDROID_CERT_SHA256|APPLE_TEAM_ID)=' "$APP_EXT" || true
  } > "$APP_DIR/web.env"
  chmod 600 "$APP_DIR/postgres.env" "$APP_DIR/api.env" "$APP_DIR/crystal.env" "$APP_DIR/web.env"
  unset senha
  # Diz qual das duas pontas falta, em vez de um aviso só que confundia.
  if [ "$(app_valor "$APP_EXT" CHAT_TRANSPORT)" = "chatwoot" ]; then
    ok "Crystal: canal da inbox (CHAT_TRANSPORT=chatwoot)"
  elif [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" ] && [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_KEY)" ]; then
    case "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" in
      http://app_crystal:*) ok "Crystal: a nossa (app_crystal)" ;;
      *webhook.$DOMINIO*) ok "Crystal: a provisória do n8n" ;;
      *) ok "Crystal: $(app_valor "$APP_EXT" CRYSTAL_API_URL | sed -E 's#^(https?://[^/]+).*#\1#')" ;;
    esac
  else
    aviso "Crystal SIMULADA (sem endereço): bash $0 crystal-nossa TAG"
  fi
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    ok "base de alunos: Supabase configurada (a confirmação vem depois do deploy, no app-supabase-teste)"
  elif [ -n "$(app_valor "$APP_EXT" DIRECTORY_API_URL)" ] && [ -n "$(app_valor "$APP_EXT" DIRECTORY_API_KEY)" ]; then
    ok "base de alunos: DIRECTORY_API configurada"
  else
    aviso "base de alunos ainda não ligada: só entra quem foi criado aqui (app-admin, contas de revisão)"
  fi
}

# A API roda sem root desde a etapa 1 do PRD de Otimização (USER node, uid 1000,
# no Dockerfile de apps/api). O volume app_uploads nasceu com dono root: sem isto a
# API nova não grava a mídia dos alunos em /app/uploads. Idempotente e calado
# quando o dono já é 1000:1000; sem a alpine:3.20, avisa e segue.
app_uploads_dono() {
  local vol="${APP_STACK}_app_uploads" dono
  docker volume inspect "$vol" >/dev/null 2>&1 || return 0
  if ! docker image inspect alpine:3.20 >/dev/null 2>&1 && ! docker pull -q alpine:3.20 >/dev/null 2>&1; then
    aviso "não baixou alpine:3.20: dono de $vol não conferido (a API, sem root, pode não gravar em /app/uploads)"
    return 0
  fi
  dono=$(docker run --rm -v "$vol:/u" alpine:3.20 stat -c '%u:%g' /u 2>/dev/null) || dono=
  [ "$dono" = "1000:1000" ] && return 0
  if docker run --rm -v "$vol:/u" alpine:3.20 chown -R 1000:1000 /u; then
    ok "volume $vol entregue ao uid 1000 (API sem root)"
  else
    aviso "não ajustou o dono de $vol: a API pode não gravar em /app/uploads"
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
    && docker pull -q "$APP_IMG-crystal:$tag" >/dev/null \
    || falha "não baixou as imagens $tag. Rodou 'bash $0 app-ghcr'? O build terminou no GitHub?"
  ok "$APP_IMG-api, -web e -crystal:$tag baixadas"

  echo "== segredos e ambiente"
  app_gerar_segredos "$tag"
  crystal_chave_sincronizar
  app_gerar_env
  app_env_preflight "$tag"

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
  app_uploads_dono   # a API sem root (etapa 1) precisa do volume com dono 1000:1000
  local t0; t0=$(date +%s)
  docker stack deploy --with-registry-auth -c "$STACKS/$APP_YAML" "$APP_STACK" --detach=true >/dev/null
  sleep 8   # deixa o Swarm registrar a atualização antes de conferir
  esperar_stack "$APP_STACK" 420 || { servico_log_morto "${APP_STACK}_app_api"; echo "  Logs da API: docker service logs --tail 80 ${APP_STACK}_app_api"; exit 1; }
  app_conferir_troca "$t0" "$tag"
  crystal_banco
  copia_cron_atualizar
  echo
  app_status
  if [ -n "$(app_valor "$APP_EXT" SUPABASE_URL)" ] && [ -n "$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)" ]; then
    echo
    if ! app_supabase_teste; then
      SUPABASE_FALHOU=1
      echo "  !! a base de alunos NÃO respondeu como devia: todo login de aluna da base vai dar 503 até corrigir (acima)"
    fi
  fi
}

# "1/1" não basta: se a tarefa nova morrer na subida, o Swarm volta sozinho para o
# spec anterior e o serviço fica 1/1 (aconteceu em 05/10 com a API da etapa 1). Com
# tag nova, a imagem denuncia; com a MESMA tag (só o .externos mudou), só o
# UpdateStatus mostra (achado 4). Ver conferir_atualizacao.
app_conferir_troca() { # app_conferir_troca T0 TAG
  local t0="$1" tag="$2" falhou=0
  conferir_atualizacao "$t0" "$tag" "${APP_STACK}_app_api" "${APP_STACK}_app_web" "${APP_STACK}_app_crystal" || falhou=1
  conferir_atualizacao "$t0" - "${APP_STACK}_app_postgres" "${APP_STACK}_app_redis" || falhou=1
  if [ "$falhou" = 1 ]; then
    echo
    falha "a subida de $tag não ficou de pé (log acima). Se só o .externos mudou, desfaça a mudança (app-definir/app-remover) e rode app-subir de novo; se a tag mudou, volte com 'bash $0 app-subir TAG_ANTERIOR'. Mande o log acima para a sessão"
  fi
  ok "os três serviços estão em $tag e nenhum voltou (UpdateStatus sem rollback)"
}

# Antes do deploy: o api.env novo passa pelo loadEnv da própria imagem, num contêiner
# sem rede que some em seguida. Valor errado aparece aqui, com a API atual ainda no ar,
# em vez de virar rollback depois. Só nomes e motivos aparecem, nunca valores.
app_env_preflight() { # app_env_preflight TAG
  local saida
  # shellcheck disable=SC2016
  saida=$(timeout 120 docker run --rm --network none --env-file "$APP_DIR/api.env" -w /app/apps/api \
    --entrypoint ./node_modules/.bin/tsx "$APP_IMG-api:$1" --eval \
    'import("./src/env.ts").then(m=>{m.loadEnv();console.log("CRYSTAL_ENV_OK")}).catch(e=>{console.log("CRYSTAL_ENV_ERRO");const i=e&&e.issues;console.log(i?i.map(x=>x.path.join(".")+": "+x.message).join("\n"):String(e&&e.message));process.exit(3)})' \
    2>&1) || true
  case "$saida" in
    *CRYSTAL_ENV_OK*) ok "api.env aceito pelo boot da API $1 (conferido antes do deploy)" ;;
    *CRYSTAL_ENV_ERRO*)
      printf '%s\n' "$saida" | sed -n '/CRYSTAL_ENV_ERRO/,$p' | sed '1d; s/^/     /' | head -25
      falha "o api.env não passa no boot da API $1 (motivos acima). Nada foi trocado: a API atual segue no ar. Corrija com app-definir/app-remover e rode de novo" ;;
    *) aviso "não deu para conferir o api.env antes do deploy; a conferência depois do deploy continua valendo" ;;
  esac
}

# Chama a função de login do Supabase como a API chama, com um CPF fictício (dígitos
# válidos, de ninguém) e e-mail .invalid. Mostra só o código HTTP e o que ele quer
# dizer: nunca a chave nem a resposta. A chave vai ao curl pela entrada padrão.
app_supabase_teste() {
  local url chave rpc code
  url=$(app_valor "$APP_EXT" SUPABASE_URL); chave=$(app_valor "$APP_EXT" SUPABASE_SERVICE_ROLE_KEY)
  rpc=$(app_valor "$APP_EXT" SUPABASE_LOGIN_RPC); rpc=${rpc:-app_verificar_login}
  [ -n "$url" ] && [ -n "$chave" ] || falha "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY não estão definidos: bash $0 app-definir SUPABASE_URL"
  echo "== base de alunos: POST $url/rest/v1/rpc/$rpc com CPF fictício"
  code=$(printf 'header = "apikey: %s"\nheader = "Authorization: Bearer %s"\n' "$chave" "$chave" \
    | curl -s -o /dev/null -m 20 -w '%{http_code}' -K - -X POST "$url/rest/v1/rpc/$rpc" \
        -H 'content-type: application/json' -d '{"p_cpf":"52998224725","p_email":"teste@exemplo.invalid"}') || code=000
  chave=""
  case "$code" in
    200) ok "HTTP 200: a função $rpc existe e a chave vale (base de alunos no ar)" ;;
    404) aviso "HTTP 404: a função $rpc não existe no Supabase. Rodar crystal-em-casa/supabase/app_verificar_login.sql no SQL Editor; se acabou de criar: notify pgrst, 'reload schema'"; return 1 ;;
    401) aviso "HTTP 401: chave recusada. É a service_role (sb_secret_ ou JWT service_role), inteira e do mesmo projeto da URL?"; return 1 ;;
    403) aviso "HTTP 403: a chave entrou mas não pode executar $rpc (grant execute para service_role)"; return 1 ;;
    000) aviso "sem resposta: URL errada, DNS ou a VPS sem saída para o Supabase"; return 1 ;;
    *) aviso "HTTP $code: resposta inesperada do Supabase"; return 1 ;;
  esac
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

# Script temporário em /app/apps/api, ao lado do src/ que ele importa. Desde a etapa 1
# a API roda sem root (USER node) e essa pasta é do root: sem -u 0 o 'cat >' dá
# "Permission denied" (achado 7 da revisão de 05/10). Só gravar e apagar usam root; o
# tsx roda como node. O arquivo não tem dado pessoal (o CPF vai pelo ambiente do
# docker exec) e fica 644 para o node ler.
app_api_ts_gravar() { # app_api_ts_gravar CID NOME < código
  docker exec -i -u 0 -w /app/apps/api "$1" sh -c 'umask 022; cat > "$1"' sh "$2"
}
app_api_ts_apagar() { # app_api_ts_apagar CID NOME
  docker exec -u 0 "$1" rm -f "/app/apps/api/$2" >/dev/null 2>&1 \
    || aviso "não apagou /app/apps/api/$2 no contêiner (não tem dado pessoal; some no próximo app-subir)"
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
  app_api_ts_gravar "$cid" .admin-bootstrap.ts <<'TS' || { unset cpf; falha "não gravou o script temporário na API (contêiner $cid)"; }
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
  # tsx roda como o usuário da imagem (node): só a gravação e a remoção usam root.
  if ! ADMIN_BOOTSTRAP="$cpf:$email:$nome" docker exec -e ADMIN_BOOTSTRAP -w /app/apps/api "$cid" \
    ./node_modules/.bin/tsx .admin-bootstrap.ts; then
    app_api_ts_apagar "$cid" .admin-bootstrap.ts; unset cpf; falha "bootstrap do admin falhou"
  fi
  app_api_ts_apagar "$cid" .admin-bootstrap.ts
  unset cpf
  echo "  Próximo: entrar em https://app.$DOMINIO com esse CPF e e-mail (o código chega pelo Resend)."
}

# Conta de aluno criada à mão (equipe, testes, quem ainda não está na base de
# alunos). CPF digitado sem eco e validado pelos dígitos; nada na linha de comando.
# Quando a base do Supabase entrar (autoritativa), o login confere lá também:
# quem não for aluno ativo na base deixa de entrar.
app_aluno() {
  local cid cpf email nome tel
  cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$cid" ] || falha "a API do app não está rodando: bash $0 app-subir TAG"
  read -rsp "CPF, só números (não aparece): " cpf; echo
  cpf=$(printf '%s' "$cpf" | tr -cd '0-9')
  [ "${#cpf}" -eq 11 ] || falha "CPF precisa de 11 dígitos"
  read -rp "E-mail (recebe o código de login): " email
  echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "e-mail inválido"
  read -rp "Nome: " nome
  [ -n "$nome" ] || falha "nome vazio"
  read -rp "WhatsApp com DDD (Enter para pular): " tel
  tel=$(printf '%s' "$tel" | tr -cd '0-9')
  if [ -n "$tel" ]; then
    case "${#tel}" in 10|11) tel="55$tel" ;; 12|13) ;; *) falha "telefone inválido" ;; esac
    echo "$tel" | grep -Eq '^55[1-9][0-9]9?[0-9]{8}$' || falha "telefone inválido (Brasil, com DDD)"
    tel="+$tel"
  fi
  app_api_ts_gravar "$cid" .aluno.ts <<'TS' || { unset cpf; falha "não gravou o script temporário na API (contêiner $cid)"; }
import { PrismaClient } from "@prisma/client";
import { cpfLast4, cpfSchema, emailSchema } from "@crystal/shared";
import { createPrismaRepos } from "./src/db/prisma";
import { loadEnv } from "./src/env";
import { hashCpf } from "./src/lib/crypto";

const env = loadEnv();
const cpf = cpfSchema.safeParse(process.env.ALUNO_CPF ?? "");
if (!cpf.success) {
  console.log("CPF inválido (dígitos verificadores não batem)");
  process.exit(2);
}
const email = emailSchema.parse((process.env.ALUNO_EMAIL ?? "").trim().toLowerCase());
const prisma = new PrismaClient();
try {
  const repos = createPrismaRepos(prisma);
  const cpfHash = hashCpf(cpf.data, env.CPF_SALT);
  const existente = await repos.users.findByCpfHash(cpfHash);
  if (existente) {
    console.log(`já existe conta com esse CPF (final ${existente.cpfLast4}, papel ${existente.role}); nada feito`);
  } else if (await repos.users.findByEmail(email)) {
    console.log("já existe conta com esse e-mail; nada feito");
  } else {
    await repos.users.create({
      cpfHash,
      cpfLast4: cpfLast4(cpf.data),
      name: (process.env.ALUNO_NOME ?? "").trim(),
      role: "user",
      crystalContactId: null,
      phoneE164: process.env.ALUNO_TEL || null,
      email,
      // Conta local: não passa pela base de alunas (Supabase) no login. Para testadores
      // e equipe usando como aluna. Precisa da API com o campo (imagens a partir de 05/10).
      localAccount: true,
    });
    console.log(`conta local de aluno criada (CPF final ${cpfLast4(cpf.data)}): entra sem passar pela base de alunas`);
  }
} finally {
  await prisma.$disconnect();
}
TS
  if ! ALUNO_CPF="$cpf" ALUNO_EMAIL="$email" ALUNO_NOME="$nome" ALUNO_TEL="$tel" \
    docker exec -e ALUNO_CPF -e ALUNO_EMAIL -e ALUNO_NOME -e ALUNO_TEL -w /app/apps/api "$cid" \
    ./node_modules/.bin/tsx .aluno.ts; then
    app_api_ts_apagar "$cid" .aluno.ts; unset cpf; falha "não criou a conta"
  fi
  app_api_ts_apagar "$cid" .aluno.ts
  unset cpf
  echo "  Entrar em https://app.$DOMINIO com esse CPF e e-mail (o código chega por e-mail)."
  echo "  É uma conta LOCAL: não passa pela base de alunas. Quem está na base com acesso ativo não precisa disto."
}

# Troca TODOS os segredos do app recriando o banco dele do zero. Só enquanto o
# banco não tem ninguém cadastrado: com usuário dentro, ENCRYPTION_KEY e
# CPF_SALT novos deixariam os dados ilegíveis. Mantém .externos (Resend etc.).
#   bash bootstrap-vps.sh app-recomecar TAG --confirmo
app_recomecar() {
  local tag="${2:-}" conf="${3:-}" cid n v ts up
  [ "$conf" = "--confirmo" ] || falha "isto apaga o banco do app e troca os segredos. Se for isso: bash $0 app-recomecar TAG --confirmo"
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "informe a tag: bash $0 app-recomecar sha-XXXXXXX --confirmo"
  # Trava real (achado 29): antes, contêiner ausente ou resposta "?" deixava passar e
  # apagava um banco com alunas. Agora só segue com n=0 comprovado.
  cid=$(docker ps -q -f name=${APP_STACK}_app_postgres 2>/dev/null | head -1 || true)
  [ -n "$cid" ] || falha "o Postgres do app não está rodando: não dá para provar que o banco está vazio. Nada apagado"
  n=$(docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc 'select count(*) from users' 2>/dev/null | tr -d '[:space:]' || true)
  [ -n "$n" ] || falha "o banco do app não respondeu: não dá para provar que está vazio. Nada apagado"
  [ "$n" = "0" ] || falha "o banco do app tem $n usuário(s). Trocar ENCRYPTION_KEY e CPF_SALT agora os tornaria ilegíveis. Não recomece"
  [ -t 0 ] || falha "rode num terminal: este comando pede confirmação digitada"
  read -rp "Digite APAGAR para apagar o banco do app e trocar TODOS os segredos dele: " v
  [ "$v" = APAGAR ] || falha "nada apagado"
  # Cópia antes de apagar: bancos (app e memória da Crystal), uploads e os segredos
  # antigos, que abrem esses dumps. Sem a cópia, nada é apagado.
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  mkdir -p "$BACKUPS"; chmod 700 "$BACKUPS"; umask 077
  backup_pg "$cid" crystal crystal_web_chat "$BACKUPS/crystal_web_chat-antes-recomecar-$ts.sql.gz" || falha "não copiei o banco do app antes de apagar. Nada apagado"
  if docker exec "$cid" psql -U crystal -d crystal_web_chat -tAc "select 1 from pg_database where datname = 'crystal_agente'" 2>/dev/null | grep -q 1; then
    backup_pg "$cid" crystal crystal_agente "$BACKUPS/crystal_agente-antes-recomecar-$ts.sql.gz" || falha "não copiei a memória da Crystal antes de apagar. Nada apagado"
  fi
  up=$VOLUMES/${APP_STACK}_app_uploads/_data
  if [ -d "$up" ] && [ -n "$(ls -A "$up" 2>/dev/null)" ]; then
    tar -C "$up" -czf "$BACKUPS/crystal_uploads-antes-recomecar-$ts.tar.gz" . || falha "não copiei os uploads antes de apagar. Nada apagado"
  fi
  [ ! -f "$APP_SEG" ] || cp -p "$APP_SEG" "$APP_DIR/.segredos.antes-recomecar-$ts" || falha "não copiei $APP_SEG. Nada apagado"
  ok "cópia em $BACKUPS (*-antes-recomecar-$ts) e $APP_DIR/.segredos.antes-recomecar-$ts"
  echo "== removendo a stack $APP_STACK"
  docker stack rm "$APP_STACK" >/dev/null 2>&1 || true
  local t=0
  while docker ps -aq -f "label=com.docker.stack.namespace=$APP_STACK" 2>/dev/null | grep -q . && [ $t -lt 120 ]; do sleep 3; t=$((t+3)); done
  sleep 5
  echo "== apagando os volumes do app (banco vazio)"
  for v in app_postgres_data app_redis_data app_uploads; do
    if docker volume inspect "${APP_STACK}_$v" >/dev/null 2>&1; then
      docker volume rm "${APP_STACK}_$v" >/dev/null || falha "não apagou o volume ${APP_STACK}_$v (ainda em uso?). Os segredos NÃO foram trocados; rode de novo em 1 min"
    fi
  done
  rm -f "$APP_SEG" "$APP_DIR/api.env" "$APP_DIR/postgres.env"
  ok "segredos antigos apagados (cópia guardada); $APP_EXT mantido"
  app_subir app-subir "$tag"
}

# ------------------------------------------------------------------ nossa Crystal
# Com o app apontando para a nossa Crystal, a chave que o app manda TEM que ser a
# CRYSTAL_AGENTE_KEY que a Crystal confere. Depois de um app-recomecar (segredos novos)
# o .externos ficava com a chave antiga e todo chat dava 401 (achado 30).
crystal_chave_sincronizar() {
  local nova
  case "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" in http://app_crystal:*) ;; *) return 0 ;; esac
  nova=$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)
  [ -n "$nova" ] || falha "CRYSTAL_AGENTE_KEY ausente em $APP_SEG"
  if [ "$(app_valor "$APP_EXT" CRYSTAL_API_KEY)" != "$nova" ]; then
    app_gravar CRYSTAL_API_KEY "$nova"
    ok "CRYSTAL_API_KEY do app igualada à CRYSTAL_AGENTE_KEY da nossa Crystal"
  fi
  nova=""
}

# Banco e papel próprios dentro do app_postgres. O papel crystal_agente só entra no
# banco crystal_agente; o banco do app deixa de aceitar conexão de quem não é dono.
# Idempotente: roda a cada app-subir e mantém a senha igual à do .segredos.
crystal_banco() {
  local pg senha t=0
  senha=$(app_valor "$APP_SEG" CRYSTAL_DB_SENHA)
  [ -n "$senha" ] || { aviso "sem CRYSTAL_DB_SENHA: banco da Crystal não criado"; return 0; }
  until pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1) && [ -n "$pg" ] \
        && docker exec "$pg" pg_isready -U crystal -d crystal_web_chat >/dev/null 2>&1; do
    [ $t -ge 120 ] && { aviso "Postgres do app não respondeu: banco da Crystal não criado"; return 0; }
    sleep 3; t=$((t+3))
  done
  # A senha vai pela entrada padrão (heredoc), não pela linha de comando.
  docker exec -i "$pg" psql -v ON_ERROR_STOP=1 -q -U crystal -d crystal_web_chat >/dev/null <<SQL || falha "não criou o banco da Crystal"
do \$\$ begin
  if not exists (select from pg_roles where rolname = 'crystal_agente') then
    create role crystal_agente login password '$senha';
  else
    alter role crystal_agente login password '$senha';
  end if;
end \$\$;
select 'create database crystal_agente owner crystal_agente'
 where not exists (select from pg_database where datname = 'crystal_agente')\\gexec
revoke all on database crystal_agente from public;
revoke connect on database crystal_web_chat from public;
SQL
  unset senha
  ok "banco crystal_agente pronto (papel próprio, sem acesso ao banco do app)"
}

# Telefone de uma conta do app (o canal da inbox identifica a pessoa pelo WhatsApp).
# Para contas criadas aqui (admin, equipe, revisão), que nascem sem telefone. Aluno
# vindo da base recebe o telefone de lá. Uso: bash bootstrap-vps.sh app-telefone EMAIL
app_telefone() {
  local email="${2:-}" tel pg n
  # Só caracteres de e-mail comum: sem aspas nem barra, o valor vai seguro para o psql.
  echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "informe o e-mail da conta: bash $0 app-telefone voce@exemplo.com"
  read -rp "WhatsApp com DDD (ex.: 11 98888 7777): " tel
  tel=$(echo "$tel" | tr -cd '0-9')
  case "${#tel}" in 10|11) tel="55$tel" ;; 12|13) ;; *) falha "telefone inválido" ;; esac
  echo "$tel" | grep -Eq '^55[1-9][0-9]9?[0-9]{8}$' || falha "telefone inválido (Brasil, com DDD)"
  pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1); [ -n "$pg" ] || falha "Postgres do app não está rodando"
  # Valores pela entrada padrão, nunca na linha de comando.
  n=$(docker exec -i "$pg" psql -v ON_ERROR_STOP=1 -tA -U crystal -d crystal_web_chat <<SQL
\set tel '+$tel'
\set email '$email'
with u as (
  update users set phone_e164 = :'tel' where lower(email) = lower(:'email') returning id
), c as (
  update conversations set channel_source_id = null, channel_conversation_id = null where user_id in (select id from u)
)
select count(*) from u;
SQL
) || falha "não gravou"
  tel=""
  [ "$n" = "1" ] && ok "telefone gravado na conta $email (vínculo antigo com a inbox desfeito)" || falha "nenhuma conta com o e-mail $email"
}

# Conta de revisão das lojas (Apple e Google). CPF válido sorteado aqui (não é de
# ninguém do app), e-mail do nosso domínio e código fixo de 6 dígitos. Os dados
# só aparecem no less, para ir ao Bitwarden e às notas de revisão das lojas.
app_revisao() {
  local nova="${2:-}" v cpf codigo
  v=$(app_valor "$APP_EXT" REVIEW_ACCOUNTS)
  if [ -n "$v" ] && [ "$nova" != "--nova" ]; then
    ok "conta de revisão já existe (trocar: bash $0 app-revisao --nova)"
  else
    cpf=$(python3 - <<'PY'
import secrets
while True:
    d = [secrets.randbelow(10) for _ in range(9)]
    if len(set(d)) > 1:
        break
for n in (10, 11):
    s = sum(x * p for x, p in zip(d, range(n, 1, -1)))
    r = (s * 10) % 11
    d.append(0 if r == 10 else r)
print("".join(map(str, d)))
PY
)
    while :; do
      codigo=$(python3 -c 'import secrets; print(f"{secrets.randbelow(10**6):06d}")')
      case "$codigo" in 000000|123456|111111|222222|333333|444444|555555|666666|777777|888888|999999|654321) ;; *) break ;; esac
    done
    app_gravar REVIEW_ACCOUNTS "$cpf:revisao@$DOMINIO:Revisão das lojas:$codigo"
    cpf=""; codigo=""
    ok "conta de revisão gravada. Vale depois do próximo app-subir"
    v=$(app_valor "$APP_EXT" REVIEW_ACCOUNTS)
  fi
  [ -t 1 ] || { echo "rode num terminal para ver os dados"; return 0; }
  echo "$v" | awk -F: '{
    print "CONTA DE REVISÃO DAS LOJAS (Apple App Review e Google Play)";
    print "Guarde no Bitwarden e cole nas notas de revisão de cada loja. Não cole em chat.";
    print "";
    print "CPF:    " $1;
    print "E-mail: " $2;
    print "Código de acesso (sempre o mesmo, não chega por e-mail): " $4;
    print "";
    print "Texto para as notas de revisão:";
    print "  Login: open the app, enter CPF " $1 " and e-mail " $2 ", accept the terms,";
    print "  then type the 6-digit access code " $4 " (it is fixed for this review account;";
    print "  no e-mail is sent). Account deletion: menu > Excluir minha conta. The review";
    print "  account is recreated empty on the next login, so it can be tested repeatedly.";
    print "";
    print "Aperte q para fechar.";
  }' | less -K
  v=""
}

# Aponta o app para a nossa Crystal. Uso: bash bootstrap-vps.sh crystal-nossa sha-XXXXXXX
crystal_nossa() {
  local tag="${2:-}" api t=0
  [ -n "$tag" ] || tag=$(app_tag_atual)
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "informe a tag: bash $0 crystal-nossa sha-XXXXXXX"
  [ -f "$APP_SEG" ] || falha "o app ainda não subiu: bash $0 app-subir $tag"
  if [ -z "$(app_valor "$APP_EXT" OPENROUTER_API_KEY)" ]; then
    echo "Chave do OpenRouter SÓ para a Crystal da VPS (crie uma nova em openrouter.ai > Keys, com limite de crédito)."
    local k; read -rsp "OPENROUTER_API_KEY (não aparece): " k; echo
    echo "$k" | grep -Eq '^sk-or-[A-Za-z0-9_-]{20,}$' || { k=""; falha "não parece uma chave do OpenRouter (sk-or-...)"; }
    app_gravar OPENROUTER_API_KEY "$k"; k=""
    ok "chave do OpenRouter gravada (só a Crystal recebe)"
  fi
  # Os segredos da Crystal têm que existir ANTES de gravar a chave do app: na
  # primeira vez eles nascem aqui (antes, a chave do app ficava vazia e dava 401).
  app_gerar_segredos "$tag"
  [ -n "$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)" ] || falha "CRYSTAL_AGENTE_KEY não foi gerada em $APP_SEG"
  echo "== app apontando para a nossa Crystal"
  app_gravar CRYSTAL_API_URL "http://app_crystal:8080"
  app_gravar CRYSTAL_API_PATH "/v1/messages"
  app_gravar CRYSTAL_API_AUTH_HEADER "authorization"
  app_gravar CRYSTAL_API_REPLY_FIELD "text"
  app_gravar CRYSTAL_API_KEY "$(app_valor "$APP_SEG" CRYSTAL_AGENTE_KEY)"
  app_subir app-subir "$tag"
  echo
  echo "== teste: a API do app pergunta à nossa Crystal"
  while :; do
    api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    [ -n "$api" ] && docker exec "$api" sh -c '[ "$CRYSTAL_API_URL" = "http://app_crystal:8080" ]' 2>/dev/null && break
    [ $t -ge 120 ] && break; sleep 5; t=$((t+5))
  done
  crystal_nossa_teste
}

crystal_nossa_teste() {
  local api; api=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
  [ -n "$api" ] || falha "API do app não está rodando"
  docker exec "$api" node -e '
    const u = process.env.CRYSTAL_API_URL + process.env.CRYSTAL_API_PATH;
    fetch(u, { method: "POST", headers: { authorization: "Bearer " + process.env.CRYSTAL_API_KEY, "content-type": "application/json" },
      body: JSON.stringify({ contact_id: null, conversation_id: "teste-bootstrap", message: { type: "text", text: "Oi, Crystal. Responda só: teste ok." } }) })
      .then(async r => { const t = await r.text(); console.log("  status", r.status, "->", t.slice(0, 160)); process.exit(r.ok ? 0 : 1); })
      .catch(e => { console.log("  falhou:", e.name); process.exit(1); });' \
    && ok "nossa Crystal respondendo. Teste no app: https://app.$DOMINIO" \
    || aviso "não respondeu. Ver: docker service logs --tail 60 ${APP_STACK}_app_crystal"
}

# ------------------------------------------------------------------ vigia do app
# A cada 5 minutos (cron), confere o app e avisa no Telegram (grupo Crystal ·
# Alertas). Só manda de novo o mesmo problema depois de 1 hora e avisa quando
# normaliza. O token do bot fica em $VIGIA_CONF (600), nunca na tela nem no log.
VIGIA_CONF="$BASE/.vigia"
VIGIA_ESTADO="$BASE/.vigia-estado"
VIGIA_LOG="$BASE/vigia.log"

vigia_telegram() { # vigia_telegram TEXTO -> 0 se o Telegram aceitou
  local token chat
  token=$(app_valor "$VIGIA_CONF" TOKEN); chat=$(app_valor "$VIGIA_CONF" CHAT)
  [ -n "$token" ] && [ -n "$chat" ] || return 1
  # URL com o token pela entrada padrão (-K -): fora da linha de comando e do ps.
  printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token" \
    | curl -s -m 20 -K - --data-urlencode "chat_id=$chat" --data-urlencode "text=$1" \
    | grep -q '"ok":true'
}

vigia_config() {
  local token chat limite
  read -rsp "Token do bot do Telegram (Bitwarden, não aparece): " token; echo
  printf '%s' "$token" | grep -Eq '^[0-9]{6,12}:[A-Za-z0-9_-]{30,}$' || falha "token em formato inesperado (123456789:AA...). Nada gravado"
  read -rp "ID do grupo [-1003662546162]: " chat; chat=${chat:--1003662546162}
  printf '%s' "$chat" | grep -Eq '^-?[0-9]{5,20}$' || falha "ID do grupo inválido"
  read -rp "Avisar quando o crédito do OpenRouter ficar abaixo de US$ [5]: " limite; limite=${limite:-5}
  printf '%s' "$limite" | grep -Eq '^[0-9]+$' || falha "limite: só número inteiro"
  mkdir -p "$BASE"; chmod 700 "$BASE"; umask 077
  printf 'TOKEN=%s\nCHAT=%s\nLIMITE=%s\n' "$token" "$chat" "$limite" > "$VIGIA_CONF"; chmod 600 "$VIGIA_CONF"
  token=""
  vigia_telegram "✅ Vigia do app da Crystal ligada na VPS. Confere a cada 5 minutos e avisa aqui se algo cair." \
    || { rm -f "$VIGIA_CONF"; falha "o Telegram recusou (token, ID do grupo ou o bot fora do grupo). Nada gravado"; }
  ok "mensagem de teste enviada ao grupo"
  copia_cron_atualizar --criar
  printf '%s\n' "*/5 * * * * root PATH=/usr/sbin:/usr/bin:/sbin:/bin /usr/bin/bash $BASE/bootstrap-vps.sh vigia >> $VIGIA_LOG 2>&1" \
    > /etc/cron.d/crystal-vigia
  chmod 644 /etc/cron.d/crystal-vigia
  ok "vigia agendada (/etc/cron.d/crystal-vigia, a cada 5 min). Log: $VIGIA_LOG"
}

vigia() {
  [ -s "$VIGIA_CONF" ] || { echo "vigia sem configuração: bash $0 vigia-config"; return 0; }
  local problemas=() u code linha falhas resumo agora anterior quando cid saldo limite r
  agora=$(date +%s)
  for u in "https://app.$DOMINIO/login" "https://api.$DOMINIO/healthz"; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "$u" || true)
    [ "$code" = "200" ] || problemas+=("$u respondeu ${code:-sem resposta}")
  done
  while read -r linha; do
    set -- $linha
    [ "${2%%/*}" = "${2##*/}" ] || problemas+=("serviço $1 com $2 réplicas")
  done < <(docker service ls --filter "name=${APP_STACK}_" --filter "name=${CW_STACK}_" --format '{{.Name}} {{.Replicas}}' 2>/dev/null)
  # O nosso Chatwoot, se estiver no ar.
  if docker service inspect "${CW_STACK}_cw_rails" >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$CW_HOST/api" || true)
    [ "$code" = "200" ] || problemas+=("https://$CW_HOST/api respondeu ${code:-sem resposta}")
  fi
  # Backup (achados 22 a 25): o último completo, falha registrada pelo backup e a
  # cópia no R2, todos com 26 h de folga; e o disco do Docker.
  local h uso
  if [ -f /etc/cron.d/crystal-backup-n8n ]; then
    h=$(horas_desde "$BACKUPS/.backup-ultimo")
    if [ "$h" = nunca ] || [ "$h" -ge 26 ]; then problemas+=("último backup completo na VPS: há ${h} h (ver $BACKUPS/backup.log)"); fi
    [ -s "$BACKUPS/.backup-falhas" ] && problemas+=("último backup com falha: $(paste -sd';' "$BACKUPS/.backup-falhas" | cut -c1-200)")
  fi
  if [ -s "$FORA_CONF" ] || [ -s "$BACKUPS/.fora-ultimo" ]; then
    h=$(horas_desde "$BACKUPS/.fora-ultimo")
    if [ "$h" = nunca ] || [ "$h" -ge 26 ]; then problemas+=("última cópia no R2: há ${h} h"); fi
  fi
  uso=$(df -P /var/lib/docker 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}' || true)
  if printf '%s' "$uso" | grep -Eq '^[0-9]+$' && [ "$uso" -ge 85 ]; then
    problemas+=("disco da VPS em ${uso}% (/var/lib/docker): limpar ou ampliar antes que o banco pare")
  fi
  falhas=$(docker service logs --since 6m "${APP_STACK}_app_api" 2>&1 | grep -E 'crystal: resposta falhou|canal: envio para a inbox falhou|base de alunos: indisponível|transcrição: (falhou|indisponível)|e-mail: envio falhou|risco: aviso à equipe falhou|crystal: forget falhou|mensagem: (geração falhou|erro da resposta não gravado)|uploads: limpeza de órfãos falhou|atendimento: (fila repassada à equipe na saída|não conferiu o acesso)' || true)
  if [ -n "$falhas" ]; then
    resumo=$(printf '%s\n' "$falhas" | grep -oE '"code":"[A-Z_]+"(,"(status|motivo)":("[^"]*"|[0-9]+|null))?' | sort | uniq -c | sort -rn | head -3 | tr -s ' ' | tr '\n' ';' || true)
    problemas+=("$(printf '%s\n' "$falhas" | wc -l) resposta(s) falharam nos últimos 5 min: ${resumo%;}")
  fi
  # Uma vez por hora: a Crystal responde de verdade e o crédito do OpenRouter está ok.
  if [ $((10#$(date +%M))) -lt 5 ]; then
    cid=$(docker ps -q -f name=${APP_STACK}_app_api | head -1)
    # Pelo nosso Chatwoot a API também chama a Crystal (robô): o teste vale nos dois canais.
    if [ -n "$cid" ] && [ -n "$(app_valor "$APP_EXT" CRYSTAL_API_URL)" ]; then
      # Mesmo cabeçalho que a API usa: "authorization" leva Bearer; outro nome (o
      # x-api-key da provisória) leva a chave crua. Antes era Bearer fixo (achado 33).
      r=$(docker exec "$cid" node -e '
        const h = (process.env.CRYSTAL_API_AUTH_HEADER || "authorization").toLowerCase();
        const k = process.env.CRYSTAL_API_KEY || "";
        fetch(process.env.CRYSTAL_API_URL + (process.env.CRYSTAL_API_PATH ?? "/v1/messages"), { method: "POST",
          headers: { [h]: h === "authorization" ? "Bearer " + k : k, "content-type": "application/json" },
          body: JSON.stringify({ contact_id: null, conversation_id: "vigia", message: { type: "text", text: "Responda só: ok" } }),
          signal: AbortSignal.timeout(60000) }).then(r => console.log(r.status)).catch(e => console.log(e.name))' 2>/dev/null || echo erro)
      [ "$r" = "200" ] || problemas+=("teste da nossa Crystal: $r")
    fi
    cid=$(docker ps -q -f name=${APP_STACK}_app_crystal | head -1)
    limite=$(app_valor "$VIGIA_CONF" LIMITE)
    if [ -n "$cid" ] && [ -n "$limite" ]; then
      saldo=$(docker exec "$cid" node -e '
        fetch("https://openrouter.ai/api/v1/credits", { headers: { authorization: "Bearer " + process.env.OPENROUTER_API_KEY },
          signal: AbortSignal.timeout(20000) }).then(r => r.json())
          .then(j => console.log(Math.floor(j.data.total_credits - j.data.total_usage))).catch(() => console.log(""))' 2>/dev/null || true)
      if printf '%s' "$saldo" | grep -Eq '^-?[0-9]+$' && [ "$saldo" -lt "$limite" ]; then
        problemas+=("crédito do OpenRouter em US\$ $saldo (abaixo de $limite): recarregar")
      fi
    fi
  fi

  anterior=$(app_valor "$VIGIA_ESTADO" RESUMO); quando=$(app_valor "$VIGIA_ESTADO" QUANDO)
  if [ ${#problemas[@]} -gt 0 ]; then
    resumo=$(printf '%s | ' "${problemas[@]}"); resumo=${resumo% | }
    # Mesmo problema: repete só depois de 1 hora (as contagens mudam, por isso compara sem números).
    if [ "$(echo "$resumo" | tr -d '0-9')" = "$(echo "$anterior" | tr -d '0-9')" ] && [ $((agora - ${quando:-0})) -lt 3600 ]; then
      return 0
    fi
    echo "$(date -Is) ALERTA $resumo"
    if vigia_telegram "⚠️ App da Crystal: $(printf '\n- %s' "${problemas[@]}")
Na VPS: bash bootstrap-vps.sh crystal-nossa-teste"; then
      umask 077; printf 'RESUMO=%s\nQUANDO=%s\n' "$resumo" "$agora" > "$VIGIA_ESTADO"
    else
      echo "$(date -Is) Telegram recusou o aviso"
    fi
  elif [ -n "$anterior" ]; then
    echo "$(date -Is) normalizado"
    vigia_telegram "✅ App da Crystal normalizado." && rm -f "$VIGIA_ESTADO"
  fi
  # Log pequeno: só as últimas 500 linhas.
  if [ -f "$VIGIA_LOG" ] && [ "$(wc -l < "$VIGIA_LOG")" -gt 1000 ]; then
    tail -500 "$VIGIA_LOG" > "$VIGIA_LOG.tmp" && mv "$VIGIA_LOG.tmp" "$VIGIA_LOG"
  fi
}

# ================================================================== ATENDIMENTO
# O nosso Chatwoot CE (stacks-app/20-atendimento.yaml) em atendimento., no lugar
# do LendChat. A Crystal responde como robô (agent bot) pela API do app
# (/webhooks/chatwoot-bot). Segredos gerados aqui, uma vez só, em $CW_SEG.
# SECRET_KEY_BASE e as três chaves ACTIVE_RECORD_ENCRYPTION_* NUNCA mudam depois
# de o Chatwoot ter dado: sem elas, 2FA e segredos guardados ficam ilegíveis.
CW_DIR="$BASE/atendimento"
CW_SEG="$CW_DIR/.segredos"
CW_YAML=20-atendimento.yaml
CW_STACK=crystal_atendimento
CW_VERSAO=v4.18.0-ce
CW_HOST="atendimento.$DOMINIO"
CW_CONTA="Crystal"
CW_INBOX="App da Crystal"

cw_rails() { # id do contêiner do Rails do Chatwoot
  docker ps -q -f name=${CW_STACK}_cw_rails | head -1
}

# Roda Ruby no Chatwoot (rails runner). O código vai pela entrada padrão; valores,
# pelo ambiente do docker exec (-e NOME, sem valor na linha de comando). O mktemp da
# imagem é o do BusyBox, que só aceita o modelo terminado em XXXXXX: com sufixo .rb ele
# recusava e o atendimento-configurar nunca terminava (achado 6). O rails runner
# carrega o arquivo pelo caminho, sem precisar da extensão.
# Saída útil só nas linhas "CW_OUT NOME=valor".
cw_ruby() { # cw_ruby [NOME_DE_VARIAVEL...] < codigo.rb
  local cid args=() v
  cid=$(cw_rails); [ -n "$cid" ] || falha "o Chatwoot não está rodando: bash $0 atendimento-subir"
  for v in "$@"; do args+=(-e "$v"); done
  docker exec -i "${args[@]}" "$cid" sh -c \
    'f=$(mktemp /tmp/cw.XXXXXX) || exit 1; cat > "$f"; RAILS_LOG_TO_STDOUT= bundle exec rails runner "$f" 2>&1; r=$?; rm -f "$f"; exit $r'
}

cw_gerar_segredos() {
  mkdir -p "$CW_DIR"; chmod 700 "$CW_DIR"
  umask 077
  if [ -f "$CW_SEG" ]; then ok "segredos do atendimento já existem em $CW_SEG (mantidos)"; return 0; fi
  {
    echo "CW_DB_SENHA=$(openssl rand -hex 24)"
    echo "CW_REDIS_SENHA=$(openssl rand -hex 24)"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
    echo "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 16)"
    echo "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 16)"
    echo "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 16)"
    echo "CRIADO_EM=$(date -u +%FT%TZ)"
  } > "$CW_SEG"
  chmod 600 "$CW_SEG"
  ok "segredos do atendimento gerados em $CW_SEG. Copie pro cofre: bash $0 atendimento-segredos"
}

cw_gerar_env() {
  local db redis
  db=$(app_valor "$CW_SEG" CW_DB_SENHA); redis=$(app_valor "$CW_SEG" CW_REDIS_SENHA)
  [ -n "$db" ] && [ -n "$redis" ] || falha "senhas ausentes em $CW_SEG"
  umask 077
  {
    echo "POSTGRES_DB=chatwoot"
    echo "POSTGRES_USER=chatwoot"
    echo "POSTGRES_PASSWORD=$db"
    echo "POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256"
  } > "$CW_DIR/postgres.env"
  echo "REDIS_PASSWORD=$redis" > "$CW_DIR/redis.env"
  {
    echo "# Gerado por bootstrap-vps.sh em $(date -u +%FT%TZ). Não editar: é regravado a cada atendimento-subir."
    echo "FRONTEND_URL=https://$CW_HOST"
    echo "DEFAULT_LOCALE=pt_BR"
    # O Traefik termina o TLS; com FORCE_SSL o Rails redirecionaria em círculo.
    echo "FORCE_SSL=false"
    echo "ENABLE_ACCOUNT_SIGNUP=false"
    echo "POSTGRES_HOST=cw_postgres"
    echo "POSTGRES_PORT=5432"
    echo "POSTGRES_USERNAME=chatwoot"
    echo "POSTGRES_PASSWORD=$db"
    echo "POSTGRES_DATABASE=chatwoot"
    echo "REDIS_URL=redis://cw_redis:6379"
    echo "REDIS_PASSWORD=$redis"
    echo "RAILS_LOG_TO_STDOUT=true"
    echo "LOG_LEVEL=info"
    echo "ACTIVE_STORAGE_SERVICE=local"
    # Nada sai para os servidores do Chatwoot: sem telemetria e sem o relay do app deles.
    echo "DISABLE_TELEMETRY=true"
    echo "ENABLE_PUSH_RELAY_SERVER=false"
    grep -E '^(SECRET_KEY_BASE|ACTIVE_RECORD_ENCRYPTION_[A-Z_]+)=' "$CW_SEG"
    # E-mail (convite de atendente, troca de senha) pelo SMTP do Resend, com o
    # mesmo remetente do app. Sem a chave, o Chatwoot fica sem e-mail.
    local chave remetente
    chave=$(app_valor "$APP_EXT" RESEND_API_KEY); remetente=$(app_valor "$APP_EXT" EMAIL_FROM)
    if [ -n "$chave" ] && [ -n "$remetente" ]; then
      echo "MAILER_SENDER_EMAIL=$remetente"
      echo "SMTP_DOMAIN=$DOMINIO"
      echo "SMTP_ADDRESS=smtp.resend.com"
      echo "SMTP_PORT=587"
      echo "SMTP_USERNAME=resend"
      echo "SMTP_PASSWORD=$chave"
      echo "SMTP_AUTHENTICATION=login"
      echo "SMTP_ENABLE_STARTTLS_AUTO=true"
    fi
  } > "$CW_DIR/chatwoot.env"
  chmod 600 "$CW_DIR/postgres.env" "$CW_DIR/redis.env" "$CW_DIR/chatwoot.env"
  unset db redis
  grep -q '^SMTP_PASSWORD=' "$CW_DIR/chatwoot.env" && ok "e-mail do Chatwoot pelo Resend" \
    || aviso "Chatwoot sem e-mail (falta RESEND_API_KEY/EMAIL_FROM do app): convite de atendente não chega"
}

atendimento_subir() {
  [ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = "true" ] || falha "este nó não é manager do Swarm"
  docker network inspect network_swarm_public >/dev/null 2>&1 || falha "rede network_swarm_public não existe"
  docker service ls --format '{{.Name}}' | grep -q '^traefik_traefik$' || aviso "Traefik não encontrado: sem ele $CW_HOST não responde"
  local ip ips
  ip=$(getent ahostsv4 "$CW_HOST" 2>/dev/null | awk 'NR==1{print $1}' || true)
  [ -n "$ip" ] || falha "$CW_HOST ainda não existe no DNS. Crie no Cloudflare: tipo A, nome atendimento, IP desta VPS, nuvem CINZA (Somente DNS)"
  hostname -I | tr ' ' '\n' | grep -qxF "$ip" \
    || falha "$CW_HOST aponta para $ip, que não é esta VPS. Nuvem LARANJA? Deixe CINZA (Somente DNS): o certificado é emitido aqui"
  ok "$CW_HOST -> $ip"

  echo "== imagem chatwoot/chatwoot:$CW_VERSAO (uns 2 minutos na primeira vez)"
  docker pull -q "chatwoot/chatwoot:$CW_VERSAO" >/dev/null || falha "não baixou chatwoot/chatwoot:$CW_VERSAO"
  ok "imagem baixada"

  echo "== segredos e ambiente"
  cw_gerar_segredos
  cw_gerar_env

  echo "== stack"
  mkdir -p "$ORIG" "$STACKS"; chmod 700 "$BASE" "$STACKS"
  if [ -f "$AQUI/stacks-app/$CW_YAML" ]; then
    cp "$AQUI/stacks-app/$CW_YAML" "$ORIG/$CW_YAML"
  else
    curl -fsSL -m 60 "$APP_RAW/$CW_YAML" -o "$ORIG/$CW_YAML" || falha "não baixou $CW_YAML de $APP_RAW"
  fi
  grep -q '^services:' "$ORIG/$CW_YAML" || falha "$CW_YAML não parece um compose"
  # Console de super admin: só os IPs do painel. Sem lista, só a própria VPS (fechado).
  ips=127.0.0.1/32
  [ -s "$PAINEL_IPS_ARQ" ] && ips=$(paste -sd, "$PAINEL_IPS_ARQ")
  umask 077
  sed -e "s|CW_VERSAO|$CW_VERSAO|g" -e "s|CW_ENV_DIR|$CW_DIR|g" -e "s|CW_IPS_ADMIN|$ips|g" "$ORIG/$CW_YAML" > "$STACKS/$CW_YAML"
  grep -nE 'CW_VERSAO|CW_ENV_DIR|CW_IPS_ADMIN' "$STACKS/$CW_YAML" | grep -vE '^\s*[0-9]+:\s*#' | grep -q . && falha "marcador sobrando em $CW_YAML"
  local t0; t0=$(date +%s)
  docker stack deploy -c "$STACKS/$CW_YAML" "$CW_STACK" --detach=true >/dev/null
  sleep 8
  echo "  na primeira vez o Chatwoot cria o banco inteiro: até 10 minutos"
  esperar_stack "$CW_STACK" 600 || { servico_log_morto "${CW_STACK}_cw_rails"; echo "  Logs: docker service logs --tail 80 ${CW_STACK}_cw_rails"; exit 1; }
  conferir_atualizacao "$t0" "$CW_VERSAO" "${CW_STACK}_cw_rails" "${CW_STACK}_cw_sidekiq" \
    && conferir_atualizacao "$t0" - "${CW_STACK}_cw_postgres" "${CW_STACK}_cw_redis" \
    || falha "o Chatwoot não ficou de pé: o Swarm desfez a troca (log acima)"
  ok "Chatwoot em $CW_VERSAO, sem rollback"
  copia_cron_atualizar
  echo
  atendimento_status
  echo
  if [ -z "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ]; then
    echo "Próximo: bash $0 atendimento-configurar"
  fi
}

atendimento_status() {
  echo "== Serviços do atendimento"
  docker service ls --filter "label=com.docker.stack.namespace=$CW_STACK" --format '{{.Name}} {{.Replicas}} {{.Image}}' \
    | awk '{printf "  %-34s %-5s %s\n",$1,$2,$3}'
  local code t=0
  while :; do
    code=$(curl -s -o /dev/null -m 20 -w '%{http_code}' "https://$CW_HOST/api" 2>/dev/null) || true
    [ "$code" = "200" ] || [ $t -ge 120 ] && break
    sleep 10; t=$((t+10))
  done
  case "${code:-000}" in
    200) ok "https://$CW_HOST/api -> 200 (certificado válido)" ;;
    000) aviso "https://$CW_HOST sem resposta ou certificado inválido (DNS cinza? Traefik ainda emitindo? tente de novo em 2 min)" ;;
    *) aviso "https://$CW_HOST/api -> $code" ;;
  esac
}

atendimento_segredos() {
  [ -f "$CW_SEG" ] || falha "ainda não há segredos: bash $0 atendimento-subir"
  if [ -t 1 ] && command -v less >/dev/null; then
    {
      echo "Segredos do Chatwoot (atendimento.). Copie pro Bitwarden, item 'Chatwoot VPS'."
      echo "SECRET_KEY_BASE e as três ACTIVE_RECORD_ENCRYPTION_* NUNCA podem mudar."
      echo "Aperte q pra fechar: os valores somem da tela e não vão pro histórico."
      echo
      grep -vE '^CRIADO_EM=' "$CW_SEG"
    } | less -K
  else
    echo "rode num terminal para ver os segredos"
  fi
}

# Conta, admin, inbox de API do app e o robô (a Crystal). Idempotente: rodar de
# novo confere e devolve os mesmos valores; a senha do admin só nasce na primeira
# vez (--nova-senha troca). Grava no app os valores do canal e do robô e sobe a API
# com a TAG (a imagem precisa ter a rota /webhooks/chatwoot-bot; sem TAG, a que roda).
# O app continua na nossa Crystal direta até: bash bootstrap-vps.sh app-canal chatwoot
atendimento_configurar() {
  local nova="" tag="" a email nome senha="" saida v
  shift
  for a in "$@"; do
    case "$a" in
      --nova-senha) nova=$a ;;
      sha-[0-9a-f]*|v[0-9]*) tag=$a ;;
      *) falha "uso: bash $0 atendimento-configurar [TAG_DO_APP] [--nova-senha]" ;;
    esac
  done
  [ -n "$tag" ] || tag=$(app_tag_atual)
  echo "$tag" | grep -Eq '^(sha-[0-9a-f]{7}|v[0-9][0-9A-Za-z.-]*)$' || falha "tag do app inválida: $tag"
  [ -n "$(cw_rails)" ] || falha "o Chatwoot não está rodando: bash $0 atendimento-subir"
  [ -f "$APP_SEG" ] || falha "o app ainda não subiu: bash $0 app-subir TAG"
  email=$(app_valor "$CW_SEG" ADMIN_EMAIL)
  if [ -z "$email" ]; then
    read -rp "E-mail do administrador do Chatwoot (você): " email
    echo "$email" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || falha "e-mail inválido"
    read -rp "Nome que aparece para a equipe: " nome
    [ -n "$nome" ] || falha "nome vazio"
  else
    nome=""
    ok "administrador: $email"
  fi
  if [ -z "$(app_valor "$CW_SEG" ADMIN_EMAIL)" ] || [ "$nova" = "--nova-senha" ]; then
    # Maiúscula, minúscula, número e símbolo: o Chatwoot exige os quatro.
    senha=$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(20))+"Aa7!")')
  fi

  echo "== conta, administrador, inbox do app e robô (leva uns 40 s)"
  saida=$(CW_EMAIL="$email" CW_NOME="$nome" CW_SENHA="$senha" CW_CONTA="$CW_CONTA" CW_INBOX="$CW_INBOX" \
    CW_WEBHOOK_APP="https://api.$DOMINIO/webhooks/chatwoot" CW_WEBHOOK_ROBO="https://api.$DOMINIO/webhooks/chatwoot-bot" \
    cw_ruby CW_EMAIL CW_NOME CW_SENHA CW_CONTA CW_INBOX CW_WEBHOOK_APP CW_WEBHOOK_ROBO <<'RUBY'
conta = Account.find_or_create_by!(name: ENV.fetch("CW_CONTA")) { |a| a.locale = "pt_BR" }

user = User.find_or_initialize_by(email: ENV.fetch("CW_EMAIL").downcase)
senha = ENV["CW_SENHA"].to_s
if user.new_record?
  user.name = ENV.fetch("CW_NOME")
  user.type = "SuperAdmin"
  user.confirmed_at = Time.current
end
unless senha.empty?
  user.password = senha
  user.password_confirmation = senha
end
user.save!
AccountUser.find_or_create_by!(account: conta, user: user) { |au| au.role = :administrator }

inbox = conta.inboxes.find_by(name: ENV.fetch("CW_INBOX"))
unless inbox
  canal = Channel::Api.create!(account: conta, webhook_url: ENV.fetch("CW_WEBHOOK_APP"), hmac_mandatory: true)
  inbox = conta.inboxes.create!(name: ENV.fetch("CW_INBOX"), channel: canal)
end
inbox.channel.update!(webhook_url: ENV.fetch("CW_WEBHOOK_APP"), hmac_mandatory: true)

robo = AgentBot.find_or_initialize_by(account_id: conta.id, name: "Crystal")
robo.description = "A Crystal responde pela API do app (webhooks/chatwoot-bot)"
robo.outgoing_url = ENV.fetch("CW_WEBHOOK_ROBO")
robo.save!
ligacao = AgentBotInbox.find_or_initialize_by(inbox_id: inbox.id)
ligacao.agent_bot = robo
ligacao.status = :active
ligacao.save!

canal = inbox.channel.reload
raise "inbox sem segredo de webhook" if canal.secret.blank?
raise "robô sem segredo" if robo.secret.blank?
raise "robô sem token" if robo.access_token&.token.blank?
puts "CW_OUT CHATWOOT_ACCOUNT_ID=#{conta.id}"
puts "CW_OUT CHATWOOT_INBOX_IDENTIFIER=#{canal.identifier}"
puts "CW_OUT CHATWOOT_INBOX_HMAC_TOKEN=#{canal.hmac_token}"
puts "CW_OUT CHATWOOT_WEBHOOK_SECRET=#{canal.secret}"
puts "CW_OUT CHATWOOT_BOT_TOKEN=#{robo.access_token.token}"
puts "CW_OUT CHATWOOT_BOT_SECRET=#{robo.secret}"
puts "CW_OUT OK=1"
RUBY
) || { saida=""; falha "a configuração no Chatwoot falhou. Ver: docker service logs --tail 80 ${CW_STACK}_cw_rails"; }
  printf '%s\n' "$saida" | grep -q '^CW_OUT OK=1$' || { saida=""; falha "o Chatwoot não confirmou a configuração"; }

  # Valores do LendChat guardados uma vez, para consulta (não voltam sozinhos).
  if [ -f "$APP_EXT" ] && [ ! -f "$APP_DIR/.externos.lendchat" ] && grep -q '^CHATWOOT_BASE_URL=' "$APP_EXT" \
     && ! grep -q "^CHATWOOT_BASE_URL=https://$CW_HOST\$" "$APP_EXT"; then
    umask 077; grep -E '^CHATWOOT_' "$APP_EXT" > "$APP_DIR/.externos.lendchat"
    ok "valores antigos do LendChat guardados em $APP_DIR/.externos.lendchat"
  fi
  app_gravar CHATWOOT_BASE_URL "https://$CW_HOST"
  for v in CHATWOOT_ACCOUNT_ID CHATWOOT_INBOX_IDENTIFIER CHATWOOT_INBOX_HMAC_TOKEN CHATWOOT_WEBHOOK_SECRET CHATWOOT_BOT_TOKEN CHATWOOT_BOT_SECRET; do
    app_gravar "$v" "$(printf '%s\n' "$saida" | sed -n "s/^CW_OUT $v=//p" | tail -1)"
  done
  saida=""
  ok "canal e robô gravados no app (sem aparecer na tela)"
  if [ -z "$(app_valor "$CW_SEG" ADMIN_EMAIL)" ]; then
    umask 077; echo "ADMIN_EMAIL=$email" >> "$CW_SEG"
  fi

  if [ -n "$senha" ]; then
    if [ -t 1 ] && command -v less >/dev/null; then
      {
        echo "LOGIN DO CHATWOOT (guarde no Bitwarden, item 'Chatwoot VPS'). Não cole em chat."
        echo
        echo "Endereço: https://$CW_HOST"
        echo "E-mail:   $email"
        echo "Senha:    $senha"
        echo
        echo "No primeiro login: Perfil > Senha e segurança > ligar a verificação em duas etapas (2FA)."
        echo "Aperte q para fechar."
      } | less -K
    else
      aviso "rode num terminal para ver a senha (ou: bash $0 atendimento-configurar --nova-senha)"
    fi
    senha=""
  fi

  echo "== API do app ($tag) com o robô ligado"
  app_subir app-subir "$tag"
  echo
  atendimento_teste
}

# Teste de ponta a ponta sem passar pelo app: um contato de teste escreve na inbox
# do app e a Crystal tem que responder como robô em até 90 s.
atendimento_teste() {
  [ -n "$(app_valor "$APP_EXT" CHATWOOT_INBOX_IDENTIFIER)" ] || falha "ainda não configurado: bash $0 atendimento-configurar"
  echo "== teste: mensagem na inbox do app, a Crystal responde como robô"
  python3 - "$APP_EXT" "$CW_HOST" <<'PY' && ok "a Crystal respondeu pelo Chatwoot" \
    || { aviso "não respondeu. Ver: docker service logs --since 5m ${APP_STACK}_app_api | grep -i chatwoot"; return 1; }
import hashlib, hmac, json, sys, time, urllib.request
conf = dict(l.rstrip("\n").split("=", 1) for l in open(sys.argv[1]) if "=" in l)
base = f"https://{sys.argv[2]}/public/api/v1/inboxes/{conf['CHATWOOT_INBOX_IDENTIFIER']}"
def chamar(metodo, caminho, corpo=None):
    req = urllib.request.Request(base + caminho, method=metodo, headers={"content-type": "application/json", "accept": "application/json"},
                                 data=None if corpo is None else json.dumps(corpo).encode())
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read() or b"null")
ident = "teste-atendimento"
hash_ = hmac.new(conf["CHATWOOT_INBOX_HMAC_TOKEN"].encode(), ident.encode(), hashlib.sha256).hexdigest()
contato = chamar("POST", "/contacts", {"identifier": ident, "identifier_hash": hash_, "name": "Teste do bootstrap (ignorar)"})
src = contato["source_id"]
conversa = chamar("POST", f"/contacts/{src}/conversations", {})
cid = conversa["id"]
chamar("POST", f"/contacts/{src}/conversations/{cid}/messages", {"content": "Oi, Crystal. Responda só: teste ok."})
fim = time.time() + 90
while time.time() < fim:
    time.sleep(5)
    msgs = chamar("GET", f"/contacts/{src}/conversations/{cid}/messages")
    saida = [m for m in (msgs or []) if m.get("message_type") in (1, "outgoing")]
    if saida:
        print("  resposta:", (saida[-1].get("content") or "")[:160].replace("\n", " "))
        sys.exit(0)
print("  sem resposta em 90 s")
sys.exit(1)
PY
}

# Por onde o app conversa: crystal (a nossa Crystal direto, sem Chatwoot) ou
# chatwoot (pelo nosso Chatwoot, com a equipe vendo e podendo assumir). Volta é
# o mesmo comando com o outro valor.
app_canal() {
  local canal="${2:-}" pg
  case "$canal" in
    crystal) ;;
    chatwoot)
      [ -n "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ] || falha "o nosso Chatwoot ainda não está configurado: bash $0 atendimento-configurar"
      [ "$(app_valor "$APP_EXT" CHATWOOT_BASE_URL)" = "https://$CW_HOST" ] || falha "CHATWOOT_BASE_URL não é o nosso Chatwoot: bash $0 atendimento-configurar" ;;
    *) falha "uso: bash $0 app-canal chatwoot   (ou crystal para voltar)" ;;
  esac
  app_gravar CHAT_TRANSPORT "$canal"
  if [ "$canal" = "chatwoot" ]; then
    # Vínculos antigos apontam para contatos do LendChat: o app refaz no nosso.
    pg=$(docker ps -q -f name=${APP_STACK}_app_postgres | head -1)
    [ -n "$pg" ] && docker exec -i "$pg" psql -q -U crystal -d crystal_web_chat \
      -c "update conversations set channel_source_id = null, channel_conversation_id = null where channel_source_id is not null" >/dev/null \
      && ok "vínculos antigos com a inbox desfeitos"
  fi
  app_subir app-subir "$(app_tag_atual)"
  echo
  ok "app conversando por: $canal. Teste no app: https://app.$DOMINIO"
  [ "$canal" = "chatwoot" ] && echo "  A conversa aparece em https://$CW_HOST (Conversas > Pendentes)."
  return 0
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

app_tag_atual() { # vazio quando a API não existe; nunca derruba o script (achado 32)
  { docker service inspect ${APP_STACK}_app_api --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null || true; } \
    | sed -E 's/@sha256:.*//; s/.*://'
}

n8n_reiniciar() {
  local s t0
  for s in n8n_editor_n8n_editor n8n_webhook_n8n_webhook n8n_worker_n8n_worker; do
    docker service inspect "$s" >/dev/null 2>&1 || continue
    echo "  reiniciando $s (até 2 min)"
    t0=$(date +%s)
    docker service update --force --detach=false "$s" >/dev/null 2>&1 || aviso "$s não confirmou a reinicialização; conferir com: docker service ls"
    conferir_atualizacao "$t0" - "$s" || falha "$s não voltou depois de reiniciar (log acima)"
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
  local redis_senha
  redis_senha=$(app_valor "$SEGREDOS" N8N_REDIS_SENHA)
  [ -n "$redis_senha" ] || falha "N8N_REDIS_SENHA ausente em $SEGREDOS: rode 'preparar' (e redeploy de 03 a 06) antes"

  echo "== credenciais no n8n (webhook, OpenRouter, Redis banco 2)"
  CHAVE="$chave" ORKEY="$orkey" REDIS_SENHA="$redis_senha" python3 - <<'PY' | docker exec -i "$cid" sh -c 'umask 077; cat > /tmp/crystal-cred.json'
import json, os
print(json.dumps([
  {"id": "crystalProvKey01", "name": "Crystal provisória · chave do app", "type": "httpHeaderAuth",
   "data": {"name": "x-api-key", "value": os.environ["CHAVE"]}},
  {"id": "crystalProvORkey", "name": "OpenRouter · Crystal provisória", "type": "httpHeaderAuth",
   "data": {"name": "Authorization", "value": "Bearer " + os.environ["ORKEY"]}},
  {"id": "crystalProvRedis", "name": "Redis do n8n · banco 2 (Crystal provisória)", "type": "redis",
   "data": {"host": "n8n_redis", "port": 6379, "database": 2, "password": os.environ["REDIS_SENHA"]}},
]))
PY
  unset orkey redis_senha
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
  # Sem CRYSTAL_API_* a API com o robô do Chatwoot não sobe (achado 33).
  [ -z "$(app_valor "$APP_EXT" CHATWOOT_BOT_TOKEN)" ] \
    || falha "o robô do Chatwoot usa a Crystal pela CRYSTAL_API_*: desligar a provisória derrubaria a API. Para sair da provisória: bash $0 crystal-nossa $tag"
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
    falha "rode num terminal: os segredos abrem no less e não ficam em log nem no histórico"
  fi
}

case "$CMD" in
  app-ghcr) app_ghcr ;;
  app-definir) app_definir "$@" ;;
  app-remover) app_remover "$@" ;;
  app-resend) app_resend ;;
  app-subir) app_subir "$@"; [ "${SUPABASE_FALHOU:-0}" = 0 ] || exit 1 ;;
  app-supabase-teste) app_supabase_teste ;;
  app-status) app_status ;;
  app-admin) app_admin ;;
  vigia-config) vigia_config ;;
  atendimento-subir) atendimento_subir ;;
  atendimento-status) atendimento_status ;;
  atendimento-configurar) atendimento_configurar "$@" ;;
  atendimento-teste) atendimento_teste ;;
  atendimento-segredos) atendimento_segredos ;;
  app-canal) app_canal "$@" ;;
  vigia) vigia ;;
  app-aluno) app_aluno ;;
  app-segredos) app_segredos ;;
  app-recomecar) app_recomecar "$@" ;;
  crystal-nossa) crystal_nossa "$@" ;;
  app-revisao) app_revisao "$@" ;;
  app-telefone) app_telefone "$@" ;;
  crystal-nossa-teste) crystal_nossa_teste ;;
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
