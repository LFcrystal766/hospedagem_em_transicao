#!/usr/bin/env bash
# Postgres descartável para os testes *.pg.test.ts do app (Motor 2.0). Nada de produção: banco local, vazio, no
# scratchpad, que some com o contêiner.
#
# Uso:  bash pg-descartavel.sh <porta> [nome-do-banco]
# Imprime a URL na última linha, por exemplo:  postgres://teste@127.0.0.1:55432/crystal_teste
# Depois:  CRYSTAL_PG_TEST_URL=<url> pnpm --filter @crystal/agente test -- onda5.pg
#          (na API: AUDIT_PG_TEST_URL, AVALIACOES_PG_TEST_URL etc., cada teste diz qual; os da API querem o banco
#          migrado: DATABASE_URL=<url> pnpm --filter @crystal/api exec prisma migrate deploy)
# Parar:   bash pg-descartavel.sh <porta> --parar
# Cada agente usa uma porta própria (a faixa dele + 50). Rodar de novo na mesma porta reaproveita o banco.
set -euo pipefail
PORTA="${1:?porta}"; NOME="${2:-crystal_teste}"
S="${UX_SCRATCH:-/tmp/claude-0/-home-user-hospedagem-em-transicao/a2a2bc38-c612-550a-a226-1af1e7b739be/scratchpad}"
DIR="$S/pg-$PORTA"; BIN=/usr/lib/postgresql/16/bin
como_pg() { su postgres -s /bin/bash -c "$*"; }

if [ "$NOME" = "--parar" ]; then
  [ -d "$DIR/dados" ] && como_pg "$BIN/pg_ctl -D '$DIR/dados' -m fast stop" >/dev/null 2>&1 || true
  echo "parado: $PORTA"; exit 0
fi

mkdir -p "$DIR"; chown postgres:postgres "$DIR"; chmod 700 "$DIR"
# O postgres precisa atravessar o caminho até o scratchpad.
p="$DIR"; while [ "$p" != "/" ]; do p=$(dirname "$p"); chmod o+x "$p" 2>/dev/null || true; done
if [ ! -s "$DIR/dados/PG_VERSION" ]; then
  como_pg "$BIN/initdb -D '$DIR/dados' -U teste --auth=trust -E UTF8 --locale=C.UTF-8" >"$DIR/initdb.log" 2>&1
fi
if ! como_pg "$BIN/pg_isready -h 127.0.0.1 -p $PORTA" >/dev/null 2>&1; then
  # O socket do Postgres aceita no máximo 107 bytes de caminho: pasta curta em /tmp.
  SOCK="/tmp/pgs-$PORTA"; mkdir -p "$SOCK"; chown postgres:postgres "$SOCK"
  como_pg "$BIN/pg_ctl -D '$DIR/dados' -l '$DIR/pg.log' -o '-p $PORTA -k $SOCK -c listen_addresses=127.0.0.1' -w start" >/dev/null
fi
psql -h 127.0.0.1 -p "$PORTA" -U teste -d postgres -tAc "select 1 from pg_database where datname='$NOME'" | grep -q 1 \
  || psql -h 127.0.0.1 -p "$PORTA" -U teste -d postgres -qc "create database $NOME"
echo "postgres://teste@127.0.0.1:$PORTA/$NOME"
