# store/scan.sh - varre READMEs, reconstrói índice e atalhos
# Pipeline: proj_readmes (find|grep) -> proj_parse (awk) -> index.tsv -> proj_regen

# @in stdin: caminhos de README (1 por linha)  @out TSV: nome versao dir desc cat tags criado
proj_parse() {
  xargs -d '\n' -r awk -F: '
    FNR==1 { h=0; delete a; d=FILENAME; sub(/\/[^\/]*$/,"",d) }
    /^<!-- proj/ { h=1; next }
    h && /-->/ { h=0
      if (a["nome"]!="") {
        if (a["versao"]=="") a["versao"]="0"
        if (a["descricao"]=="") a["descricao"]="-"
        if (a["categoria"]=="") a["categoria"]="-"
        if (a["tags"]=="") a["tags"]="-"
        if (a["criado"]=="") a["criado"]="-"
        print a["nome"]"\t"a["versao"]"\t"d"\t"a["descricao"]"\t"a["categoria"]"\t"a["tags"]"\t"a["criado"]
      }
      next }
    h { i=index($0,":"); if (i) { k=substr($0,1,i-1); v=substr($0,i+1)
        gsub(/^[ \t]+|[ \t]+$/,"",k); gsub(/^[ \t]+|[ \t]+$/,"",v); a[k]=v } }
  '
}

# @in raiz profundidade [stamp]  @out TSV (via proj_parse). Com stamp: só READMEs mais novos
proj_readmes() {
  local newer=()
  [ -n "$3" ] && newer=(-newer "$3")
  find "$1" -maxdepth "$2" \
    \( -name .git -o -name node_modules -o -name .cache -o -name .npm \
       -o -name .config -o -name .local -o -path "$PROJ_BASE/vendor" \
       -o -path "$PROJ_BASE/archive" \) -prune -o \
    -name README.md "${newer[@]}" -print0 2>/dev/null |
  xargs -0r grep -l '^<!-- proj' 2>/dev/null | proj_parse
}

# @in candidato usados antigos  @ret 0 se o nome já está ocupado
# (sem subshell: declare -F / type -t direto)
proj_taken() {
  case " $2 " in *" $1 "*) return 0;; esac
  if declare -F "$1" >/dev/null; then
    case " $3 " in *" $1 "*) return 1;; esac
    return 0
  fi
  type -t "$1" >/dev/null 2>&1
}

# @in nome  @out REPLY identificador seguro (bytes fora de [A-Za-z0-9_-] viram _)
_proj_ident() { local LC_ALL=C; REPLY=${1//[^A-Za-z0-9_-]/_}; }

# @effect reescreve $PROJ_FN (1 função atalho por projeto) e dá source
# (antes: tr/sed/grep/wc por projeto; agora tudo em bash, 1 escrita só)
proj_regen() {
  local n new o line out="" used="" old="" count=0
  local -A keep=()
  local -a rows=()
  if [ -f "$PROJ_FN" ]; then
    while IFS= read -r line; do
      case $line in *"()"*) old="$old ${line%%"()"*}";; esac
    done < "$PROJ_FN"
  fi
  while read -r n; do
    [ -z "$n" ] && continue
    _proj_ident "$n"; new=$REPLY
    case "$new" in [0-9-]*) new="p$new";; esac
    while proj_taken "$new" "$used" "$old"; do new="${new}x"; done
    used="$used $new"; keep[$new]=1
    printf -v line '%s() { proj_cd %q "$@"; }\n' "$new" "$n"; out+=$line
    if [ "$new" != "$n" ]; then
      echo "aviso: '$n' foi registrado, mas possivelmente poderá ter conflito com um comando ou projeto existente. Atalho criado: '$new' (sufixo x pra evitar conflito). Modifique manualmente se preferir. Digite proj help pra mais informações."
    fi
  done < <(cut -f1 "$PROJ_IDX" 2>/dev/null | sort -u)
  printf '%s' "$out" > "$PROJ_FN"
  . "$PROJ_FN"
  # atalhos de projetos que sumiram deixam de existir na sessão atual
  for o in $old; do [ -n "${keep[$o]:-}" ] || unset -f "$o"; done
  [ -r "$PROJ_IDX" ] && mapfile -t rows < "$PROJ_IDX"
  echo "${#rows[@]} projeto(s) registrado(s)."
}

# @in [full]  @effect reconstrói index.tsv (incremental por padrão), atalhos, imunes, tamanhos
# (antes: 1 grep -Fx por linha do índice; agora array associativo + 1 escrita)
proj_scan() {
  mkdir -p "$PROJ_DIR" "$PROJ_BASE/projects" "$PROJ_BASE/vendor"
  local stamp="$PROJ_DIR/.stamp" novo="$PROJ_DIR/.novo" inc="" tmp
  local n v d desc c t cr
  local -A fresh=()
  [ -f "$stamp" ] && [ -f "$PROJ_IDX" ] && [ "$1" != "full" ] && inc=1
  touch "$stamp.tmp"
  tmp=$(mktemp "$PROJ_IDX.XXXXXX") || return 1
  if [ -n "$inc" ]; then
    proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}" "$stamp" > "$novo"
    while IFS=$'\t' read -r _ _ d _; do [ -n "$d" ] && fresh["$d"]=1; done < "$novo"
    {
      while IFS=$'\t' read -r n v d desc c t cr; do
        [ -d "$d" ] || continue
        [ -n "${fresh["$d"]:-}" ] && continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$v" "$d" "$desc" "$c" "$t" "${cr:--}"
      done < "$PROJ_IDX"
      cat "$novo"
    } > "$tmp"
    rm -f "$novo"
  else
    proj_readmes "$PROJ_BASE" "${PROJ_DEPTH:-6}" > "$tmp"
  fi
  _proj_extras "$tmp"
  mv "$tmp" "$PROJ_IDX"
  mv "$stamp.tmp" "$stamp"
  proj_regen
  proj_imune_sync
  ( proj_size_all >/dev/null 2>&1 & )
}

# @in tmp  acrescenta ao índice-em-construção as pastas de extras.tsv (fora de $PROJ_BASE)
_proj_extras() {
  local d f="$PROJ_DIR/extras.tsv"
  [ -r "$f" ] || return 0
  while IFS= read -r d; do
    [ -f "$d/README.md" ] || continue
    grep -qF "$(printf '\t%s\t' "$d")" "$1" && continue
    printf '%s\n' "$d/README.md" | proj_parse >> "$1"
  done < "$f"
}
