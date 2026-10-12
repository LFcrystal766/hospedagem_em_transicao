# Onda 4 do painel da equipe: plano (12/10, caminho A escolhido pelo dono)

Caminho A: publicar `sha-5a5b198` agora (passo 1, o dono roda na VPS) e trazer o painel novo (`painel/base`,
ondas 1 a 3) para cima dele, com a QA exaustiva, antes de publicar o painel novo (passo 2).

Pedido novo do dono, vindo dos usuários do teste dos avisos: o aviso é uma mensagem da Crystal e tem que
**entrar na conversa com ela** (bolha, botões), além da notificação; e a prévia na tela da equipe mostra
**lado a lado** como fica na conversa e como fica na notificação. O painel novo (A06) já foi desenhado assim;
a T2 garante que funciona de ponta a ponta nos dois canais (direto e Chatwoot).

## Fase 1 (em paralelo, 12/10 20:57 UTC)

| Sessão | Branch | O que faz |
|---|---|---|
| T1 Integração (`session_01Mpqse55SWKhCTa99UndMBh`) | `painel/onda4` | junta `painel/base` + `otimizacao/publicar-10-10` (42 conflitos); painel novo manda nas telas, 10/10 manda nas correções; modelo por caixa, tabela de gasto, Ligações e teste rápido vão para `/equipe/crystal` (rotas `/staff/crystal/modelos` e `/staff/crystal/ligacoes`); avisos programados de 10/10 descartados (migração `pa15_01` apaga `scheduled_notices`); CI passa a rodar em `painel/**` |
| T2 Mensagens (`session_01Tdbn88kf75m34BYwkg5Mpg`) | `painel/onda4-mensagens` | entrega na conversa nos dois canais, prévia dupla (conversa + notificação) no computador e a 390 px, três melhorias da branch de 10/10 (para onde o toque leva, atraso na aba Agendadas, régua de horário), QA do módulo A06–A08 |
| T3 Publicação (`session_01TKgFPYtEg4DFSCP1GrMeAE`) | `claude/gracious-shannon-6x9l5j` (este repositório) | ensaio das 9 migrações + `audit:backfill` + a nova `pa15_01` em Postgres local, SQL de volta testado, variáveis novas, comandos no `bootstrap-vps.sh`, roteiro "Publicação do painel novo" |
| Memória completa (`session_01EAUG7y3ujVLUv21rTdovhb`) | `otimizacao/memoria-ficha` | fora da onda, em paralelo: gerador de fichas na Crystal + API + bloco pequeno no painel (vai para `/equipe/crystal` na integração) |

Achado da varredura que a onda corrige: `painel/**` nunca passou pelo CI do GitHub (`ci.yml` e `imagens-vps.yml`
só rodam em `otimizacao/**`).

## Fase 2 (depois de juntar T1 e T2 em `painel/onda4`)

QA exaustiva do painel novo, como a de 10/10, em sessões por área (Início e Alunos; Mensagens e Crystal;
Configurações, Métricas, Auditoria e Titular; celular, acessibilidade e permissões 5 papéis × áreas), correções
integradas, imagem `sha-<commit>` gerada, roteiro da T3 conferido e só então o passo 2 na VPS.

## Fora da onda

- Dúvidas dos avisos de 10/10: respondidas pelo A07 do painel novo (`docs/otimizacao/avisos-agendados-duvidas.md`
  na branch `otimizacao/avisos-agendados` do app); nada a decidir.
- Sessão "Adicionar novo usuário Crystal" (10/10, aberta pelo dono no site): parada esperando e-mail, nome e
  permissões; é de outro sistema.
