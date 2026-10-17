#!/usr/bin/env bash
# Compila o projd (opcional) para a arquitetura desta máquina.
set -eu
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
CXX="${CXX:-}"
if [ -z "$CXX" ]; then
  for c in clang++ g++ c++; do command -v "$c" >/dev/null 2>&1 && { CXX=$c; break; }; done
fi
[ -n "$CXX" ] || { echo "Sem compilador C++. Termux: pkg install clang make | Debian: apt install g++" >&2; exit 1; }
mkdir -p "$ROOT/bin"
echo "compilando para $(uname -m) com $CXX..."
"$CXX" -O2 -std=c++17 -Wall -o "$ROOT/bin/projd" "$ROOT/src/main.cpp"
echo "pronto: bin/projd (remova o arquivo para voltar ao modo só-shell)"
