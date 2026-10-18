# cmd/doctor.sh - proj doctor [-f]
# Verifica dependências, registros órfãos, imunes sumidos, duplicados, atalhos, backups sem dono.
# (antes: 1 awk no índice por backup/pasta e cut|sort|uniq; agora: um array com as chaves do índice)
# @in [-f]  @out stdout diagnóstico  @effect -f: scan full + limpa backup.tsv órfão  @ret 0
proj_doctor() {
  local fix="" issues=0 x n v d k o new dups="" t
  local -A have=() seen=()
  [ "$1" = -f ] && fix=1
  _ok()  { printf '  %s✓%s %s\n' "$PC_G" "$PC_RST" "$1"; }
  _bad() { printf '  %s✗%s %s\n' "$PC_R" "$PC_RST" "$1"; issues=$((issues+1)); }
  echo "${PC_B}proj doctor${PC_RST}"
  for x in tar find du awk sed xargs; do command -v "$x" >/dev/null 2>&1 || _bad "falta o comando: $x"; done
  command -v git >/dev/null 2>&1 || echo "  ${PC_D}· git ausente (opcional: vendor via URL e info)${PC_RST}"
  command -v termux-notification >/dev/null 2>&1 || echo "  ${PC_D}· termux-api ausente (opcional: notificações)${PC_RST}"
  while IFS=$'\t' read -r n v d x; do
    [ -d "$d" ] || _bad "registro órfão: $n-$v ($d)"
    k="$n-$v"
    [ -n "${seen[$k]:-}" ] && dups="$dups $n@$v"
    seen[$k]=1; have[$k]=1
  done < "$PROJ_IDX"
  while IFS=$'\t' read -r k d; do
    [ -z "$k" ] && continue
    [ -d "$d" ] || _bad "🔒 PROJETO IMUNE SUMIU: $k ($d). Restaure: proj undo ls / proj archive ls"
  done < "$PROJ_IMU"
  [ -n "$dups" ] && _bad "nome+versão duplicados:$dups"
  while IFS=' ' read -r new o; do
    [ -n "$new" ] && [ "$new" != "$o" ] && echo "  ${PC_Y}!${PC_RST} atalho '$new' aponta para '$o' (conflito de nome evitado)"
  done < <(sed -n 's/^\([^(]*\)() { proj_cd \([^ ]*\) "$@"; }$/\1 \2/p' "$PROJ_FN" 2>/dev/null)
  while IFS=$'\t' read -r k x x; do
    [ -z "$k" ] && continue
    [ -n "${have[$k]:-}" ] || _bad "backup.tsv sem projeto: $k"
  done < "$BKP_CFG"
  if [ -d "$PROJ_BKP" ]; then
    for d in "$PROJ_BKP"/*/; do
      k="${d%/}"; k="${k##*/}"
      case "$k" in removidos|pre-restore|_config|'*') continue;; esac
      [ -n "${have[$k]:-}" ] || echo "  ${PC_Y}!${PC_RST} backups sem projeto registrado: $k"
    done
  fi
  x=$(proj_free_mb "$HOME")
  if [ "${x:-999999}" -lt "$FREE_WARN_MB" ]; then _bad "pouco espaço livre: ${x}MB"; else _ok "espaço livre: ${x}MB"; fi
  if [ -n "$fix" ]; then
    proj_scan full >/dev/null
    have=()
    while IFS=$'\t' read -r n v _; do have["$n-$v"]=1; done < "$PROJ_IDX"
    while IFS=$'\t' read -r k x x; do
      [ -z "$k" ] && continue
      [ -n "${have[$k]:-}" ] || proj_key_drop "$k"
    done < "$BKP_CFG"
    echo "  corrigido: reescaneado e backup.tsv limpo (registros imunes sumidos ficam até você restaurar)."
  fi
  [ $issues -eq 0 ] && _ok "tudo certo" || echo "  ${PC_D}$issues problema(s). Rode 'proj doctor -f' para corrigir o que for seguro.${PC_RST}"
  unset -f _ok _bad
}
