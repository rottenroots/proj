# core/tags.sh - tags separadas por vírgula ("a,b,c"; "-" = vazio)

# @in tag  @g IMUNE_TAG  @ret 0 se a lista $1 contém a tag de imunidade
proj_is_imune() { case ",$1," in *",${IMUNE_TAG:-imune},"*) return 0;; esac; return 1; }

# @in lista tag  @out lista com tag (sem duplicar)
proj_tag_add() {
  local IFS=,; local out="" t seen=0
  for t in $1; do [ "$t" = - ] && continue; [ "$t" = "$2" ] && seen=1; out="${out:+$out,}$t"; done
  [ $seen = 1 ] || out="${out:+$out,}$2"
  echo "$out"
}

# @in lista tag  @out lista sem a tag
proj_tag_del() {
  local IFS=,; local out="" t
  for t in $1; do [ "$t" = "$2" ] || [ "$t" = - ] || out="${out:+$out,}$t"; done
  echo "$out"
}
