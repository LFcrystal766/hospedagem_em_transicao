# Zona do Cloudflare em 29/09/2026 — export BIND do painel

`cloudflare-export-0343utc.bind` é o export feito pelo Luiz no painel do
Cloudflare em 29/09/2026 03:43 UTC (00:43 BRT). Primeira leitura completa da
zona: as rodadas anteriores eram por sondagem de nomes (DoH), e o token de 28/09
não lia DNS.

## Resumo

Zona com **21 registros**, todos **cinza** (`cf-proxied:false`). Nada laranja,
então nada passa pelo Cloudflare ainda: o degrau 2 não começou. Os três nomes
da VPS da Crystal (`painel`, `editor`, `webhook`) **não existem** na zona: o
que foi criado em 29/09 pelo painel não entrou nesta zona.

## Registro a registro contra a tabela Z

| Registro | Tabela Z | Situação |
|---|---|---|
| `@ A 45.224.128.177`, `@ AAAA 2804:3744:0:105::2` | AZAN, cinza | ok |
| `www CNAME @` | idem | ok |
| `server A 35.199.71.234`, `server AAAA 2600:1901:0:17b4::` | Stape, sempre cinza | ok |
| `mail A/AAAA` (IPs da AZAN), `MX 0 mail.` | e-mail separado do apex | ok |
| SPF `v=spf1 +a +mx +ip4:45.224.128.177 include:spf.jupiter... ~all` | igual à AZAN | ok. O `+a` sai no degrau 2 |
| `default._domainkey` RSA 2048 | igual à AZAN | ok |
| `_dmarc p=none` | igual | ok |
| TXT `facebook-domain-verification` | criado (só soma) | ok |
| `ftp CNAME @` | plano: A cinza ou apagar | **decidir**: com o apex laranja, FTP pelo nome para |
| `ipv6 AAAA 2804:3744:0:105::2` | plano: não copiar | inofensivo; apagar no fim, junto com a AZAN |
| `_acme-challenge` (2 TXT em 28/09) | Universal SSL do Cloudflare | sumiram: o Cloudflare limpou depois de validar. Esperado |
| `painel`, `editor`, `webhook` A → `177.7.61.136` | VPS da Crystal | **faltam** |

## Amazon SES: registros de origem não registrada

Cinco registros que não estão em nenhum inventário anterior:

- 3 CNAME `<seletor>._domainkey` → `<seletor>.dkim.amazonses.com` (DKIM do SES)
- `bounce MX 10 feedback-smtp.us-east-1.amazonses.com` e
  `bounce TXT v=spf1 include:amazonses.com ~all` (MAIL FROM customizado do SES)

Alguém verificou `crystalnowpp.com.br` no Amazon SES (região us-east-1) para
enviar e-mail como `@crystalnowpp.com.br`. As sondagens de 13/09 e 28/09 não
consultavam esses nomes, então não dá pra dizer se vieram da zona da AZAN (via
export da sessão TASK-DNS-001) ou se foram criados depois no Cloudflare. Não
quebram nada e não dependem do laranja. **Descobrir de quem é a conta AWS**
(agência? Assiny? algum plugin do WordPress?) antes de decidir o destino do
e-mail no item `decidir-email`.

## O que fazer com o que falta

1. Criar `painel`, `editor` e `webhook` como A cinza para `177.7.61.136`:
   `scripts/cloudflare-crystal-vps-dns.sh criar --aplicar` (precisa de token
   com DNS Edit) ou pelo painel, **na zona certa** (id `c8f015c8...`, NS
   `aldo`/`jule`). Conferir com `scripts/cloudflare-crystal-vps-dns.sh conferir`.
2. Decidir `ftp` antes do degrau 2 (A cinza se houver conta FTP em uso; senão apagar).
3. Registrar de quem é o SES.
