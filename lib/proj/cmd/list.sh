# cmd/list.sh - ls, recent, stale, grep
# Linha de proj_rows: n v d desc cat tags criado | acesso acessos bytes fav
# @uses proj_rows proj_hum proj_ago proj_is_imune proj_size_all

# proj ls [filtro] [-j|-t] [-s|-r|-a] [-p] [-f]
# @in [filtro] [-j|-t] [-s|-r|-a] [-p] [-f]  @out stdout tabela | json | tsv  @g PC_* SIZE_WARN_MB COLUMNS
# @uses proj_rows proj_hum proj_ago proj_is_imune proj_size_all proj_rule
proj_ls() {
  local fmt="" sk=fav filt="" force="" showp="" W nw fx showc rest rows
  local n v d desc c t cr last cnt size fav mark col
  local total=0 np=0 miss=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -j|--json) fmt=json;; -t|--tsv) fmt=tsv;;
      -s) sk=size;; -r) sk=recent;; -a) sk=alpha;;
      -p) showp=1;; -f) force=1;;
      *) filt="$1";;
    esac; shift
  done
  [ -n "$force" ] && { echo "Recalculando tamanhos..." >&2; proj_size_all force; }
  rows=$(proj_rows | awk -F'\t' -v f="$filt" 'f=="" || index($1,f) || index($5,f) || index($6,f)')
  if [ -z "$rows" ]; then
    [ "$fmt" = json ] && echo '[]'
    [ -z "$fmt" ] && echo "Nenhum projeto${filt:+ para '$filt'}."
    return 0
  fi
  case "$sk" in
    size)   rows=$(sort -t$'\t' -k10,10nr -k1,1 <<<"$rows");;
    recent) rows=$(sort -t$'\t' -k8,8nr -k1,1 <<<"$rows");;
    alpha)  rows=$(sort -t$'\t' -k1,1 -k2,2V <<<"$rows");;
    *)      rows=$(sort -t$'\t' -k11,11nr -k1,1 -k2,2V <<<"$rows");;
  esac
  case "$fmt" in
    tsv) printf 'nome\tversao\tdir\tdescricao\tcategoria\ttags\tcriado\tultimo_acesso\tacessos\tbytes\tfav\n'
         printf '%s\n' "$rows"; return;;
    json) awk -F'\t' '
      function e(s) { gsub(/\\/,"",s); gsub(/"/,"\\\"",s); return s }
      BEGIN { printf "[" }
      { printf "%s{\"nome\":\"%s\",\"versao\":\"%s\",\"dir\":\"%s\",\"descricao\":\"%s\",\"categoria\":\"%s\",\"tags\":\"%s\",\"criado\":\"%s\",\"ultimo_acesso\":%d,\"acessos\":%d,\"bytes\":%d,\"fav\":%d}", (NR>1?",":""), e($1),e($2),e($3),e($4),e($5),e($6),e($7),$8,$9,$10,$11 }
      END { print "]" }' <<<"$rows"; return;;
  esac
  W="${COLUMNS:-0}"; case "$W" in ''|*[!0-9]*) W=0;; esac
  [ "$W" -gt 0 ] || W=$(tput cols 2>/dev/null || echo 80)
  nw=$(awk -F'\t' '{ if (length($1)>m) m=length($1) } END{ print m+0 }' <<<"$rows")
  [ "$nw" -lt 6 ] && nw=6; [ "$nw" -gt 20 ] && nw=20
  fx=$((3+1+nw+1+7+1+7+1+6+1)); showc=0
  if [ "$W" -ge $((fx+13+12)) ]; then showc=1; fx=$((fx+13)); fi
  rest=$((W-fx)); [ "$rest" -lt 8 ] && rest=0
  printf '%s    %-*s %-7s ' "$PC_H" "$nw" NOME VERSAO
  [ $showc = 1 ] && printf '%-12s ' CATEGORIA
  printf '%7s %-6s ' TAM ULTIMO
  [ "$rest" -gt 0 ] && printf 'DESCRICAO'
  printf '%s\n' "$PC_RST"
  proj_rule "$W"
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    np=$((np+1)); total=$((total+${size:-0})); [ "${size:-0}" -eq 0 ] && miss=$((miss+1))
    mark=" "; [ "$fav" = 1 ] && mark="★"
    if proj_is_imune "$t"; then mark="$mark🔒"; else mark="$mark  "; fi
    printf '%s ' "$mark"
    printf '%s%-*.*s%s ' "$PC_B" "$nw" "$nw" "$n" "$PC_RST"
    printf '%sv%-6.6s%s ' "$PC_D" "$v" "$PC_RST"
    [ $showc = 1 ] && printf '%s%-12.12s%s ' "$PC_C" "$c" "$PC_RST"
    col="$PC_RST"; [ "${size:-0}" -gt $(( SIZE_WARN_MB * 1048576 )) ] && col="$PC_R"
    if [ "${size:-0}" -gt 0 ]; then printf '%s%7s%s ' "$col" "$(proj_hum "$size")" "$PC_RST"; else printf '%7s ' "-"; fi
    printf '%s%-6s%s ' "$PC_D" "$(proj_ago "$last")" "$PC_RST"
    if [ "$rest" -gt 0 ] && [ "$desc" != "-" ]; then
      if [ "${#desc}" -gt "$rest" ]; then printf '%s…' "${desc:0:rest-1}"; else printf '%s' "$desc"; fi
    fi
    printf '\n'
    [ -n "$showp" ] && printf '%s    %s%s\n' "$PC_D" "$d" "$PC_RST"
  done <<<"$rows"
  proj_rule "$W"
  printf '%s%d projeto(s) · total %s%s\n' "$PC_D" "$np" "$(proj_hum "$total")" "$PC_RST"
  if [ "$miss" -gt 0 ]; then
    printf '%s(%d sem tamanho em cache; calculando em segundo plano)%s\n' "$PC_D" "$miss" "$PC_RST"
    ( proj_size_all >/dev/null 2>&1 & )
  fi
}

# @in [N=10]  últimos projetos acessados
proj_recent() {
  local lim="${1:-10}" n v d desc c t cr last cnt size fav
  [[ "$lim" =~ ^[0-9]+$ ]] || lim=10
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    printf '%s%-6s%s %s%-18s%s %sv%-7s %sx%s\n' "$PC_D" "$(proj_ago "$last")" "$PC_RST" "$PC_B" "$n" "$PC_RST" "$PC_D" "$v" "$cnt" "$PC_RST"
  done < <(proj_rows | awk -F'\t' '$8>0' | sort -t$'\t' -k8,8nr | head -n "$lim")
}

# @in [dias=30]  projetos sem acesso há mais de N dias
proj_stale() {
  local days="${1:-30}" cut now n v d desc c t cr last cnt size fav found=0
  [[ "$days" =~ ^[0-9]+$ ]] || days=30
  printf -v now '%(%s)T' -1
  cut=$(( now - days*86400 ))
  echo "Sem acesso há mais de $days dias:"
  while IFS=$'\t' read -r n v d desc c t cr last cnt size fav; do
    found=1
    printf '  %s%-18s%s v%-7s %-6s %7s%s\n' "$PC_B" "$n" "$PC_RST" "$v" "$(proj_ago "$last")" "$([ "$size" -gt 0 ] && proj_hum "$size" || echo -)" "$(proj_is_imune "$t" && echo ' 🔒')"
  done < <(proj_rows | awk -F'\t' -v c="$cut" '$8<c' | sort -t$'\t' -k8,8n)
  [ $found = 0 ] && echo "  (nenhum)"
  echo "${PC_D}Dica: proj archive <nome> guarda sem apagar.${PC_RST}"
}

# proj grep [-i] <texto>   (antes: 1 subshell com cd por projeto; agora grep direto no caminho)
# @in [-i] texto  @out stdout "projeto/arquivo:linha:texto" (máx. 200)  @ret 1 sem texto
proj_grep() {
  local ic="" txt="" n v d x l
  for x in "$@"; do case "$x" in -i) ic="-i";; *) txt="$x";; esac; done
  [ -z "$txt" ] && { echo "uso: proj grep [-i] <texto>"; return 1; }
  while IFS=$'\t' read -r n v d x; do
    [ -d "$d" ] || continue
    grep -rIn $ic --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.cache -e "$txt" "$d" 2>/dev/null |
      while IFS= read -r l; do printf '%s%s%s/%s\n' "$PC_C" "$n" "$PC_RST" "${l#"$d"/}"; done
  done < "$PROJ_IDX" | head -n 200
}
