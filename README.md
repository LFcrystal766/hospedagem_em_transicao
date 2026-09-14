# hospedagem_em_transicao

Saída do `crystalnowpp.com.br` da AZAN para uma hospedagem nova, com o Cloudflare
na frente. O plano da virada (três degraus reversíveis: DNS, Cloudflare na frente
do site atual, troca de servidor) vive no artefato
[Virada Cloudflare do Crystal](https://claude.ai/code/artifact/d48c3476-5287-4895-87b2-53fbc82206ab).

Este repositório guarda o que precisa sobreviver fora do artefato: as auditorias
e as ferramentas que as produzem.

## Auditorias

Cada rodada fica em `auditorias/<data>/`, com o relatório em `RELATORIO.md` e as
evidências cruas em `evidencias/`.

| Data | Situação |
|---|---|
| [2026-09-13](auditorias/2026-09-13/RELATORIO.md) | DNS, certificados e rastreamento iguais ao inventário de 11/09. `/crystal-ttk/` publicada em 12/09 (Fase A do TikTok) e os 3 redirects envenenados já limpos. |

## Como rodar

```bash
./scripts/auditoria-so-leitura.sh              # grava em auditorias/<hoje>/
./scripts/auditoria-so-leitura.sh /outro/lugar
```

Precisa de `curl`, `jq`, `python3` e `openssl`. Onde não houver `dig`, o script usa
DNS-over-HTTPS.

O script **só faz GET e consulta de DNS** — pode rodar em produção a qualquer hora.
A regra que ele respeita e que não pode ser afrouxada: **URL que responde 301 nunca
recebe `fbclid`, `utm` ou `gclid`**. O Drop Query String do LiteSpeed tira esses
parâmetros da chave de cache, então um 301 gravado com query de teste passa a ser
servido para todo mundo — foi assim que três redirects do site ficaram envenenados
em 11/09/2026.
