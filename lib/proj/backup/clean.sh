# backup/clean.sh - limpeza automática de backups velhos + proj config / proj clean
# Globals de trabalho: _CL_N (qtde) _CL_B (bytes) _CL_DRY (simulação) _CL_Q (silencioso)
# Imunidade: nunca apaga backup de projeto com a tag $IMUNE_TAG; sempre mantém as CLEAN_MIN mais novas.

# @in arquivo  @effect apaga (ou só conta, se _CL_DRY) o .tar.gz e o .meta
proj_clean_del() {
  local f="$1" sz verbo; sz=$(stat -c %s "$f" 2>/dev/null); sz=${sz:-0}
  _CL_N=$((_CL_N+1)); _CL_B=$((_CL_B+sz))
  if [ -z "$_CL_Q" ]; then
    verbo=apagado; [ -n "$_CL_DRY" ] && verbo=apagaria
    printf '  %s %s (%s)\n' "$verbo" "${f##*/}" "$(proj_hum "$sz")"
  fi
  [ -n "$_CL_DRY" ] || rm -f "$f" "${f%.tar.gz}.meta"
}

# @in dir  cópias com mais de CLEAN_DIAS dias; nunca as CLEAN_MIN mais novas de cada chave
# (antes: basename + sed + ls|grep|cut por arquivo; agora: glob + loop em bash)
proj_clean_dir() {
  local dir="$1" f key meta tg pos i
  local S='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]'
  [ -d "$dir" ] || return 0
  while IFS= read -r f; do
    key="${f##*/}"; key="${key%.tar.gz}"; key="${key%-$S}"
    meta="${f%.tar.gz}.meta"
    if [ -f "$meta" ]; then
      { read -r _; read -r tg; } < "$meta"
      proj_is_imune "$tg" && continue
    fi
    pos=0
    if _proj_desc "$dir/$key"-$S.tar.gz; then
      for i in "${!BK_F[@]}"; do [ "${BK_F[i]}" = "$f" ] && { pos=$((i+1)); break; }; done
    fi
    (( pos <= ${CLEAN_MIN:-1} )) && continue
    proj_clean_del "$f"
  done < <(find "$dir" -maxdepth 1 -name '*.tar.gz' -mtime +"${CLEAN_DIAS:-30}" 2>/dev/null)
}

# backups periódicos acima do "manter"
# (antes: 1 awk no índice por projeto; agora: tags carregadas 1x num array)
# @g PROJ_IDX BKP_CFG CLEAN_MIN  @effect apaga backups periódicos acima do "manter" (pula imunes)
proj_clean_rotate() {
  local k s keep f n v d desc c t i
  local -A tg=()
  while IFS=$'\t' read -r n v d desc c t _; do tg["$n-$v"]=$t; done < "$PROJ_IDX"
  while IFS=$'\t' read -r k s keep; do
    [ -z "$k" ] && continue
    proj_is_imune "${tg[$k]:-}" && continue
    [ "${keep:-5}" -lt "${CLEAN_MIN:-1}" ] && keep="${CLEAN_MIN:-1}"
    if _proj_desc "$PROJ_BKP/$k"/*.tar.gz; then
      for (( i=keep; i<${#BK_F[@]}; i++ )); do proj_clean_del "${BK_F[i]}"; done
    fi
  done < "$BKP_CFG"
}

# @in [-n|dry] [quiet]
proj_clean_run() {
  local a
  _CL_N=0; _CL_B=0; _CL_DRY=""; _CL_Q=""
  for a in "$@"; do case "$a" in -n|dry) _CL_DRY=1;; quiet) _CL_Q=1;; esac; done
  proj_clean_dir "$PROJ_BKP/removidos"
  proj_clean_dir "$PROJ_BKP/pre-restore"
  proj_clean_rotate
  if [ -z "$_CL_Q" ]; then
    if [ "$_CL_N" -eq 0 ]; then echo "Nada para limpar."
    else echo "${_CL_DRY:+(simulação) }$_CL_N arquivo(s), $(proj_hum "$_CL_B")"; fi
  fi
  [ -z "$_CL_DRY" ] && [ "$_CL_N" -gt 0 ] && proj_notify "Limpeza: $_CL_N arquivo(s), $(proj_hum "$_CL_B") liberados"
  return 0
}

# @effect no máx. 1x/dia, com trava
proj_clean_auto() {
  [ "${CLEAN_ON:-1}" = 1 ] || return 0
  local st="$PROJ_DIR/.clean"
  [ -f "$st" ] && [ -z "$(find "$st" -mmin +1440 2>/dev/null)" ] && return 0
  touch "$st"
  proj_lockrun clean proj_clean_run quiet
}

# @in [chave [valor]]  @effect lista, lê ou grava em $PROJ_CFG
proj_config() {
  local k
  if [ -z "$1" ]; then
    for k in PROJ_COLOR CLEAN_ON CLEAN_DIAS CLEAN_MIN IMUNE_TAG BKP_IV BKP_KEEP SIZE_WARN_MB FREE_WARN_MB NOTIFY HOOKS PROJ_UI_KEY PROJ_PICK BKP_ALL CMP_LINES; do
      printf '%s%-13s%s %s\n' "$PC_D" "$k" "$PC_RST" "${!k}"
    done; return
  fi
  case "$1" in PROJ_COLOR|CLEAN_ON|CLEAN_DIAS|CLEAN_MIN|IMUNE_TAG|BKP_IV|BKP_KEEP|SIZE_WARN_MB|FREE_WARN_MB|NOTIFY|HOOKS|PROJ_UI_KEY|PROJ_PICK|BKP_ALL|CMP_LINES) ;;
    *) echo "Chave inválida: $1 (veja: proj config)" >&2; return 1;; esac
  [ -z "$2" ] && { echo "$1=${!1}"; return; }
  [[ "$2" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Valor inválido." >&2; return 1; }
  { grep -v "^$1=" "$PROJ_CFG" 2>/dev/null; echo "$1=$2"; } > "$PROJ_CFG.tmp" && mv "$PROJ_CFG.tmp" "$PROJ_CFG"
  echo "$1=$2"
}

# proj clean [on|off|dias N|min N|now|-n]
# @in on|off|dias N|min N|now|-n  @effect grava em $PROJ_CFG ou roda proj_clean_run  @ret 1 se N inválido
proj_clean() {
  local a="${1:-status}"; [ $# -gt 0 ] && shift
  case "$a" in
    on)  proj_config CLEAN_ON 1 >/dev/null; echo "Limpeza automática ${PC_G}ligada${PC_RST}.";;
    off) proj_config CLEAN_ON 0 >/dev/null; echo "Limpeza automática ${PC_R}desligada${PC_RST}.";;
    dias) [[ "$1" =~ ^[0-9]+$ ]] || { echo "uso: proj clean dias <N>"; return 1; }
          proj_config CLEAN_DIAS "$1" >/dev/null; echo "Idade mínima: $1 dias.";;
    min)  [[ "$1" =~ ^[0-9]+$ ]] || { echo "uso: proj clean min <N>"; return 1; }
          proj_config CLEAN_MIN "$1" >/dev/null; echo "Mínimo mantido por projeto: $1.";;
    -n|dry) proj_clean_run -n;;
    now) proj_clean_run "$@";;
    status|*)
      printf 'Limpeza automática: %s | idade mínima: %s dias | mantém ao menos %s por projeto | imunidade: tag "%s"\n' \
        "$([ "${CLEAN_ON:-1}" = 1 ] && echo ligada || echo desligada)" "$CLEAN_DIAS" "$CLEAN_MIN" "$IMUNE_TAG"
      echo "uso: proj clean on|off | dias N | min N | now | -n (simula)";;
  esac
}
