# Madrugada do degrau 2 — 29/09/2026

Pedido do dono em 28/09: passar o degrau 2 nesta madrugada e conferir depois.
Cada etapa roda numa sessão nova do Claude, disparada por agendamento.

## Antes de qualquer etapa

```bash
git fetch origin claude/modest-brown-3sg4zm
git checkout claude/modest-brown-3sg4zm
git pull origin claude/modest-brown-3sg4zm
env | grep -E '^CLOUDFLARE_(API_TOKEN|ACCOUNT_ID)=' | sed 's/=.*/=<definida>/'
```

Sem `CLOUDFLARE_API_TOKEN`, ou com a chamada ao Cloudflare barrada pela
permissão da sessão: não tentar contornar. Registrar o bloqueio no relatório,
fazer push e encerrar. O site segue como está (tudo cinza, servido pela AZAN).

Relatório de cada etapa: `auditorias/2026-09-29/madrugada/<hora>-<etapa>.md`,
com a saída dos comandos. Commit e push no branch `claude/modest-brown-3sg4zm`.

## 00:30 — Preparação (nada muda para o visitante)

```bash
scripts/cloudflare-degrau2.sh foto
scripts/cloudflare-degrau2.sh preparar            # simulação
scripts/cloudflare-degrau2.sh preparar --aplicar
scripts/cloudflare-degrau2.sh cert
```

Se `cert` falhar, a virada das 02:00 não acontece.

## 02:00 — Virada

```bash
scripts/cloudflare-degrau2.sh cert                # tem que passar
scripts/cloudflare-degrau2.sh preparar --aplicar  # idempotente
scripts/cloudflare-degrau2.sh laranja --aplicar
```

Espere uns 3 minutos (por exemplo, repetindo o `foto` e o `saude`) e confira:

```bash
scripts/cloudflare-degrau2.sh saude 5     # 0 ok, 1 ruim, 3 sem métricas
scripts/cloudflare-degrau2.sh validar             # 0 ok, 1 ruim, 3 inconclusivo
```

## Quando voltar para cinza (rollback)

Rode `scripts/cloudflare-degrau2.sh cinza --aplicar` na hora se qualquer um
destes acontecer, e escreva no relatório qual foi:

- `saude` sai 1: mais de 5% de 5xx na borda ou 403 da AZAN
- `validar` sai 1 com erro real: página de venda sem 200, `referrer-policy`
  presente, `server.` fora de `35.199.71.234`, `server./healthz` sem 200
- `cert` falha

`validar` saindo 3 (inconclusivo) não é motivo de rollback sozinho: o
ambiente de nuvem pode estar bloqueado pela AZAN. Nesse caso vale o `saude`.
Se os dois ficarem sem dado, mantenha e registre.

## 02:30 — Consolidação (só se 02:00 ficou laranja e saudável)

```bash
scripts/cloudflare-degrau2.sh saude 30
scripts/cloudflare-degrau2.sh https --aplicar
scripts/cloudflare-degrau2.sh regras --aplicar
scripts/cloudflare-degrau2.sh saude 5
scripts/cloudflare-degrau2.sh validar
```

Se piorar depois de `https`: `https-off --aplicar`. Se piorar depois de
`regras`: `desfazer-regras --aplicar`. Se continuar ruim: `cinza --aplicar`.

## 03:30, 07:00 e 12:00 — Conferências

```bash
scripts/cloudflare-degrau2.sh foto
scripts/cloudflare-degrau2.sh saude 60
scripts/cloudflare-degrau2.sh validar
```

Mesmas regras de rollback. A das 12:00 fecha o relatório do dia em
`auditorias/2026-09-29/RELATORIO.md`: o que foi aplicado, a que horas, as
métricas de cada conferência e o que ficou pendente (resposta da AZAN ao
chamado #RAI-374885, linha de base, Stape).

## Nunca

- Laranja em `server.`, `mail.` ou `ftp.`
- Mexer na zona da AZAN, nos NS ou no Registro.br
- fbclid, utm ou gclid em URL que responde 301
- Publicar no GTM
- Imprimir o token
