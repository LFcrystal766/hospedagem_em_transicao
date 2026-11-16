# Degrau 2: Cloudflare na frente do site (15/11/2026, 23:55 BRT)

Pedido do dono às 23:39 BRT: "faça agora!", "pode mandar bala", "agora inclusive". Foi feito **fora da janela
02:00–05:00 BRT**, com `FORA_DA_JANELA=sim`, por decisão explícita dele.

- **Chave:** de conta, em Network secrets (`api.cloudflare.com`), salva pelo dono às 23:52.
- **Page Rules:** a chave de conta não lê esse endpoint (1011), e ele não foi conferido no painel. O dono mandou
  seguir (`PAGERULES_CONFERIDAS=dono-autorizou`). O `validar` logo depois do laranja não mostrou nada estranho.

## O que foi feito

| Hora (BRT) | Comando | Resultado |
|---|---|---|
| 23:52 | `foto` | Tudo cinza. Site e www na AZAN, app na VPS, `server.` na Stape. Saída em `auditorias/2026-11-15/cloudflare/` |
| 23:54 | `preparar --aplicar` | `ssl_automatic_mode` de auto para custom; `email_obfuscation` de on para off; `ftp` de CNAME do apex para A e AAAA cinza (IPs da AZAN). O resto já estava certo: SSL strict, TLS 1.2+, Rocket Loader off, sem HSTS, sem security headers, robôs sem desafio |
| 23:54 | `cert` | Universal SSL ativo para apex e `*.` |
| 23:55:18 | `laranja --aplicar` | `@ A`, `@ AAAA` e `www` laranja; SPF sem `+a` (`v=spf1 +mx +ip4:45.224.128.177 include:spf.jupiter.servidor.net.br ~all`); `server.`, `mail.` e `ftp.` cinza |

## Conferência logo depois (23:55–23:57 BRT)

- **`/cdn-cgi/trace`:** 200, `colo=IAD`, `http/2`, `TLSv1.3`. O teste roda nos EUA.
- **Cabeçalhos:** apex com `server: cloudflare`, `cf-ray` e `x-litespeed-cache: hit`. `www` com 301 para
  `https://crystalnowpp.com.br/`.
- **DNS:**
  - apex e `www` em `104.21.79.149` e `172.67.146.80` (Cloudflare);
  - `server.` em `35.199.71.234` (Stape);
  - `app.` em `177.7.61.136` (VPS);
  - `mail.` e `ftp.` em `45.224.128.177` (AZAN).
- **`validar`: sem erro.**
  - Páginas de venda com 200 pela borda.
  - Crawler da Meta com 200.
  - `www` e `http` com 301 para o apex.
  - TTFB de 0,27 a 0,73 s no POP IAD/EWR, contra 0,10–0,17 s da AZAN direta. A medida é feita dos EUA: o critério
    "POP fora do Brasil" precisa do teste do dono no iPhone.
- **`saude` (5 min):** 24 pedidos, 0 ruins.
- **As 56 páginas da lista** (`site-estatico/ferramentas/paginas.txt`): 56 com 200 e `cf-ray`.
- **Fora do muro:** `server./healthz` 200; `app.` 200 e `api./healthz` 200, sem Cloudflare.

## Pendente

- **O dono abre `https://crystalnowpp.com.br/cdn-cgi/trace` no iPhone** (4G e Wi-Fi) e diz o `colo=`.
  - GRU, GIG, FOR, POA, CNF ou CWB: ok.
  - Fora do Brasil (MIA, IAD…): voltar para cinza, pela regra do plano.
- **00:30 BRT:** consolidação (`https`, `regras`), se a saúde seguir boa e o POP for do Brasil.
- **02:00, 07:00 e 12:00 BRT:** `foto`, `saude` e `validar`.
- **Origin CA no cPanel antes de 26/12.**
- **O dono apaga a chave** depois da última conferência.

Volta: `scripts/cloudflare-degrau2.sh cinza --aplicar` (segundos).
