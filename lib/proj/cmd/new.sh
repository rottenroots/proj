# cmd/new.sh - proj new nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]
# @effect cria pasta + README com cabeçalho, registra e entra (cd)
# @uses proj_resolve proj_bump proj_valid_* proj_tag_del proj_readme_set proj_scan proj_enter
proj_new() {
  local nome="" ver="" categ="" tags="" desc="" base="" pos=0 d srcd="" bsel now
  local bdesc bcat bt
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|-t|-d|-b)
        [ $# -ge 2 ] || { echo "Faltou valor para $1" >&2; return 1; }
        case "$1" in -c) categ="$2";; -t) tags="$2";; -d) desc="$2";; -b) base="$2";; esac
        shift 2;;
      *) pos=$((pos+1)); if [ $pos = 1 ]; then nome="$1"; else ver="$1"; fi; shift;;
    esac
  done
  [ -z "$nome" ] && { echo 'uso: proj new nome [versao] [-c cat/sub] [-t tags] [-d "desc"] [-b versao_base|.]'; return 1; }
  proj_valid_name "$nome" || { echo "Nome inválido (use letras, números, . _ -)" >&2; return 1; }
  if [ -n "$base" ]; then
    bsel="$nome"; [ "$base" != . ] && bsel="$nome@$base"
    proj_resolve "$bsel" || return 1
    if [ -z "$ver" ]; then
      ver=$(proj_bump "$T_V") || { echo "Não consegui incrementar '$T_V'; informe a versão." >&2; return 1; }
    fi
    IFS=$'\t' read -r _ _ _ bdesc bcat bt _ <<<"$T_L"
    [ -z "$categ" ] && categ="$bcat"
    [ -z "$tags" ] && tags=$(proj_tag_del "$bt" "$IMUNE_TAG")   # cópia não herda imunidade
    [ -z "$desc" ] && { desc="$bdesc"; [ "$desc" = - ] && desc=""; }
    srcd="$T_D"
  fi
  ver="${ver:-1.0}"; categ="${categ:-inbox}"; [ "$categ" = - ] && categ=inbox
  proj_valid_name "$ver"   || { echo "Versão inválida: $ver" >&2; return 1; }
  proj_valid_cat "$categ"  || { echo "Categoria inválida: $categ (use letras, números, . _ - e / para subpastas)" >&2; return 1; }
  proj_valid_tags "$tags"  || { echo "Tags inválidas (use letras, números, . _ - separadas por vírgula)" >&2; return 1; }
  desc="${desc//$'\n'/ }"; desc="${desc//-->/->}"
  d="$PROJ_BASE/projects/$categ/$nome-$ver"
  [ -e "$d" ] && { echo "Já existe: $d"; return 1; }
  printf -v now '%(%Y-%m-%d %H:%M)T' -1
  if [ -n "$srcd" ]; then
    mkdir -p "$d" && tar -C "$srcd" --exclude=node_modules --exclude=.cache -cf - . | tar -C "$d" -xf - ||
      { echo "Falha ao copiar de $srcd" >&2; return 1; }
    proj_readme_set "$d" nome "$nome"; proj_readme_set "$d" versao "$ver"
    proj_readme_set "$d" categoria "$categ"; proj_readme_set "$d" tags "$tags"
    proj_readme_set "$d" criado "$now"
    [ -n "$desc" ] && proj_readme_set "$d" descricao "$desc"
  else
    mkdir -p "$d"/{src,resources,docs,refs}
    printf '<!-- proj\nnome: %s\nversao: %s\ncategoria: %s\ntags: %s\ncriado: %s\ndescricao: %s\n-->\n\n# %s\n\n%s\n' \
      "$nome" "$ver" "$categ" "$tags" "$now" "$desc" "$nome" "$desc" > "$d/README.md"
  fi
  proj_scan | grep -F "'$nome'"   # mostra só o aviso de conflito, se houver
  proj_resolve "$nome@$ver" q && proj_enter
}
