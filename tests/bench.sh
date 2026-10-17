#!/usr/bin/env bash
# tests/bench.sh - tempo de carregar (source) em ms, média de N shells novos
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
N="${N:-30}"
t() {  # rótulo arquivo
  local s e i
  s=$EPOCHREALTIME
  for ((i=0; i<N; i++)); do bash --norc -c ". '$2'" ; done
  e=$EPOCHREALTIME
  awk -v a="$s" -v b="$e" -v n="$N" -v l="$1" 'BEGIN{ printf "%-28s %6.1f ms\n", l, (b-a)*1000/n }'
}
echo "carga média de $N shells:"
t "bash vazio (baseline)" /dev/null
t "modular + lazy (init.sh)" "$ROOT/lib/proj/init.sh"
[ -f "$ROOT/dist/proj.sh" ] && t "bundle (dist/proj.sh)" "$ROOT/dist/proj.sh"
