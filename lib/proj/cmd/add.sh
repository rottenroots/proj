# cmd/add.sh - proj add [pasta] [nome] [versao] [-c cat] [-t tags] [-d "desc"]
# @effect registra uma pasta existente (cria/completa o cabeçalho do README; não move nada)
proj_add() {
  local dir="" nome="" ver="" categ="" tags="" desc="" pos=0 now tmp rel rest
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|-t|-d) [ $# -ge 2 ] || { echo "Faltou valor para $1" >&2; return 1; }
        case "$1" in -c) categ="$2";; -t) tags="$2";; -d) desc="$2";; esac; shift 2;;
      *) pos=$((pos+1))
         case $pos in 1) dir="$1";; 2) nome="$1";; 3) ver="$1";; esac; shift;;
    esac
  done
  dir=$(cd "${dir:-.}" 2>/dev/null && pwd -P) || { echo "Pasta não existe." >&2; return 1; }
  case "$dir" in /|"$HOME") echo "Recusado: $dir" >&2; return 1;; esac

  # já tem cabeçalho? só registra
  if [ -f "$dir/README.md" ] && grep -q '^<!-- proj' "$dir/README.md"; then
    echo "README já tem cabeçalho; só registrando."
  else
    # infere de .../projects/<cat>/<nome>-<versao>
    case "$dir" in "$PROJ_BASE"/projects/*/*-*)
      rel="${dir#"$PROJ_BASE"/projects/}"; rest="${rel##*/}"
      [ -z "$categ" ] && categ="${rel%/*}"
      [ -z "$ver" ]   && ver="${rest##*-}"
      [ -z "$nome" ]  && nome="${rest%-*}";;
    esac
    nome="${nome:-${dir##*/}}"; ver="${ver:-1.0}"; categ="${categ:-inbox}"
    proj_valid_name "$nome" || { echo "Nome inválido: $nome (passe outro: proj add . nome)" >&2; return 1; }
    proj_valid_name "$ver"  || { echo "Versão inválida: $ver" >&2; return 1; }
    proj_valid_cat "$categ" || { echo "Categoria inválida: $categ" >&2; return 1; }
    proj_valid_tags "$tags" || { echo "Tags inválidas." >&2; return 1; }
    desc="${desc//$'\n'/ }"; desc="${desc//-->/->}"
    printf -v now '%(%Y-%m-%d %H:%M)T' -1
    tmp=$(mktemp) || return 1
    printf '<!-- proj\nnome: %s\nversao: %s\ncategoria: %s\ntags: %s\ncriado: %s\ndescricao: %s\n-->\n\n' \
      "$nome" "$ver" "$categ" "$tags" "$now" "$desc" > "$tmp"
    if [ -f "$dir/README.md" ]; then cat "$dir/README.md" >> "$tmp"
    else printf '# %s\n\n%s\n' "$nome" "$desc" >> "$tmp"; fi
    cat "$tmp" > "$dir/README.md"; rm -f "$tmp"
  fi

  case "$dir" in "$PROJ_BASE"/*) ;; *)
    grep -qxF -- "$dir" "$PROJ_DIR/extras.tsv" 2>/dev/null || echo "$dir" >> "$PROJ_DIR/extras.tsv";;
  esac
  proj_scan full | grep -F "'" ; true
  echo "Registrado: $dir"
}
