# Religar no app quem foi desligado só por cancelamento de assinatura (26/11/2026)

## O que aconteceu

- **Desde 15/10**, cada `subscription_canceled` da Assiny desligava o cliente. Esse evento chega quando a assinatura
  anual é cancelada, em geral porque o cliente desligou a renovação, sem pedir reembolso.
  - No Supabase, a compra ficava bloqueada.
  - O n8n chamava `/webhooks/reembolso`, e o app marcava a conta como **Desligado**.
- **Os atingidos:** 166 clientes da base antiga, com assinatura anual válida e sem nenhum reembolso. Foram 115 só nos
  últimos 30 dias.

## O que já foi feito pelo Claude (Supabase, 26/11)

1. **`app_compra_evento` mudou:** cancelamento de assinatura só fica registrado. Não bloqueia a compra e não chama
   mais o app. Reembolso e chargeback continuam bloqueando. Arquivo: `supabase/app_compras_cancelamento.sql`.
2. **As 166 compras foram desbloqueadas** (`bloqueado_em` volta a null). O login delas responde `liberado = true`:
   conferido, 166 de 166.
3. **Lotes 100%:** os 9.357 clientes que estavam fora do lote foram marcados como liberados. Hoje os 11.149 estão
   liberados.
   - O login já não olhava o lote desde 11/10, só a compra válida, então isso não abre acesso para quem não pagou.
   - Serve para o painel (Operação › Lotes) mostrar 100%.
4. **Teste sem gravar nada** (feito dentro de uma transação desfeita):
   - um cancelamento responde `cancelamento`, nas duas vezes em que chega;
   - um reembolso da mesma compra continua bloqueando.

## O que falta: religar as contas no app (VPS)

As contas que o app já desligou continuam como **Desligado** até serem religadas. Rode na VPS, um comando por vez.

**1. Contar (só leitura).** Mostra as contas desligadas pelo webhook, pelo último evento de cada uma:

```bash
docker exec $(docker ps -qf name=crystal_app_app_postgres | head -1) psql -U crystal -d crystal_web_chat -c "select u.disabled_reason, a.ev, count(*) from users u join lateral (select l.details->>'event' as ev from audit_log l where l.target_id = u.id::text and l.action = 'user.refund_disable' order by l.created_at desc limit 1) a on true where u.status = 'disabled' and u.role = 'user' group by 1, 2 order by 3 desc;"
```

**2. Religar só quem foi desligado por cancelamento.** Ficam de fora: quem tem reembolso ou chargeback em qualquer
evento, quem foi desligado à mão pela equipe e as contas de equipe.

```bash
docker exec $(docker ps -qf name=crystal_app_app_postgres | head -1) psql -U crystal -d crystal_web_chat -c "update users u set status = 'active', disabled_reason = null, disabled_note_enc = null, disabled_at = null where u.status = 'disabled' and u.role = 'user' and u.disabled_reason in ('refund', 'preblock') and exists (select 1 from audit_log l where l.target_id = u.id::text and l.action = 'user.refund_disable' and l.details->>'event' in ('subscription_canceled', 'canceled_subscription')) and not exists (select 1 from audit_log l where l.target_id = u.id::text and l.action = 'user.refund_disable' and coalesce(l.details->>'event', '') not in ('subscription_canceled', 'canceled_subscription'));"
```

- Responde `UPDATE <n>`. O número deve bater com a soma das linhas de cancelamento do passo 1.

**3. Contar de novo.** Rode o comando do passo 1: as linhas de `subscription_canceled` têm de sumir.

## Depois

- **O cliente entra de novo com e-mail e senha.** As sessões antigas foram derrubadas quando a conta foi desligada.
- **Não há linha de auditoria da religação**, porque ela foi feita direto no banco. O registro está aqui e no
  CONTINUAR, item 189.
- **Pendência (decisão do dono):** cortar o acesso no fim do período pago de quem cancelou. Hoje, quem cancela a
  renovação continua com acesso.
