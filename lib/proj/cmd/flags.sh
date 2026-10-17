# cmd/flags.sh - lock/unlock (imunidade), fav/unfav, tag
# @uses proj_resolve proj_tag_add proj_tag_del proj_readme_set proj_idx_set proj_imune_sync proj_st_set

# @in on|off [alvo]
proj_lock() {
  proj_resolve "${2:-.}" || return 1
  local tags new
  IFS=$'\t' read -r _ _ _ _ _ tags _ <<<"$T_L"
  [ "$tags" = - ] && tags=""
  if [ "$1" = on ]; then new=$(proj_tag_add "$tags" "$IMUNE_TAG"); else new=$(proj_tag_del "$tags" "$IMUNE_TAG"); fi
  proj_readme_set "$T_D" tags "$new" || { echo "README não encontrado em $T_D" >&2; return 1; }
  proj_idx_set "$T_D" 6 "${new:--}"
  proj_imune_sync
  if [ "$1" = on ]; then echo "🔒 $T_K agora é imune (rm, --purge e clean não tocam nele)."
  else echo "🔓 $T_K não é mais imune."; fi
}

# @in 1|0 [alvo]
proj_fav() {
  proj_resolve "${2:-.}" || return 1
  proj_st_set "$T_K" "6:$1"
  [ "$1" = 1 ] && echo "★ $T_K fixado no topo." || echo "$T_K desfixado."
}

# @in add|rm <tag> [alvo]  |  ls [alvo]
proj_tag() {
  local op="$1" tg="$2" cur new
  case "$op" in
    ls) proj_resolve "${2:-.}" || return 1
        IFS=$'\t' read -r _ _ _ _ _ cur _ <<<"$T_L"
        echo "${cur//,/ }"; return;;
    add|rm) ;;
    *) echo "uso: proj tag add|rm <tag> [alvo]  |  proj tag ls [alvo]"; return 1;;
  esac
  [[ "$tg" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo "Tag inválida." >&2; return 1; }
  [ "$tg" = "$IMUNE_TAG" ] && { echo "Use proj lock/unlock para a tag '$IMUNE_TAG'." >&2; return 1; }
  proj_resolve "${3:-.}" || return 1
  IFS=$'\t' read -r _ _ _ _ _ cur _ <<<"$T_L"
  [ "$cur" = - ] && cur=""
  if [ "$op" = add ]; then new=$(proj_tag_add "$cur" "$tg"); else new=$(proj_tag_del "$cur" "$tg"); fi
  proj_readme_set "$T_D" tags "$new" && proj_idx_set "$T_D" 6 "${new:--}" && echo "tags: ${new:-(nenhuma)}"
}
