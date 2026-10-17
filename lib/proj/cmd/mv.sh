# cmd/mv.sh - proj mv <alvo> [-n nome] [-v versao] [-c categoria]
# @effect move a pasta, atualiza README, renomeia chave de estado/backup, rescan
# @uses proj_resolve proj_valid_* proj_readme_set proj_key_rename proj_scan
proj_mv() {
  local alvo="" nn="" nv="" nc="" oc wasin=0 dest oldk newk od
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|-v|-c) [ $# -ge 2 ] || { echo "Faltou valor para $1" >&2; return 1; }
        case "$1" in -n) nn="$2";; -v) nv="$2";; -c) nc="$2";; esac; shift 2;;
      *) alvo="$1"; shift;;
    esac
  done
  [ -z "$nn$nv$nc" ] && { echo "uso: proj mv <alvo> [-n nome] [-v versao] [-c categoria]"; return 1; }
  case "${alvo:-.}" in .|*@*) ;; *) alvo="$alvo@?";; esac
  proj_resolve "${alvo:-.}" || return 1
  IFS=$'\t' read -r _ _ _ _ oc _ <<<"$T_L"
  [ "$oc" = - ] && oc=inbox
  nn="${nn:-$T_N}"; nv="${nv:-$T_V}"; nc="${nc:-$oc}"
  proj_valid_name "$nn" || { echo "Nome inválido." >&2; return 1; }
  proj_valid_name "$nv" || { echo "Versão inválida." >&2; return 1; }
  proj_valid_cat "$nc"  || { echo "Categoria inválida." >&2; return 1; }
  dest="$PROJ_BASE/projects/$nc/$nn-$nv"; od="$T_D"; oldk="$T_K"; newk="$nn-$nv"
  [ "$dest" = "$od" ] && { echo "Nada a mudar."; return 0; }
  [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
  case "$PWD" in "$od"|"$od"/*) wasin=1;; esac
  mkdir -p "${dest%/*}" && mv "$od" "$dest" || return 1
  proj_readme_set "$dest" nome "$nn"; proj_readme_set "$dest" versao "$nv"; proj_readme_set "$dest" categoria "$nc"
  [ "$oldk" != "$newk" ] && proj_key_rename "$oldk" "$newk"
  proj_scan full >/dev/null
  [ $wasin = 1 ] && { cd "$dest" || return; }
  echo "Movido: $od -> $dest"
}
