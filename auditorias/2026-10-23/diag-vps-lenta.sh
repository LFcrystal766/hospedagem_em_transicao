#!/usr/bin/env bash
# Só leitura (23/10): por que a VPS está travando. Não muda nada; só mostra números de CPU, memória,
# disco, quem mais consome e se o sistema matou processos por falta de memória.
echo "== 1. carga (load) e núcleos"; uptime; echo "  núcleos: $(nproc)"
echo "== 2. memória e swap"; free -h
echo "== 3. disco"; df -h / /var/lib/docker 2>/dev/null | sort -u
echo "== 4. 5 segundos de CPU (us=programas, sy=sistema, wa=esperando disco, st=roubado pela Hostinger)"; vmstat 1 6 | tail -n +1
echo "== 5. contêineres (CPU, memória e disco agora)"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.BlockIO}}' 2>/dev/null | sort -k2 -t$'\t' -rh | head -25
echo "== 6. processos que mais usam CPU"; ps -eo pid,pcpu,pmem,etime,comm --sort=-pcpu | head -12
echo "== 7. processos que mais usam memória"; ps -eo pid,pmem,rss,comm --sort=-rss | head -10
echo "== 8. o sistema matou algo por falta de memória (24 h)?"
journalctl -k --since "24 hours ago" 2>/dev/null | grep -iE "out of memory|oom-kill|killed process" | tail -8 || true
[ -n "$(journalctl -k --since '24 hours ago' 2>/dev/null | grep -iE 'oom-kill|killed process')" ] || echo "  nada"
echo "== 9. backup, compactação ou envio rodando agora?"
ps -eo pid,etime,pcpu,comm,args | grep -E "pg_dump|tar |gzip|age |rclone|aws s3|curl .*r2" | grep -v grep | cut -c1-140 || true
echo "== 10. serviços que reiniciaram (tarefas que caíram nas últimas horas)"
docker service ls --format '{{.Name}} {{.Replicas}}' 2>/dev/null | while read -r n r; do
  q=$(docker service ps "$n" --filter desired-state=shutdown --format '{{.CurrentState}}' 2>/dev/null | grep -cE 'hours?|minutes?|seconds?' || true)
  [ "${q:-0}" -gt 0 ] && echo "  $n ($r): $q tarefa(s) encerradas recentemente"
done; echo "  (fim)"
