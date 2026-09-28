# Migração do crystalnowpp.com.br

Saída do site da AZAN (hospeda.info, cPanel `jupiter`) para a Hostinger, com o
Cloudflare na frente, em três degraus reversíveis. O plano completo, item a
item, está no artefato "Virada Cloudflare do Crystal" (link no README). A
situação mais recente está em `artefato/overview-2026-09-28.html` e em
`PROXIMOS-PASSOS.md`.

## Onde estamos (28/09/2026)

- **Degrau 1 feito** entre 18 e 22/09: NS no Cloudflare (`aldo`/`jule`), zona
  `c8f015c8ed7347f8900aa90d6701a15c` ativa, tudo cinza, valores iguais aos da
  AZAN. Certificado de borda ativo para apex e `*.`.
- **Degrau 2 não começou.** O apex ainda resolve `45.224.128.177` (AZAN).
- **Chamado #RAI-374885** aberto na AZAN em 28/09 para liberar os IPs do
  Cloudflare e ler `CF-Connecting-IP`. O laranja só entra depois da resposta.
- **Fatura AZAN**: mensal, R$ 99,90, próxima prevista para 14/10/2026. Não cancelar.

## Primeira coisa a fazer numa sessão nova

1. Conferir quais variáveis existem (sem imprimir valores):
   `env | grep -E 'CLOUDFLARE|CPANEL|STAPE|WP_APP|SUPABASE|HOSTINGER' | sed 's/=.*//'`
2. Com `CLOUDFLARE_API_TOKEN`: `scripts/cloudflare-degrau2.sh foto` e depois
   `scripts/cloudflare-degrau2.sh preparar` (simulação). Mostrar o resultado e
   aplicar com `--aplicar`. Tudo em `preparar` só age com a nuvem laranja.
3. Registrar cada rodada em `auditorias/<data>/` e atualizar o overview.

## Regras que não mudam

- `server.crystalnowpp.com.br` (Stape, `35.199.71.234`) fica **sempre cinza**.
  Laranja nele derruba GTM, CAPI e o webhook de Purchase. `mail.` e `ftp.` também.
- **URL que responde 301 nunca recebe fbclid, utm ou gclid.** O LiteSpeed grava
  o 301 com a query de teste para todo mundo (aconteceu em 11/09).
- **Laranja só na janela 02:00–05:00 BRT**, com a vigia ligada e o time avisado.
  Rollback do degrau 2: `scripts/cloudflare-degrau2.sh cinza --aplicar`.
- Não mexer na zona da AZAN nem nos NS no Registro.br. Não seguir o "aponte
  seus DNS" da Hostinger nem ligar a integração Cloudflare do hPanel.
- Segredos só em variável de ambiente. Nunca em arquivo do repositório nem no chat.
- Não publicar nada no GTM: a migração não exige mudança lá.

## Onde está cada coisa

| Caminho | O que é |
|---|---|
| `scripts/auditoria-so-leitura.sh` | Auditoria só GET/DNS. Rodar de fora: o proxy deste ambiente retermina TLS |
| `scripts/cloudflare-degrau2.sh` | Degrau 2 inteiro, com simulação, backup antes de gravar e rollback |
| `auditorias/<data>/` | Evidências de cada rodada |
| `pedidos/` | Chamado da AZAN e prompt do Cowork |
| `artefato/` | Cópia do plano e o overview |

## O que existe fora deste repositório

As sessões "TASK-DNS-001" e "DNS-002" (18 a 21/09) fizeram o degrau 1 a partir
do MacBook, na pasta `hospedagem-crystal-dns` (6 scripts, linha de base de 45
páginas, commit `c437fa3`). Ela não está no GitHub. Se aparecer, conciliar com
`scripts/cloudflare-degrau2.sh` antes de usar os dois.
