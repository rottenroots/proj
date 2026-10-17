# cmd/vendor.sh - bibliotecas/dirs copiados em $PROJ_BASE/vendor
# proj vendor add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>
# @in add <projeto|url|caminho> [nome] | ls | use <nome> | rm <nome>
# @effect copia/clona em $PROJ_BASE/vendor; use cria symlink em refs/  @ret 1 erro
proj_vendor() {
  local a="$1" src nome dest srcdir ans s
  case "$a" in
    add)
      src="$2"
      [ -z "$src" ] && { echo "uso: proj vendor add <projeto[@versao]|url|caminho> [nome]"; return 1; }
      case "$src" in
        http*|git@*)   # URL: clona
          s="${src%.git}"; nome="${3:-${s##*/}}"; dest="$PROJ_BASE/vendor/$nome"
          proj_valid_name "$nome" || { echo "Nome inválido: $nome" >&2; return 1; }
          [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
          mkdir -p "$PROJ_BASE/vendor"
          git clone --depth 1 "$src" "$dest" && echo "vendor/$nome pronto"
          return;;
      esac
      if proj_resolve "$src" q; then   # projeto registrado
        srcdir="$T_D"; nome="${3:-$T_N}"
      elif [ -d "$src" ]; then         # caminho
        s="${src%/}"; srcdir="$src"; nome="${3:-${s##*/}}"
      else
        echo "Não achei projeto, caminho nem URL: $src"
        echo "Dica: proj ls  (lista os projetos registrados)"
        return 1
      fi
      proj_valid_name "$nome" || { echo "Nome inválido: $nome" >&2; return 1; }
      dest="$PROJ_BASE/vendor/$nome"
      [ -e "$dest" ] && { echo "Já existe: $dest"; return 1; }
      mkdir -p "$dest" &&
      tar -C "$srcdir" --exclude=node_modules --exclude=.cache -cf - . |
        tar -C "$dest" -xf - &&
      echo "vendor/$nome pronto (de $srcdir)";;
    ls|l) ls -1 "$PROJ_BASE/vendor";;
    use|u)
      proj_resolve . || return 1
      [ -d "$PROJ_BASE/vendor/$2" ] || { echo "vendor/$2 não existe"; return 1; }
      mkdir -p "$T_D/refs"; ln -sfn "$PROJ_BASE/vendor/$2" "$T_D/refs/$2"
      echo "refs/$2 -> vendor/$2";;
    rm|remove)
      [ -z "$2" ] && { echo "uso: proj vendor rm <nome>"; return 1; }
      dest="$PROJ_BASE/vendor/$2"
      [ -d "$dest" ] || { echo "vendor/$2 não existe"; return 1; }
      read -rp "Apagar vendor/$2? [s/N] " ans
      case "$ans" in s|S|y|Y) rm -rf "$dest" && echo "vendor/$2 removido";; *) echo "Cancelado.";; esac;;
    *) echo "proj vendor add <projeto[@versao]|url|caminho> [nome] | ls | use <nome> | rm <nome>";;
  esac
}
