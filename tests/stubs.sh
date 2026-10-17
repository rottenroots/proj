#!/usr/bin/env bash
# toda função proj_* definida em lib/ precisa estar registrada (eager ou lazy)
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
HOME=$(mktemp -d); export HOME; trap 'rm -rf "$HOME"' EXIT
. "$ROOT/lib/proj/init.sh"
bad=0
for f in $(grep -rhoE '^proj_[a-z_]+\(\)' "$ROOT/lib" | tr -d '()' | sort -u); do
  declare -F "$f" >/dev/null || { echo "sem registro: $f"; bad=1; }
done
[ $bad = 0 ] && echo "stubs ok"; exit $bad
