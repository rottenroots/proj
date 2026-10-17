# store/readme.sh - cabeçalho <!-- proj ... --> do README e coluna do índice

# @in dir chave valor  @effect edita o bloco <!-- proj --> de $dir/README.md
proj_readme_set() {
  local f="$1/README.md" tmp
  [ -f "$f" ] || return 1
  tmp=$(mktemp) || return 1
  K="$2" V="$3" awk '
    BEGIN { k=ENVIRON["K"]; v=ENVIRON["V"] }
    /^<!-- proj/ && !done { h=1; print; next }
    h && /-->/ { if (!set) print k": "v; h=0; set=1; done=1; print; next }
    h && !set && $0 ~ "^"k"[ \t]*:" { print k": "v; set=1; next }
    { print }' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

# @in dir coluna valor  @effect altera uma coluna do $PROJ_IDX (linha com $3==dir)
proj_idx_set() {
  local tmp; tmp=$(mktemp "$PROJ_IDX.XXXXXX") || return 1
  D="$1" C="$2" V="$3" awk -F'\t' -v OFS='\t' \
    '$3==ENVIRON["D"] { $(ENVIRON["C"]+0)=ENVIRON["V"] } { print }' "$PROJ_IDX" > "$tmp" &&
    mv "$tmp" "$PROJ_IDX" || rm -f "$tmp"
}
