# Erro crítico no iPhone antigo (16/10/2026, noite)

Relato: print de um aluno no Safari do iPhone em `app.crystalnowpp.com.br` com a tela "Algo deu errado do meu lado.
Um erro crítico aconteceu. Quer tentar de novo?" (tela global de erro do app). Só leitura, sem dado pessoal aqui.

- **Bundle de produção baixado e lido** (`sha-9ec8151`): o pedaço compartilhado do web traz
  `RegExp("(?<!\\bameac\\w* (?:de )?)\\bme matar\\b")` e a detecção de CPF com `(?<!\\d)`. Lookbehind em regex só existe
  no Safari 16.4 em diante; antes disso o `RegExp(...)` lança erro de sintaxe quando o módulo carrega e o app cai na
  tela global de erro antes de mostrar qualquer coisa.
- **Origem no código:** `packages/shared/src/risco.ts:25` (no ar desde 05/10, commit `604b5aa`), `risco.ts:117`
  (número sem dígito colado) e `packages/shared/src/notices.ts:120` (CPF). O web importa o pacote `shared` inteiro.
- **Outro ponto:** `apps/web/lib/use-chat.ts:655` usa `Array.prototype.at` (Safari 15.4+).
- **Quem é afetado:** iPhone com iOS abaixo de 16.4 (quem não atualizou; iPhone 7 e SE de 1ª geração param no iOS 15;
  iPhone 8 e X param no 16.7 e funcionam se estiverem atualizados).
- **Contorno imediato:** atualizar o iOS ou usar outro aparelho/computador.
- **Correção:** regex reescritas sem lookbehind (mesmo comportamento, com testes), `.at(-1)` trocado, e uma conferência
  no build do web que falha se o bundle tiver `(?<!` ou `(?<=`. Feita em `painel/onda4` (nova etiqueta da produção) e
  levada para `painel/onda5-alma`. A imagem depende da cobrança do GitHub Actions (bloqueada desde 14/10).
