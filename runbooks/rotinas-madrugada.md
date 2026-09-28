# Rotinas da madrugada de 29/09/2026

## Já agendadas pelo Claude (sessão nova em cada uma, aviso por push e e-mail)

| Hora (BRT) | Rotina | id |
|---|---|---|
| 00:30 | Preparação (nada muda para o visitante) | `trig_019Ndgrrgbb4rQo3U7s9b9uy` |
| 03:30 | Conferência | `trig_017tmqEbh4vQaxSvTbUZWynr` |
| 07:00 | Conferência | `trig_0149M6FuPmgkzQrQ1Qw4cC1D` |
| 12:00 | Conferência e relatório final | `trig_01KTf8WSHBBiE9wEYPVZrSig` |

## Para o dono criar em claude.ai > Routines

A permissão da sessão do Claude não deixou agendar as duas etapas que mudam o
site. Crie cada uma como rotina de execução única, com sessão nova, na hora
indicada, colando o texto abaixo.

**Ao criar, selecione o repositório `LFcrystal766/hospedagem_em_transicao` e o
branch `claude/modest-brown-3sg4zm`.** É nesse branch que está a regra
`.claude/settings.json` que libera o script. Sem isso, a sessão abre fora do
repositório, a regra não vale e a gravação pode ser barrada.

As quatro rotinas já agendadas abrem sem o repositório selecionado. Se a
preparação das 00:30 ou um rollback numa conferência for barrado, a sessão
registra, avisa por push e para. O site fica como está.

### 02:00 — Virada (29/09/2026 02:00 BRT = 05:00 UTC)

```text
Migração do site crystalnowpp.com.br, etapa "02:00 — Virada" da madrugada de 29/09/2026 (degrau 2: ligar a nuvem laranja do Cloudflare no apex e no www, com a AZAN ainda como origem). O dono pediu em 28/09 para passar o degrau 2 nesta madrugada e conferir depois.

1. Se o repositório não estiver na pasta de trabalho, clone https://github.com/LFcrystal766/hospedagem_em_transicao. Faça fetch, checkout e pull do branch claude/modest-brown-3sg4zm.
2. Leia CLAUDE.md e runbooks/madrugada-degrau2.md. Leia também o relatório da etapa das 00:30 em auditorias/2026-09-29/madrugada/, se existir. Se a preparação das 00:30 foi barrada por permissão, isso não impede a virada: esta etapa roda a preparação de novo. Só não ligue o laranja se o comando cert falhar agora.
3. Execute a seção "02:00 — Virada" e aplique as regras de rollback da seção "Quando voltar para cinza". Se CLOUDFLARE_API_TOKEN não existir, ou se a permissão da sessão barrar as chamadas, não tente contornar: registre o bloqueio e pare. O site segue cinza.
4. Grave o relatório em auditorias/2026-09-29/madrugada/0200-virada.md com a saída dos comandos (nunca o token), faça commit e push no branch claude/modest-brown-3sg4zm.
5. Termine com um resumo de até 3 linhas: estado final (laranja ou cinza), resultado do saude e do validar, e se houve rollback.
```

### 02:30 — Consolidação (29/09/2026 02:30 BRT = 05:30 UTC)

```text
Migração do site crystalnowpp.com.br, etapa "02:30 — Consolidação" da madrugada de 29/09/2026 (degrau 2: Cloudflare na frente da hospedagem AZAN). O dono pediu em 28/09 para passar o degrau 2 nesta madrugada e conferir depois.

1. Se o repositório não estiver na pasta de trabalho, clone https://github.com/LFcrystal766/hospedagem_em_transicao. Faça fetch, checkout e pull do branch claude/modest-brown-3sg4zm.
2. Leia CLAUDE.md, runbooks/madrugada-degrau2.md e o relatório das 02:00 em auditorias/2026-09-29/madrugada/0200-virada.md.
3. Só siga se o relatório das 02:00 mostrar o apex e o www laranja e saudáveis, e se "scripts/cloudflare-degrau2.sh foto" confirmar isso agora. Se estiver cinza, ou se houve rollback, não aplique nada: registre e pare.
4. Execute a seção "02:30 — Consolidação" (Always Use HTTPS e regras de borda), com as regras de desfazer e de rollback do roteiro. Se CLOUDFLARE_API_TOKEN não existir, ou se a permissão da sessão barrar as chamadas, não tente contornar: registre e pare.
5. Grave o relatório em auditorias/2026-09-29/madrugada/0230-consolidacao.md (nunca o token), faça commit e push no branch claude/modest-brown-3sg4zm.
6. Termine com um resumo de até 3 linhas: o que foi aplicado ou desfeito e o estado atual.
```
