#!/usr/bin/env bash
# DNS da VPS da Crystal (o app, não o site): painel, editor, webhook, app e api.
#
# Uso: scripts/cloudflare-crystal-vps-dns.sh <comando> [--aplicar]
#
# Comandos:
#   conferir   só leitura, SEM token: resolve os cinco nomes por DNS-over-HTTPS
#              e confere se apontam pro IP da VPS. Sai 0 = todos certos,
#              1 = falta ou divergência
#   criar      cria os registros A que faltarem, cinza (proxied=false), TTL 300. Sem
#              --aplicar só imprime o que faria. Idempotente: registro que já
#              existe com o mesmo IP e cinza é deixado como está; com IP
#              diferente ou laranja é corrigido
#
# Precisa de CLOUDFLARE_API_TOKEN (com DNS Edit na zona) pro criar; curl e jq.
#
# Por que cinza: os arquivos da agência (stacks-exemplo/00-traefik.yaml) emitem
# o certificado por desafio HTTP direto na VPS. Com a nuvem laranja o Let's
# Encrypt bate no Cloudflare, não na VPS, e a emissão falha. Depois de tudo no
# ar dá pra reavaliar (Full strict com Origin CA), nunca antes.
#
# Regra que não muda: server. (Stape), mail. e ftp. ficam sempre cinza. Depois
# de gravar, o script relê server., mail. e ftp. e força proxied=false se algum virou laranja.

set -uo pipefail

ZONA_ID=c8f015c8ed7347f8900aa90d6701a15c
DOMINIO=crystalnowpp.com.br
IP_VPS="${IP_VPS:-177.7.61.136}"
NOMES=(painel editor webhook app api)
API=https://api.cloudflare.com/client/v4
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CMD="${1:-}"
APLICAR=0
[ "${2:-}" = "--aplicar" ] && APLICAR=1

if [ -z "$CMD" ]; then
  sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

BACKUP="$RAIZ/auditorias/$(TZ=America/Sao_Paulo date +%F)/cloudflare/$(TZ=America/Sao_Paulo date +%H%M%S)-vps-$CMD"

falha() { echo "ERRO: $*" >&2; exit 2; }
aviso() { echo "  ! $*"; }
ok() { echo "  ok $*"; }

api() {
  local m=$1 p=$2 b=${3:-}
  if [ -n "$b" ]; then
    curl -sS -m 40 -X "$m" "$API$p" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H 'Content-Type: application/json' --data "$b"
  else
    curl -sS -m 40 -X "$m" "$API$p" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
  fi
}

ler() {
  local r; r=$(api GET "$1")
  [ "$(echo "$r" | jq -r '.success')" = "true" ] || falha "GET $1: $(echo "$r" | jq -c '.errors')"
  echo "$r" | jq '.result'
}

salvar() { mkdir -p "$BACKUP"; printf '%s\n' "$2" > "$BACKUP/$1.json"; }

gravar() { # gravar MÉTODO CAMINHO CORPO DESCRIÇÃO
  local m=$1 p=$2 b=$3 d=$4
  if [ "$APLICAR" -ne 1 ]; then
    echo "  [simulação] $d"
    echo "              $m $p $(echo "$b" | jq -c .)"
    return 0
  fi
  local r; r=$(api "$m" "$p" "$b")
  [ "$(echo "$r" | jq -r '.success')" = "true" ] && ok "$d" || falha "$d: $(echo "$r" | jq -c '.errors')"
}

# ------------------------------------------------------------------ conferir
doh() { # doh NOME TIPO -> "status;dado1,dado2"
  curl -sS -m 15 -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=$1&type=$2" \
    | jq -r '"\(.Status);\([.Answer[]? | select(.type==1) | .data] | join(","))"'
}

conferir() {
  local erro=0 r st dados
  echo "Resolvendo por DNS-over-HTTPS (1.1.1.1), esperado A = $IP_VPS:"
  for n in "${NOMES[@]}"; do
    r=$(doh "$n.$DOMINIO" A); st=${r%%;*}; dados=${r#*;}
    if [ "$st" = "0" ] && [ "$dados" = "$IP_VPS" ]; then
      ok "$n.$DOMINIO -> $dados"
    elif [ "$st" = "3" ]; then
      aviso "$n.$DOMINIO não existe (NXDOMAIN)"; erro=1
    else
      aviso "$n.$DOMINIO -> status $st, A = '${dados:-nenhum}'"; erro=1
    fi
  done
  # Se resolver, mostra se está indo direto (cinza) ou pelo Cloudflare (laranja).
  # Registro laranja resolve pra IP do Cloudflare, não pro da VPS: o teste acima
  # já pega isso como divergência.
  r=$(doh "server.$DOMINIO" A); dados=${r#*;}
  [ "$dados" = "35.199.71.234" ] && ok "server.$DOMINIO segue 35.199.71.234 (Stape, cinza)" \
    || { aviso "server.$DOMINIO -> '$dados' (esperado 35.199.71.234)"; erro=1; }
  return $erro
}

# ------------------------------------------------------------------ criar
criar() {
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || falha "CLOUDFLARE_API_TOKEN não está no ambiente"
  local regs; regs=$(ler "/zones/$ZONA_ID/dns_records?per_page=100")
  salvar dns_records_antes "$regs"
  local n fqdn atual id conteudo proxied corpo
  for n in "${NOMES[@]}"; do
    fqdn="$n.$DOMINIO"
    atual=$(echo "$regs" | jq -c --arg f "$fqdn" '[.[] | select(.name==$f)]')
    corpo=$(jq -nc --arg n "$n" --arg ip "$IP_VPS" \
      '{type:"A",name:$n,content:$ip,ttl:300,proxied:false,comment:"VPS da Crystal (Hostinger KVM 4). Cinza: Traefik emite o cert por HTTP"}')
    if [ "$atual" = "[]" ]; then
      gravar POST "/zones/$ZONA_ID/dns_records" "$corpo" "cria A $fqdn -> $IP_VPS, cinza"
      continue
    fi
    if [ "$(echo "$atual" | jq 'length')" != "1" ] || [ "$(echo "$atual" | jq -r '.[0].type')" != "A" ]; then
      falha "$fqdn já tem registro de outro tipo ou mais de um: $(echo "$atual" | jq -c '[.[]|{type,content,proxied}]'). Resolver à mão"
    fi
    id=$(echo "$atual" | jq -r '.[0].id')
    conteudo=$(echo "$atual" | jq -r '.[0].content')
    proxied=$(echo "$atual" | jq -r '.[0].proxied')
    if [ "$conteudo" = "$IP_VPS" ] && [ "$proxied" = "false" ]; then
      ok "$fqdn já é A $IP_VPS, cinza"
    else
      gravar PATCH "/zones/$ZONA_ID/dns_records/$id" "$corpo" "corrige $fqdn: era $conteudo proxied=$proxied"
    fi
  done

  if [ "$APLICAR" -eq 1 ]; then
    regs=$(ler "/zones/$ZONA_ID/dns_records?per_page=100")
    salvar dns_records_depois "$regs"
    # Os nomes da VPS: relê e prova proxied=false
    for n in "${NOMES[@]}"; do
      echo "$regs" | jq -e --arg f "$n.$DOMINIO" --arg ip "$IP_VPS" \
        '.[] | select(.name==$f and .type=="A" and .content==$ip and .proxied==false)' >/dev/null \
        && ok "releu $n.$DOMINIO: A $IP_VPS, proxied=false" \
        || falha "$n.$DOMINIO não releu como A $IP_VPS cinza"
    done
    # server., mail. e ftp. nunca laranja
    local problemas; problemas=$(echo "$regs" | jq -c --arg d "$DOMINIO" \
      '[.[] | select((.name=="server."+$d or .name=="mail."+$d or .name=="ftp."+$d) and .proxied==true) | .id]')
    if [ "$problemas" = "[]" ]; then
      ok "server., mail. e ftp. seguem cinza"
    else
      echo "$problemas" | jq -r '.[]' | while read -r id; do
        gravar PATCH "/zones/$ZONA_ID/dns_records/$id" '{"proxied":false}' "força cinza no registro $id"
      done
    fi
    echo
    conferir || aviso "a propagação em 1.1.1.1 pode levar até 5 min (TTL 300); rodar 'conferir' de novo"
  fi
}

case "$CMD" in
  conferir) conferir ;;
  criar) criar ;;
  *) falha "comando desconhecido: $CMD" ;;
esac
