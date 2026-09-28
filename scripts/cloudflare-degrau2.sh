#!/usr/bin/env bash
# Degrau 2 da virada do crystalnowpp.com.br: Cloudflare na frente da AZAN.
#
# Uso: scripts/cloudflare-degrau2.sh <comando> [--aplicar]
#
# Sem --aplicar, NADA é gravado: o script lê o estado atual e imprime o que
# faria (método, caminho e corpo de cada chamada). Com --aplicar, antes de cada
# gravação ele salva o estado anterior em auditorias/<data>/cloudflare/ e relê
# depois de gravar.
#
# Comandos, na ordem do plano:
#   foto            só leitura: salva DNS, settings, regras, certificados
#   preparar        settings que só agem com a nuvem laranja (SSL, scripts,
#                   headers, bots). Seguro com tudo cinza
#   cert            só leitura: confere o Universal SSL ativo (apex e *.)
#   laranja         @ A, @ AAAA e www em proxied=true e tira o +a do SPF.
#                   SÓ NA JANELA COMBINADA (02:00-05:00 BRT)
#   validar         só leitura: matriz HTTP pela borda, TTFB, POP, server.
#   https           liga Always Use HTTPS (depois do laranja validado)
#   regras          bloqueia /xmlrpc.php, freia /wp-login.php e reescreve
#                   /crystal-teste -> /crystal-teste/ (sem redirect)
#   cinza           ROLLBACK: @ A, @ AAAA e www de volta pra proxied=false
#   desfazer-regras apaga só as regras criadas por este script
#
# Precisa de CLOUDFLARE_API_TOKEN no ambiente (token da zona), curl e jq.
#
# Regras que o script respeita:
#   - server., mail. e ftp. ficam SEMPRE cinza. Depois de toda gravação de DNS
#     o script relê os três e força proxied=false se algum virou laranja.
#   - URL que responde 301 nunca recebe fbclid/utm/gclid (cache envenenado de
#     11/09). O validar só manda query de teste pra /crystal-teste, que dá 200.

set -uo pipefail

ZONA_ID=c8f015c8ed7347f8900aa90d6701a15c
DOMINIO=crystalnowpp.com.br
IP_STAPE=35.199.71.234
API=https://api.cloudflare.com/client/v4
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CMD="${1:-}"
APLICAR=0
[ "${2:-}" = "--aplicar" ] && APLICAR=1

if [ -z "$CMD" ]; then
  sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

BACKUP="$RAIZ/auditorias/$(TZ=America/Sao_Paulo date +%F)/cloudflare/$(TZ=America/Sao_Paulo date +%H%M%S)-$CMD"

falha() { echo "ERRO: $*" >&2; exit 2; }
aviso() { echo "  ! $*"; }
ok() { echo "  ok $*"; }

precisa_token() {
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || falha "CLOUDFLARE_API_TOKEN não está no ambiente"
}

# api MÉTODO CAMINHO [CORPO] -> JSON da resposta no stdout
api() {
  local m=$1 p=$2 b=${3:-}
  if [ -n "$b" ]; then
    curl -sS -m 40 -X "$m" "$API$p" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H 'Content-Type: application/json' --data "$b"
  else
    curl -sS -m 40 -X "$m" "$API$p" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
  fi
}

# ler CAMINHO -> .result, ou falha com a mensagem da API
ler() {
  local r; r=$(api GET "$1")
  if [ "$(echo "$r" | jq -r '.success')" != "true" ]; then
    falha "GET $1: $(echo "$r" | jq -c '.errors')"
  fi
  echo "$r" | jq '.result'
}

salvar() { # salvar NOME JSON
  mkdir -p "$BACKUP"
  printf '%s\n' "$2" > "$BACKUP/$1.json"
}

# gravar MÉTODO CAMINHO CORPO DESCRIÇÃO
gravar() {
  local m=$1 p=$2 b=$3 d=$4
  if [ "$APLICAR" -ne 1 ]; then
    echo "  [simulação] $d"
    echo "              $m $p $(echo "$b" | jq -c .)"
    return 0
  fi
  local r; r=$(api "$m" "$p" "$b")
  if [ "$(echo "$r" | jq -r '.success')" = "true" ]; then
    ok "$d"
  else
    falha "$d: $(echo "$r" | jq -c '.errors')"
  fi
}

# ------------------------------------------------------------------ settings
setting() { # setting NOME VALOR_DESEJADO   (valor em JSON: "off", 1.2 vira "1.2")
  local nome=$1 desejado=$2 atual
  atual=$(ler "/zones/$ZONA_ID/settings/$nome")
  salvar "setting_$nome" "$atual"
  local v; v=$(echo "$atual" | jq -c '.value')
  if [ "$v" = "$desejado" ]; then
    ok "$nome já está $v"
    return 0
  fi
  gravar PATCH "/zones/$ZONA_ID/settings/$nome" "{\"value\":$desejado}" "$nome: $v -> $desejado"
  if [ "$APLICAR" -eq 1 ]; then
    local depois; depois=$(ler "/zones/$ZONA_ID/settings/$nome" | jq -c '.value')
    [ "$depois" = "$desejado" ] || falha "$nome releu $depois, esperado $desejado"
  fi
}

# ------------------------------------------------------------------ DNS
registros() { ler "/zones/$ZONA_ID/dns_records?per_page=100"; }

registro_id() { # registro_id JSON TIPO NOME
  echo "$1" | jq -r --arg t "$2" --arg n "$3" '.[] | select(.type==$t and .name==$n) | .id' | head -1
}

garantir_cinza() {
  # server. (Stape), mail. e ftp. nunca podem ficar laranja.
  local regs; regs=$(registros)
  local problemas; problemas=$(echo "$regs" | jq -c --arg d "$DOMINIO" \
    '[.[] | select((.name=="server."+$d or .name=="mail."+$d or .name=="ftp."+$d) and .proxied==true) | {id,type,name}]')
  if [ "$problemas" = "[]" ]; then
    ok "server., mail. e ftp. seguem cinza"
    return 0
  fi
  aviso "laranja onde não pode: $problemas"
  echo "$problemas" | jq -r '.[].id' | while read -r id; do
    gravar PATCH "/zones/$ZONA_ID/dns_records/$id" '{"proxied":false}' "força cinza no registro $id"
  done
}

proxied() { # proxied true|false
  local alvo=$1 regs
  regs=$(registros)
  salvar dns_records "$regs"
  local a aaaa www
  a=$(registro_id "$regs" A "$DOMINIO")
  aaaa=$(registro_id "$regs" AAAA "$DOMINIO")
  www=$(registro_id "$regs" CNAME "www.$DOMINIO")
  [ -n "$a" ] || falha "não achei o A do apex"
  [ -n "$www" ] || falha "não achei o CNAME do www"
  for par in "A:$a" "AAAA:$aaaa" "www:$www"; do
    local nome=${par%%:*} id=${par#*:}
    [ -n "$id" ] || { aviso "$nome não existe, pulando"; continue; }
    local atual; atual=$(echo "$regs" | jq -r --arg i "$id" '.[] | select(.id==$i) | .proxied')
    if [ "$atual" = "$alvo" ]; then
      ok "$nome já está proxied=$alvo"
    else
      gravar PATCH "/zones/$ZONA_ID/dns_records/$id" "{\"proxied\":$alvo}" "$nome proxied $atual -> $alvo"
    fi
  done
  [ "$APLICAR" -eq 1 ] && garantir_cinza
}

tirar_a_do_spf() {
  local regs spf id conteudo novo
  regs=$(registros)
  spf=$(echo "$regs" | jq -c --arg d "$DOMINIO" '[.[] | select(.type=="TXT" and .name==$d and (.content|test("v=spf1")))][0]')
  [ "$spf" != "null" ] || { aviso "SPF não encontrado no apex"; return 0; }
  id=$(echo "$spf" | jq -r '.id')
  conteudo=$(echo "$spf" | jq -r '.content')
  # Com o apex laranja, +a passa a apontar pros IPs do Cloudflare. O ip4 da
  # AZAN e o include já cobrem o envio.
  novo=$(echo "$conteudo" | sed -E 's/ \+a / /; s/"//g')
  if [ "$novo" = "$(echo "$conteudo" | sed 's/"//g')" ]; then
    ok "SPF já está sem +a"
    return 0
  fi
  gravar PATCH "/zones/$ZONA_ID/dns_records/$id" "$(jq -nc --arg c "\"$novo\"" '{content:$c}')" "SPF: tira o +a ($novo)"
}

# ------------------------------------------------------------------ regras
REF_XMLRPC=crystal_bloqueia_xmlrpc
REF_LOGIN=crystal_freio_wp_login
REF_REWRITE=crystal_teste_sem_barra

# regra_na_fase FASE REF REGRA_JSON : junta a regra no entrypoint, por ref
regra_na_fase() {
  local fase=$1 ref=$2 regra=$3 r atual regras novo
  r=$(api GET "/zones/$ZONA_ID/rulesets/phases/$fase/entrypoint")
  if [ "$(echo "$r" | jq -r '.success')" = "true" ]; then
    atual=$(echo "$r" | jq '.result')
    regras=$(echo "$atual" | jq '[.rules[]? | {ref,expression,action,action_parameters,description,enabled,ratelimit} | with_entries(select(.value!=null))]')
  else
    atual='null'; regras='[]'
  fi
  salvar "ruleset_$fase" "$atual"
  if echo "$regras" | jq -e --arg ref "$ref" 'any(.[]; .ref==$ref)' >/dev/null; then
    ok "regra $ref já existe em $fase"
    return 0
  fi
  local outras; outras=$(echo "$regras" | jq 'length')
  [ "$outras" -gt 0 ] && aviso "$fase já tem $outras regra(s) de outra origem; elas são mantidas"
  novo=$(echo "$regras" | jq --argjson n "$regra" '. + [$n] | {rules: .}')
  gravar PUT "/zones/$ZONA_ID/rulesets/phases/$fase/entrypoint" "$novo" "cria $ref em $fase"
}

tirar_regra() { # tirar_regra FASE REF
  local fase=$1 ref=$2 r regras novo
  r=$(api GET "/zones/$ZONA_ID/rulesets/phases/$fase/entrypoint")
  [ "$(echo "$r" | jq -r '.success')" = "true" ] || { ok "$fase sem regras"; return 0; }
  salvar "ruleset_$fase" "$(echo "$r" | jq '.result')"
  regras=$(echo "$r" | jq '[.result.rules[]? | {ref,expression,action,action_parameters,description,enabled,ratelimit} | with_entries(select(.value!=null))]')
  if ! echo "$regras" | jq -e --arg ref "$ref" 'any(.[]; .ref==$ref)' >/dev/null; then
    ok "$ref não existe em $fase"
    return 0
  fi
  novo=$(echo "$regras" | jq --arg ref "$ref" '[.[] | select(.ref!=$ref)] | {rules: .}')
  gravar PUT "/zones/$ZONA_ID/rulesets/phases/$fase/entrypoint" "$novo" "apaga $ref de $fase"
}

# ------------------------------------------------------------------ comandos
cmd_foto() {
  precisa_token
  local d="$BACKUP"
  mkdir -p "$d"
  api GET "/zones/$ZONA_ID" > "$d/zona.json"
  api GET "/zones/$ZONA_ID/dns_records?per_page=100" > "$d/dns_records.json"
  api GET "/zones/$ZONA_ID/settings" > "$d/settings.json"
  api GET "/zones/$ZONA_ID/ssl/certificate_packs?status=all" > "$d/certificate_packs.json"
  api GET "/zones/$ZONA_ID/managed_headers" > "$d/managed_headers.json"
  api GET "/zones/$ZONA_ID/bot_management" > "$d/bot_management.json"
  api GET "/zones/$ZONA_ID/pagerules" > "$d/pagerules.json"
  api GET "/zones/$ZONA_ID/rulesets" > "$d/rulesets.json"
  for fase in http_request_firewall_custom http_ratelimit http_request_transform \
              http_response_headers_transform http_request_cache_settings \
              http_config_settings http_request_dynamic_redirect http_request_origin; do
    api GET "/zones/$ZONA_ID/rulesets/phases/$fase/entrypoint" > "$d/ruleset_$fase.json"
  done
  echo "foto em $d"
  for f in "$d"/*.json; do
    printf '  %-45s %s\n' "$(basename "$f")" "$(jq -c '[.success, ([.errors[]?.code]|join(","))]' "$f" 2>/dev/null)"
  done
  echo "DNS:"
  jq -r '.result[]? | "  \(.type)\t\(.name)\t\(.content[0:60])\tproxied=\(.proxied)"' "$d/dns_records.json"
}

cmd_preparar() {
  precisa_token
  echo "Settings (só agem com a nuvem laranja):"
  # ssl_automatic_mode primeiro: em "auto" o Cloudflare escolhe o modo sozinho.
  setting ssl_automatic_mode '"custom"'
  setting ssl '"strict"'
  setting min_tls_version '"1.2"'
  setting tls_1_3 '"on"'
  setting rocket_loader '"off"'
  setting email_obfuscation '"off"'
  setting early_hints '"off"'
  setting fonts '"off"'
  setting speed_brain '"off"'
  setting hotlink_protection '"off"'
  setting sort_query_string_for_cache '"off"'
  setting always_use_https '"off"'

  echo "HSTS:"
  local hsts; hsts=$(ler "/zones/$ZONA_ID/settings/security_header" | jq -c '.value.strict_transport_security.enabled')
  [ "$hsts" = "false" ] && ok "HSTS desligado" || aviso "HSTS está $hsts: desligar antes do laranja"

  echo "Security level:"
  local nivel; nivel=$(ler "/zones/$ZONA_ID/settings/security_level" | jq -r '.value')
  [ "$nivel" = "under_attack" ] && setting security_level '"medium"' || ok "security_level=$nivel (sem Under Attack)"

  echo "Managed headers (Add security headers manda referrer-policy: same-origin):"
  local mh; mh=$(ler "/zones/$ZONA_ID/managed_headers")
  salvar managed_headers "$mh"
  if echo "$mh" | jq -e '.managed_response_headers[]? | select(.id=="add_security_headers" and .enabled==true)' >/dev/null; then
    gravar PATCH "/zones/$ZONA_ID/managed_headers" \
      '{"managed_request_headers":[],"managed_response_headers":[{"id":"add_security_headers","enabled":false}]}' \
      "desliga add_security_headers"
  else
    ok "add_security_headers desligado"
  fi

  echo "Bots (Bot Fight Mode, bloqueio de IA e AI Labyrinth desligados):"
  local bm alvo; bm=$(ler "/zones/$ZONA_ID/bot_management")
  salvar bot_management "$bm"
  alvo=$(echo "$bm" | jq '
    (if has("fight_mode") then .fight_mode=false else . end)
    | (if has("ai_bots_protection") then .ai_bots_protection="disabled" else . end)
    | (if has("crawler_protection") then .crawler_protection="disabled" else . end)')
  if [ "$(echo "$bm" | jq -S -c .)" = "$(echo "$alvo" | jq -S -c .)" ]; then
    ok "bots já sem desafio: $(echo "$bm" | jq -c '{fight_mode,ai_bots_protection,crawler_protection}')"
  else
    gravar PUT "/zones/$ZONA_ID/bot_management" \
      "$(echo "$alvo" | jq -c 'with_entries(select(.key|IN("enable_js","fight_mode","ai_bots_protection","crawler_protection","is_robots_txt_managed")))')" \
      "bots: $(echo "$bm" | jq -c '{fight_mode,ai_bots_protection,crawler_protection}') -> desligados"
  fi

  echo "Conferências (só leitura):"
  local pr; pr=$(api GET "/zones/$ZONA_ID/pagerules" | jq -c '[.result[]? | select(.status=="active") | .targets[].constraint.value]')
  [ "$pr" = "[]" ] || [ "$pr" = "null" ] && ok "nenhuma Page Rule ativa" || aviso "Page Rules ativas: $pr"
  local cr; cr=$(api GET "/zones/$ZONA_ID/rulesets/phases/http_request_cache_settings/entrypoint" \
    | jq -c '[.result.rules[]? | select(.action_parameters.cache==true) | .expression]')
  [ "$cr" = "[]" ] && ok "nenhuma Cache Rule marcando HTML como cacheável" || aviso "Cache Rules com cache ligado: $cr"
  garantir_cinza
}

cmd_cert() {
  precisa_token
  local packs; packs=$(ler "/zones/$ZONA_ID/ssl/certificate_packs?status=all")
  salvar certificate_packs "$packs"
  echo "$packs" | jq -r '.[] | "  \(.type)\t\(.status)\t\(.hosts|join(","))"'
  if echo "$packs" | jq -e --arg d "$DOMINIO" \
      'any(.[]; .status=="active" and (.hosts|index($d)) and (.hosts|index("*."+$d)))' >/dev/null; then
    ok "certificado de borda ativo cobrindo $DOMINIO e *.$DOMINIO"
  else
    falha "sem certificado de borda ativo cobrindo apex e wildcard: não ligar o laranja"
  fi
}

cmd_laranja() {
  precisa_token
  local h; h=$(TZ=America/Sao_Paulo date +%H)
  if [ "$APLICAR" -eq 1 ] && { [ "$h" -lt 2 ] || [ "$h" -ge 5 ]; } && [ "${FORA_DA_JANELA:-}" != "sim" ]; then
    falha "fora da janela 02:00-05:00 BRT (agora ${h}h). Para forçar: FORA_DA_JANELA=sim"
  fi
  cmd_cert
  echo "Laranja em @ A, @ AAAA e www:"
  proxied true
  echo "SPF:"
  tirar_a_do_spf
  [ "$APLICAR" -eq 1 ] && echo "Rollback em segundos: scripts/cloudflare-degrau2.sh cinza --aplicar"
}

cmd_cinza() {
  precisa_token
  echo "ROLLBACK: @ A, @ AAAA e www de volta pra cinza"
  proxied false
}

cmd_https() {
  precisa_token
  setting always_use_https '"on"'
}

cmd_regras() {
  precisa_token
  regra_na_fase http_request_firewall_custom "$REF_XMLRPC" \
    '{"ref":"crystal_bloqueia_xmlrpc","description":"Bloqueia xmlrpc (o WAF da AZAN fazia isso)","expression":"(http.request.uri.path eq \"/xmlrpc.php\")","action":"block"}'
  regra_na_fase http_ratelimit "$REF_LOGIN" \
    '{"ref":"crystal_freio_wp_login","description":"Freio de força bruta no wp-login","expression":"(http.request.uri.path eq \"/wp-login.php\")","action":"block","ratelimit":{"characteristics":["cf.colo.id","ip.src"],"period":10,"requests_per_period":10,"mitigation_timeout":10}}'
  regra_na_fase http_request_transform "$REF_REWRITE" \
    '{"ref":"crystal_teste_sem_barra","description":"/crystal-teste sem barra vira /crystal-teste/ na borda (rewrite, sem redirect; a query não é tocada)","expression":"(http.request.uri.path eq \"/crystal-teste\")","action":"rewrite","action_parameters":{"uri":{"path":{"value":"/crystal-teste/"}}}}'
}

cmd_desfazer_regras() {
  precisa_token
  tirar_regra http_request_firewall_custom "$REF_XMLRPC"
  tirar_regra http_ratelimit "$REF_LOGIN"
  tirar_regra http_request_transform "$REF_REWRITE"
}

cmd_validar() {
  # Só GET. Tem que rodar de uma máquina SEM proxy que retermine TLS.
  local UA='Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 341.0'
  local fb='facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)'
  local erros=0
  echo "server. (Stape) tem que resolver direto, sem Cloudflare:"
  local ip; ip=$(curl -sS -m 20 -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=server.$DOMINIO&type=A" | jq -r '.Answer[0].data')
  if [ "$ip" = "$IP_STAPE" ]; then ok "server. = $ip"; else aviso "server. = $ip (esperado $IP_STAPE): VOLTAR PRA CINZA"; erros=$((erros+1)); fi
  local hz; hz=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "https://server.$DOMINIO/healthz")
  [ "$hz" = "200" ] && ok "server./healthz 200" || { aviso "server./healthz $hz"; erros=$((erros+1)); }

  echo "Matriz pela borda:"
  printf '  %-58s %-4s %-11s %-8s %-6s %s\n' URL COD SERVIDOR CF-RAY REFPOL LOCATION
  for u in "/" "/crystal-teste/" "/crystal-teste?fbclid=VALIDA&utm_content=VALIDA" \
           "/crystal-promocional-r-r/" "/crystal-promocional-r-wpp/" \
           "/crystal-247-promocional-r-r/" "/crystal-247-promocional-r-wpp/" \
           "/rmkt-v1/" "/crystal-v6-teste/" "/crystal-ttk/"; do
    local cab; cab=$(mktemp)
    local st; st=$(curl -sS -m 30 -A "$UA" -o /dev/null -D "$cab" -w '%{http_code}' "https://$DOMINIO$u")
    local srv ray ref loc
    srv=$(grep -i '^server:' "$cab" | tr -d '\r' | awk '{print $2}')
    ray=$(grep -i '^cf-ray:' "$cab" | tr -d '\r' | awk '{print $2}' | sed 's/.*-//')
    ref=$(grep -ci '^referrer-policy:' "$cab")
    loc=$(grep -i '^location:' "$cab" | tr -d '\r' | sed 's/^[Ll]ocation: *//')
    printf '  %-58s %-4s %-11s %-8s %-6s %s\n' "$u" "$st" "${srv:--}" "${ray:--}" "$ref" "${loc:--}"
    [ "$st" = "200" ] || erros=$((erros+1))
    [ "$ref" = "0" ] || erros=$((erros+1))
    rm -f "$cab"
  done

  echo "Crawler da Meta:"
  local fbst; fbst=$(curl -sS -m 30 -A "$fb" -o /dev/null -w '%{http_code}' "https://$DOMINIO/crystal-teste/")
  [ "$fbst" = "200" ] && ok "facebookexternalhit 200" || { aviso "facebookexternalhit $fbst"; erros=$((erros+1)); }

  echo "www e http:"
  curl -sS -m 30 -o /dev/null -D - "https://www.$DOMINIO/" | tr -d '\r' | grep -iE '^(HTTP/|location:)' | sed 's/^/  /'
  curl -sS -m 30 -o /dev/null -D - "http://$DOMINIO/crystal-teste/?fbclid=VALIDA&utm_content=VALIDA" | tr -d '\r' | grep -iE '^(HTTP/|location:)' | sed 's/^/  /'

  echo "xmlrpc (403 da borda depois do comando regras):"
  curl -sS -m 30 -o /dev/null -D - "https://$DOMINIO/xmlrpc.php" | tr -d '\r' | grep -iE '^(HTTP/|server:)' | sed 's/^/  /'

  echo "TTFB e POP (base da AZAN direta: 0,104 a 0,172 s):"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    curl -sS -m 30 -A "$UA" -o /dev/null -D /tmp/.cab.$$ -w '%{time_starttransfer}\n' "https://$DOMINIO/crystal-teste/" \
      | tr '\n' ' '
    grep -i '^cf-ray:' /tmp/.cab.$$ | tr -d '\r' | sed 's/.*-//'
  done | sed 's/^/  /'
  rm -f /tmp/.cab.$$
  echo "POP fora do Brasil (GRU, GIG, FOR, POA, CNF, CWB...) ou TTFB acima do dobro da base = voltar pra cinza"

  echo
  [ "$erros" -eq 0 ] && echo "validar: sem erro" || echo "validar: $erros problema(s)"
  return "$erros"
}

case "$CMD" in
  foto) cmd_foto ;;
  preparar) cmd_preparar ;;
  cert) cmd_cert ;;
  laranja) cmd_laranja ;;
  cinza) cmd_cinza ;;
  https) cmd_https ;;
  regras) cmd_regras ;;
  desfazer-regras) cmd_desfazer_regras ;;
  validar) cmd_validar ;;
  *) falha "comando desconhecido: $CMD" ;;
esac

if [ "$APLICAR" -ne 1 ] && [ "$CMD" != "foto" ] && [ "$CMD" != "cert" ] && [ "$CMD" != "validar" ]; then
  echo
  echo "Simulação: nada foi gravado. Rode de novo com --aplicar para gravar."
fi
