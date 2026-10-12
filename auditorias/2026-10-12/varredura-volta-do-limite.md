# Varredura de 12/10 (volta depois do limite semanal)

Pedido do dono: "faça uma varredura em tudo novamente, veja tudo como está, depois reinicie a orquestração".
Tudo só leitura; nada mudou na VPS, no Supabase nem no n8n.

## Produção (VPS 177.7.61.136, KVM 4, no ar)

| O quê | Como está |
|---|---|
| `api.` /healthz, `app.` /login, `atendimento.` (Chatwoot 4.18.0) | 200, todos |
| Código publicado | continua `74092e0` (branch `otimizacao/etapa-3` sem push desde 09/10). A publicação de 10/10 (`sha-5a5b198`) **não foi feita** |
| DNS `ia.` (Crystal Python da agência) | não existe: nunca foi publicada, como combinado |
| n8n "Crystal · compra e reembolso da Assiny" | ativo, 8 nós, igual ao desenhado. Editado em 12/10 02:42 UTC: foi só a opção "disponível no MCP" (por isso este conector passou a ver o fluxo) |

## Supabase "Crystal AI" (só leitura)

- **22 compras reais** em `crystal_compras` desde 10/10: 2 em 10/10 e **20 em 12/10**. 21 liberadas (`active`), 1 reembolsada e
  bloqueada. 19 do produto "CRYSTAL - A NOVA MELHOR AMIGA DOS HOMENS", 1 "Botão Dourado", 1 "Recuperação", 1 liberação manual
  (missoesexecutivo, de 10/10). Eventos de 72 h: 21 `approved_purchase -> liberar`, 1 `refunded_purchase -> bloquear`.
  Ou seja: a compra direta pela Assiny está funcionando de ponta a ponta, sem a agência.
- As linhas de teste do n8n já foram apagadas (0). Sobrou a função `zz_teste_cabecalho_20261009` (sem permissão para ninguém):
  apagar no SQL Editor com `drop function public.zz_teste_cabecalho_20261009();`.
- `app_memoria_ficha` (ficha pré-gerada): NÃO aplicada (0 tabelas, 0 funções), como esperado: espera decisão do dono.
- 21 funções `app_*` publicadas.

## Repositórios e GitHub

- `hospedagem_em_transicao`: `claude/gracious-shannon-6x9l5j` = `721b037`, local e remoto iguais, nada pendente.
- `crystal-web-chat`: CI verde em `otimizacao/publicar-10-10` (`5a5b198`, imagens api/web/crystal geradas),
  `otimizacao/crystal-ligacoes` (`15d9288`), `otimizacao/painel-qa` (`73bb815`), `otimizacao/avisos-agendados` (`abdcf32`).
  Produção `otimizacao/etapa-3` = `74092e0`, CI verde.
- Sobras: `qa/painel-2026-10-10` (cópia igual, pode apagar); PR #1 do app (`otimizacao/blindagem`, 02/10) e PR #1 deste
  repositório (`claude/magical-turing-j6t8p6`, 13/09) continuam abertos e antigos.

## Sessões paralelas

| Sessão | Estado em 12/10 | O que fiz |
|---|---|---|
| Memória completa (10/10) | caiu pelo limite semanal; SQL `app_memoria_ficha.sql` commitado (`e447c0f`), código do gerador não | **religada** como `session_01EAUG7y3ujVLUv21rTdovhb`: gerador na Crystal + API + bloco pequeno no painel, tudo parametrizável, sem gastar nem aplicar sem OK |
| Avisos programados (10/10) | pronta (`abdcf32`), mas as "3 dúvidas" ficaram só no chat dela | sessão curta `session_017BbFmynPVzsFL9iRRRcVxC` escreve `docs/otimizacao/avisos-agendados-duvidas.md` na branch |
| "Adicionar novo usuário Crystal" (10/10, aberta pelo dono no site) | parada esperando e-mail, nome e permissões (`can_read`, `can_replay`, `can_activate`, conta no Supabase Auth) | nada: é de outro sistema (parece o painel Python da agência) e é do dono |
| Painel admin, ondas 1 a 3 (08/10, nove sessões) | **concluídas e integradas** em `painel/base` (`03cff13`, 09/10): 81 commits, 394 arquivos, 9 migrações. Nunca publicada | ver "A bifurcação" abaixo |

## A bifurcação do painel (decisão do dono)

Existem duas linhagens do painel da equipe, e as duas partem de `c320aa0`:

1. **`otimizacao/publicar-10-10`** (`sha-5a5b198`): o painel de hoje com as correções da bateria de testes, a escolha do modelo
   por fornecedor com a tabela de gasto, "Ligações da Crystal" e os avisos programados. Pronta, testada (e2e 35/35), imagens
   geradas, 1 migração aditiva. Publica com `app-subir sha-5a5b198`.
2. **`painel/base`**: o painel novo do PRD `docs/painel-admin/PRD.md` (A01 a A14, menos o A10): moldura e kit novos, Início,
   Alunos (lista, ficha, lotes com palavra LIBERAR e senha), Mensagens (A06 a A08, com agendamento em data e hora ou na hora
   local do aluno, silêncio 22h–8h, limite por dia), Crystal (A09: modelo, teste, pausa), Configurações (A11), Métricas (A12),
   Auditoria com cadeia de hash (A13), pedidos do titular LGPD (A14). `/equipe/operacao` e `/equipe/avisos` viram
   redirecionamentos. 9 migrações. Sem a bateria de testes exaustiva de 10/10 e sem as correções dela.

As duas se sobrepõem em 69 arquivos. A junção textual até passa sem conflito, mas não faz sentido: o painel novo tira a
Operação e os Avisos de onde o trabalho de 10/10 colocou a caixa de modelo, as ligações e o agendamento. Em outras
palavras, **o pedido de 10/10 (caixa de modelo, agendar avisos, pré-visualização) já existia no painel novo, não publicado**;
foi refeito no painel antigo porque esta sessão perdeu esse contexto ao ser resumida.

Caminhos:
- **A (recomendado): publicar `sha-5a5b198` agora** (correções graves já em produção, risco baixo, volta fácil) e abrir a onda 4:
  trazer `painel/base` para cima dela, levando a caixa de modelo, as ligações e a bateria de testes para o painel novo, descartar
  o agendamento duplicado (`scheduled_notices`), rodar a mesma QA exaustiva no painel novo e só então publicar o painel novo.
- **B: pular direto para `painel/base`**: mais mudança de uma vez (9 migrações, telas novas para a equipe aprender), sem a QA
  exaustiva ainda; as correções de 10/10 que valem para os dois (CORS do PATCH, senha derrubando Usuários, e-mail repetido…)
  precisam ser portadas antes.
- **C: ficar só no painel antigo** e arquivar `painel/base` (perde 3 ondas de trabalho: auditoria com hash, LGPD, métricas).
