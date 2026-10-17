#!/usr/bin/env bash
# install.sh [--dev] [--uninstall]
#   padrão:      copia para $PROJ_PREFIX (~/.local/share/proj)
#   --dev:       symlink para este diretório (edita e já vale)
#   --uninstall: remove tudo (seus dados em ~/.config/proj ficam)
set -eu
SRC=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
DEST="${PROJ_PREFIX:-$HOME/.local/share/proj}"
BIN="${PROJ_BINDIR:-$HOME/.local/bin}"
RC="${PROJ_RC:-$HOME/.bashrc}"
B='# >>> proj >>>'; E='# <<< proj <<<'

rm_block() { [ -f "$RC" ] && sed -i "\|$B|,\|$E|d" "$RC" || true; }

case "${1:-}" in
  --uninstall)
    rm_block; rm -f "$BIN/proj"; rm -rf "$DEST"
    echo "Removido. Dados mantidos em ~/.config/proj"; exit 0;;
  --dev|"") ;;
  *) echo "uso: $0 [--dev] [--uninstall]" >&2; exit 1;;
esac

mkdir -p "$BIN" "$(dirname "$DEST")"
rm -rf "$DEST"
if [ "${1:-}" = --dev ]; then
  ln -s "$SRC" "$DEST"
else
  mkdir -p "$DEST"
  cp -r "$SRC/bin" "$SRC/lib" "$DEST/"
fi
ln -sf "$DEST/bin/proj" "$BIN/proj"

rm_block
touch "$RC"
printf '%s\n[ -f "%s/lib/proj/init.sh" ] && . "%s/lib/proj/init.sh"\n%s\n' "$B" "$DEST" "$DEST" "$E" >> "$RC"

echo "Instalado em $DEST (${1:-cópia})."
echo "Abra um novo terminal ou rode: . \"$DEST/lib/proj/init.sh\""
if grep -q '\.proj\.sh' "$RC"; then
  echo "AVISO: seu $RC ainda carrega ~/.proj.sh. Remova essa linha (senão carrega duas vezes)."
fi
