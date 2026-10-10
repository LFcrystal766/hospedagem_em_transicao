# Painel da equipe (/equipe): bateria de testes de 10/10

Pedido do dono: "testar todas as funções e botões do painel, até a exaustão", conferindo cada detalhe do PRD.

## Como foi testado

- App local montado a partir da versão de produção (`74092e0`, `otimizacao/etapa-3`):
  - API em modo demo;
  - web em build de produção;
  - um Supabase falso: Postgres com os mesmos `.sql` aplicados em produção, mais um imitador do PostgREST.
- Nenhum teste tocou a VPS, o Supabase real, o Chatwoot ou o WhatsApp.
- Contas de teste:
  - equipe: admin, suporte e tech;
  - 60 alunos: com e sem CPF, liberados e não, com e sem conversa no WhatsApp, parte delas no arquivo, metade dos telefones sem o nono dígito.
- Varreduras feitas:
  - Permissões: 5 papéis × 12 áreas. Tudo certo: quem não pode recebe 404, não 403.
  - Botões: todos os botões de todas as áreas, por papel, com Playwright.
  - Operação: 136 checagens pela API e os fluxos na tela. Também as chaves arriscadas: lotes, limite por IP, manutenção, e eventos e produtos de reembolso cortando sessão.
  - WhatsApp: silêncio (inclusive a chave sem o nono dígito), memória de chegada e memória em lote.
  - Celular: estouro de largura e sobreposição.
  - Acessibilidade: axe.
- Quatro agentes testaram, cada um, uma área contra o PRD:
  - Usuários e Auditoria;
  - Suporte, Avisos e Financeiro;
  - Crystal, Integrações e Painel gerencial;
  - Alunos e Base.

## Correções

Estão no repositório do app, branch `otimizacao/painel-qa`, em cima de `74092e0`.

| Commit | O quê |
|---|---|
| `8d21a68` | Aviso desligado não vaza no `/app/aviso`. Barra de áreas no celular não cobre mais o último botão. Pedido inexistente mostra "não achei". Contraste AA. |
| `a3f83cd` | **Salvar senha derrubava a tela de Usuários.** **PATCH barrado pelo CORS: "Corrigir contato" nunca gravava.** E-mail de equipe repetido. Contato de aluno da compra se corrige na Base. Link de aviso com `\`. "1.297" lido como R$ 1,30. Fuso da data do pagamento. |
| `bc38643` | **Canal: andar com a seta ligava o backup de produção na hora** (agora pede confirmação). Login da equipe: 5 por IP travava o escritório. Foto com tipo errado prendia a conexão. Ritmo perdia o que estava sendo digitado. `vencido=false`. Logo sumindo no celular. |
| `c3dd3e0` | Datas que não existem (31/02) recusadas. Data de pagamento num pendente recusada no PUT. Cancelados contados no resumo. Mensagens próprias na gaveta do Financeiro. Falha dos Avisos aparece como erro. Resumo de Integrações atualiza depois do teste. |

Testes ao fim: API 885, web 638 e shared 212, todos passando. Lint limpo.

## O que ficou, tudo baixo e sem risco

- Auditoria: "Modo backup alterado" mostra `off → auto` em vez dos rótulos da tela.
- Painel lateral (detalhe e nova conta) não leva o foco para dentro, e Esc não devolve.
- Busca por CPF em Usuários ignora os filtros de papel e status.
- Financeiro:
  - "Ver lançamentos" de um aluno não deixa o aluno escolhido no "Novo lançamento";
  - mensagens do zod em inglês (limite de caracteres).
- Integrações:
  - tabela do webhook quebra palavras longas;
  - cartão da Meta "Não checado";
  - rótulos do funil cortados.
- Nuvem de palavras: nomes próprios em início de frase.
- Texto alternativo da foto da Crystal.
- "AGUARDANDO ALUNO" quebra no meio da palavra em telas estreitas.
- `/equipe` sem login leva ao login (a spec não diz).

## Publicar

Nada foi publicado. Para publicar:
1. Juntar `otimizacao/painel-qa` em `otimizacao/etapa-3`. É um avanço direto, sem conflito, e gera as imagens `sha-c3dd3e0`.
2. Rodar `bootstrap-vps.sh app-subir`, conforme `crystal-em-casa/publicar-prd.md`.

Volta: `sha-74092e0`. Não há mudança de banco nem de variável.
