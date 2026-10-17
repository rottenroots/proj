# cmd/archive.sh - proj archive [alvo] | ls | restore <nome-versao>
# @effect move projeto entre projects/ e archive/, rescan
proj_archive() {
  local d dest cat
  case "$1" in
    ls) ls -1 "$PROJ_BASE/archive" 2>/dev/null; return;;
    restore|r)
      [ -z "$2" ] && { echo "uso: proj archive restore <nome-versao>   (veja: proj archive ls)"; return 1; }
      d="$PROJ_BASE/archive/$2"; [ -d "$d" ] || { echo "Não existe: $d"; return 1; }
      cat=$(sed -n 's/^categoria:[ \t]*//{p;q}' "$d/README.md" 2>/dev/null)
      { [ -z "$cat" ] || [ "$cat" = - ]; } && cat=inbox
      proj_valid_cat "$cat" || cat=inbox
      dest="$PROJ_BASE/projects/$cat/$2"
      [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
      mkdir -p "${dest%/*}" && mv "$d" "$dest" && proj_scan full >/dev/null &&
        echo "Desarquivado: $dest"; return;;
  esac
  case "${1:-.}" in .|*@*) set -- "${1:-.}";; *) set -- "$1@?";; esac
  proj_resolve "$1" || return 1
  dest="$PROJ_BASE/archive/$T_K"
  [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
  case "$PWD" in "$T_D"|"$T_D"/*) cd "${T_D%/*}" || cd "$HOME";; esac
  mkdir -p "$PROJ_BASE/archive" && mv "$T_D" "$dest" || return 1
  proj_scan full >/dev/null
  echo "Arquivado em: $dest  (volta com: proj archive restore $T_K)"
}
