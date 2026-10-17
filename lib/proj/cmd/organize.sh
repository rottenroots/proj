# cmd/organize.sh - proj organize [-n]   (-n = só mostra o que faria)
# @effect acha READMEs proj em $HOME (prof. 4) e $PROJ_BASE e move p/ projects/<cat>/<nome-versao>
# @uses proj_readmes proj_valid_cat proj_readme_set proj_scan
proj_organize() {
  local dry="" n v d desc c t cr c2 dest tmp
  [ "$1" = "-n" ] && dry=1
  tmp=$(mktemp)
  { proj_readmes "$HOME" 4; proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}"; } |
    sort -u -t$'\t' -k3,3 > "$tmp"
  while IFS=$'\t' read -r n v d desc c t cr; do
    if [ -z "$c" ] || [ "$c" = "-" ]; then
      c="inbox"
      if [ -z "$dry" ] && [ -r /dev/tty ]; then
        read -rp "Categoria de $n-$v [inbox]: " c2 </dev/tty
        c="${c2:-inbox}"
      fi
    fi
    proj_valid_cat "$c" || { echo "Categoria inválida para $n-$v: $c (pulado)"; continue; }
    dest="$PROJ_BASE/projects/$c/$n-$v"
    [ "$d" = "$dest" ] && continue
    if [ -e "$dest" ]; then echo "Pulado (destino existe): $dest"; continue; fi
    echo "$d -> $dest"
    [ -n "$dry" ] && continue
    mkdir -p "${dest%/*}" && mv "$d" "$dest" || continue
    proj_readme_set "$dest" categoria "$c"
  done < "$tmp"
  rm -f "$tmp"
  [ -z "$dry" ] && proj_scan full
}
