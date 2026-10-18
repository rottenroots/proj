# backup/backup.sh - backups periódicos (tar.gz em $PROJ_BKP/<chave>/AAAAMMDD-HHMMSS.tar.gz)
# BKP_CFG: chave <TAB> segundos <TAB> manter
# @uses proj_resolve proj_lockrun proj_notify proj_free_mb proj_hum _proj_desc

# @in 30m|12h|1d|2w  @out stdout segundos  @ret 1 se inválido
proj_secs() {
  local n="${1%[mhdw]}" u="${1##*[0-9]}"
  case "$n" in ''|*[!0-9]*) echo "Intervalo inválido: $1 (use 30m, 12h, 1d, 1w)" >&2; return 1;; esac
  case "$u" in
    m) echo $((n*60));;
    h) echo $((n*3600));;
    d) echo $((n*86400));;
    w) echo $((n*604800));;
    *) echo "Intervalo inválido: $1 (use 30m, 12h, 1d, 1w)" >&2; return 1;;
  esac
}

# @in segundos  @out stdout 30m|12h|1d|1w
proj_fmt_secs() {
  local s="$1"
  if   (( s % 604800 == 0 )); then echo "$((s/604800))w"
  elif (( s % 86400  == 0 )); then echo "$((s/86400))d"
  elif (( s % 3600   == 0 )); then echo "$((s/3600))h"
  else echo "$((s/60))m"; fi
}

# @in chave dir [manter]  @effect cria tar.gz, verifica, poda acima de "manter", avisa pouco espaço
# (antes: date + dirname + basename + ls|tail|xargs; agora só tar)
proj_backup_do() {
  local k="$1" d="$2" keep="${3:-5}" out="$PROJ_BKP/$1" f r fr i stamp
  mkdir -p "$out"
  printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
  f="$out/$stamp.tar.gz"
  tar -czf "$f" --exclude=node_modules --exclude=.cache \
    -C "${d%/*}" "${d##*/}" 2>/dev/null; r=$?
  if [ $r -le 1 ] && tar -tzf "$f" >/dev/null 2>&1; then   # verifica o arquivo gerado
    if _proj_desc "$out"/*.tar.gz; then
      for (( i=keep; i<${#BK_F[@]}; i++ )); do rm -f "${BK_F[i]}"; done
    fi
    fr=$(proj_free_mb "$PROJ_BKP"); [ -z "$fr" ] && fr=$(proj_free_mb "$HOME")
    [ "${fr:-999999}" -lt "${FREE_WARN_MB:-300}" ] && proj_notify "Pouco espaço livre: ${fr}MB (backup de $k)"
    return 0
  fi
  rm -f "$f"; proj_notify "Backup FALHOU: $k"
  return 1
}

# @in dir arquivo_ref  @ret 0 se algum arquivo é mais novo que a referência
proj_changed_since() {
  [ -n "$(find "$1" \( -name node_modules -o -name .cache -o -name .git \) -prune -o \
    -type f -newer "$2" -print -quit 2>/dev/null)" ]
}

# @in chave dir  @effect faz backup se o intervalo passou E algo mudou
# (antes: awk + 2 cut + ls|head + date; agora: 1 read + glob + 1 stat)
proj_backup_auto() {
  local k="$1" d="$2" kk s keep lf last now found=
  while IFS=$'\t' read -r kk s keep; do
    [ "$kk" = "$k" ] && { found=1; break; }
  done < "$BKP_CFG"
  if [ -z "$found" ]; then
    [ "${BKP_ALL:-0}" = 1 ] || return 0
    s=$(proj_secs "${BKP_IV:-1d}") || return 0; keep=${BKP_KEEP:-5}
  fi
  if _proj_desc "$PROJ_BKP/$k"/*.tar.gz; then
    lf="${BK_F[0]}"
    last=$(stat -c %Y "$lf")
    printf -v now '%(%s)T' -1
    (( now - last >= s )) || return 0
    proj_changed_since "$d" "$lf" || return 0      # nada mudou: pula
  fi
  proj_lockrun "bk-$k" proj_backup_do "$k" "$d" "$keep"
}

# @effect avisa (no máx. 1x/dia) se o espaço livre estiver baixo
proj_free_check() {
  local st="$PROJ_DIR/.free" f
  [ -f "$st" ] && [ -z "$(find "$st" -mmin +1440 2>/dev/null)" ] && return 0
  f=$(proj_free_mb "$HOME")
  if [ "${f:-999999}" -lt "${FREE_WARN_MB:-300}" ]; then touch "$st"; proj_notify "Pouco espaço livre: ${f}MB"; fi
  return 0
}

# @in chave dir  @effect tarefas de fundo disparadas pelo proj_enter
proj_bg() { proj_backup_auto "$1" "$2"; proj_size_refresh "$1" "$2"; proj_clean_auto; proj_free_check; }

# proj backup [alvo] | on [alvo] [intervalo] [manter] | off [alvo] | now [alvo] | ls | restore [alvo] [-f]
# @in on|off|now|ls|restore|<alvo> [args]
# @effect on/off: edita backup.tsv | now: tar.gz verificado | restore: extrai (-f substitui o original, com cópia em pre-restore)
# @ret 0 ok, 1 erro
# @uses proj_resolve proj_lockrun proj_backup_do proj_secs proj_fmt_secs _proj_desc
proj_backup() {
  local a="${1:-now}" s iv keep k secs cnt last arg tgt force i f dest stamp r sz m
  [ $# -gt 0 ] && shift
  case "$a" in
    all)
      case "$1" in on|1) k=1;; off|0) k=0;; *) echo "BKP_ALL=${BKP_ALL:-0}  (uso: proj b all on|off)"; return;; esac
      proj_config BKP_ALL "$k" >/dev/null; proj_cfg_load
      if [ "$k" = 1 ]; then echo "Backup automático ${PC_G}ligado${PC_RST} em todos (a cada $BKP_IV, mantém $BKP_KEEP)."
      else echo "Backup em todos ${PC_R}desligado${PC_RST} (os individuais continuam)."; fi;;
    on)
      case "$1" in [0-9]*[mhdw]) set -- . "$@";; esac   # "proj b on 12h" vale pro projeto atual
      proj_resolve "$1" || return 1
      iv="${2:-$BKP_IV}"; keep="${3:-$BKP_KEEP}"
      s=$(proj_secs "$iv") || return 1
      case "$keep" in ''|*[!0-9]*|0) echo "Valor de 'manter' inválido: $keep" >&2; return 1;; esac
      awk -F'\t' -v k="$T_K" '$1!=k' "$BKP_CFG" > "$BKP_CFG.tmp"
      printf '%s\t%s\t%s\n' "$T_K" "$s" "$keep" >> "$BKP_CFG.tmp"
      mv "$BKP_CFG.tmp" "$BKP_CFG"
      echo "Backup ${PC_G}ativo${PC_RST}: $T_K a cada $iv, mantém $keep";;
    off)
      proj_resolve "$1" || return 1
      awk -F'\t' -v k="$T_K" '$1!=k' "$BKP_CFG" > "$BKP_CFG.tmp" 2>/dev/null
      mv "$BKP_CFG.tmp" "$BKP_CFG"; echo "Backup desativado: $T_K";;
    now|n)
      proj_resolve "$1" || return 1
      keep=
      while IFS=$'\t' read -r k _ m; do [ "$k" = "$T_K" ] && { keep=$m; break; }; done < "$BKP_CFG"
      proj_lockrun "bk-$T_K" proj_backup_do "$T_K" "$T_D" "${keep:-$BKP_KEEP}"; r=$?
      case $r in
        0) _proj_desc "$PROJ_BKP/$T_K"/*.tar.gz; f="${BK_F[0]}"
           sz=$(stat -c %s "$f" 2>/dev/null)
           echo "Backup feito: $T_K ($(proj_hum "$sz"), verificado)";;
        99) echo "Já há um backup de $T_K em andamento.";;
        *) echo "Backup FALHOU: $T_K"; return 1;;
      esac;;
    ls|l)
      [ -s "$BKP_CFG" ] || { echo "Nenhum backup ativado."; return; }
      printf '%s%-22s %-8s %-6s %-5s %s%s\n' "$PC_D" PROJETO INTERV MANTER QTD ULTIMO "$PC_RST"
      while IFS=$'\t' read -r k secs keep; do
        if _proj_desc "$PROJ_BKP/$k"/*.tar.gz; then
          cnt=${#BK_F[@]}
          printf -v last '%(%d/%m %H:%M)T' "$(stat -c %Y "${BK_F[0]}")"
        else cnt=0; last="nunca"; fi
        printf '%s%-22s%s %-8s %-6s %-5s %s\n' "$PC_B" "$k" "$PC_RST" "$(proj_fmt_secs "$secs")" "$keep" "$cnt" "$last"
      done < "$BKP_CFG";;
    restore|r)
      force=""; tgt=""
      for arg in "$@"; do if [ "$arg" = "-f" ]; then force=1; else tgt="$arg"; fi; done
      proj_resolve "$tgt" || return 1
      _proj_desc "$PROJ_BKP/$T_K"/*.tar.gz || { echo "Sem backups de $T_K."; return 1; }
      echo "Backups de $T_K (mais novo primeiro):"
      for i in "${!BK_F[@]}"; do echo "$((i+1))) ${BK_F[i]##*/}"; done
      read -rp "Qual? [1] " i; i="${i:-1}"
      f=
      [[ $i =~ ^[0-9]+$ ]] && (( i >= 1 )) && f="${BK_F[i-1]:-}"
      [ -z "$f" ] && { echo "Opção inválida."; return 1; }
      printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
      if [ -n "$force" ]; then
        mkdir -p "$PROJ_BKP/pre-restore"
        tar -czf "$PROJ_BKP/pre-restore/$T_K-$stamp.tar.gz" \
          -C "${T_D%/*}" "${T_D##*/}" || { echo "Falhou o backup de segurança."; return 1; }
        rm -rf "$T_D" && tar -xzf "$f" -C "${T_D%/*}" &&
          echo "Restaurado em $T_D (versão anterior guardada em $PROJ_BKP/pre-restore)" &&
          cd "$T_D" || return
      else
        dest="$HOME/proj-restaurado/$T_K-$stamp"
        mkdir -p "$dest" && tar -xzf "$f" -C "$dest" &&
          echo "Restaurado em: $dest/${T_D##*/}  (use -f pra substituir o original)"
      fi;;
    *)
      if proj_resolve "$a" q; then proj_backup now "$a"
      else echo "proj b [alvo] | on [alvo] [intervalo] [manter] | off | ls | restore [alvo] [-f]"; fi;;
  esac
}
