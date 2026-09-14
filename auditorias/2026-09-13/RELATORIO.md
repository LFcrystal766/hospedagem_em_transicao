# Auditoria só-leitura — crystalnowpp.com.br

**Rodada em 13/09/2026, 21:22 BRT.** Comparada com o inventário de 11/09/2026
(artefato "Virada Cloudflare do Crystal"). Reproduzível com
`scripts/auditoria-so-leitura.sh`; as evidências desta rodada estão em `evidencias/`.

Nada foi alterado: só GET e consulta de DNS. Nenhuma URL de 301 recebeu
fbclid/utm/gclid, pela regra do item `limpar-301-envenenado`.

## Resumo

Rastreamento, DNS, certificados e funil estão exatamente como no inventário de
11/09. Duas coisas mudaram no site, e uma delas mexe no sequenciamento da
migração.

## Deltas vs 11/09

### 1. A Fase A do runbook TikTok rodou depois do inventário

`/crystal-ttk/` foi publicada em **12/09/2026 01:12 UTC (11/09 22:12 BRT)** e é hoje
a página mais recente do site (`wp/v2/pages`, ordenado por `modified`). O site
passou de **43 para 45 páginas** no sitemap (44 publicadas em `wp/v2/pages`).

O que isso implica:

- A linha de base de 11/09 está desatualizada. Ela precisa ser refeita antes do
  degrau 1, com a `/crystal-ttk/` dentro da matriz.
- A `/crystal-ttk/` tem que entrar no backup da AZAN.
- No HTML dela **não há** `ttq` nem `analytics.tiktok` — a tag viria do GTM, que
  esta auditoria não consegue ler (sem credencial). Confirmar pela GTM API se a
  versão live do container web mudou.
- **Não existe TXT de verificação do TikTok no DNS.** O apex só tem o SPF. Se o
  runbook previa esse TXT, ele ainda não foi criado; e depois da troca de NS ele
  tem que ser criado no Cloudflare, não no cPanel.

### 2. Os 3 redirects envenenados estão limpos

`/crystal-promocional-r-wpp`, `/teste-server-gtm` e `/teste-v8` respondem 301 com
Location **sem `fbclid=TESTE123` e sem `utm_source=`**. Na primeira sondagem os três
vieram com `x-litespeed-cache: miss`, ou seja, a entrada envenenada tinha sido
descartada — provavelmente por um purge geral do LSCache ao publicar a
`/crystal-ttk/`, não por purge manual. A sondagem seguinte já veio `hit` com o
Location limpo: o cache agora guarda a versão correta.

O item `limpar-301-envenenado` pode ser fechado. A causa raiz continua de pé
(Drop Query String + 301 cacheado), então a regra de nunca mandar fbclid pra URL
de 301 vale pra todas as rodadas seguintes.

### 3. TTFB não medido nesta rodada

Os 0,80–1,85 s observados passam pelo proxy de saída do ambiente e não comparam
com os 0,104–0,172 s da base, medidos direto. Não é sinal de degradação: é
instrumento errado. O TTFB tem que ser medido de fora deste ambiente.

## Conferido e idêntico à base

**DNS** (`evidencias/dns.txt`) — delegação ainda em `ns1`/`ns2.jupiter.servidor.net.br`,
SOA serial `2026090201`. Apex `45.224.128.177` e `2804:3744:0:105::2`;
`server` em `35.199.71.234` e `2600:1901:0:17b4::`; `mail` e `ftp` ainda CNAME do
apex; `ipv6` AAAA; `MX 0 crystalnowpp.com.br`; SPF
`v=spf1 +a +mx +ip4:45.224.128.177 include:spf.jupiter.servidor.net.br ~all`;
DKIM `default` RSA 2048 igual; DMARC `p=none`; sem CAA; sem DS.
`_acme-challenge` e `_cpanel-dcv-test-record` ainda resolvem (os dois "não copiar"
da tabela Z). `cpanel`, `webmail`, `webdisk`, `autodiscover` e `autoconfig`: NXDOMAIN.
`leticiafelisberto.com` segue com NS da AZAN e MX do Google Workspace.

**Registro** (`evidencias/rdap.json`) — ativo, registrado em 02/03/2026, expira
**02/03/2028**, `delegationSigned: false` (DNSSEC desligado, dá pra trocar NS direto).
O RDAP público não mostra o e-mail do contato, então o item `acesso-registro-br`
continua dependendo do Luiz.

**Certificados** (`evidencias/certificados.txt`) — o proxy de saída não reterminou
TLS nesses dois hosts, então os dados são do certificado real:

| Host | Emissor | Validade | Dias |
|---|---|---|---|
| `crystalnowpp.com.br` | Let's Encrypt YR2 | 02/09 → **01/12/2026** | 79 |
| `server.crystalnowpp.com.br` | Let's Encrypt YR1 | 30/08 → **28/11/2026** | 76 |

O SAN do certificado do site confirma a conta compartilhada: `*.crystalnowpp.com.br`,
`*.leticiafelisberto.com`, `crystalnowpp.com.br` e `www.crystal.leticiafelisberto.com`.
O do `server.` cobre só ele mesmo.

**Rastreamento** (`evidencias/paginas.tsv`, `evidencias/stape.txt`) — loader
`67hcnvgovw` em **45 de 45** páginas, com a **mesma chave** em todas
(`8=HhJSICIjTiNBMVsxMTgoTgFLXUlHSAcGShUdHgUaAgQZGRgXBkAABxpYDRU%3D`); o bundle
entrega `GTM-K6G4VGVK`; `server.crystalnowpp.com.br/healthz` responde 200; a meta
`facebook-domain-verification` está em 45 de 45 páginas.

**Funil** — 13 páginas com `createOneClickBuy` apontando pra
`pay.assiny.com.br/fe5c30/node/<id>/one-click`; as 4 páginas de vendedor respondem
200 e carregam a Visitor API.

**Origem** — ainda 100% AZAN: `LiteSpeed/6.3.6 Enterprise` em tudo e zero `cf-ray`.
Nada passa pelo Cloudflare, como esperado antes do degrau 1.

## Defeitos que já existiam e continuam no ar

- `http://crystalnowpp.com.br/` responde **200 sem redirecionar** pra https.
- Pixel `fbevents.js` avulso só no `/rmkt-v1/`.
- `robots.txt` de 23/08 aponta **5 sitemaps que dão 404** (`sitemap613`, `592`, `669`,
  `690`, `712`). O válido é `sitemap_index.xml`.
- `/wp-json/wp/v2/users` expõe o usuário `admin` (id 1) — o que torna a troca de
  senha do item `app-password-wp` mais urgente do que parece.

## Frentes que esta auditoria não cobre

Dependem de credencial que não existe neste ambiente (o repositório estava vazio,
sem `.env.local`):

| Frente | O que falta |
|---|---|
| GTM | versões live dos containers web e servidor |
| Stape | status do domínio `server.`, logs do `/lead/`, volume por domínio |
| Meta | anúncios ativos, `last_fired_time` do Pixel |
| Supabase | vendas, connect rate, webhooks |
| Cloudflare | zona (ainda não existe) |
| cPanel AZAN | zona real por UAPI, caixas de e-mail, TTL |
| `/api/tracking-health` | os 14 checks (app não está neste repositório) |
| SMTP/IMAP | portas 465/587/993 — a saída deste ambiente é só HTTPS |

Das 6 frentes do inventário original, esta rodada cobriu DNS, HTML e o que é
público de WordPress e certificados. GTM/Stape, integrações e Cloudflare ficaram
em branco.
