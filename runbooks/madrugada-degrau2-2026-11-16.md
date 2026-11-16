# Madrugada do degrau 2: domingo para segunda, 16/11/2026 (BRT)

Pedido do dono em 15/11 às 23:39 BRT: "faça agora!". O chamado da AZAN #RAI-374885 foi respondido em 28/09: a
liberação do Cloudflare é global na rede deles.

- **Janela:** a regra do `CLAUDE.md` diz 02:00–05:00 BRT, ou seja, 05:00–08:00 UTC de 16/11.
- **Quem roda:** Claude, com a chave da zona que o dono pôs em Network secrets (`api.cloudflare.com`, `Authorization:
  Bearer …`). O valor nunca aparece.
- **Base:** este roteiro substitui o `madrugada-degrau2.md` de 29/09, que nunca rodou por falta de chave, para esta
  data e esta branch.

## Antes de qualquer etapa

```bash
cd /home/user/hospedagem_em_transicao   # ou o clone do repositório na sessão nova
git fetch origin claude/gracious-shannon-6x9l5j && git checkout claude/gracious-shannon-6x9l5j && git pull
export CLOUDFLARE_API_TOKEN=substituido-pelo-proxy   # o proxy troca pelo valor salvo; nunca imprimir
scripts/cloudflare-degrau2.sh foto                  # leitura: tem de passar
```

**Se o `foto` falhar por autenticação, não fazer nada:**
- registrar no CONTINUAR;
- avisar o dono;
- o site segue como está, tudo cinza.

**Relatórios:**
- `auditorias/2026-11-16/madrugada/<hora>-<etapa>.md`, com a saída dos comandos;
- commit e push na branch acima.

## 00:30 BRT (03:30 UTC): preparação. Nada muda para o visitante.

```bash
scripts/cloudflare-degrau2.sh preparar            # simulação: ler o que muda
scripts/cloudflare-degrau2.sh preparar --aplicar  # settings que só agem com laranja; ftp vira A cinza
scripts/cloudflare-degrau2.sh cert                # certificado de borda ativo para apex e *.
```

Se o `cert` falhar, a virada das 02:00 não acontece.

## 02:00 BRT (05:00 UTC): virada

```bash
scripts/cloudflare-degrau2.sh cert
scripts/cloudflare-degrau2.sh preparar --aplicar  # idempotente
scripts/cloudflare-degrau2.sh laranja --aplicar   # @ A, @ AAAA e www laranja; tira o +a do SPF; server./mail./ftp. cinza
```

Esperar uns 3 minutos e conferir:

```bash
MINUTOS=5 scripts/cloudflare-degrau2.sh saude     # 0 ok, 1 ruim, 3 sem métricas
scripts/cloudflare-degrau2.sh validar             # 0 ok, 1 ruim, 3 inconclusivo
curl -sS https://crystalnowpp.com.br/cdn-cgi/trace | grep -E '^(colo|http|tls)='   # a prova do dono: colo=GRU…
```

**Conferências de fora, sem chave:**
- as 56 páginas com 200 e `cf-ray`;
- `server.` ainda em `35.199.71.234`, com `/healthz` 200;
- `app.` e `api.` ainda na VPS, com HTTPS 200.

## Volta para cinza (na hora)

```bash
scripts/cloudflare-degrau2.sh cinza --aplicar
```

**Quando voltar:**
- `saude` sai 1 (mais de 5% de 5xx na borda ou 403 da AZAN);
- `validar` sai 1 com erro real;
- o `cert` falha;
- qualquer página de venda sem 200;
- `server.` fora do IP da Stape.

**Nunca:**
- `fbclid`, `utm` ou `gclid` em URL que responde 301;
- laranja em `server.`, `mail.`, `ftp.`, `app.`, `api.`, `atendimento.`, `painel.`, `editor.` ou `webhook.`;
- mexer na zona da AZAN, nos NS ou no Registro.br;
- publicar no GTM;
- imprimir a chave.

## 02:30 BRT (05:30 UTC): consolidação (só se 02:00 ficou laranja e saudável)

```bash
MINUTOS=30 scripts/cloudflare-degrau2.sh saude
scripts/cloudflare-degrau2.sh https --aplicar     # Always Use HTTPS
scripts/cloudflare-degrau2.sh regras --aplicar    # bloqueia /xmlrpc.php, freia /wp-login.php
MINUTOS=5 scripts/cloudflare-degrau2.sh saude
scripts/cloudflare-degrau2.sh validar
```

**Se piorar:**
- depois do `https`: `https-off --aplicar`;
- depois das `regras`: `desfazer-regras --aplicar`;
- se continuar ruim: `cinza --aplicar`.

## 03:30, 07:00 e 12:00 BRT: conferências

```bash
scripts/cloudflare-degrau2.sh foto
MINUTOS=60 scripts/cloudflare-degrau2.sh saude
scripts/cloudflare-degrau2.sh validar
```

- As regras de volta são as mesmas.
- A conferência das 12:00 fecha o relatório do dia em `auditorias/2026-11-16/RELATORIO.md`.
- Ela também atualiza `CLAUDE.md` ("Degrau 2") e o CONTINUAR.
- Avisar o dono para apagar a chave no Cloudflare.

## Depois (não nesta madrugada)

- **Origin CA do Cloudflare no cPanel da AZAN antes de 26/12**, quando vence o AutoSSL da Sectigo.
- **A regra da zona que tira `fbclid`/`utm`/`gclid` de redirecionamento.** A do LiteSpeed segue valendo atrás do
  Cloudflare.
