#!/usr/bin/env bash
# Auditoria só-leitura do crystalnowpp.com.br.
#
# Só faz GET e consulta de DNS. Não escreve em nada: nem no WordPress, nem no
# DNS, nem em painel nenhum. Pode rodar a qualquer hora, inclusive em produção.
#
# Regra que o script respeita (e que não pode ser afrouxada): URL que responde
# 301 nunca recebe fbclid/utm/gclid. O Drop Query String do LiteSpeed tira esses
# parâmetros da chave de cache, então um 301 gravado com query de teste passa a
# ser servido pra todo mundo. Foi assim que os 3 redirects de /crystal-* ficaram
# envenenados em 11/09/2026.
#
# Uso: scripts/auditoria-so-leitura.sh [pasta-de-saida]
# Padrão: auditorias/<data de hoje em America/Sao_Paulo>/

set -uo pipefail

DOMINIO=crystalnowpp.com.br
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAIDA="${1:-$RAIZ/auditorias/$(TZ=America/Sao_Paulo date +%F)}"
EV="$SAIDA/evidencias"
mkdir -p "$EV"

UA_INSTAGRAM='Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 341.0'
get() { curl -sS -m 40 -A "$UA_INSTAGRAM" "$@"; }
doh() { curl -sS -m 25 -H 'accept: application/dns-json' "https://dns.google/resolve?name=$1&type=$2"; }

echo "auditoria só-leitura de $DOMINIO"
echo "rodada em $(TZ=America/Sao_Paulo date '+%d/%m/%Y %H:%M:%S %Z')"
echo "saída: $SAIDA"
echo

# ---------------------------------------------------------------- 1. DNS
echo "[1/7] DNS (DNS-over-HTTPS)"
{
  for nome in "$DOMINIO" "www.$DOMINIO" "server.$DOMINIO" "mail.$DOMINIO" "ftp.$DOMINIO" \
              "ipv6.$DOMINIO" "cpanel.$DOMINIO" "webmail.$DOMINIO" "webdisk.$DOMINIO" \
              "autodiscover.$DOMINIO" "autoconfig.$DOMINIO"; do
    for tipo in A AAAA CNAME; do
      echo "### $nome $tipo"
      doh "$nome" "$tipo" | jq -c '{Status,Answer:(.Answer//[]|map({name,TTL,data})),Comment}'
    done
  done
  for tipo in NS SOA MX TXT CAA DS; do
    echo "### $DOMINIO $tipo"
    doh "$DOMINIO" "$tipo" | jq -c '{Status,Answer:(.Answer//[]|map({name,TTL,data})),Comment}'
  done
  for nome in "_dmarc.$DOMINIO" "default._domainkey.$DOMINIO" "_acme-challenge.$DOMINIO" \
              "_cpanel-dcv-test-record.$DOMINIO"; do
    echo "### $nome TXT"
    doh "$nome" TXT | jq -c '{Status,Answer:(.Answer//[]|map({name,TTL,data}))}'
  done
  # A conta cPanel é compartilhada: o que muda lá afeta o Crystal.
  echo "### leticiafelisberto.com NS"; doh leticiafelisberto.com NS | jq -c '{Answer:(.Answer//[]|map(.data))}'
  echo "### leticiafelisberto.com MX"; doh leticiafelisberto.com MX | jq -c '{Answer:(.Answer//[]|map(.data))}'
} > "$EV/dns.txt" 2>&1

# ---------------------------------------------------------------- 2. Registro
echo "[2/7] registro do domínio (RDAP)"
get "https://rdap.registro.br/domain/$DOMINIO" -o "$EV/rdap.json"

# ---------------------------------------------------------------- 3. Matriz HTTP
echo "[3/7] matriz HTTP"
{
  printf '%-52s %-5s %-18s %-7s %-6s %s\n' URL STATUS SERVIDOR CACHE CF-RAY LOCATION
  for caminho in /crystal-teste /crystal-teste/ /rmkt-v1/ /crystal-v6-teste/ \
      /crystal-promocional-r-r/ /crystal-promocional-r-wpp/ \
      /crystal-247-promocional-r-r/ /crystal-247-promocional-r-wpp/ \
      /crystal-ttk/ /crystal-promocional-r-wpp /teste-server-gtm /teste-v8 \
      /robots.txt /sitemap_index.xml /; do
    cab=$(mktemp)
    st=$(get -o /dev/null -D "$cab" -w '%{http_code}' "https://$DOMINIO$caminho")
    loc=$(grep -i '^location:' "$cab" | tr -d '\r' | sed 's/^[Ll]ocation: *//')
    cache=$(grep -i '^x-litespeed-cache:' "$cab" | tr -d '\r' | awk '{print $2}')
    srv=$(grep -i '^server:' "$cab" | tr -d '\r' | awk '{print $2}')
    cf=$(grep -ci '^cf-ray:' "$cab")
    printf '%-52s %-5s %-18s %-7s %-6s %s\n' "$caminho" "$st" "${srv:--}" "${cache:--}" "$cf" "${loc:--}"
    rm -f "$cab"
  done
  # www e http só fazem sentido no host/esquema deles.
  for url in "https://www.$DOMINIO/" "http://$DOMINIO/"; do
    cab=$(mktemp)
    st=$(get -o /dev/null -D "$cab" -w '%{http_code}' "$url")
    loc=$(grep -i '^location:' "$cab" | tr -d '\r' | sed 's/^[Ll]ocation: *//')
    printf '%-52s %-5s %-18s %-7s %-6s %s\n' "$url" "$st" - - - "${loc:--}"
    rm -f "$cab"
  done
} > "$EV/matriz-http.txt" 2>&1

# ---------------------------------------------------------------- 4. Páginas
echo "[4/7] páginas do sitemap e marcadores de rastreamento"
get "https://$DOMINIO/page-sitemap.xml" -o "$EV/page-sitemap.xml"
get "https://$DOMINIO/robots.txt" -o "$EV/robots.txt"
TMP_PAGINAS="$(mktemp -d)"
UA_INSTAGRAM="$UA_INSTAGRAM" DESTINO="$EV/paginas.tsv" HTML="$TMP_PAGINAS" \
python3 - "$EV/page-sitemap.xml" <<'PY'
import os, re, subprocess, sys
sitemap = open(sys.argv[1], encoding='utf8', errors='replace').read()
urls = re.findall(r'<loc>(.*?)</loc>', sitemap)
ua, destino, pasta = os.environ['UA_INSTAGRAM'], os.environ['DESTINO'], os.environ['HTML']
colunas = ['caminho','status','bytes','loader','meta_fb','one_click','vturb','visitor_api','fbq_avulso','ttq','assiny']
linhas = []
for url in urls:
    caminho = url.replace('https://crystalnowpp.com.br', '') or '/'
    arq = os.path.join(pasta, (caminho.strip('/').replace('/', '_') or 'home') + '.html')
    status = subprocess.run(['curl','-sS','-m','40','-A',ua,'-o',arq,'-w','%{http_code}',url],
                            capture_output=True, text=True).stdout.strip()
    h = open(arq, encoding='utf8', errors='replace').read() if os.path.exists(arq) else ''
    linhas.append([caminho, status, str(len(h)),
        str(h.count('67hcnvgovw')),
        '1' if 'zo0z05dmsem2pmd5qb4x8txu2bho2z' in h else '0',
        str(h.count('createOneClickBuy')),
        '1' if ('vturb' in h or 'converteai' in h) else '0',
        '1' if 'visitorapi' in h else '0',
        '1' if 'fbevents.js' in h else '0',
        '1' if ('ttq' in h or 'analytics.tiktok' in h) else '0',
        '1' if 'assiny' in h else '0'])
with open(destino, 'w', encoding='utf8') as f:
    f.write('\t'.join(colunas) + '\n')
    for l in linhas:
        f.write('\t'.join(l) + '\n')
total = len(linhas)
sem_loader = [l[0] for l in linhas if l[3] == '0']
sem_meta   = [l[0] for l in linhas if l[4] == '0']
fbq        = [l[0] for l in linhas if l[8] == '1']
print(f'  {total} páginas | sem loader: {sem_loader or "nenhuma"} | sem meta da Meta: {sem_meta or "nenhuma"}')
print(f'  fbq avulso em: {fbq or "nenhuma"} | one-click: {sum(1 for l in linhas if int(l[5]) > 0)} páginas')
PY
rm -rf "$TMP_PAGINAS"

# ---------------------------------------------------------------- 5. Certificados
echo "[5/7] certificados"
{
  for host in "$DOMINIO" "server.$DOMINIO"; do
    echo "### $host"
    # -proxy: o egress desta máquina só sai por HTTPS. Se o proxy reterminar o
    # TLS, o emissor vem como CA do proxy: nesse caso o dado não vale e o cert
    # tem que ser lido de fora (crt.sh ou um host sem proxy).
    proxy_arg=()
    [ -n "${HTTPS_PROXY:-}" ] && proxy_arg=(-proxy "${HTTPS_PROXY#http://}")
    echo | timeout 30 openssl s_client "${proxy_arg[@]}" -servername "$host" -connect "$host:443" 2>/dev/null \
      | openssl x509 -noout -issuer -subject -dates -ext subjectAltName 2>/dev/null
    echo
  done
} > "$EV/certificados.txt" 2>&1
grep -E '^(###|issuer|notAfter)' "$EV/certificados.txt" | sed 's/^/  /'

# ---------------------------------------------------------------- 6. Stape
echo "[6/7] sGTM (Stape)"
{
  echo "### GET https://server.$DOMINIO/healthz"
  get -o /dev/null -D - "https://server.$DOMINIO/healthz" | tr -d '\r'
  echo "### loader 67hcnvgovw.js (só o que identifica o container)"
  get "https://server.$DOMINIO/67hcnvgovw.js?8=aWQ9R1RNLUs2RzRWR1ZL" -o - \
    | grep -oE 'GTM-[A-Z0-9]{6,}' | sort -u
} > "$EV/stape.txt" 2>&1
grep -E '^(HTTP/|GTM-)' "$EV/stape.txt" | sed 's/^/  /'

# ---------------------------------------------------------------- 7. WordPress
echo "[7/7] WordPress (REST público, sem autenticação)"
{
  echo "### /wp-json/ (namespaces e autenticação)"
  get "https://$DOMINIO/wp-json/" | jq '{name,description,authentication:(.authentication|keys),namespaces}'
  echo "### páginas editadas mais recentemente"
  get "https://$DOMINIO/wp-json/wp/v2/pages?per_page=10&orderby=modified&order=desc&_fields=slug,modified_gmt,status" \
    | jq -r '.[]|"\(.modified_gmt)  \(.status)  \(.slug)"'
  echo "### total de páginas publicadas"
  get -o /dev/null -D - "https://$DOMINIO/wp-json/wp/v2/pages?per_page=1" | tr -d '\r' | grep -i '^x-wp-total:'
  echo "### usuários expostos"
  get "https://$DOMINIO/wp-json/wp/v2/users" | jq -c '.[]?|{id,name,slug}'
} > "$EV/wordpress.txt" 2>&1
sed -n '/páginas editadas/,/total de páginas/p' "$EV/wordpress.txt" | head -6 | sed 's/^/  /'

echo
echo "evidências em $EV"
