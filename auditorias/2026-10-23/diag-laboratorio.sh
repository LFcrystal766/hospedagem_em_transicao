#!/usr/bin/env bash
# Só leitura (23/10): o que a API e a Crystal registraram do Laboratório nas últimas 24 h.
# Mostra só o tipo de mensagem, código, status e modelo, contados: nada de texto de conversa.
for s in api crystal; do
  echo "== $s (24 h)"
  docker service logs --since 24h --raw "crystal_app_app_$s" 2>&1 | grep -i 'laborat' | python3 -c '
import sys, json, collections
c = collections.Counter()
for l in sys.stdin:
    i = l.find("{")
    try:
        d = json.loads(l[i:])
    except Exception:
        c["(linha sem JSON)"] += 1
        continue
    res = d.get("res") or {}
    req = d.get("req") or {}
    partes = [str(d.get(k)) for k in ("msg", "code", "status", "err", "modelo") if d.get(k) is not None]
    if res.get("statusCode"): partes.append("HTTP " + str(res["statusCode"]))
    if req.get("url"): partes.append(req.get("method", "") + " " + req["url"].split("?")[0])
    c[" | ".join(partes)] += 1
for k, v in c.most_common(25):
    print(" ", v, "x", k)
if not c: print("  nada com laboratorio no log")
'
done
echo "== rotas do Laboratório respondendo (sem sessão: 401/404 é esperado, 5xx não)"
for p in /staff/laboratorio/estado /staff/laboratorio/modelos /staff/laboratorio/conversas; do
  printf '  %s -> ' "$p"; curl -s -o /dev/null -w '%{http_code}\n' "https://api.crystalnowpp.com.br$p"
done
