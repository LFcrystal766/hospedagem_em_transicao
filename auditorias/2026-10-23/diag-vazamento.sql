-- Só leitura (23/10 noite): a trava deixou passar um vazamento da base. Mostra, nas últimas 6 h, o que a Crystal
-- registrou por turno: hora, tipo, modelo, código de erro/trava, reserva, tamanho da resposta. Nada de texto nem aluno.
\pset footer off
\echo '== 1. turnos das últimas 6 h, do mais novo para o mais antigo (até 60)'
select to_char(em at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI:SS') as hora, tipo, modelo, coalesce(erro, '-') as erro,
       reserva, chars_saida as letras, tokens_saida as tok_saida, trechos, busca
from uso_turnos where em > now() - interval '6 hours' order by em desc limit 60;
\echo '== 2. contagem por modelo e código nas últimas 24 h'
select modelo, coalesce(erro, '-') as erro, count(*) from uso_turnos where em > now() - interval '24 hours' group by 1, 2 order by 3 desc;
