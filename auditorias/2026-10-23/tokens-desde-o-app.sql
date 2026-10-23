-- Só leitura (23/10): volume de tokens da Crystal desde que o app começou a registrar o uso, para a tabela de
-- custo por modelo. Roda no banco crystal_agente. Só somas e contagens: nada de texto, nome ou contato.
\pset footer off
\echo '== 1. turnos de aluno (sem os testes do painel): período, alunos e tokens'
select min(em)::date as desde, max(em)::date as ate,
       round(extract(epoch from max(em) - min(em)) / 86400.0, 1) as dias,
       count(*) as turnos,
       count(distinct contato_hash) as alunos_no_periodo,
       count(distinct contato_hash) filter (where em > now() - interval '30 days') as alunos_30d,
       sum(tokens_entrada) as tok_entrada, sum(tokens_cache) as tok_cache,
       sum(tokens_saida) as tok_saida, sum(tokens_raciocinio) as tok_raciocinio,
       round(sum(custo_usd), 2) as custo_real_usd
from uso_turnos
where tipo = 'turno' and contato_hash <> '' and erro is null;
\echo '== 2. últimos 30 dias, mesmos números'
select count(*) as turnos, sum(tokens_entrada) as tok_entrada, sum(tokens_cache) as tok_cache,
       sum(tokens_saida) as tok_saida, round(sum(custo_usd), 2) as custo_real_usd
from uso_turnos
where tipo = 'turno' and contato_hash <> '' and erro is null and em > now() - interval '30 days';
\echo '== 3. tudo por tipo (turno, resumo, embedding, laboratório...) desde o começo'
select tipo, count(*) as linhas, sum(tokens_entrada) as tok_entrada, sum(tokens_cache) as tok_cache,
       sum(tokens_saida) as tok_saida, round(sum(custo_usd), 2) as custo_real_usd
from uso_turnos group by 1 order by 6 desc nulls last;
\echo '== 4. turnos de aluno por modelo que respondeu'
select modelo, count(*) as turnos, sum(tokens_entrada) as tok_entrada, sum(tokens_saida) as tok_saida,
       round(sum(custo_usd), 2) as custo_real_usd, min(em)::date as desde, max(em)::date as ate
from uso_turnos where tipo = 'turno' and contato_hash <> '' and erro is null group by 1 order by 2 desc;
