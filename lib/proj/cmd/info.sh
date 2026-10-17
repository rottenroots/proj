# cmd/info.sh - proj info [alvo] [-j]
# @uses proj_resolve proj_st_get proj_st_set proj_size_calc proj_fmt_secs proj_fdate proj_hum proj_kv _proj_desc
proj_info() {
  local json="" arg="" x desc c t cr row last cnt fav d k n v
  local sz_t sz_f mod bk iv keep bcnt blast bstat vend gitb gitn free lock=0 now bkk bs
  for x in "$@"; do case "$x" in -j|--json) json=1;; *) arg="$x";; esac; done
  proj_resolve "${arg:-.}" || return 1
  n="$T_N"; v="$T_V"; d="$T_D"; k="$T_K"
  IFS=$'\t' read -r _ _ _ desc c t cr <<< "$T_L"
  [ -d "$d" ] || { echo "A pasta não existe mais: $d" >&2; return 1; }
  proj_is_imune "$t" && lock=1
  row=$(proj_st_get "$k")
  IFS=$'\t' read -r _ last cnt _ _ fav _ <<<"$row"
  sz_t=$(du -sb "$d" 2>/dev/null); sz_t=${sz_t%%[[:space:]]*}
  sz_f=$(proj_size_calc "$d")
  printf -v now '%(%s)T' -1
  proj_st_set "$k" "4:${sz_f:-0}" "5:$now"
  mod=$(find "$d" \( -name .git -o -name node_modules -o -name .cache \) -prune -o -type f -printf '%T@\n' 2>/dev/null |
        awk '$1>m{m=$1} END{printf "%d", m}')
  bk=
  while IFS=$'\t' read -r bkk bs keep; do
    [ "$bkk" = "$k" ] && { bk=1; iv=$bs; break; }
  done < "$BKP_CFG"
  if _proj_desc "$PROJ_BKP/$k"/*.tar.gz; then
    bcnt=${#BK_F[@]}; blast=$(stat -c %Y "${BK_F[0]}")
  else bcnt=0; blast=0; fi
  vend=$(find "$d/refs" -maxdepth 1 -type l -printf '%f ' 2>/dev/null)
  if [ -d "$d/.git" ] && command -v git >/dev/null 2>&1; then
    gitb=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null)
    gitn=$(git -C "$d" status --porcelain 2>/dev/null | wc -l)
  fi
  if [ -n "$json" ]; then
    printf '{"nome":"%s","versao":"%s","dir":"%s","descricao":"%s","categoria":"%s","tags":"%s","criado":"%s","ultimo_acesso":%d,"acessos":%d,"bytes":%d,"bytes_total":%d,"modificado":%d,"imune":%s,"fav":%s,"backup_ativo":%s,"backups":%d,"ultimo_backup":%d,"vendors":"%s","git_branch":"%s","git_alteracoes":%d}\n' \
      "$(proj_jesc "$n")" "$(proj_jesc "$v")" "$(proj_jesc "$d")" "$(proj_jesc "$desc")" "$(proj_jesc "$c")" "$(proj_jesc "$t")" "$(proj_jesc "$cr")" \
      "${last:-0}" "${cnt:-0}" "${sz_f:-0}" "${sz_t:-0}" "${mod%.*}" \
      "$([ $lock = 1 ] && echo true || echo false)" "$([ "$fav" = 1 ] && echo true || echo false)" \
      "$([ -n "$bk" ] && echo true || echo false)" "$bcnt" "$blast" "$(proj_jesc "${vend% }")" "$(proj_jesc "$gitb")" "${gitn:-0}"
    return
  fi
  if [ -n "$bk" ]; then
    bstat="${PC_G}ativo${PC_RST} (a cada $(proj_fmt_secs "$iv"), mantém $keep) · $bcnt cópia(s) · última $(proj_fdate "$blast")"
  else
    bstat="${PC_R}off${PC_RST}$([ "$bcnt" -gt 0 ] && echo " · $bcnt cópia(s) antigas")"
  fi
  free=$(proj_free_mb "$d")
  printf '%s%s%s %sv%s%s' "$PC_H" "$n" "$PC_RST" "$PC_D" "$v" "$PC_RST"
  [ $lock = 1 ] && printf ' 🔒 imune'; [ "$fav" = 1 ] && printf ' %s★%s' "$PC_Y" "$PC_RST"
  printf '\n'
  [ "$desc" != "-" ] && printf '%s%s%s\n' "$PC_D" "$desc" "$PC_RST"
  proj_rule
  proj_kv caminho "$d"
  proj_kv categoria "$c"
  proj_kv tags "${t//,/ }"
  proj_kv criado "${cr}"
  proj_sec atividade
  proj_kv modificado "$(proj_fdate "${mod%.*}")"
  proj_kv acesso "$(proj_fdate "${last:-0}") · ${cnt:-0}x"
  proj_kv tamanho "$(proj_hum "$sz_f") (sem node_modules/.cache) · total $(proj_hum "$sz_t")"
  proj_sec "backup e disco"
  proj_kv backup "$bstat"
  proj_kv vendor "${vend:--}"
  [ -n "$gitb" ] && proj_kv git "$gitb · $gitn alteração(ões) pendente(s)"
  proj_kv livre "$(proj_hum $(( ${free:-0} * 1048576 )))"
  proj_rule
}
