# cmd/pick.sh - seletor interativo de projetos (estilo mc), com seleção múltipla
# shellcheck disable=SC2154
# locais de proj_pick vistos pelos helpers (escopo dinâmico): filt sel top h tot msg dirty R TG bk mk RI

# @in [filtro]  @effect tela cheia; ⏎ entra no projeto (cd no shell atual)
# @effect espaço marca vários; b/f/x/t/T/z agem nos marcados (ou no selecionado) e gravam na hora
# @ret 1 sem terminal
# @uses proj_rows proj_resolve proj_enter proj_info proj_backup proj_fav proj_lock proj_tag proj_archive proj_pad
proj_pick() {
  [ -t 0 ] && [ -t 1 ] || return 1
  proj_boot
  local filt="${1:-}" sel=0 top=0 h tot=0 key rest msg="" go="" dirty=1
  local n v d desc c t cr last cnt size fav
  local -a R=() TG=()
  local -A bk=() mk=() RI=()
  trap '_pick_leave; trap - INT; return 130' INT
  printf '\e[?1049h\e[?25l'
  while :; do
    (( dirty )) && { _pick_load; dirty=0; }
    tot=${#R[@]}
    (( sel >= tot )) && sel=$(( tot > 0 ? tot - 1 : 0 ))
    h=$(( ${LINES:-24} - 10 )); (( h < 3 )) && h=3
    (( sel < top )) && top=$sel
    (( sel >= top + h )) && top=$(( sel - h + 1 ))
    _pick_draw
    IFS= read -rsn1 key || break
    if [[ $key == $'\e' ]]; then
      rest=""; read -rsn2 -t 0.05 rest
      case $rest in
        '') key=ESC;;
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
      ' ') if (( tot > 0 )); then
             if [ -n "${mk["$n@$v"]:-}" ]; then unset -v "mk[$n@$v]"; else mk["$n@$v"]=1; fi
             sel=$(( (sel + 1) % tot ))
           fi;;
      a) _pick_markall;;
      c) mk=();;
      ESC) if (( ${#mk[@]} > 0 )); then mk=(); else break; fi;;
      '') (( tot > 0 )) && { go="$n@$v"; break; };;
      i) (( tot > 0 )) || continue
         printf '\e[2J\e[H'; proj_info "$n@$v"
         printf '\n%s (qualquer tecla)%s' "$PC_D" "$PC_RST"; read -rsn1 _;;
      b) (( tot > 0 )) || continue
         if [ "${BKP_ALL:-0}" = 1 ]; then msg="backup global ligado (proj b all off)"
         else _pick_flag b; dirty=1; fi;;
      f) (( tot > 0 )) || continue; _pick_flag f; dirty=1;;
      x) (( tot > 0 )) || continue; _pick_flag x; dirty=1;;
      t) (( tot > 0 )) || continue; _pick_tag add; dirty=1;;
      T) (( tot > 0 )) || continue; _pick_tag rm; dirty=1;;
      z) (( tot > 0 )) || continue; _pick_archive; dirty=1;;
      /) printf '\e[?25h\n\e[K filtro: '; IFS= read -re filt; printf '\e[?25l'; sel=0; top=0; dirty=1;;
      q) break;;
    esac
  done
  _pick_leave; trap - INT
  if [ -n "$go" ]; then proj_resolve "$go" q && proj_enter; fi
  return 0
}

# @effect sai da tela alternativa
_pick_leave() { printf '\e[?25h\e[?1049l'; }

# @effect recarrega R (filtrado, favoritos primeiro), RI (todas as linhas por n@v) e bk (backup próprio)
_pick_load() {
  local k a b rows r
  bk=(); RI=()
  while IFS=$'\t' read -r k a b; do [ -n "$k" ] && bk[$k]=1; done < "$BKP_CFG"
  rows=$(proj_rows)
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    IFS=$'\t' read -r k a _ <<<"$r"
    RI["$k@$a"]=$r
  done <<<"$rows"
  for k in "${!mk[@]}"; do [ -n "${RI[$k]:-}" ] || unset -v "mk[$k]"; done
  mapfile -t R < <(awk -F'\t' -v f="$filt" 'f=="" || index($1,f) || index($5,f) || index($6,f)' <<<"$rows" |
                   sort -t$'\t' -k11,11nr -k1,1 -k2,2V)
}

# @effect marca todos os visíveis; se já estavam todos marcados, desmarca
_pick_markall() {
  local r k1 k2 allm=1
  for r in "${R[@]}"; do IFS=$'\t' read -r k1 k2 _ <<<"$r"; [ -n "${mk["$k1@$k2"]:-}" ] || allm=0; done
  for r in "${R[@]}"; do
    IFS=$'\t' read -r k1 k2 _ <<<"$r"
    if (( allm )); then unset -v "mk[$k1@$k2]"; else mk["$k1@$k2"]=1; fi
  done
}

# @out TG = n@v dos marcados, ou do selecionado se nada estiver marcado
_pick_targets() {
  local k
  TG=()
  if (( ${#mk[@]} > 0 )); then
    for k in "${!mk[@]}"; do TG+=("$k"); done
  else
    TG=("$n@$v")
  fi
}

# @in b|f|x  @effect liga em todos se algum alvo não tem; senão desliga em todos
_pick_flag() {
  local k a b t fav r cnt=0 want=0 lbl
  _pick_targets
  for k in "${TG[@]}"; do
    IFS=$'\t' read -r a b _ _ _ t _ _ _ _ fav <<<"${RI[$k]}"
    case $1 in
      b) [ -n "${bk["$a-$b"]:-}" ] || want=1;;
      f) [ "$fav" = 1 ] || want=1;;
      x) proj_is_imune "$t" || want=1;;
    esac
  done
  for k in "${TG[@]}"; do
    r=0
    case $1 in
      b) proj_backup "$( ((want)) && echo on || echo off)" "$k" >/dev/null 2>&1 || r=1;;
      f) proj_fav "$want" "$k" >/dev/null 2>&1 || r=1;;
      x) proj_lock "$( ((want)) && echo on || echo off)" "$k" >/dev/null 2>&1 || r=1;;
    esac
    (( r == 0 )) && cnt=$((cnt+1))
  done
  case $1 in b) lbl=backup;; f) lbl=favorito;; x) lbl=imunidade;; esac
  msg="$lbl $( ((want)) && echo ligado || echo desligado): $cnt de ${#TG[@]}"
}

# @in add|rm  @effect pergunta as tags (a,b,c) e aplica nos alvos
_pick_tag() {
  local tg k cnt=0 op=$1
  printf '\e[?25h\n\e[K tags (a,b,c): '
  IFS= read -re tg
  printf '\e[?25l'
  [ -n "$tg" ] || return 0
  _pick_targets
  for k in "${TG[@]}"; do
    proj_tag "$op" "$tg" "$k" >/dev/null 2>&1 && cnt=$((cnt+1))
  done
  msg="tag $op '$tg': $cnt de ${#TG[@]}"
}

# @effect arquiva os alvos (pede confirmação; pula imunes)
_pick_archive() {
  local k t ans cnt=0 skip=0
  _pick_targets
  printf '\n\e[K Arquivar %d projeto(s)? [s/N] ' "${#TG[@]}"
  read -rsn1 ans
  case $ans in s|S|y|Y) ;; *) msg="cancelado"; return 0;; esac
  for k in "${TG[@]}"; do
    IFS=$'\t' read -r _ _ _ _ _ t _ <<<"${RI[$k]}"
    if proj_is_imune "$t"; then skip=$((skip+1)); continue; fi
    proj_archive "$k" >/dev/null 2>&1 && cnt=$((cnt+1))
  done
  mk=()
  msg="arquivados: $cnt"
  (( skip > 0 )) && msg="$msg · imunes ignorados: $skip"
  return 0
}

# @effect redesenha a tela (sem limpar antes: sem piscar)
_pick_draw() {
  local i end n v d desc c t cr last cnt size fav mark ck fl lk bm nm sz col hdr=""
  [ -n "$filt" ] && hdr="  filtro: $filt"
  [ "${BKP_ALL:-0}" = 1 ] && hdr="$hdr  backup: todos"
  (( ${#mk[@]} > 0 )) && hdr="$hdr  ${#mk[@]} marcado(s)"
  printf '\e[H%s proj · projetos%s%s%s%s\e[K\n' "$PC_H" "$PC_RST" "$PC_D" "$hdr" "$PC_RST"
  proj_rule
  (( tot == 0 )) && printf ' (nenhum projeto)\e[K\n'
  end=$(( top + h )); (( end > tot )) && end=$tot
  for (( i=top; i<end; i++ )); do
    IFS=$'\t' read -r n v d desc c t cr last cnt size fav <<<"${R[i]}"
    if (( i == sel )); then mark="${PC_H}▸${PC_RST}"; else mark=" "; fi
    if [ -n "${mk["$n@$v"]:-}" ]; then ck="${PC_G}✓${PC_RST}"; else ck=" "; fi
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
    printf '%s%s%s%s %s %s %s%-7s%s %s%7s%s %s%-6s%s\e[K\n' \
      "$mark" "$ck" "$fl" "$lk" "$bm" "$nm" "$PC_D" "v$v" "$PC_RST" "$col" "$sz" "$PC_RST" \
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
  printf '%s ↑↓ mover  ⏎ entrar  i info  / filtro\e[K\n espaço marca  a todos  c limpa\e[K\n b backup  f fav  x imune  t tag\e[K\n T tira tag  z arquiva  q sair%s\e[K\n\e[J' "$PC_D" "$PC_RST"
}
