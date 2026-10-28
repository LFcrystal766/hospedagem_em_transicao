#!/usr/bin/env bash
# Monta o WebKit do Playwright no scratchpad da sessão (o CI do app roda mobile-audit e onda6-iphone também no WebKit).
# Uso: bash webkit-local.sh [worktree do app]   (padrão: /home/user/cw-ux-onda3)
# O Chromium continua o de /opt/pw-browsers (não reinstalar); aqui ele só ganha um atalho ao lado do WebKit.
set -euo pipefail
WT="${1:-/home/user/cw-ux-onda3}"
S="${UX_SCRATCH:-/tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad}"
mkdir -p "$S/pw-browsers"
cd "$WT"
PLAYWRIGHT_BROWSERS_PATH="$S/pw-browsers" pnpm exec playwright install --with-deps webkit
for d in /opt/pw-browsers/*; do [ -e "$S/pw-browsers/$(basename "$d")" ] || ln -s "$d" "$S/pw-browsers/"; done
ls "$S/pw-browsers"
