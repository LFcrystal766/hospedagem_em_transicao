#!/usr/bin/env bash
# Portão do harness de execução do PRD de UX/UI da Crystal.
# Roda numa cópia de trabalho (git worktree) do crystal-web-chat o mesmo que o CI roda, em camadas.
#
# Uso:
#   gate.sh <worktree> rapido  [--porta N]            tipos + lint + testes dos pacotes mudados desde a base
#   gate.sh <worktree> e2e     --porta N spec1 [spec2…] e2e só das specs dadas (portas próprias)
#   gate.sh <worktree> completo [--porta N]           tudo do CI: tipos, lint, 4 suítes, build do web,
#                                                     conferir-safari, audit e o e2e inteiro (Chromium)
#   gate.sh <worktree> ci      [--porta N]            o e2e inteiro como o GitHub roda: Chromium e WebKit juntos
#                                                     (E2E_WEBKIT=1), workers 1, retries 1; "flaky" conta como falha
# Variáveis: BASE (ref de comparação do "rapido"; padrão: merge-base com origin/painel/onda6-custo-aluno-2)
#
# Portas: o e2e sobe a API e o web; cada agente usa uma faixa própria (--porta 3200, 3220, 3240…):
#   web = N, API = N+1, Chatwoot falso = N+2. Dois agentes nunca usam a mesma faixa.
# Saída: cada etapa imprime "OK <etapa>" ou "FALHOU <etapa>" e o log fica em <worktree>/.gate/<etapa>.log.
# Termina com "PORTÃO VERDE" ou "PORTÃO VERMELHO: <etapas>".
# Guardado no repositório da hospedagem (crystal-em-casa/ux-harness/) desde 28/10: o contêiner que zera não o leva.
set -uo pipefail

WT="${1:?worktree}"; MODO="${2:?modo: rapido|e2e|completo|ci}"; shift 2
PORTA=3200; SPECS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --porta) PORTA="$2"; shift 2 ;;
    *) SPECS+=("$1"); shift ;;
  esac
done

cd "$WT" || { echo "worktree não existe: $WT"; exit 2; }
mkdir -p .gate
if [ -f .git ]; then gitdir=$(sed 's/^gitdir: //' .git); else gitdir=.git; fi
mkdir -p "$gitdir/info" 2>/dev/null; grep -qx '.gate/' "$gitdir/info/exclude" 2>/dev/null || echo '.gate/' >> "$gitdir/info/exclude" 2>/dev/null

FALHAS=()
etapa() { # etapa <nome> <comando…>
  local nome="$1"; shift
  local log=".gate/${nome//[^a-zA-Z0-9_-]/_}.log"
  if "$@" >"$log" 2>&1; then echo "OK $nome"; else echo "FALHOU $nome (log: $WT/$log)"; tail -40 "$log" | sed 's/^/    | /'; FALHAS+=("$nome"); fi
}

# Dependências: só instala se faltar.
if [ ! -d node_modules ] || [ ! -d apps/web/node_modules ]; then
  etapa instalar pnpm install --frozen-lockfile --prefer-offline
fi
etapa prisma pnpm --filter @crystal/api db:generate

base="${BASE:-$(git merge-base HEAD origin/painel/onda6-custo-aluno-2 2>/dev/null || echo HEAD~1)}"
mudou() { git diff --name-only "$base" -- "$1" | grep -q . ; }

case "$MODO" in
  rapido|completo)
    etapa tipos-shared pnpm --filter @crystal/shared typecheck
    etapa tipos-api pnpm --filter @crystal/api typecheck
    etapa tipos-web pnpm --filter @crystal/web typecheck
    etapa tipos-crystal pnpm --filter @crystal/agente typecheck
    etapa lint pnpm lint
    for par in "shared:@crystal/shared:packages/shared" "api:@crystal/api:apps/api" "web:@crystal/web:apps/web" "crystal:@crystal/agente:apps/crystal"; do
      IFS=: read -r curto pacote pasta <<<"$par"
      if [ "$MODO" = completo ] || mudou "$pasta" || mudou packages/shared; then
        etapa "testes-$curto" pnpm --filter "$pacote" test -- --testTimeout=30000
      else
        echo "-- testes-$curto pulado (nada mudou em $pasta)"
      fi
    done
    ;;
esac

if [ "$MODO" = completo ]; then
  etapa build-web pnpm --filter @crystal/web build
  etapa safari node apps/web/scripts/conferir-safari.mjs
  etapa audit pnpm audit --prod --audit-level=moderate
fi

export E2E_PORT="$PORTA" E2E_API_PORT="$((PORTA + 1))" E2E_CHATWOOT_PORT="$((PORTA + 2))" CI=true
if [ "$MODO" = e2e ] || [ "$MODO" = completo ]; then
  # Navegador: o Playwright do repositório acha o Chromium por PLAYWRIGHT_BROWSERS_PATH (/opt/pw-browsers).
  export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}"
  if [ "${#SPECS[@]}" -gt 0 ]; then
    etapa "e2e" pnpm exec playwright test "${SPECS[@]}" --reporter=line
  else
    etapa "e2e-completo" pnpm exec playwright test --reporter=line
  fi
fi

if [ "$MODO" = ci ]; then
  # WebKit no scratchpad da sessão (montado por crystal-em-casa/ux-harness/webkit-local.sh); Chromium em /opt.
  S="${UX_SCRATCH:-/tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad}"
  export PLAYWRIGHT_BROWSERS_PATH="$S/pw-browsers" E2E_WEBKIT=1
  [ -d "$S/webkit-root" ] && export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 LD_LIBRARY_PATH="$S/webkit-root/usr/lib/x86_64-linux-gnu:$S/webkit-root/lib/x86_64-linux-gnu"
  [ -e "$S/pw-browsers/chromium" ] || ln -s /opt/pw-browsers/* "$S/pw-browsers/" 2>/dev/null
  etapa "e2e-ci" pnpm exec playwright test --reporter=line
  if grep -qE '^\s+[0-9]+ flaky' ".gate/e2e-ci.log"; then
    echo "FALHOU e2e-ci-flaky (teste instável conta como defeito; veja .gate/e2e-ci.log)"; FALHAS+=("e2e-ci-flaky")
  fi
fi

if [ "${#FALHAS[@]}" -eq 0 ]; then echo "PORTÃO VERDE ($MODO)"; exit 0; fi
echo "PORTÃO VERMELHO: ${FALHAS[*]}"; exit 1
