# store/size.sh - tamanho em disco (cache de 1h em estado.tsv, campos 4=bytes 5=bytes_ts)

# @in dir  @out stdout bytes (ignora node_modules e .cache)
proj_size_calc() {
  local s
  s=$(du -sb --exclude=node_modules --exclude=.cache "$1" 2>/dev/null)
  printf '%s\n' "${s%%[[:space:]]*}"
}

# @in chave dir [force]  @effect recalcula se o cache tem > 1h
proj_size_refresh() {
  local ts now s
  printf -v now '%(%s)T' -1
  IFS=$'\t' read -r _ _ _ _ ts _ <<<"$(proj_st_get "$1")"
  [ "$3" != force ] && [ $(( now - ${ts:-0} )) -lt 3600 ] && return 0
  [ -d "$2" ] || return 0
  s=$(proj_size_calc "$2"); [ -z "$s" ] && return 0
  proj_st_set "$1" "4:$s" "5:$now"
}

# @in [force]  @effect refresh de todos
# (antes: awk+cut+date por projeto mesmo com cache válido; agora lê o estado 1x
#  e só chama refresh nos vencidos)
proj_size_all() {
  local n v d x k t now
  local -A ts=()
  printf -v now '%(%s)T' -1
  while read -r k t; do ts[$k]=$t; done < <(awk -F'\t' '{print $1, ($5==""?0:$5)}' "$PROJ_ST" 2>/dev/null)
  while IFS=$'\t' read -r n v d x; do
    k="$n-$v"
    [ "$1" != force ] && (( now - ${ts[$k]:-0} < 3600 )) && continue
    proj_size_refresh "$k" "$d" force
  done < "$PROJ_IDX"
}
