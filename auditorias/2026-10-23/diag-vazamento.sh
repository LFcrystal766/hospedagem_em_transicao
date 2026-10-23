#!/usr/bin/env bash
# Só leitura: o que a Crystal e a API logaram sobre a trava nas últimas 6 h (só códigos e contagens, sem texto).
for s in crystal api; do
  echo "== $s (6 h): linhas com trava/vazamento/ataque"
  docker service logs --since 6h --raw "crystal_app_app_$s" 2>&1 | grep -iE 'vazament|trava|ataque|reserva|liberarResposta|semantic' \
    | grep -oE '"(msg|code|codigo|camada|modelo|err|status|similaridade|sim)":("[^"]*"|[0-9.]+|null)' | paste -d' ' - - - - - - | sort | uniq -c | sort -rn | head -40
done
echo "== uso_turnos"
docker exec -i "$(docker ps -q -f name=crystal_app_app_postgres | head -1)" psql -U crystal -d crystal_agente -tA -F ' | ' < /root/diag-vazamento.sql
