-- Diagnóstico só de leitura (21/10): "a Crystal não fala de mais de uma coisa". Só números por dia, nada de texto nem aluno.
\pset footer off
\echo '== 1. mensagens do aluno por dia: quantas chegaram com a resposta anterior ainda saindo, e quanto a resposta levou (segundos)'
with ins as (
  select m.id, m.conversation_id, m.created_at,
         lag(m.id) over (partition by m.conversation_id order by m.created_at) as anterior
  from messages m
  where m.direction = 'in' and m.notice_id is null and m.created_at >= now() - interval '7 days'
), r as (
  select i.created_at, i.anterior,
         (select min(o.completed_at) from messages o where o.reply_to_id = i.anterior) as anterior_pronta,
         (select min(o.completed_at) from messages o where o.reply_to_id = i.id) as pronta
  from ins i
)
select to_char(created_at at time zone 'America/Sao_Paulo', 'DD/MM') as dia,
       count(*) as msgs_aluno,
       count(*) filter (where anterior is not null and (anterior_pronta is null or anterior_pronta > created_at)) as atropelou_a_anterior,
       round((percentile_cont(0.5) within group (order by extract(epoch from pronta - created_at)))::numeric, 1) as seg_mediana,
       round((percentile_cont(0.9) within group (order by extract(epoch from pronta - created_at)))::numeric, 1) as seg_90pct
from r group by 1 order by min(created_at);
\echo '== 2. respostas da Crystal por dia e modelo (tamanho medio em letras, erros)'
select to_char(created_at at time zone 'America/Sao_Paulo', 'DD/MM') as dia, coalesce(model, '-') as modelo,
       count(*) as bolhas, round(avg(length(content))) as letras_media,
       count(*) filter (where status = 'error') as erros
from messages
where direction = 'out' and notice_id is null and created_at >= now() - interval '7 days'
group by 1, 2 order by min(created_at), 2;
\echo '== 3. falhas por codigo nos ultimos 2 dias'
select coalesce(error_code, '-') as codigo, count(*) from messages
where direction = 'out' and status = 'error' and created_at >= now() - interval '2 days' group by 1 order by 2 desc;
