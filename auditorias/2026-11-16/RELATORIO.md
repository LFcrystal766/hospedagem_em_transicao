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

## Consolidação (16/11, 00:30–00:33 BRT)

- **`saude` (30 min):** 3.999 pedidos e 0 ruins.
  - 2.805 servidos pela borda sem ir à AZAN.
  - 17 com 404 (página inexistente) e 1 com 499 (o visitante fechou).
- **`validar`:** sem erro.
- **POP dos visitantes do Brasil, medido nas métricas do Cloudflare (30 min, `clientCountryName` × `coloCode`):**
  - todos em POP do Brasil: GRU 2.602, GIG 342, CFC 60, UDI 48, NVT 36, QWJ 35, FOR 27, XAP 27, CWB 21, BSB 20;
  - nenhum visitante do Brasil em POP de fora.
  - O critério do plano está atendido sem depender do iPhone do dono.
- **00:31 `https --aplicar`:** Always Use HTTPS ligado. `http://` passou a dar 301 para `https://`; home e
  `/crystal-ttk/` com 200; `saude` (5 min) com 403 pedidos e 0 ruins.
- **00:32 `regras --aplicar`:**
  - `crystal_bloqueia_xmlrpc` (`/xmlrpc.php` com 403 na borda);
  - `crystal_freio_wp_login` (limite em `/wp-login.php`, que segue com 200);
  - `crystal_teste_sem_barra` (`/crystal-teste` com 200 sem redirecionar).
  - Depois: `saude` (5 min) com 397 pedidos e 0 ruins; `validar` sem erro.

## Conferência das 07:00 BRT

- **`foto`:** apex, AAAA e `www` laranja; `server.` cinza em `35.199.71.234`.
- **`saude` (60 min):** 4.903 pedidos e 0 ruins.
  - 3.715 servidos pela borda.
  - 71 com 404 (página inexistente) e 1 com 403 (bloqueio do `xmlrpc`).
- **`validar`:** sem erro. `server.` correto, `/healthz` com 200 e crawler da Meta com 200.
- **56 de 56 páginas** com 200 pelo Cloudflare.
- **Fora do muro:** `server./healthz`, `app.` e `api./healthz` com 200.

## Conferência das 12:00 BRT (fechamento do dia)

- **`foto`:** apex, AAAA e `www` laranja; `server.` cinza em `35.199.71.234`.
- **`saude` (60 min):** 5.609 pedidos e 29 ruins (0,5%), abaixo do limite de 5%.
  - 5.101 com 200 e 356 com 204.
  - 72 com 404 (página inexistente), 31 com 403 (quase todos o bloqueio do `xmlrpc`) e 1 com 500 da AZAN.
- **`validar`:** sem erro. `server.` correto, `/healthz` com 200 e crawler da Meta com 200.
- **56 de 56 páginas** com 200 pelo Cloudflare.
- **Fora do muro:** `server./healthz`, `app.` e `api./healthz` com 200.

**O degrau 2 está fechado.** Doze horas no ar, quatro conferências, nenhuma volta para cinza.

## Resumo do que foi aplicado

| Quando (BRT) | O quê |
|---|---|
| 15/11 23:55 | `preparar` e `laranja`: apex, AAAA e `www` laranja; `ftp` de CNAME para A/AAAA cinza; SPF sem `+a`; SSL em modo estrito |
| 16/11 00:31 | "Sempre HTTPS" ligado |
| 16/11 00:32 | Três regras: bloqueio do `/xmlrpc.php`, freio no `/wp-login.php` e o acerto do `/teste` sem barra |
| 16/11 07:00 e 12:00 | Conferências: tudo ok |

## Pendente

- ~~O dono abre `/cdn-cgi/trace` no iPhone~~: dispensado, porque as métricas já mostram os visitantes do Brasil em
  POP do Brasil. O teste no iPhone continua valendo como prova para o dono.
  - GRU, GIG, FOR, POA, CNF ou CWB: ok.
  - Fora do Brasil (MIA, IAD…): voltar para cinza, pela regra do plano.
- ~~00:30 BRT: consolidação~~ feita (ver acima).
- ~~02:00, 07:00 e 12:00 BRT: `foto`, `saude` e `validar`~~ feitas as de 07:00 e 12:00. A de 02:00 não rodou: o
  degrau já estava consolidado desde 00:33 e a de 07:00 cobriu a madrugada.
- **Origin CA no cPanel antes de 26/12**, quando vence o certificado AutoSSL da AZAN.
- **Regra da zona que tira `fbclid`/`utm`/`gclid` de redirecionamento.** Hoje quem faz isso é o LiteSpeed, atrás do
  Cloudflare.
- **Page Rules não conferidas.** A chave usada não lê Page Rules; o dono mandou seguir. Abrir uma vez
  Rules › Page Rules no painel e confirmar que está vazio.
- **O script `validar` precisa de dois acertos** antes de rodar de novo (revisão de segurança de 16/11): ele manda
  parâmetros de teste a um endereço `http://` que responde 301, o que a regra da casa proíbe. Não houve efeito
  visível, mas o teste sai do script.
- **A chave do Cloudflare:** apagar quando não houver mais nada para fazer com ela. A revisão de segurança de 16/11
  sugere três regras novas na zona; se o dono quiser que o Claude as aplique, a chave fica até lá.

Volta: `scripts/cloudflare-degrau2.sh cinza --aplicar` (segundos).
