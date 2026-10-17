#!/usr/bin/env bash
# tests/gen-interfaces.sh - gera docs/INTERFACES.md a partir dos comentários @in/@out/... em lib/
# Uso: bash tests/gen-interfaces.sh [--check]   (--check lista funções sem contrato e sai com 1)
ROOT=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
OUT="$ROOT/docs/INTERFACES.md"
check=0; [ "${1:-}" = --check ] && check=1

gen() {
  local f rel fn line c tags mod prev="" total=0 undoc=0
  echo "# Interfaces"
  echo
  echo "Gerado por \`tests/gen-interfaces.sh\`. Não edite: altere os comentários em \`lib/proj/\`."
  echo "Tags: \`@in\` entradas, \`@out\` saída, \`@g\` globais, \`@effect\` efeitos colaterais, \`@ret\` retorno, \`@uses\` dependências."
  echo
  while IFS= read -r f; do
    rel="${f#"$ROOT"/lib/proj/}"
    mod="${rel%%/*}"; [ "$mod" = "$rel" ] && mod="(raiz)"
    [ "$mod" != "$prev" ] && { echo; echo "## $mod"; prev="$mod"; }
    echo; echo "### \`$rel\`"; echo
    c=""; tags=""
    while IFS= read -r line; do
      case "$line" in
        "#"*) c+="${line#\# }"$'\n'
              case "$line" in *"@in"*|*"@out"*|*"@g"*|*"@effect"*|*"@ret"*|*"@uses"*) tags=1;; esac;;
        [a-zA-Z_]*"() {"*|[a-zA-Z_]*"()"*"{"*)
              fn="${line%%\(*}"
              total=$((total+1))
              if [ -n "$tags" ]; then
                echo "- **\`$fn\`**"
                printf '%s' "$c" | sed -e '/^[[:space:]]*$/d' -e 's/^/  - /'
              else
                undoc=$((undoc+1)); echo "- **\`$fn\`** — _sem contrato_"
                [ "$check" = 1 ] && echo "sem contrato: $rel: $fn" >&2
              fi
              c=""; tags="";;
        "") c=""; tags="";;
        *) ;;
      esac
    done < "$f"
  done < <(find "$ROOT/lib/proj" -name '*.sh' | sort)
  echo; echo "---"; echo "$total funções, $undoc sem contrato."
}

mkdir -p "$ROOT/docs"
gen > "$OUT"
tail -1 "$OUT"
[ "$check" = 1 ] && grep -q 'sem contrato' "$OUT" && exit 1
exit 0
