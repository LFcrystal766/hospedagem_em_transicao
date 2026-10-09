# Conector da Hostinger: primeira leitura (09/10/2026)

Só leitura pela API da Hostinger (conector ligado pelo dono em 09/10). Nada foi alterado.

| Item | O que a API mostrou |
|---|---|
| VPS | 1 só: KVM 4, id `2006998`, `177.7.61.136`, Ubuntu 24.04, `running`, sem trava de ação. 4 CPU, 16 GB, 200 GB |
| Firewall da Hostinger | Nenhum criado, nenhum ligado na VPS (`firewall_group_id` nulo). A proteção hoje é só o UFW de dentro da máquina (`bootstrap-vps.sh seguranca`) |
| Backup da Hostinger | Semanal: 01/10 e 08/10. Fica na conta da Hostinger; não substitui o backup cifrado no R2 |
| Snapshot | Nenhum |
| Docker Manager | Lista vazia: as stacks sobem por `docker stack`/Portainer, que o painel da Hostinger não enxerga. O conector não reinicia nem lê container |
| Hospedagem de sites (hPanel) | Nenhum site na conta. Domínios: só o domínio grátis da VPS, `pending_setup`. O degrau 3 (site saindo da AZAN) não tem plano de hospedagem nesta conta |
| Métricas | `vps_virtual-machines_metrics` devolve HTTP 500 do lado da Hostinger (duas tentativas, formatos de data diferentes) |

O conector não roda comando dentro da VPS: o que é de terminal continua por SSH.

Conferido no mesmo dia, de fora: NS `aldo`/`jule` (Cloudflare), apex e `www` resolvem `45.224.128.177`
(AZAN), resposta com `server: jupiter`, `x-powered-by: PHP/7.4.33`, `x-litespeed-cache: hit` e sem `cf-ray`.
Ou seja: o DNS está no Cloudflare, cinza; o site em si continua servido pela AZAN.

Proposta, esperando OK do dono:

1. Firewall da Hostinger na frente da VPS, liberando só 22, 80 e 443 TCP (o mesmo do UFW). É a segunda camada:
   se um container publicar porta por engano, a rede da Hostinger barra antes.
2. Snapshot antes de cada mudança grande na VPS (cada novo snapshot apaga o anterior).
