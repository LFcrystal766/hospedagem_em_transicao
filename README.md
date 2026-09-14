# hospedagem_em_transicao

Saída do `crystalnowpp.com.br` da AZAN para uma hospedagem nova, com o Cloudflare
na frente. O plano da virada (três degraus reversíveis: DNS, Cloudflare na frente
do site atual, troca de servidor) vive no artefato
[Virada Cloudflare do Crystal](https://claude.ai/code/artifact/d48c3476-5287-4895-87b2-53fbc82206ab).

Este repositório guarda o que precisa sobreviver fora do artefato: as auditorias,
as ferramentas que as produzem e uma cópia do próprio artefato.

## Auditorias

Cada rodada fica em `auditorias/<data>/`, com o relatório em `RELATORIO.md` e as
evidências cruas em `evidencias/`.

| Data | Situação |
|---|---|
| [2026-09-13](auditorias/2026-09-13/RELATORIO.md) | DNS, certificados e rastreamento iguais ao inventário de 11/09. `/crystal-ttk/` publicada em 12/09 (Fase A do TikTok) e os 3 redirects envenenados já limpos. Achados levados para o artefato na versão 2. |

## Cópia do artefato

`artefato/virada-cloudflare-crystal.html` é o conteúdo publicado na versão 2
(13/09/2026), logo depois da auditoria. **A cópia envelhece:** a página publicada
salva uma versão nova dela mesma toda vez que alguém marca um item do checklist,
então o que está aqui é o texto do plano, não o estado dos marcados. Para editar o
plano, edite este arquivo e republique-o na mesma URL — publicar sem a URL cria um
artefato separado.

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
