-- Diagnóstico só de leitura (23/10): compra com cartão recusado e depois aprovado não libera.
-- Roda no Postgres do n8n (banco n8n_queue). Mostra só datas, contagens, nomes de evento e códigos de erro:
-- nada de e-mail, nome, telefone ou corpo da compra.
\pset footer off
\echo '== 1. execuções do fluxo de compras por dia e resultado (14 dias)'
select to_char(e."startedAt" at time zone 'America/Sao_Paulo', 'DD/MM') as dia, e.status, count(*) as execucoes
from execution_entity e
where e."workflowId" = 'qMRPSFT9OAScVUP4' and e."startedAt" > now() - interval '14 days'
group by 1, 2 order by min(e."startedAt"), 2;
\echo '== 2. nomes de evento que a Assiny mandou (execuções com dados guardados, 14 dias)'
select m[1] as evento, e.status, count(distinct e.id) as execucoes
from execution_entity e
join execution_data d on d."executionId" = e.id
cross join lateral regexp_matches(d.data, '"([a-z]+_(?:purchase|subscription|payment|order|charge|billet|pix)|(?:purchase|subscription|payment|order|charge)_[a-z_]+|chargeback)"', 'g') as m
where e."workflowId" = 'qMRPSFT9OAScVUP4' and e."startedAt" > now() - interval '14 days'
group by 1, 2 order by 3 desc;
\echo '== 3. códigos de erro nas execuções que falharam (14 dias)'
select m[1] as codigo, count(distinct e.id) as execucoes
from execution_entity e
join execution_data d on d."executionId" = e.id
cross join lateral regexp_matches(d.data, '(EMAIL_INVALIDO|EVENTO_INVALIDO|PGRST[0-9]+|ETIMEDOUT|ECONNREFUSED|ENOTFOUND|ECONNRESET|status code [0-9]{3}|timeout of [0-9]+ms)', 'g') as m
where e."workflowId" = 'qMRPSFT9OAScVUP4' and e."startedAt" > now() - interval '14 days' and e.status in ('error', 'crashed')
group by 1 order by 2 desc;
