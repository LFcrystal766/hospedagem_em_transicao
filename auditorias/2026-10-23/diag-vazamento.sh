#!/usr/bin/env bash
# Só leitura: o que a Crystal e a API logaram sobre a trava nas últimas 6 h (só códigos e contagens, sem texto).
# Revisão de 24/10 (INF-26): "msg" só aparece se for uma das mensagens conhecidas da trava (as do código,
# apps/crystal/src/app.ts); qualquer outra vira "(outra mensagem)". De "err" fica só o nome do erro
# (antes do primeiro ":") e os demais campos de texto ficam em até 60 letras: um log que um dia traga
# trecho de conversa ou o valor recebido num erro não vai para a tela nem para o chat.
for s in crystal api; do
  echo "== $s (6 h): linhas com trava/vazamento/ataque"
  docker service logs --since 6h --raw "crystal_app_app_$s" 2>&1 | grep -iE 'vazament|trava|ataque|reserva|liberarResposta|semantic' \
    | python3 -c '
import collections, json, re, sys
CONHECIDAS = re.compile(r"^(pedido barrado na entrada: tentativa de extrair o conteúdo interno"
                        r"|trava semântica: (entrada|saída)"
                        r"|resposta vazia: segunda tentativa na reserva"
                        r"|trava de saída falhou: resposta segurada \(falha fechada\)"
                        r"|reserva falhou depois do vazamento"
                        r"|laboratorio: resposta)$")
CAMPOS = ("msg", "code", "codigo", "camada", "modelo", "err", "status", "similaridade", "sim",
          "similaridade_ataque", "similaridade_alma", "similaridade_base")
c = collections.Counter()
for linha in sys.stdin:
    i = linha.find("{")
    try:
        d = json.loads(linha[i:])
    except Exception:
        c["(linha sem JSON)"] += 1
        continue
    partes = []
    for k in CAMPOS:
        v = d.get(k)
        if v is None:
            continue
        if k == "msg" and not CONHECIDAS.match(str(v)):
            v = "(outra mensagem)"
        if k == "err":   # só o nome do erro (o type do pino, ou o que vem antes do primeiro ":")
            v = v.get("type") if isinstance(v, dict) else v
            v = re.split(r"[:\n]", str(v or ""))[0].strip()[:40] or "(erro)"
        if isinstance(v, (int, float)):
            partes.append(f"{k}={v}")
        else:
            partes.append(f"{k}={str(v)[:60]}")
    c[" ".join(partes)] += 1
for k, v in c.most_common(40):
    print(f"  {v:5d} {k}")
if not c:
    print("  nada")
'
done
echo "== uso_turnos"
# O .sql que vale é o do repositório, ao lado deste script (só uso_turnos, agregado). Sem o clone,
# o que tiver sido copiado para /root.
SQL="$(dirname "$0")/diag-vazamento.sql"
[ -f "$SQL" ] || SQL=/root/diag-vazamento.sql
docker exec -i "$(docker ps -q -f name=crystal_app_app_postgres | head -1)" psql -U crystal -d crystal_agente -tA -F ' | ' < "$SQL"
