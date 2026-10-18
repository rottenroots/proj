# cmd/pick.sh - seletor interativo de projetos (estilo mc)
# shellcheck disable=SC2154
# locais de proj_pick vistos pelos helpers (escopo dinâmico): filt sel top h tot msg R bk

# @in [filtro]  @effect tela cheia; ⏎ entra no projeto (cd no shell atual)
# @effect b/f/x gravam backup, favorito e imunidade na hora  @ret 1 sem terminal
# @uses proj_rows proj_resolve proj_enter proj_info proj_backup proj_fav proj_lock proj_pad
proj_pick() {
  [ -t 0 ] && [ -t 1 ] || return 1
  proj_boot
  local filt="${1:-}" sel=0 top=0 h tot key rest msg="" go=""
  local n v d desc c t cr last cnt size fav
  local -a R=()
  local -A bk=()
  trap '_pick_leave; trap - INT; return 130' INT
  printf '\e[?1049h\e[?25l'
  while :; do
    _pick_load
    tot=${#R[@]}
    (( sel >= tot )) && sel=$(( tot > 0 ? tot - 1 : 0 ))
    h=$(( ${LINES:-24} - 8 )); (( h < 3 )) && h=3
    (( sel < top )) && top=$sel
    (( sel >= top + h )) && top=$(( sel - h + 1 ))
    _pick_draw
    IFS= read -rsn1 key || break
    if [[ $key == $'\e' ]]; then
      rest=""; read -rsn2 -t 0.05 rest
      case $rest in
        '') key=q;;
        '[A'|OA) key=k;;
        '[B'|OB) key=j;;
        *) key=_;;
      esac
    fi
    msg=""
    (( tot > 0 )) && IFS=$'\t' read -r n v d desc c t cr last cnt size fav <<<"${R[sel]}"
    case $key in
      j) (( tot > 0 )) && sel=$(( (sel + 1) % tot ));;
      k) (( tot > 0 )) && sel=$(( (sel - 1 + tot) % tot ));;
      g) sel=0;;
      G) sel=$(( tot > 0 ? tot - 1 : 0 ));;
      '') (( tot > 0 )) && { go="$n@$v"; break; };;
      i) (( tot > 0 )) || continue
         printf '\e[2J\e[H'; proj_info "$n@$v"
         printf '\n%s (qualquer tecla)%s' "$PC_D" "$PC_RST"; read -rsn1 _;;
      b) (( tot > 0 )) || continue
         if [ "${BKP_ALL:-0}" = 1 ]; then msg="backup global ligado (proj b all off)"
         elif [ -n "${bk["$n-$v"]:-}" ]; then msg=$(proj_backup off "$n@$v" 2>&1)
         else msg=$(proj_backup on "$n@$v" 2>&1); fi;;
      f) (( tot > 0 )) || continue
         if [ "$fav" = 1 ]; then msg=$(proj_fav 0 "$n@$v" 2>&1); else msg=$(proj_fav 1 "$n@$v" 2>&1); fi;;
      x) (( tot > 0 )) || continue
         if proj_is_imune "$t"; then msg=$(proj_lock off "$n@$v" 2>&1); else msg=$(proj_lock on "$n@$v" 2>&1); fi;;
      /) printf '\e[?25h\n\e[K filtro: '; IFS= read -re filt; printf '\e[?25l'; sel=0; top=0;;
      q) break;;
    esac
  done
  _pick_leave; trap - INT
  if [ -n "$go" ]; then proj_resolve "$go" q && proj_enter; fi
  return 0
}

# @effect sai da tela alternativa
_pick_leave() { printf '\e[?25h\e[?1049l'; }

# @effect recarrega R (linhas de proj_rows, favoritos primeiro) e bk (chaves com backup próprio)
_pick_load() {
  local k _a _b
  bk=()
  while IFS=$'\t' read -r k _a _b; do [ -n "$k" ] && bk[$k]=1; done < "$BKP_CFG"
  mapfile -t R < <(proj_rows | awk -F'\t' -v f="$filt" 'f=="" || index($1,f) || index($5,f) || index($6,f)' |
                   sort -t$'\t' -k11,11nr -k1,1 -k2,2V)
}

# @effect redesenha a tela (sem limpar antes: sem piscar)
_pick_draw() {
  local i end n v d desc c t cr last cnt size fav mark fl lk bm nm sz col hdr=""
  [ -n "$filt" ] && hdr="  filtro: $filt"
  [ "${BKP_ALL:-0}" = 1 ] && hdr="$hdr  backup: todos"
  printf '\e[H%s proj · projetos%s%s%s%s\e[K\n' "$PC_H" "$PC_RST" "$PC_D" "$hdr" "$PC_RST"
  proj_rule
  (( tot == 0 )) && printf ' (nenhum projeto)\e[K\n'
  end=$(( top + h )); (( end > tot )) && end=$tot
  for (( i=top; i<end; i++ )); do
    IFS=$'\t' read -r n v d desc c t cr last cnt size fav <<<"${R[i]}"
    if (( i == sel )); then mark="${PC_H}▸${PC_RST}"; else mark=" "; fi
    fl=" "; [ "$fav" = 1 ] && fl="${PC_Y}★${PC_RST}"
    lk="  "; proj_is_imune "$t" && lk="🔒"
    bm="${PC_D}·${PC_RST}"
    if [ -n "${bk["$n-$v"]:-}" ] || [ "${BKP_ALL:-0}" = 1 ]; then bm="${PC_G}●${PC_RST}"; fi
    proj_pad "${n:0:14}" 14; nm=$REPLY
    if (( i == sel )); then nm="${PC_H}${nm}${PC_RST}"; else nm="${PC_B}${nm}${PC_RST}"; fi
    sz="-"; col="$PC_RST"
    if [ "${size:-0}" -gt 0 ]; then
      sz=$(proj_hum "$size")
      [ "$size" -gt $(( ${SIZE_WARN_MB:-500} * 1048576 )) ] && col="$PC_R"
    fi
    printf '%s%s%s %s %s %s%-7s%s %s%7s%s %s%-6s%s\e[K\n' \
      "$mark" "$fl" "$lk" "$bm" "$nm" "$PC_D" "v$v" "$PC_RST" "$col" "$sz" "$PC_RST" \
      "$PC_D" "$(proj_ago "$last")" "$PC_RST"
  done
  if (( tot > 0 )); then
    IFS=$'\t' read -r _ _ d desc _ <<<"${R[sel]}"
    [ "$desc" = "-" ] && desc=""
    printf '%s %s%s\e[K\n' "$PC_D" "${desc:-${d/#$HOME/\~}}" "$PC_RST"
  else
    printf '\e[K\n'
  fi
  printf ' %s%s%s\e[K\n' "$PC_Y" "${msg//$'\n'/ }" "$PC_RST"
  printf '%s ↑↓ mover  ⏎ entrar  i info  / filtrar\e[K\n b backup  f fav  x imune  q sair%s\e[K\n\e[J' "$PC_D" "$PC_RST"
}
