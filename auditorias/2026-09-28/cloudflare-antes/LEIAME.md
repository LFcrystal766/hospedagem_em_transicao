# Zona do Cloudflare antes do degrau 2 — 28/09/2026

Leitura só-GET da zona `crystalnowpp.com.br` (id `c8f015c8ed7347f8900aa90d6701a15c`,
conta `a938d629ec1d8ac1f21e77e8723ac514`), feita com o token de conta
entregue em 28/09. Nada foi alterado. O token não está neste repositório.

## Zona

Criada em 18/09/2026 04:18 UTC, ativada em 22/09/2026 17:11 UTC, plano Free,
NS `aldo`/`jule.ns.cloudflare.com`, sem pausa.

## Configurações (`settings.json`) contra o plano do degrau 2

| Setting | Hoje | Plano | |
|---|---|---|---|
| `ssl` | strict | strict | ok |
| `min_tls_version` | 1.2 | 1.2 | ok |
| `tls_1_3` | on | on | ok |
| HSTS | desligado | desligado | ok |
| `rocket_loader` | off | off | ok |
| `email_obfuscation` | **on** | off | **mudar antes do laranja** |
| `early_hints` | off | off | ok |
| `automatic_https_rewrites` | on | pode ficar on | ok |
| `always_use_https` | off | on só depois do laranja validado | ok por ora |
| `hotlink_protection` | off | off | ok |
| `sort_query_string_for_cache` | off | off | ok |
| `security_level` | medium | sem Under Attack | ok |
| `browser_check` | on | on | ok |
| `ssl_automatic_mode`, `speed_brain`, `fonts` | não lidos | custom / off / off | conferir |

## Regras

`rulesets_list.json`: só os três rulesets gerenciados que toda zona tem
(normalização, Managed Free, DDoS L7). As fases de firewall custom, transform,
response headers e rate limit respondem "entrypoint não encontrado", ou seja,
nenhuma regra criada.

## O que o token não alcança

Resposta de autenticação negada (10000, 9109 ou "request is not authorized"):

- DNS (`dns_records.json`): sem isso não dá pra ligar o laranja, reler o
  `server.` nem fazer o rollback do degrau 2
- Certificados de borda (`certificate_packs.json`): sem isso não dá pra
  confirmar o Universal SSL `active` antes do laranja
- Page Rules, Cache Rules, Config Rules, Origin Rules, Redirect Rules
- Managed headers (Add security headers / Referrer-Policy)
- Bot management (Bot Fight Mode, AI Labyrinth), Zaraz, DNSSEC, Email Routing

## Certificado de borda

`ssl_verification.json`: Universal SSL `active` para `*.crystalnowpp.com.br`,
validado por TXT (DV). Isso explica os dois TXT novos em `_acme-challenge`
vistos no DNS público em 28/09: são do Cloudflare e não devem ser apagados.
O pré-requisito do item `ligar-laranja` (cert de borda ativo) está cumprido.

## Leitura complementar (28/09, fim da tarde)

| Setting | Hoje | Plano |
|---|---|---|
| `ssl_automatic_mode` | **auto** | custom (em auto o Cloudflare pode trocar o strict sozinho) |
| `speed_brain` | off | off |
| `fonts` | off | off |
| `early_hints` | off | off |
| `email_obfuscation` | **on** | off |

As duas mudanças (ssl_automatic_mode e email_obfuscation) não foram gravadas:
a permissão da sessão barrou. Estão no comando `preparar` do
`scripts/cloudflare-degrau2.sh`.
